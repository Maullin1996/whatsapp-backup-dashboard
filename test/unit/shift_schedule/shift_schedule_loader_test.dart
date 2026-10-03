import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/shift_stats_provider.dart';
import 'package:whatsapp_monitor_viewer/features/shift_schedule/data/datasources/shift_schedule_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/shift_schedule/presentation/providers/shift_schedule_providers.dart';

/// Cargador de horarios y festivos, con un datasource falso.
class _FakeDatasource implements ShiftScheduleDatasource {
  _FakeDatasource(this.result);

  final Either<Failure, ShiftTable> result;
  int calls = 0;

  @override
  Future<Either<Failure, ShiftTable>> fetchShiftTable() async {
    calls++;
    return result;
  }
}

final _withHoliday = ShiftTable(
  weekdayRanges: fixedShiftTable.weekdayRanges,
  holidayRange: fixedShiftTable.holidayRange,
  holidays: const {'2026-10-12'},
);

void main() {
  late List<String?> logs;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    logs = [];
    originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message);
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    restoreFixedShiftTable();
  });

  /// Corre el cargador y devuelve cuántas veces se construyó
  /// shiftStatsProvider (1 = no se invalidó; 2 = se invalidó).
  Future<int> run({
    required String? uid,
    required _FakeDatasource datasource,
  }) async {
    var statsBuilds = 0;
    final container = ProviderContainer(
      overrides: [
        reviewerUidProvider.overrideWithValue(uid),
        shiftScheduleDatasourceProvider.overrideWithValue(datasource),
        shiftStatsProvider.overrideWith((ref) {
          statsBuilds++;
          return ShiftStats.empty();
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(shiftStatsProvider, (_, _) {});
    expect(statsBuilds, 1);

    await container.read(shiftScheduleLoaderProvider.future);
    container.read(shiftStatsProvider);
    return statsBuilds;
  }

  test('sin uid: no lee ni registra nada', () async {
    final ds = _FakeDatasource(Right(_withHoliday));
    final builds = await run(uid: null, datasource: ds);
    expect(ds.calls, 0);
    expect(logs, isEmpty);
    expect(builds, 1);
    expect(activeShiftTable, fixedShiftTable);
  });

  test('tabla distinta: la reemplaza e invalida shiftStatsProvider', () async {
    final ds = _FakeDatasource(Right(_withHoliday));
    final builds = await run(uid: 'u1', datasource: ds);
    expect(ds.calls, 1);
    expect(activeShiftTable, _withHoliday);
    expect(builds, 2);
    expect(logs, isEmpty);
  });

  test('tabla igual a la activa: no invalida nada', () async {
    final ds = _FakeDatasource(const Right(fixedShiftTable));
    final builds = await run(uid: 'u1', datasource: ds);
    expect(ds.calls, 1);
    expect(activeShiftTable, fixedShiftTable);
    expect(builds, 1);
  });

  test('falla: queda la tabla fija, deja el log y no invalida', () async {
    final ds = _FakeDatasource(
      const Left(Failure.unauthorized(message: 'Missing permissions')),
    );
    final builds = await run(uid: 'u1', datasource: ds);
    expect(ds.calls, 1);
    expect(activeShiftTable, fixedShiftTable);
    expect(builds, 1);
    expect(logs, ['[JORNADAS] falló (unauthorized): Missing permissions']);
  });

  test('falla después de una carga buena: queda la tabla que había', () async {
    replaceShiftTable(_withHoliday);
    final ds = _FakeDatasource(const Left(Failure.unknown()));
    await run(uid: 'u1', datasource: ds);
    expect(activeShiftTable, _withHoliday);
    expect(logs, ['[JORNADAS] falló (unknown)']);
  });
}
