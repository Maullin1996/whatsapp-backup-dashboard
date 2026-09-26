import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_local_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/local_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

const _chat = 'chat@g.us';
const _fecha = '2026-01-15';
const _shift = 'Jornada Mañana (06:00 – 10:54)';

ImageReviewRecord _record({
  String messageId = 'm1',
  ReviewRole rol = ReviewRole.revisor,
  String chatJid = _chat,
  String fechaJornada = _fecha,
  String shift = _shift,
  int total = 9000,
  bool editado = false,
  EstadoSync estadoSync = EstadoSync.pendiente,
  DateTime? registradoEn,
}) => ImageReviewRecord(
  messageId: messageId,
  chatJid: chatJid,
  shift: shift,
  rol: rol,
  storagePath: 'img_$messageId.png',
  fechaJornada: fechaJornada,
  form: ImageReviewForm(
    comprobantes: [
      Comprobante(
        codigo: '0457',
        numeros: rol == ReviewRole.revisor ? const ['0123'] : const [],
        total: total,
      ),
    ],
    anotaciones: null,
  ),
  registradoEn: registradoEn ?? DateTime(2026, 1, 15, 8),
  registradoPor: '${rol.name}@example.com',
  editado: editado,
  estadoSync: estadoSync,
);

T _right<T>(Either<Failure, T> e) => e.fold(
  (f) => fail('no se esperaba Left: ${mapFailureToMessage(f)}'),
  (r) => r,
);

Failure _left<T>(Either<Failure, T> e) =>
    e.fold((f) => f, (_) => fail('se esperaba Left'));

