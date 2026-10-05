import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/firestore_review_remote_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/models/image_review_record_model.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_raw_document.dart';

const _chat = 'c1@g.us';
const _fecha = '2026-01-15';
const _registrosPath =
    'image_reviews/c1@g.us/jornadas/2026-01-15_morning/registros';

ImageReviewRecord _record(String id, {ReviewRole rol = ReviewRole.revisor}) =>
    ImageReviewRecord(
      messageId: id,
      chatJid: _chat,
      shift: shiftNames[Shift.morning]!,
      rol: rol,
      storagePath: 'img_$id.png',
      fechaJornada: _fecha,
      messageTimestamp: 1788489942000,
      form: ImageReviewForm(
        codigo: 'A1',
        comprobantes: [
          Comprobante(
            numeros: rol == ReviewRole.revisor ? const ['0123'] : const [],
            total: 9000,
            loteria: 'Chontico',
          ),
        ],
        anotaciones: 'nota',
      ),
      registradoEn: DateTime.utc(2026, 1, 15, 8),
      registradoPor: 'a@x.com',
      editado: true,
      estadoSync: EstadoSync.pendiente,
    );

/// El documento tal como lo deja la subida real (`toUploadDocument`).
RawDocument _uploaded(String id, {ReviewRole rol = ReviewRole.revisor}) {
  final doc = ImageReviewRecordModel(
    _record(id, rol: rol),
  ).toUploadDocument().getOrElse(() => fail('no se pudo armar'));
  return (id: doc.pathSegments.last, data: doc.data);
}

