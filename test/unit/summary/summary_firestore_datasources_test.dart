import 'package:dartz/dartz.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_group_name_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_raw_document.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_shift_image_counts_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_summary_records_datasource.dart';

Failure _left<T>(Either<Failure, T> result) =>
    result.fold((f) => f, (_) => fail('se esperaba Left'));

T _right<T>(Either<Failure, T> result) =>
    result.fold((f) => fail('Left: $f'), (v) => v);

/// Payload como el que sube la app (`toUploadDocument`), sin lo que el
/// Resumen no usa.
Map<String, dynamic> _registro({String rol = 'revisor'}) => {
  'messageId': 'm1',
  'chatJid': 'g1@g.us',
  'shift': 'Jornada Mañana (06:00 – 10:54)',
  'shiftKey': 'morning',
  'rol': rol,
  'fechaJornada': '2026-10-05',
  'messageTimestamp': 1790000000000,
  'comprobantes': [
    {
      'codigo': 'A1',
      'numeros': rol == 'revisor' ? ['0123'] : <String>[],
      'total': 1000,
    },
    {'codigo': 'A2', 'numeros': <String>[], 'total': 2500},
  ],
  'anotaciones': null,
  'registradoEn': '2026-10-05T12:00:00.000Z',
  'registradoPor': 'a@x.com',
  'editado': false,
};

Map<String, dynamic> _contador() => {
  'chatJid': 'g1@g.us',
  'shiftDate': '2026-10-05',
  'shiftKey': 'afternoon1',
  'lastIndex': 12,
  'publishedAt': DateTime.utc(2026, 10, 5),
};

