import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/app/providers.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure_log.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/message_context_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/revisor_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/winning_numbers_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/repositories/firestore_matches_repository.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/providers/matches_providers.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/providers/real_matches_providers.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/group_name_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/providers/real_summary_providers.dart';

class _FakeWinners implements WinningNumbersDatasource {
  @override
  Future<Either<Failure, List<String>>> fetchByFecha(String fecha) async =>
      const Right(['4521']);
}

class _FakeRecords implements RevisorRecordsDatasource {
  Failure? failure;

  @override
  Future<Either<Failure, List<RevisorRecord>>> fetchByFechaJornada(
    String fechaJornada,
  ) async {
    final failure = this.failure;
    if (failure != null) return Left(failure);
    return Right([
      RevisorRecord(
        chatJid: 'g1@g.us',
        shift: Shift.morning,
        messageId: 'm1',
        storagePath: 'img/m1.jpg',
        fechaJornada: fechaJornada,
        numeros: const ['4521'],
      ),
    ]);
  }
}

class _FakeMessages implements MessageContextDatasource {
  @override
  Future<Either<Failure, MessageContext>> fetchById(String messageId) async =>
      const Right((senderName: 'Ana', localTime: '08:15'));
}

class _FakeGroupNames implements GroupNameDatasource {
  @override
  Future<Either<Failure, String?>> fetchGroupName(String chatJid) async =>
      const Right('Grupo Uno');
}

void main() {
  late _FakeRecords records;
  late ProviderContainer container;
  late DebugPrintCallback originalDebugPrint;
  late List<String> printed;

  setUp(() {
    records = _FakeRecords();
    container = ProviderContainer(
      overrides: [
        winningNumbersDatasourceProvider.overrideWithValue(_FakeWinners()),
        revisorRecordsDatasourceProvider.overrideWithValue(records),
        messageContextDatasourceProvider.overrideWithValue(_FakeMessages()),
        groupNameDatasourceProvider.overrideWithValue(_FakeGroupNames()),
        // Si algo leyera el Firestore real, el test falla aquí.
        firestoreProvider.overrideWith(
          (ref) => throw StateError('no se debe leer el Firestore real'),
        ),
      ],
    );
    container.read(matchesDateProvider.notifier).select(DateTime(2026, 10, 5));

    originalDebugPrint = debugPrint;
    printed = [];
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    container.dispose();
  });

  test('matchesRepositoryProvider es el repositorio real y, con los '
      'datasources falsos, arma la coincidencia', () async {
    final repository = container.read(matchesRepositoryProvider);
    expect(repository, isA<FirestoreMatchesRepository>());
    expect(repository, same(container.read(realMatchesRepositoryProvider)));

    final day = await container.read(dayMatchesProvider.future);
    final match = day.jornadas.expand((j) => j.matches).single;
    expect(match.senderName, 'Ana');
    expect(match.groupName, 'Grupo Uno');
    expect(printed, isEmpty);
  });

  group('log de error', () {
    test('un Left con el id de un registro en el texto: solo el tipo, nunca '
        'el texto ni el id', () async {
      records.failure = const Failure.unknown(
        message: 'El registro m1_revisor tiene una jornada inválida ("x").',
      );

      await expectLater(
        container.read(dayMatchesProvider.future),
        throwsA(isA<UnknownFailure>()),
      );

      expect(printed, ['[COINCIDENCIAS] falló (unknown)']);
      expect(printed.single, isNot(contains('m1')));
    });

    test('un error de Firestore con el enlace del índice se imprime '
        'completo', () async {
      const message =
          'The query requires an index. You can create it here: '
          'https://console.firebase.google.com/project/x/firestore/indexes';
      records.failure = const Failure.firestore(message: message);

      await expectLater(
        container.read(dayMatchesProvider.future),
        throwsA(isA<FirestoreFailure>()),
      );

      expect(printed, ['[COINCIDENCIAS] falló (firestore): $message']);
    });

    test('failureLogLine por tipo y etiqueta', () {
      expect(
        failureLogLine('X', const Failure.firestore(message: 'm')),
        '[X] falló (firestore): m',
      );
      expect(
        failureLogLine('X', const Failure.unauthorized()),
        startsWith('[X] falló (unauthorized): '),
      );
      expect(
        failureLogLine('X', const Failure.storage(message: 'doc m9')),
        '[X] falló (storage)',
      );
      expect(
        failureLogLine('X', const Failure.unknown(message: 'doc m9')),
        '[X] falló (unknown)',
      );
    });
  });
}
