import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/app/providers.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/group_name_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/shift_image_counts_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/summary_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/repositories/firestore_summary_repository.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/providers/real_summary_providers.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/providers/summary_providers.dart';

const _fecha = '2026-10-05';
final _day = DateTime(2026, 10, 5);
const _g1 = 'g1@g.us';

class _FakeRecords implements SummaryRecordsDatasource {
  List<SummaryRecord> records = [];
  Failure? failure;

  @override
  Future<Either<Failure, List<SummaryRecord>>> fetchByFechaJornada(
    String fechaJornada,
  ) async {
    final failure = this.failure;
    return failure != null ? Left(failure) : Right(records);
  }
}

class _FakeCounts implements ShiftImageCountsDatasource {
  List<ShiftImageCount> counts = [];

  @override
  Future<Either<Failure, List<ShiftImageCount>>> fetchByShiftDate(
    String shiftDate,
  ) async => Right(counts);
}

class _FakeGroupNames implements GroupNameDatasource {
  @override
  Future<Either<Failure, String?>> fetchGroupName(String chatJid) async =>
      const Right('Grupo Uno');
}

void main() {
  late _FakeRecords records;
  late _FakeCounts counts;
  late ProviderContainer container;
  late DebugPrintCallback originalDebugPrint;
  late List<String> printed;

  setUp(() {
    records = _FakeRecords();
    counts = _FakeCounts();
    container = ProviderContainer(
      overrides: [
        summaryRecordsDatasourceProvider.overrideWithValue(records),
        shiftImageCountsDatasourceProvider.overrideWithValue(counts),
        groupNameDatasourceProvider.overrideWithValue(_FakeGroupNames()),
        // Si algo leyera el Firestore real, el test falla aquí.
        firestoreProvider.overrideWith(
          (ref) => throw StateError('no se debe leer el Firestore real'),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 5, 23)),
      ],
    );
    container.read(summaryDateProvider.notifier).select(_day);

    originalDebugPrint = debugPrint;
    printed = [];
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    container.dispose();
  });

  JornadaSummary expected() => JornadaSummary(
    chatJid: _g1,
    groupName: 'Grupo Uno',
    fechaJornada: _fecha,
    shift: shiftNamesAt(_day.millisecondsSinceEpoch)[Shift.morning]!,
    revisor: const RoleSummary(
      registrado: true,
      cantidadImagenes: 1,
      cantidadTickets: 2,
      totalSuma: 3500,
    ),
    sumador: RoleSummary.sinRegistrar,
    imagenesEnJornada: 4,
  );

  void seed() {
    records.records = [
      const SummaryRecord(
        chatJid: _g1,
        fechaJornada: _fecha,
        shift: Shift.morning,
        rol: ReviewRole.revisor,
        totales: [1000, 2500],
      ),
    ];
    counts.counts = [
      const ShiftImageCount(chatJid: _g1, shift: Shift.morning, lastIndex: 4),
    ];
  }

  test('summaryRepositoryProvider es el repositorio real y, con los tres '
      'datasources falsos, devuelve los resúmenes esperados', () async {
    seed();

    final repository = container.read(summaryRepositoryProvider);
    expect(repository, isA<FirestoreSummaryRepository>());
    expect(repository, same(container.read(realSummaryRepositoryProvider)));

    final result = await repository.getJornadaSummaries(_day);
    expect(result.fold((f) => fail('Left: $f'), (list) => list), [expected()]);
  });

  test('jornadaSummariesProvider lee del repositorio real (por la '
      'caché)', () async {
    seed();

    expect(await container.read(jornadaSummariesProvider.future), [expected()]);
    expect(printed, isEmpty);
  });

  group('log de error', () {
    test('un Left con el id de un registro en el texto: solo se imprime el '
        'tipo, nunca el texto ni el id', () async {
      records.failure = const Failure.unknown(
        message:
            'El registro m1_revisor tiene un comprobante sin un "total" '
            'entero.',
      );

      await expectLater(
        container.read(jornadaSummariesProvider.future),
        throwsA(isA<UnknownFailure>()),
      );

      expect(printed, ['[RESUMEN] falló (unknown)']);
      expect(printed.single, isNot(contains('m1')));
      expect(printed.single, isNot(contains('total')));
    });

    test('un error de Firestore se imprime con su texto completo (p. ej. el '
        'enlace para crear un índice que falta)', () async {
      const message =
          'The query requires an index. You can create it here: '
          'https://console.firebase.google.com/project/x/firestore/indexes';
      records.failure = const Failure.firestore(message: message);

      await expectLater(
        container.read(jornadaSummariesProvider.future),
        throwsA(isA<FirestoreFailure>()),
      );

      expect(printed, ['[RESUMEN] falló (firestore): $message']);
    });

    test('summaryFailureLog por tipo', () {
      expect(
        summaryFailureLog(const Failure.unauthorized()),
        startsWith('[RESUMEN] falló (unauthorized): '),
      );
      expect(
        summaryFailureLog(const Failure.storage(message: 'doc m9_sumador')),
        '[RESUMEN] falló (storage)',
      );
      expect(
        summaryFailureLog(const Failure.unknown(message: 'doc m9_sumador')),
        '[RESUMEN] falló (unknown)',
      );
    });
  });
}
