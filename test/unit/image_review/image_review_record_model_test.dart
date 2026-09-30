import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/models/image_review_record_model.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

ImageReviewRecord _record({
  ReviewRole rol = ReviewRole.revisor,
  String? anotaciones,
  bool editado = false,
  EstadoSync estadoSync = EstadoSync.pendiente,
  List<Comprobante>? comprobantes,
}) => ImageReviewRecord(
  messageId: 'm-1',
  chatJid: '1203630@g.us',
  shift: 'Jornada Noche (15:24 – 22:24)',
  rol: rol,
  storagePath: 'chats/1203630/img_1.jpg',
  fechaJornada: '2026-01-15',
  form: ImageReviewForm(
    comprobantes:
        comprobantes ??
        const [
          Comprobante(codigo: '0457', numeros: ['0123', '5311'], total: 9000),
          Comprobante(codigo: 'Antioquia', numeros: ['007'], total: 3000),
        ],
    anotaciones: anotaciones,
  ),
  registradoEn: DateTime(2026, 1, 15, 16, 30, 5, 123),
  registradoPor: 'revisor@example.com',
  editado: editado,
  estadoSync: estadoSync,
);

/// Ida y vuelta por el mismo camino que usa el almacenamiento (JSON).
ImageReviewRecord _roundTrip(ImageReviewRecord r) {
  final json = jsonEncode(ImageReviewRecordModel(r).toMap());
  return ImageReviewRecordModel.fromMap(
    jsonDecode(json) as Map<String, dynamic>,
  ).record;
}

