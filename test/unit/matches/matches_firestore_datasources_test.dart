import 'package:dartz/dartz.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/firestore_message_context_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/firestore_revisor_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/firestore_winning_numbers_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_raw_document.dart';

Failure _left<T>(Either<Failure, T> result) =>
    result.fold((f) => f, (_) => fail('se esperaba Left'));

T _right<T>(Either<Failure, T> result) =>
    result.fold((f) => fail('Left: $f'), (v) => v);

/// Payload como el que sube la app (`toUploadDocument`), del Revisor.
Map<String, dynamic> _registro() => {
  'messageId': 'm1',
  'chatJid': 'g1@g.us',
  'shift': 'Jornada Mañana (06:00 – 10:54)',
  'shiftKey': 'morning',
  'rol': 'revisor',
  'storagePath': 'chats/g1/img_m1.jpg',
  'fechaJornada': '2026-10-05',
  'messageTimestamp': 1790000000000,
  'codigo': 'A1',
  'comprobantes': [
    {
      'numeros': ['0123', '5311'],
      'total': 1000,
      'loteria': 'Lotería de Medellín',
    },
    {
      'numeros': ['007'],
      'total': 2500,
      'loteria': null,
    },
  ],
  'anotaciones': null,
  'registradoEn': '2026-10-05T12:00:00.000Z',
  'registradoPor': 'a@x.com',
  'editado': false,
};

