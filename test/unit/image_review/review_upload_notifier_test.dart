import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/in_memory_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/sync/simulated_review_uploader.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/review_uploader.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/pending_uploads_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_upload_notifier.dart';

const _shift = 'Jornada Mañana (06:00 – 10:54)';
const _jornada = (chatJid: 'c1', fechaJornada: '2026-01-15', shift: _shift);

ImageReviewRecord _record(
  String id, {
  String shift = _shift,
  String fecha = '2026-01-15',
  ReviewRole rol = ReviewRole.revisor,
  DateTime? registradoEn,
  int total = 1000,
}) => ImageReviewRecord(
  messageId: id,
  chatJid: 'c1',
  shift: shift,
  rol: rol,
  storagePath: 'img_$id.png',
  fechaJornada: fecha,
  form: ImageReviewForm(
    comprobantes: [
      Comprobante(
        codigo: 'A1',
        numeros: rol == ReviewRole.revisor ? const ['0123'] : const [],
        total: total,
      ),
    ],
  ),
  registradoEn: registradoEn ?? DateTime(2026, 1, 15, 8),
  registradoPor: 'a@x.com',
);

/// Uploader falso: falla para los ids indicados y permite ejecutar código
/// (p. ej. editar un registro) justo cuando "sube" uno.
class _FakeUploader implements ReviewUploader {
  final Set<String> failIds;
  final Future<void> Function(ImageReviewRecord)? onUpload;
  final List<String> uploaded = [];

  _FakeUploader({this.failIds = const {}, this.onUpload});

  @override
  Future<Either<Failure, Unit>> upload(ImageReviewRecord record) async {
    await onUpload?.call(record);
    if (failIds.contains(record.messageId)) {
      return const Left(Failure.firestore(message: 'sin conexión'));
    }
    uploaded.add(record.messageId);
    return const Right(unit);
  }
}

/// Repositorio cuyo `save` falla para los ids indicados (al marcar).
class _FailingSaveRepository extends InMemoryImageReviewRepository {
  final Set<String> failSaveIds = {};

  @override
  Future<Either<Failure, Unit>> save(ImageReviewRecord record) async {
    if (failSaveIds.contains(record.messageId)) {
      return const Left(Failure.storage(message: 'no se pudo guardar'));
    }
    return super.save(record);
  }
}