void main() {
  late Directory dir;
  ReviewLocalDatasource? datasource;

  Future<ReviewLocalDatasource> open() async {
    final ds = _right(await ReviewLocalDatasource.open(path: dir.path));
    datasource = ds;
    return ds;
  }

  /// Simula una recarga de la página: cierra el almacenamiento y lo reabre.
  Future<ReviewLocalDatasource> reload() async {
    await datasource!.close();
    return open();
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('review_repo_');
    await open();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  LocalImageReviewRepository repoFor(String uid, [ReviewLocalDatasource? ds]) =>
      LocalImageReviewRepository(ds ?? datasource!, uid: uid);

  group('persistencia', () {
    test('guardar, cerrar y reabrir el almacenamiento devuelve el mismo '
        'registro', () async {
      final r = _record(editado: true);
      _right(await repoFor('u1').save(r));

      final reopened = await reload();

      expect(
        _right(
          await repoFor(
            'u1',
            reopened,
          ).getByMessageId('m1', ReviewRole.revisor),
        ),
        r,
      );
    });

    test('un registro inexistente da Right(null)', () async {
      expect(
        _right(await repoFor('u1').getByMessageId('nope', ReviewRole.revisor)),
        isNull,
      );
    });

    test('guardar de nuevo el mismo registro lo actualiza', () async {
      final repo = repoFor('u1');
      await repo.save(_record(total: 9000));
      final updated = _record(total: 12000, editado: true);
      await repo.save(updated);

      final reopened = await reload();
      expect(
        _right(
          await repoFor(
            'u1',
            reopened,
          ).getByMessageId('m1', ReviewRole.revisor),
        ),
        updated,
      );
    });

    test('el pendiente sigue en la lista tras recargar', () async {
      await repoFor('u1').save(_record());

      final reopened = await reload();

      final pending = _right(
        await repoFor('u1', reopened).getPending(
          chatJid: _chat,
          fechaJornada: _fecha,
          shift: _shift,
          rol: ReviewRole.revisor,
        ),
      );
      expect(pending.map((r) => r.messageId), ['m1']);
    });
  });

  group('separación por usuario', () {
    test('los datos del usuario A no aparecen para B y siguen ahí al volver '
        'a A', () async {
      final a = _record(total: 1000);
      await repoFor('uid-a').save(a);

      expect(
        _right(await repoFor('uid-b').getByMessageId('m1', ReviewRole.revisor)),
        isNull,
      );
      expect(
        _right(
          await repoFor('uid-b').getPending(
            chatJid: _chat,
            fechaJornada: _fecha,
            shift: _shift,
            rol: ReviewRole.revisor,
          ),
        ),
        isEmpty,
      );

      final b = _record(total: 2000);
      await repoFor('uid-b').save(b);

      final reopened = await reload();
      expect(
        _right(
          await repoFor(
            'uid-a',
            reopened,
          ).getByMessageId('m1', ReviewRole.revisor),
        ),
        a,
      );
      expect(
        _right(
          await repoFor(
            'uid-b',
            reopened,
          ).getByMessageId('m1', ReviewRole.revisor),
        ),
        b,
      );
    });

    test('un uid que es prefijo de otro no se mezcla', () async {
      await repoFor('u').save(_record(total: 1));
      await repoFor('u|x').save(_record(total: 2));

      expect(
        _right(
          await repoFor('u').getByMessageId('m1', ReviewRole.revisor),
        )!.form.comprobantes.single.total,
        1,
      );
      final pending = _right(
        await repoFor('u').getPending(
          chatJid: _chat,
          fechaJornada: _fecha,
          shift: _shift,
          rol: ReviewRole.revisor,
        ),
      );
      expect(pending, hasLength(1));
    });
  });

  group('separación por rol', () {
    test(
      'conviven, no se pisan y leer un rol no devuelve el del otro',
      () async {
        final repo = repoFor('u1');
        final revisor = _record(rol: ReviewRole.revisor, total: 9000);
        final sumador = _record(rol: ReviewRole.sumador, total: 9500);
        await repo.save(revisor);
        expect(
          _right(await repo.getByMessageId('m1', ReviewRole.sumador)),
          isNull,
        );
        await repo.save(sumador);
        await repo.save(
          _record(rol: ReviewRole.sumador, total: 9600, editado: true),
        );

        final reopened = await reload();
        final again = repoFor('u1', reopened);
        expect(
          _right(await again.getByMessageId('m1', ReviewRole.revisor)),
          revisor,
        );
        expect(
          _right(
            await again.getByMessageId('m1', ReviewRole.sumador),
          )!.form.comprobantes.single.total,
          9600,
        );
      },
    );
  });

  group('consulta de pendientes', () {
    Future<List<String>> ids(
      LocalImageReviewRepository repo, {
      String chatJid = _chat,
      String fechaJornada = _fecha,
      String shift = _shift,
      ReviewRole rol = ReviewRole.revisor,
    }) async => _right(
      await repo.getPending(
        chatJid: chatJid,
        fechaJornada: fechaJornada,
        shift: shift,
        rol: rol,
      ),
    ).map((r) => r.messageId).toList();

    test('filtra por chat, fecha, jornada y rol', () async {
      final repo = repoFor('u1');
      await repo.save(_record(messageId: 'ok'));
      await repo.save(_record(messageId: 'otro-chat', chatJid: 'otro@g.us'));
      await repo.save(
        _record(messageId: 'otra-fecha', fechaJornada: '2026-01-16'),
      );
      await repo.save(
        _record(messageId: 'otra-jornada', shift: 'Jornada Tarde 1'),
      );
      await repo.save(_record(messageId: 'otro-rol', rol: ReviewRole.sumador));

      expect(await ids(repo), ['ok']);
      expect(await ids(repo, chatJid: 'otro@g.us'), ['otro-chat']);
      expect(await ids(repo, fechaJornada: '2026-01-16'), ['otra-fecha']);
      expect(await ids(repo, shift: 'Jornada Tarde 1'), ['otra-jornada']);
      expect(await ids(repo, rol: ReviewRole.sumador), ['otro-rol']);
    });

    test(
      'no devuelve sincronizados, y un re-guardado pendiente reaparece',
      () async {
        final repo = repoFor('u1');
        await repo.save(_record(messageId: 'a'));
        await repo.save(_record(messageId: 'b'));
        expect(await ids(repo), ['a', 'b']);

        await repo.save(
          _record(messageId: 'a', estadoSync: EstadoSync.sincronizado),
        );
        expect(await ids(repo), ['b']);

        await repo.save(_record(messageId: 'a', editado: true));
        expect(await ids(repo), ['a', 'b']);
      },
    );

    test('solo trae los del usuario actual', () async {
      await repoFor('u1').save(_record(messageId: 'mio'));
      await repoFor('u2').save(_record(messageId: 'ajeno'));

      expect(await ids(repoFor('u1')), ['mio']);
      expect(await ids(repoFor('u2')), ['ajeno']);
    });

    test('van del más antiguo al más nuevo', () async {
      final repo = repoFor('u1');
      await repo.save(
        _record(messageId: 'tarde', registradoEn: DateTime(2026, 1, 15, 10)),
      );
      await repo.save(
        _record(messageId: 'temprano', registradoEn: DateTime(2026, 1, 15, 7)),
      );

      expect(await ids(repo), ['temprano', 'tarde']);
    });

    test(
      'si un registro cambia de jornada, el índice viejo no queda',
      () async {
        final repo = repoFor('u1');
        await repo.save(_record());
        await repo.save(_record(shift: 'Jornada Tarde 1'));

        expect(await ids(repo), isEmpty);
        expect(await ids(repo, shift: 'Jornada Tarde 1'), ['m1']);
      },
    );

    test('datos con "|" en chat o jornada no rompen las claves', () async {
      final repo = repoFor('u1');
      await repo.save(_record(chatJid: 'a|b@g.us', shift: 'Jornada | rara'));

      expect(await ids(repo, chatJid: 'a|b@g.us', shift: 'Jornada | rara'), [
        'm1',
      ]);
      expect(
        await ids(repo, chatJid: 'a', shift: 'b@g.us|Jornada | rara'),
        isEmpty,
      );
    });

    test('un índice viejo de un registro ya sincronizado se ignora', () async {
      final repo = repoFor('u1');
      await repo.save(_record());
      // Simula un corte entre "guardar el registro" y "quitar el índice".
      final box = Hive.lazyBox<String>(ReviewLocalDatasource.boxName);
      final indexKey = box.keys.firstWhere(
        (k) => (k as String).startsWith('p|'),
      );
      await repo.save(_record(estadoSync: EstadoSync.sincronizado));
      await box.put(indexKey, '');

      expect(await ids(repo), isEmpty);
    });
  });

  group('registro ilegible', () {
    late LazyBox<String> box;

    setUp(() => box = Hive.lazyBox<String>(ReviewLocalDatasource.boxName));

    String recordKey(String id) => 'r|u1|revisor|$id';

    test('getByMessageId: el Left identifica cuál falló', () async {
      await box.put(recordKey('m-roto'), '{esto no es json');

      final failure = _left(
        await repoFor('u1').getByMessageId('m-roto', ReviewRole.revisor),
      );

      expect(failure, isA<StorageFailure>());
      expect(mapFailureToMessage(failure), contains('m-roto'));
    });

    test(
      'getByMessageId: un esquema más nuevo también identifica el mensaje',
      () async {
        await repoFor('u1').save(_record(messageId: 'm-futuro'));
        final json = (await box.get(recordKey('m-futuro')))!;
        await box.put(
          recordKey('m-futuro'),
          json.replaceFirst('"v":1', '"v":99'),
        );

        final failure = _left(
          await repoFor('u1').getByMessageId('m-futuro', ReviewRole.revisor),
        );

        expect(mapFailureToMessage(failure), contains('m-futuro'));
      },
    );

    test('getPending: el Left identifica cuál falló', () async {
      await repoFor('u1').save(_record(messageId: 'm-bueno'));
      await repoFor('u1').save(_record(messageId: 'm-roto'));
      await box.put(recordKey('m-roto'), '{"v":1}');

      final failure = _left(
        await repoFor('u1').getPending(
          chatJid: _chat,
          fechaJornada: _fecha,
          shift: _shift,
          rol: ReviewRole.revisor,
        ),
      );

      expect(failure, isA<StorageFailure>());
      expect(mapFailureToMessage(failure), contains('m-roto'));
      expect(mapFailureToMessage(failure), isNot(contains('m-bueno')));
    });

    test('guardar encima de un registro ilegible lo repara', () async {
      await box.put(recordKey('m1'), 'basura');
      await repoFor('u1').save(_record());

      expect(
        _right(await repoFor('u1').getByMessageId('m1', ReviewRole.revisor)),
        _record(),
      );
    });
  });

  group('no se puede abrir el almacenamiento', () {
    test(
      'open devuelve un Left de almacenamiento con mensaje en español',
      () async {
        await datasource!.close();
        final file = File('${dir.path}/no_es_un_directorio')
          ..writeAsStringSync('x');

        final failure = _left(
          await ReviewLocalDatasource.open(path: file.path),
        );

        expect(failure, isA<StorageFailure>());
        expect(
          mapFailureToMessage(failure),
          'No se pudo abrir el almacenamiento local de este dispositivo',
        );
        await open(); // para el tearDown
      },
    );
  });
}