void main() {
  group('FirestoreRevisorRecordsDatasource', () {
    late Future<List<RawDocument>> Function() behavior;
    late List<String> requested;
    late FirestoreRevisorRecordsDatasource datasource;

    setUp(() {
      requested = [];
      behavior = () async => [];
      datasource = FirestoreRevisorRecordsDatasource.withReader((fecha) {
        requested.add(fecha);
        return behavior();
      });
    });

    test('mapea grupo, jornada, mensaje, imagen, día y los números '
        'aplanados (con ceros a la izquierda)', () async {
      behavior = () async => [(id: 'm1_revisor', data: _registro())];

      final list = _right(await datasource.fetchByFechaJornada('2026-10-05'));

      expect(requested, ['2026-10-05']);
      final r = list.single;
      expect(r.chatJid, 'g1@g.us');
      expect(r.shift, Shift.morning);
      expect(r.messageId, 'm1');
      expect(r.storagePath, 'chats/g1/img_m1.jpg');
      expect(r.fechaJornada, '2026-10-05');
      expect(r.numeros, ['0123', '5311', '007']);
    });

    group('formato inesperado: Left con el id, sin omitir el documento', () {
      for (final (caso, mutate)
          in <(String, void Function(Map<String, dynamic>))>[
            ('falta messageId', (d) => d.remove('messageId')),
            ('falta storagePath', (d) => d.remove('storagePath')),
            ('chatJid no es texto', (d) => d['chatJid'] = 42),
            ('shiftKey desconocido', (d) => d['shiftKey'] = 'madrugada'),
            ('shiftKey outOfShift', (d) => d['shiftKey'] = 'outOfShift'),
            ('rol del Sumador', (d) => d['rol'] = 'sumador'),
            (
              'comprobante sin numeros',
              (d) => d['comprobantes'] = [
                {'total': 1000},
              ],
            ),
            (
              'un número que no es texto',
              (d) => d['comprobantes'] = [
                {
                  'numeros': [123],
                  'total': 1000,
                },
              ],
            ),
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

    test('FirebaseException -> mapFirestoreError; otra excepción -> '
        'unknown en español', () async {
      behavior = () async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      expect(
        _left(await datasource.fetchByFechaJornada('2026-10-05')),
        const Failure.firestore(message: 'Servicio no disponible'),
      );

      behavior = () async => throw StateError('x');
      final failure = _left(await datasource.fetchByFechaJornada('2026-10-05'));
      expect(failure, isA<UnknownFailure>());
      expect(failure.message, contains('Error inesperado'));
    });
  });

  group('FirestoreWinningNumbersDatasource', () {
    test('la colección y el campo son los PROVISIONALES', () {
      expect(winningNumbersSource.collection, 'winning_numbers');
      expect(winningNumbersSource.field, 'numbers');
    });

    test('lee la lista del documento de la fecha', () async {
      final requested = <String>[];
      final datasource = FirestoreWinningNumbersDatasource.withReader((
        fecha,
      ) async {
        requested.add(fecha);
        return {
          'numbers': ['0123', '4521'],
        };
      });

      expect(_right(await datasource.fetchByFecha('2026-10-05')), [
        '0123',
        '4521',
      ]);
      expect(requested, ['2026-10-05']);
    });

    test('documento ausente: lista vacía, sin error', () async {
      final datasource = FirestoreWinningNumbersDatasource.withReader(
        (_) async => null,
      );
      expect(_right(await datasource.fetchByFecha('2026-10-05')), isEmpty);
    });

    test('campo faltante o de otro tipo: Left con la fecha', () async {
      for (final data in <Map<String, dynamic>>[
        {},
        {'numbers': '0123'},
        {
          'numbers': [123],
        },
      ]) {
        final datasource = FirestoreWinningNumbersDatasource.withReader(
          (_) async => data,
        );
        final failure = _left(await datasource.fetchByFecha('2026-10-05'));
        expect(failure, isA<UnknownFailure>(), reason: '$data');
        expect(failure.message, contains('2026-10-05'), reason: '$data');
      }
    });

    test('FirebaseException -> mapFirestoreError; otra -> unknown', () async {
      var datasource = FirestoreWinningNumbersDatasource.withReader(
        (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );
      expect(
        _left(await datasource.fetchByFecha('2026-10-05')),
        isA<UnauthorizedFailure>(),
      );

      datasource = FirestoreWinningNumbersDatasource.withReader(
        (_) async => throw StateError('x'),
      );
      expect(
        _left(await datasource.fetchByFecha('2026-10-05')),
        isA<UnknownFailure>(),
      );
    });
  });

  group('FirestoreMessageContextDatasource', () {
    test('lee senderName y localTime del mensaje por id', () async {
      final requested = <String>[];
      final datasource = FirestoreMessageContextDatasource.withReader((
        id,
      ) async {
        requested.add(id);
        return {
          'senderName': 'Ana',
          'localTime': '08:15',
          'chatJid': 'g1@g.us',
          'messageTimestamp': 1790000000000,
        };
      });

      final context = _right(await datasource.fetchById('m1'));

      expect(requested, ['m1']);
      expect(context.senderName, 'Ana');
      expect(context.localTime, '08:15');
    });

    test('mensaje inexistente: Left con el id', () async {
      final datasource = FirestoreMessageContextDatasource.withReader(
        (_) async => null,
      );
      final failure = _left(await datasource.fetchById('m9'));
      expect(failure, isA<UnknownFailure>());
      expect(failure.message, contains('m9'));
    });

    test('sin senderName o localTime de texto: Left con el id', () async {
      for (final data in <Map<String, dynamic>>[
        {'localTime': '08:15'},
        {'senderName': 'Ana'},
        {'senderName': 1, 'localTime': '08:15'},
      ]) {
        final datasource = FirestoreMessageContextDatasource.withReader(
          (_) async => data,
        );
        final failure = _left(await datasource.fetchById('m9'));
        expect(failure.message, contains('m9'), reason: '$data');
      }
    });

    test('FirebaseException -> mapFirestoreError; otra -> unknown', () async {
      var datasource = FirestoreMessageContextDatasource.withReader(
        (_) async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      );
      expect(
        _left(await datasource.fetchById('m1')),
        const Failure.firestore(message: 'Servicio no disponible'),
      );

      datasource = FirestoreMessageContextDatasource.withReader(
        (_) async => throw StateError('x'),
      );
      final failure = _left(await datasource.fetchById('m1'));
      expect(failure, isA<UnknownFailure>());
      expect(failure.message, contains('m1'));
    });
  });
}
