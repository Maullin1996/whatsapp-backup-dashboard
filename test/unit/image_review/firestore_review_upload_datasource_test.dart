import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/firestore_review_upload_datasource.dart';

const _segments = [
  'image_reviews',
  'c1@g.us',
  'jornadas',
  '2026-01-15_morning',
  'registros',
  'm1_revisor',
];
const _path =
    'image_reviews/c1@g.us/jornadas/2026-01-15_morning/registros/m1_revisor';
const _data = <String, dynamic>{'messageId': 'm1', 'shiftKey': 'morning'};

/// Escritura falsa: registra cada llamada y hace lo que diga [behavior].
class _Writer {
  final List<(String, Map<String, dynamic>)> calls = [];
  Future<void> Function() behavior = () async {};

  Future<void> call(String path, Map<String, dynamic> data) {
    calls.add((path, data));
    return behavior();
  }
}

Failure _left(Either<Failure, Unit> result) =>
    result.fold((f) => f, (_) => fail('se esperaba Left'));

void main() {
  late _Writer writer;
  late FirestoreReviewUploadDatasource datasource;

  setUp(() {
    writer = _Writer();
    datasource = FirestoreReviewUploadDatasource.withWriter(writer.call);
  });

  test('el timeout por defecto es de 15 segundos', () {
    expect(reviewUploadTimeout, const Duration(seconds: 15));
    expect(datasource.timeout, reviewUploadTimeout);
  });

  test('éxito: escribe una vez con el path unido por "/" y los datos, y '
      'devuelve Right', () async {
    final result = await datasource.setDocument(_segments, _data);

    expect(result, const Right<Failure, Unit>(unit));
    expect(writer.calls, hasLength(1));
    expect(writer.calls.single.$1, _path);
    expect(writer.calls.single.$2, _data);
  });

  group('ruta inválida: Left sin llamar a la escritura', () {
    for (final (caso, segments) in [
      ('segmento vacío', [..._segments]..[1] = ''),
      ('segmento con "/"', [..._segments]..[1] = 'a/b@g.us'),
      ('número impar de segmentos', _segments.take(5).toList()),
      ('sin segmentos', <String>[]),
    ]) {
      test(caso, () async {
        final result = await datasource.setDocument(segments, _data);

        expect(_left(result), isA<UnknownFailure>());
        expect(writer.calls, isEmpty);
      });
    }
  });

  test('FirebaseException(permission-denied) -> Left(unauthorized)', () async {
    writer.behavior = () async => throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );

    final result = await datasource.setDocument(_segments, _data);

    expect(_left(result), isA<UnauthorizedFailure>());
  });

  test('FirebaseException(unavailable) -> Left(firestore)', () async {
    writer.behavior = () async =>
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

    final result = await datasource.setDocument(_segments, _data);

    final failure = _left(result);
    expect(failure, isA<FirestoreFailure>());
    expect(failure.message, 'Servicio no disponible');
  });

  test('la escritura nunca completa: Left(unknown) al vencer el timeout, sin '
      'quedar colgado', () async {
    writer.behavior = () => Completer<void>().future; // nunca completa
    final fast = FirestoreReviewUploadDatasource.withWriter(
      writer.call,
      timeout: const Duration(milliseconds: 20),
    );

    final result = await fast
        .setDocument(_segments, _data)
        .timeout(const Duration(seconds: 2));

    final failure = _left(result);
    expect(failure, isA<UnknownFailure>());
    expect(failure.message, contains('a tiempo'));
    expect(failure.message, contains(_path));
  });

  test('una excepción cualquiera -> Left(unknown), sin relanzar', () async {
    writer.behavior = () async => throw const FormatException('rara');

    final result = await datasource.setDocument(_segments, _data);

    final failure = _left(result);
    expect(failure, isA<UnknownFailure>());
    expect(failure.message, contains(_path));
  });

  test('un Error -> Left(unknown), sin relanzar', () async {
    writer.behavior = () async => throw StateError('rota');

    final result = await datasource.setDocument(_segments, _data);

    expect(_left(result), isA<UnknownFailure>());
  });

  test(
    'una escritura que lanza antes de devolver el Future -> Left(unknown)',
    () async {
      final sync = FirestoreReviewUploadDatasource.withWriter(
        (_, _) => throw ArgumentError('ruta rara'),
      );

      final result = await sync.setDocument(_segments, _data);

      expect(_left(result), isA<UnknownFailure>());
    },
  );
}