void main() {
  group('FirestoreSummaryRecordsDatasource', () {
    late List<String> requested;
    late Future<List<RawDocument>> Function() behavior;
    late FirestoreSummaryRecordsDatasource datasource;

    setUp(() {
      requested = [];
      behavior = () async => [];
      datasource = FirestoreSummaryRecordsDatasource.withReader((fecha) {
        requested.add(fecha);
        return behavior();
      });
    });

    test('mapea los campos: grupo, día, jornada, rol y totales', () async {
      behavior = () async => [
        (id: 'm1_revisor', data: _registro()),
        (id: 'm1_sumador', data: _registro(rol: 'sumador')),
      ];

      final list = _right(await datasource.fetchByFechaJornada('2026-10-05'));

      expect(requested, ['2026-10-05']);
      expect(list, hasLength(2));
      final r = list.first;
      expect(r.chatJid, 'g1@g.us');
      expect(r.fechaJornada, '2026-10-05');
      expect(r.shift, Shift.morning);
      expect(r.rol, ReviewRole.revisor);
      expect(r.totales, [1000, 2500]);
      expect(list.last.rol, ReviewRole.sumador);
      expect(list.last.totales, [1000, 2500]);
    });

    test('sin documentos: lista vacía', () async {
      expect(_right(await datasource.fetchByFechaJornada('2026-10-05')), []);
    });

    group('formato inesperado: Left con el id, sin omitir el documento', () {
      for (final (caso, mutate)
          in <(String, void Function(Map<String, dynamic>))>[
            ('falta chatJid', (d) => d.remove('chatJid')),
            ('falta fechaJornada', (d) => d.remove('fechaJornada')),
            ('falta comprobantes', (d) => d.remove('comprobantes')),
            ('chatJid no es texto', (d) => d['chatJid'] = 42),
            (
              'total no es entero',
              (d) => d['comprobantes'] = [
                {'codigo': 'A1', 'numeros': <String>[], 'total': '1000'},
              ],
            ),
            (
              'comprobante sin total',
              (d) => d['comprobantes'] = [
                {'codigo': 'A1', 'numeros': <String>[]},
              ],
            ),
            ('comprobante que no es un map', (d) => d['comprobantes'] = [1000]),
            ('shiftKey desconocido', (d) => d['shiftKey'] = 'madrugada'),
            ('shiftKey outOfShift', (d) => d['shiftKey'] = 'outOfShift'),
            ('rol desconocido', (d) => d['rol'] = 'auditor'),
          ]) {
        test(caso, () async {
          final bad = _registro();
          mutate(bad);
          behavior = () async => [
            (id: 'ok_revisor', data: _registro()),
            (id: 'malo_revisor', data: bad),
          ];

          final failure = _left(
            await datasource.fetchByFechaJornada('2026-10-05'),
          );

          expect(failure, isA<UnknownFailure>());
          expect(failure.message, contains('malo_revisor'));
        });
      }
    });

    test('FirebaseException: el Failure de mapFirestoreError', () async {
      behavior = () async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      expect(
        _left(await datasource.fetchByFechaJornada('2026-10-05')),
        const Failure.unauthorized(),
      );
    });

    test('otra excepción: unknown en español, sin lanzar', () async {
      behavior = () async => throw StateError('boom');

      final failure = _left(await datasource.fetchByFechaJornada('2026-10-05'));

      expect(failure, isA<UnknownFailure>());
      expect(failure.message, contains('2026-10-05'));
    });
  });

  group('FirestoreShiftImageCountsDatasource', () {
    late List<String> requested;
    late Future<List<RawDocument>> Function() behavior;
    late FirestoreShiftImageCountsDatasource datasource;

    setUp(() {
      requested = [];
      behavior = () async => [];
      datasource = FirestoreShiftImageCountsDatasource.withReader((date) {
        requested.add(date);
        return behavior();
      });
    });

    test('mapea chatJid, jornada y lastIndex', () async {
      behavior = () async => [
        (id: 'g1@g.us_2026-10-05_afternoon1', data: _contador()),
      ];

      final c = _right(await datasource.fetchByShiftDate('2026-10-05')).single;

      expect(requested, ['2026-10-05']);
      expect(c.chatJid, 'g1@g.us');
      expect(c.shift, Shift.afternoon1);
      expect(c.lastIndex, 12);
    });

    group('formato inesperado: Left con el id', () {
      for (final (caso, mutate)
          in <(String, void Function(Map<String, dynamic>))>[
            ('falta lastIndex', (d) => d.remove('lastIndex')),
            ('lastIndex no es entero', (d) => d['lastIndex'] = '12'),
            ('falta chatJid', (d) => d.remove('chatJid')),
            ('shiftKey desconocido', (d) => d['shiftKey'] = 'out_of_shift'),
            ('shiftKey outOfShift', (d) => d['shiftKey'] = 'outOfShift'),
          ]) {
        test(caso, () async {
          final bad = _contador();
          mutate(bad);
          behavior = () async => [(id: 'contador-malo', data: bad)];

          final failure = _left(
            await datasource.fetchByShiftDate('2026-10-05'),
          );

          expect(failure, isA<UnknownFailure>());
          expect(failure.message, contains('contador-malo'));
        });
      }
    });

    test('FirebaseException: el Failure de mapFirestoreError', () async {
      behavior = () async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      expect(
        _left(await datasource.fetchByShiftDate('2026-10-05')),
        const Failure.firestore(message: 'Servicio no disponible'),
      );
    });

    test('otra excepción: unknown en español, sin lanzar', () async {
      behavior = () async => throw StateError('boom');

      expect(
        _left(await datasource.fetchByShiftDate('2026-10-05')),
        isA<UnknownFailure>(),
      );
    });
  });

  group('FirestoreGroupNameDatasource', () {
    late List<String> requested;
    late Future<Map<String, dynamic>?> Function() behavior;
    late FirestoreGroupNameDatasource datasource;

    setUp(() {
      requested = [];
      behavior = () async => null;
      datasource = FirestoreGroupNameDatasource.withReader((id) {
        requested.add(id);
        return behavior();
      });
    });

    test('lee group_stats/{chatJid}.groupName', () async {
      behavior = () async => {'chatJid': 'g1@g.us', 'groupName': 'Grupo Uno'};

      expect(_right(await datasource.fetchGroupName('g1@g.us')), 'Grupo Uno');
      expect(requested, ['g1@g.us']);
    });

    test('documento ausente: Right(null)', () async {
      expect(_right(await datasource.fetchGroupName('g1@g.us')), isNull);
    });

    test('groupName que no es texto: Left con el chatJid', () async {
      behavior = () async => {'groupName': 7};

      final failure = _left(await datasource.fetchGroupName('g1@g.us'));

      expect(failure, isA<UnknownFailure>());
      expect(failure.message, contains('g1@g.us'));
    });

    test('FirebaseException: el Failure de mapFirestoreError', () async {
      behavior = () async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );

      expect(
        _left(await datasource.fetchGroupName('g1@g.us')),
        const Failure.unauthorized(),
      );
    });

    test('otra excepción: unknown, sin lanzar', () async {
      behavior = () async => throw StateError('boom');

      expect(
        _left(await datasource.fetchGroupName('g1@g.us')),
        isA<UnknownFailure>(),
      );
    });
  });
}