void main() {
  group('ImageReviewRecordModel: ida y vuelta', () {
    test('conserva todos los campos', () {
      final r = _record(anotaciones: 'no se lee bien', editado: true);
      expect(_roundTrip(r), r);
    });

    test('conserva ceros a la izquierda en números y códigos', () {
      final back = _roundTrip(_record());
      final c = back.form.comprobantes;
      expect(c.first.codigo, '0457');
      expect(c.first.numeros, ['0123', '5311']);
      expect(c.last.numeros, ['007']);
    });

    test('anotaciones null se mantiene null', () {
      expect(_roundTrip(_record()).form.anotaciones, isNull);
    });

    test('registro del Sumador: sin números', () {
      final r = _record(
        rol: ReviewRole.sumador,
        comprobantes: const [
          Comprobante(codigo: 'A1', numeros: [], total: 500),
        ],
      );
      final back = _roundTrip(r);
      expect(back, r);
      expect(back.rol, ReviewRole.sumador);
      expect(back.form.comprobantes.single.numeros, isEmpty);
    });

    test('conserva el estado de sincronización y editado', () {
      for (final estado in EstadoSync.values) {
        final r = _record(estadoSync: estado, editado: true);
        expect(_roundTrip(r).estadoSync, estado);
        expect(_roundTrip(r).editado, isTrue);
      }
    });

    test('conserva texto con acentos, espacios y símbolos', () {
      final r = _record(
        anotaciones: '  Ñandú — "comprobante" 2 | no cuadra\n(línea 2)  ',
      );
      expect(_roundTrip(r).form.anotaciones, r.form.anotaciones);
    });

    test('la fecha de registro conserva el mismo instante', () {
      final r = _record();
      expect(_roundTrip(r).registradoEn, r.registradoEn);
      expect(_roundTrip(r).registradoEn.isUtc, isFalse);
    });

    test('la referencia de imagen es un path, no una URL ni la imagen', () {
      final map = ImageReviewRecordModel(_record()).toMap();
      expect(map['storagePath'], 'chats/1203630/img_1.jpg');
      expect(jsonEncode(map), isNot(contains('http')));
    });
  });

  group('ImageReviewRecordModel: documento de subida', () {
    ReviewUploadDocument document(ImageReviewRecord r) =>
        ImageReviewRecordModel(
          r,
        ).toUploadDocument().fold((f) => fail('Left: $f'), (d) => d);

    Failure failure(ImageReviewRecord r) => ImageReviewRecordModel(
      r,
    ).toUploadDocument().fold((f) => f, (_) => fail('se esperaba Left'));

    final asignables = Shift.values.where((s) => s != Shift.outOfShift);

    test('las 6 jornadas asignables: ruta grupo -> jornada -> registro, sin '
        '"/" en ningún segmento', () {
      expect(asignables, hasLength(6));
      for (final shift in asignables) {
        final doc = document(_record().copyWith(shift: shiftNames[shift]!));
        expect(doc.pathSegments, [
          'image_reviews',
          '1203630@g.us',
          'jornadas',
          '2026-01-15_${shift.name}',
          'registros',
          'm-1_revisor',
        ], reason: shift.name);
        for (final segment in doc.pathSegments) {
          expect(segment, isNot(contains('/')), reason: shift.name);
          expect(segment, isNotEmpty, reason: shift.name);
        }
        expect(doc.path, doc.pathSegments.join('/'));
        expect(doc.data['shiftKey'], shift.name);
        expect(doc.data['shift'], shiftNames[shift]);
      }
    });

    test(
      'domingo/festivo: la etiqueta lleva "/" pero la ruta usa "holiday"',
      () {
        final label = shiftNames[Shift.holiday]!;
        expect(label, contains('/'));

        final doc = document(_record().copyWith(shift: label));

        expect(doc.pathSegments[3], '2026-01-15_holiday');
        expect(doc.pathSegments.where((s) => s.contains('/')), isEmpty);
        expect(doc.pathSegments, hasLength(6));
      },
    );

    test('fuera de jornada: Left (Failure.unknown)', () {
      final r = _record().copyWith(shift: shiftNames[Shift.outOfShift]!);
      expect(failure(r), isA<UnknownFailure>());
    });

    test('etiqueta desconocida: Left (Failure.unknown)', () {
      final r = _record().copyWith(shift: 'Jornada Madrugada (01:00 – 05:00)');
      expect(failure(r), isA<UnknownFailure>());
    });

    test('un segmento con "/" o vacío: Left, no una ruta más larga', () {
      expect(
        failure(_record().copyWith(chatJid: 'a/b@g.us')),
        isA<UnknownFailure>(),
      );
      expect(failure(_record().copyWith(chatJid: '')), isA<UnknownFailure>());
    });

    test('Revisor y Sumador de la misma imagen: mismo documento de jornada, '
        'ids de registro distintos', () {
      final revisor = document(_record());
      final sumador = document(
        _record(
          rol: ReviewRole.sumador,
          comprobantes: const [
            Comprobante(codigo: 'A1', numeros: [], total: 500),
          ],
        ),
      );

      expect(
        revisor.pathSegments.take(5).toList(),
        sumador.pathSegments.take(5).toList(),
      );
      expect(revisor.pathSegments.last, 'm-1_revisor');
      expect(sumador.pathSegments.last, 'm-1_sumador');
    });

    test('los datos: lo persistido sin v ni estadoSync, más shiftKey', () {
      final r = _record(anotaciones: 'no se lee bien', editado: true);
      final doc = document(r);

      final expected = ImageReviewRecordModel(r).toMap()
        ..remove('v')
        ..remove('estadoSync')
        ..['shiftKey'] = 'night1';
      expect(doc.data, expected);
      expect(doc.data['rol'], 'revisor');
      expect(doc.data['registradoPor'], 'revisor@example.com');
      expect(
        doc.data['registradoEn'],
        r.registradoEn.toUtc().toIso8601String(),
      );
      expect(doc.data.containsKey('uid'), isFalse);
    });
  });

  group('ImageReviewRecordModel: esquema', () {
    test('escribe la versión de esquema actual', () {
      final map = ImageReviewRecordModel(_record()).toMap();
      expect(map['v'], ImageReviewRecordModel.currentSchemaVersion);
      expect(ImageReviewRecordModel.currentSchemaVersion, 1);
    });

    Map<String, dynamic> validMap() =>
        ImageReviewRecordModel(_record()).toMap();

    test('migrate de la versión actual no cambia nada', () {
      final map = validMap();
      expect(ImageReviewRecordModel.migrate(map), map);
    });

    test('una versión más nueva que la soportada falla', () {
      final map = validMap()..['v'] = 99;
      expect(
        () => ImageReviewRecordModel.fromMap(map),
        throwsA(isA<FormatException>()),
      );
    });

    test('sin versión falla', () {
      final map = validMap()..remove('v');
      expect(
        () => ImageReviewRecordModel.fromMap(map),
        throwsA(isA<FormatException>()),
      );
    });

    test('un campo faltante o de tipo equivocado falla', () {
      expect(
        () => ImageReviewRecordModel.fromMap(validMap()..remove('messageId')),
        throwsA(anything),
      );
      expect(
        () => ImageReviewRecordModel.fromMap(validMap()..['editado'] = 'si'),
        throwsA(anything),
      );
    });

    test('un rol o estado desconocido falla', () {
      expect(
        () => ImageReviewRecordModel.fromMap(validMap()..['rol'] = 'admin'),
        throwsA(anything),
      );
      expect(
        () => ImageReviewRecordModel.fromMap(
          validMap()..['estadoSync'] = 'subiendo',
        ),
        throwsA(anything),
      );
    });
  });
}