void main() {
  late InMemoryImageReviewRepository repo;

  ProviderContainer makeContainer(
    ReviewUploader uploader, {
    ReviewRole rol = ReviewRole.revisor,
  }) {
    final c = ProviderContainer(
      overrides: [
        imageReviewRepositoryProvider.overrideWithValue(repo),
        reviewUploaderProvider.overrideWithValue(uploader),
        currentReviewRoleProvider.overrideWithValue(rol),
        reviewerUidProvider.overrideWithValue('uid-a'),
        reviewerEmailProvider.overrideWithValue('a@x.com'),
      ],
    );
    addTearDown(c.dispose);
    c
        .read(activeChatProvider.notifier)
        .select(
          Chat(chatJid: 'c1', groupName: 'g', lastMessageAt: 0, totalImages: 0),
        );
    return c;
  }

  Future<ImageReviewRecord?> stored(String id) async =>
      (await repo.getByMessageId(
        id,
        ReviewRole.revisor,
      )).fold((_) => fail('Left'), (r) => r);

  setUp(() => repo = InMemoryImageReviewRepository());

  group('SimulatedReviewUploader', () {
    late List<String> printed;
    late DebugPrintCallback original;

    setUp(() {
      original = debugPrint;
      printed = [];
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    });
    tearDown(() => debugPrint = original);

    test('imprime colección, id de documento y datos (sin v ni estadoSync) '
        'y no falla', () async {
      final record = _record('m1', registradoEn: DateTime.utc(2026, 1, 15, 8));

      final result = await const SimulatedReviewUploader().upload(record);

      expect(result.isRight(), isTrue);
      expect(printed, hasLength(1));
      final lines = printed.single.split('\n');
      expect(lines.first, '[SUBIDA SIMULADA] image_reviews/m1_revisor');
      final data = jsonDecode(lines.skip(1).join('\n')) as Map<String, dynamic>;
      expect(data.containsKey('v'), isFalse);
      expect(data.containsKey('estadoSync'), isFalse);
      expect(data, {
        'messageId': 'm1',
        'chatJid': 'c1',
        'shift': _shift,
        'rol': 'revisor',
        'storagePath': 'img_m1.png',
        'fechaJornada': '2026-01-15',
        'comprobantes': [
          {
            'codigo': 'A1',
            'numeros': ['0123'],
            'total': 1000,
          },
        ],
        'anotaciones': null,
        'registradoEn': '2026-01-15T08:00:00.000Z',
        'registradoPor': 'a@x.com',
        'editado': false,
      });
    });

    test('el id del documento lleva el rol', () async {
      await const SimulatedReviewUploader().upload(
        _record('m2', rol: ReviewRole.sumador),
      );
      expect(printed.single, contains('image_reviews/m2_sumador'));
    });
  });

  group('subir una jornada', () {
    test('sube todos los pendientes de esa jornada y los pasa a '
        'sincronizado', () async {
      await repo.save(_record('a'));
      await repo.save(_record('b'));
      final uploader = _FakeUploader();
      final c = makeContainer(uploader);

      final outcome = await c
          .read(reviewUploadProvider.notifier)
          .upload(_jornada);

      expect(outcome!.subidos, 2);
      expect(outcome.todoSubido, isTrue);
      expect(uploader.uploaded, ['a', 'b']);
      expect((await stored('a'))!.estadoSync, EstadoSync.sincronizado);
      expect((await stored('b'))!.estadoSync, EstadoSync.sincronizado);
      expect(await c.read(pendingUploadsProvider.future), isEmpty);
    });

    test('solo sube la jornada pedida, no las demás', () async {
      await repo.save(_record('a'));
      await repo.save(_record('b', shift: 'Jornada Tarde 1'));
      await repo.save(_record('c', fecha: '2026-01-14'));
      final uploader = _FakeUploader();
      final c = makeContainer(uploader);

      await c.read(reviewUploadProvider.notifier).upload(_jornada);

      expect(uploader.uploaded, ['a']);
      expect((await stored('b'))!.estadoSync, EstadoSync.pendiente);
      expect((await stored('c'))!.estadoSync, EstadoSync.pendiente);
      expect(await c.read(pendingUploadsProvider.future), hasLength(2));
    });

    test('falla a medias: los que subieron quedan sincronizados y los que '
        'fallaron siguen pendientes', () async {
      await repo.save(_record('a'));
      await repo.save(_record('b'));
      await repo.save(_record('c'));
      final c = makeContainer(_FakeUploader(failIds: {'b'}));

      final outcome = await c
          .read(reviewUploadProvider.notifier)
          .upload(_jornada);

      expect((outcome!.subidos, outcome.fallidos), (2, 1));
      expect(outcome.todoSubido, isFalse);
      expect((await stored('a'))!.estadoSync, EstadoSync.sincronizado);
      expect((await stored('b'))!.estadoSync, EstadoSync.pendiente);
      expect((await stored('c'))!.estadoSync, EstadoSync.sincronizado);
      final pendientes = await c.read(pendingUploadsProvider.future);
      expect(pendientes.single.cantidad, 1);
    });

    test('un reintento sube solo los que faltaban', () async {
      await repo.save(_record('a'));
      await repo.save(_record('b'));
      final failing = _FakeUploader(failIds: {'b'});
      await makeContainer(
        failing,
      ).read(reviewUploadProvider.notifier).upload(_jornada);

      final ok = _FakeUploader();
      final outcome = await makeContainer(
        ok,
      ).read(reviewUploadProvider.notifier).upload(_jornada);

      expect(ok.uploaded, ['b']);
      expect(outcome!.todoSubido, isTrue);
    });

    test('si se subió pero no se pudo marcar, sigue pendiente (se cuenta '
        'como fallido)', () async {
      final failing = _FailingSaveRepository();
      repo = failing;
      await failing.save(_record('a'));
      failing.failSaveIds.add('a');
      final c = makeContainer(_FakeUploader());

      final outcome = await c
          .read(reviewUploadProvider.notifier)
          .upload(_jornada);

      expect((outcome!.subidos, outcome.fallidos), (0, 1));
      expect((await stored('a'))!.estadoSync, EstadoSync.pendiente);
    });

    test(
      'un registro editado mientras se sube NO se marca sincronizado',
      () async {
        final original = _record('a', registradoEn: DateTime(2026, 1, 15, 8));
        await repo.save(original);
        await repo.save(_record('b'));
        final edited = original.copyWith(
          editado: true,
          registradoEn: DateTime(2026, 1, 15, 9),
        );
        final c = makeContainer(
          _FakeUploader(
            onUpload: (r) async {
              if (r.messageId == 'a') await repo.save(edited);
            },
          ),
        );

        final outcome = await c
            .read(reviewUploadProvider.notifier)
            .upload(_jornada);

        expect((outcome!.subidos, outcome.editados), (1, 1));
        expect(await stored('a'), edited);
        expect((await stored('a'))!.estadoSync, EstadoSync.pendiente);
        expect((await stored('b'))!.estadoSync, EstadoSync.sincronizado);
      },
    );

    test('registros nuevos después de subir hacen reaparecer la jornada y '
        'se pueden volver a subir', () async {
      await repo.save(_record('a'));
      final c = makeContainer(_FakeUploader());
      await c.read(reviewUploadProvider.notifier).upload(_jornada);
      expect(await c.read(pendingUploadsProvider.future), isEmpty);

      await repo.save(_record('late'));
      c.invalidate(pendingUploadsProvider);
      final pendientes = await c.read(pendingUploadsProvider.future);
      expect(pendientes.single.cantidad, 1);

      final outcome = await c
          .read(reviewUploadProvider.notifier)
          .upload(_jornada);
      expect(outcome!.subidos, 1);
    });

    test('sin pendientes no sube nada', () async {
      final uploader = _FakeUploader();
      final c = makeContainer(uploader);

      final outcome = await c
          .read(reviewUploadProvider.notifier)
          .upload(_jornada);

      expect(outcome!.subidos, 0);
      expect(outcome.todoSubido, isTrue);
      expect(uploader.uploaded, isEmpty);
    });

    test('solo sube los del rol activo', () async {
      await repo.save(_record('a'));
      await repo.save(_record('s', rol: ReviewRole.sumador));
      final uploader = _FakeUploader();
      final c = makeContainer(uploader, rol: ReviewRole.sumador);

      await c.read(reviewUploadProvider.notifier).upload(_jornada);

      expect(uploader.uploaded, ['s']);
      expect((await stored('a'))!.estadoSync, EstadoSync.pendiente);
    });

    test('una jornada que ya se está subiendo no se sube dos veces', () async {
      await repo.save(_record('a'));
      final uploader = _FakeUploader(
        onUpload: (_) => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      final c = makeContainer(uploader);
      final notifier = c.read(reviewUploadProvider.notifier);

      final first = notifier.upload(_jornada);
      expect(notifier.isUploading(_jornada), isTrue);
      final second = await notifier.upload(_jornada);
      final firstOutcome = await first;

      expect(second, isNull);
      expect(firstOutcome!.subidos, 1);
      expect(uploader.uploaded, ['a']);
      expect(notifier.isUploading(_jornada), isFalse);
    });
    test('salir del chat a mitad corta el lote: lo ya subido queda '
        'sincronizado y el resto pendiente', () async {
      for (final id in ['a', 'b', 'c', 'd']) {
        await repo.save(_record(id));
      }
      late ProviderContainer c;
      final uploader = _FakeUploader(
        onUpload: (r) async {
          // Mientras se sube 'b', el usuario abre otro chat.
          if (r.messageId == 'b') {
            c
                .read(activeChatProvider.notifier)
                .select(
                  Chat(
                    chatJid: 'otro',
                    groupName: 'otro',
                    lastMessageAt: 0,
                    totalImages: 0,
                  ),
                );
          }
        },
      );
      c = makeContainer(uploader);

      final outcome = await c
          .read(reviewUploadProvider.notifier)
          .upload(_jornada);

      // 'b' ya se había subido cuando se detectó el corte: queda marcado.
      expect(uploader.uploaded, ['a', 'b']);
      expect((outcome!.subidos, outcome.sinIntentar), (2, 2));
      expect(outcome.todoSubido, isFalse);
      expect((await stored('a'))!.estadoSync, EstadoSync.sincronizado);
      expect((await stored('b'))!.estadoSync, EstadoSync.sincronizado);
      expect((await stored('c'))!.estadoSync, EstadoSync.pendiente);
      expect((await stored('d'))!.estadoSync, EstadoSync.pendiente);
      expect(c.read(reviewUploadProvider), isEmpty);
    });

    test('volver a ese chat permite reintentar el resto', () async {
      for (final id in ['a', 'b']) {
        await repo.save(_record(id));
      }
      late ProviderContainer c;
      c = makeContainer(
        _FakeUploader(
          onUpload: (r) async {
            if (r.messageId == 'a') {
              c.read(activeChatProvider.notifier).clear();
            }
          },
        ),
      );
      await c.read(reviewUploadProvider.notifier).upload(_jornada);
      expect((await stored('b'))!.estadoSync, EstadoSync.pendiente);

      final ok = _FakeUploader();
      final c2 = makeContainer(ok);
      final outcome = await c2
          .read(reviewUploadProvider.notifier)
          .upload(_jornada);

      expect(ok.uploaded, ['b']);
      expect(outcome!.todoSubido, isTrue);
    });

    test('descartar el notifier a mitad corta el lote sin error', () async {
      for (final id in ['a', 'b', 'c']) {
        await repo.save(_record(id));
      }
      late ProviderContainer c;
      final uploader = _FakeUploader(
        onUpload: (r) async {
          if (r.messageId == 'a') c.dispose();
        },
      );
      c = makeContainer(uploader);

      final outcome = await c
          .read(reviewUploadProvider.notifier)
          .upload(_jornada);

      expect(uploader.uploaded, ['a']);
      expect((outcome!.subidos, outcome.sinIntentar), (1, 2));
      expect((await stored('a'))!.estadoSync, EstadoSync.sincronizado);
      expect((await stored('b'))!.estadoSync, EstadoSync.pendiente);
    });

    test('expone el avance real "hechos de total" mientras sube', () async {
      for (final id in ['a', 'b', 'c']) {
        await repo.save(_record(id));
      }
      final c = makeContainer(_FakeUploader(failIds: {'b'}));
      final seen = <UploadProgress?>[];
      c.listen(
        reviewUploadProvider,
        (_, next) => seen.add(next[_jornada]),
        fireImmediately: false,
      );

      await c.read(reviewUploadProvider.notifier).upload(_jornada);

      expect(seen, [
        (hechos: 0, total: 0),
        (hechos: 0, total: 3),
        (hechos: 1, total: 3),
        (hechos: 2, total: 3),
        null,
      ]);
    });
  });
}