void main() {
  late List<(String, String)> calls;
  late Future<List<RawDocument>> Function() behavior;
  late FirestoreReviewRemoteRecordsDatasource datasource;

  setUp(() {
    calls = [];
    behavior = () async => [];
    datasource = FirestoreReviewRemoteRecordsDatasource.withReader((path, rol) {
      calls.add((path, rol));
      return behavior();
    });
  });

  Future<Either<Failure, List<ImageReviewRecordModel>>> fetch({
    Shift shift = Shift.morning,
    ReviewRole rol = ReviewRole.revisor,
    FirestoreReviewRemoteRecordsDatasource? ds,
  }) => (ds ?? datasource).fetchJornada(
    chatJid: _chat,
    fechaJornada: _fecha,
    shift: shift,
    rol: rol,
  );

  List<ImageReviewRecordModel> right(
    Either<Failure, List<ImageReviewRecordModel>> result,
  ) => result.getOrElse(() => fail('se esperaba Right: $result'));

  Failure left(Either<Failure, List<ImageReviewRecordModel>> result) =>
      result.fold((f) => f, (r) => fail('se esperaba Left: $r'));

  test('el timeout por defecto es de 15 segundos', () {
    expect(reviewRemoteReadTimeout, const Duration(seconds: 15));
    expect(datasource.timeout, reviewRemoteReadTimeout);
  });

  test(
    'consulta la colección registros de la jornada, filtrada por el rol',
    () async {
      await fetch(rol: ReviewRole.sumador);
      expect(calls, [(_registrosPath, 'sumador')]);
    },
  );

  test('jornada vacía: Right([])', () async {
    expect(right(await fetch()), isEmpty);
  });

  test('convierte lo subido en el mismo registro, como sincronizado', () async {
    behavior = () async => [_uploaded('m1'), _uploaded('m2')];

    final models = right(await fetch());

    expect(models.map((m) => m.record.messageId), ['m1', 'm2']);
    final r = models.first.record;
    final original = _record('m1');
    expect(r.estadoSync, EstadoSync.sincronizado);
    expect(r.form, original.form);
    expect(r.chatJid, original.chatJid);
    expect(r.shift, original.shift);
    expect(r.rol, ReviewRole.revisor);
    expect(r.storagePath, original.storagePath);
    expect(r.fechaJornada, original.fechaJornada);
    expect(r.messageTimestamp, original.messageTimestamp);
    expect(r.registradoEn.isAtSameMomentAs(original.registradoEn), isTrue);
    expect(r.registradoPor, original.registradoPor);
    expect(r.editado, isTrue);
  });

  group('error de lectura: Left, nunca lanza', () {
    test('permission-denied -> Left(unauthorized)', () async {
      behavior = () async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(left(await fetch()), isA<UnauthorizedFailure>());
    });

    test('unavailable (sin conexión, sin caché) -> Left(firestore)', () async {
      behavior = () async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      expect(left(await fetch()), isA<FirestoreFailure>());
    });

    test('cualquier otra excepción -> Left(unknown)', () async {
      behavior = () async => throw StateError('boom');
      expect(left(await fetch()), isA<UnknownFailure>());
    });

    test('la lectura nunca completa: Left al vencer el timeout', () async {
      final never = Completer<List<RawDocument>>();
      final ds = FirestoreReviewRemoteRecordsDatasource.withReader(
        (_, _) => never.future,
        timeout: const Duration(milliseconds: 20),
      );
      expect(left(await fetch(ds: ds)), isA<UnknownFailure>());
    });
  });

  group('documento ilegible: se omite, los demás siguen', () {
    Future<List<String>> idsWith(RawDocument bad) async {
      behavior = () async => [_uploaded('m1'), bad, _uploaded('m3')];
      return [for (final m in right(await fetch())) m.record.messageId];
    }

    test('falta un campo', () async {
      final doc = _uploaded('m2');
      final data = Map<String, dynamic>.of(doc.data)..remove('registradoPor');
      expect(await idsWith((id: doc.id, data: data)), ['m1', 'm3']);
    });

    test('un campo de otro tipo', () async {
      final doc = _uploaded('m2');
      final data = {...doc.data, 'messageTimestamp': '1788489942000'};
      expect(await idsWith((id: doc.id, data: data)), ['m1', 'm3']);
    });

    test('una fecha que no se puede leer', () async {
      final doc = _uploaded('m2');
      final data = {...doc.data, 'registradoEn': 'ayer'};
      expect(await idsWith((id: doc.id, data: data)), ['m1', 'm3']);
    });

    test('deja un debugPrint con la ruta del documento omitido', () async {
      final logs = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      addTearDown(() => debugPrint = previous);
      final doc = _uploaded('m2');
      final data = Map<String, dynamic>.of(doc.data)..remove('comprobantes');

      await idsWith((id: doc.id, data: data));

      expect(logs, [
        '[REVISION] registro subido ilegible, omitido: $_registrosPath/m2_revisor',
      ]);
    });
  });

  group(
    'documento que no corresponde a la consulta: Left que lo identifica',
    () {
      Future<String> messageFor(RawDocument bad) async {
        behavior = () async => [_uploaded('m1'), bad];
        final failure = left(await fetch());
        expect(failure, isA<UnknownFailure>());
        return (failure as UnknownFailure).message;
      }

      test('de otro rol', () async {
        final doc = _uploaded('m2', rol: ReviewRole.sumador);
        expect(await messageFor(doc), contains('m2_sumador'));
      });

      test('con un id que no corresponde a su messageId', () async {
        final doc = _uploaded('m2');
        expect(
          await messageFor((id: 'otro_revisor', data: doc.data)),
          contains('otro_revisor'),
        );
      });

      test('de otra jornada', () async {
        final doc = _uploaded('m2');
        final data = {...doc.data, 'shiftKey': 'afternoon1'};
        expect(
          await messageFor((id: doc.id, data: data)),
          contains('m2_revisor'),
        );
      });

      test('de otro grupo', () async {
        final doc = _uploaded('m2');
        final data = {...doc.data, 'chatJid': 'otro@g.us'};
        expect(
          await messageFor((id: doc.id, data: data)),
          contains('m2_revisor'),
        );
      });

      test('de otra fecha', () async {
        final doc = _uploaded('m2');
        final data = {...doc.data, 'fechaJornada': '2026-01-16'};
        expect(
          await messageFor((id: doc.id, data: data)),
          contains('m2_revisor'),
        );
      });
    },
  );

  test('fuera de jornada: Left sin leer', () async {
    expect(left(await fetch(shift: Shift.outOfShift)), isA<UnknownFailure>());
    expect(calls, isEmpty);
  });
}
