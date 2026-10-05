import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';

/// Tabla activa reemplazable y festivos (horarios dinámicos, pieza 2). Cada
/// test que reemplaza la tabla la restaura en tearDown.

/// Lunes 12 de octubre de 2026 (hora local): festivo de la lista.
DateTime _holidayMonday(int h, int m, [int s = 0]) =>
    DateTime(2026, 10, 12, h, m, s);

/// Martes 13 de octubre de 2026: no es festivo ni domingo.
DateTime _tuesday(int h, int m, [int s = 0]) => DateTime(2026, 10, 13, h, m, s);

/// Domingo 11 de octubre de 2026.
DateTime _sunday(int h, int m, [int s = 0]) => DateTime(2026, 10, 11, h, m, s);

ShiftTable _withHolidays(Set<String> holidays) => ShiftTable(
  weekdayRanges: fixedShiftTable.weekdayRanges,
  holidayRange: fixedShiftTable.holidayRange,
  holidays: holidays,
);

const _dayShifts = {
  Shift.morning,
  Shift.afternoon1,
  Shift.afternoon2,
  Shift.night1,
};

void main() {
  tearDown(restoreFixedShiftTable);

  test('las fechas de prueba caen en el día de la semana esperado', () {
    expect(_holidayMonday(0, 0).weekday, DateTime.monday);
    expect(_tuesday(0, 0).weekday, DateTime.tuesday);
    expect(_sunday(0, 0).weekday, DateTime.sunday);
  });

  group('tabla por defecto', () {
    test('la activa es la fija, sin festivos', () {
      expect(activeShiftTable, fixedShiftTable);
      expect(fixedShiftTable.holidays, isEmpty);
    });

    test('shiftLastMinute sale de los rangos de la tabla fija', () {
      expect(shiftLastMinute, {
        Shift.morning: 10 * 60 + 51,
        Shift.afternoon1: 13 * 60 + 55,
        Shift.afternoon2: 15 * 60 + 20,
        Shift.night1: 22 * 60 + 15,
        Shift.holiday: 19 * 60 + 15,
      });
    });
  });

  group('replaceShiftTable', () {
    test('una tabla igual no cambia nada y devuelve false', () {
      const same = ShiftTable(
        weekdayRanges: {
          Shift.morning: (start: 5 * 60 + 30, end: 10 * 60 + 51),
          Shift.afternoon1: (start: 10 * 60 + 58, end: 13 * 60 + 55),
          Shift.afternoon2: (start: 14 * 60 + 1, end: 15 * 60 + 20),
          Shift.night1: (start: 15 * 60 + 28, end: 22 * 60 + 15),
        },
        holidayRange: (start: 6 * 60, end: 19 * 60 + 15),
      );
      expect(same, fixedShiftTable);
      expect(same.hashCode, fixedShiftTable.hashCode);
      expect(replaceShiftTable(same), isFalse);
    });

    test('una tabla distinta la reemplaza y devuelve true', () {
      final other = _withHolidays({'2026-10-12'});
      expect(replaceShiftTable(other), isTrue);
      expect(activeShiftTable, other);
      expect(replaceShiftTable(other), isFalse);
    });

    test('restoreFixedShiftTable vuelve a la fija', () {
      replaceShiftTable(_withHolidays({'2026-10-12'}));
      restoreFixedShiftTable();
      expect(activeShiftTable, fixedShiftTable);
    });
  });

  group('otros límites', () {
    // La mañana termina a las 10:45 en vez de 10:51.
    final shorterMorning = ShiftTable(
      weekdayRanges: {
        ...fixedShiftTable.weekdayRanges,
        Shift.morning: (start: 5 * 60 + 30, end: 10 * 60 + 45),
      },
      holidayRange: fixedShiftTable.holidayRange,
    );

    test('cambian los bordes de getCurrentShift y el hueco', () {
      replaceShiftTable(shorterMorning);
      expect(getCurrentShift(_tuesday(10, 45, 59)), Shift.morning);
      expect(getCurrentShift(_tuesday(10, 46)), Shift.outOfShift);
      expect(shiftGapBefore(_tuesday(10, 46)), Shift.morning);
      expect(shiftViewerLabel(_tuesday(10, 46)), shiftGapLabels[Shift.morning]);
    });

    test('las etiquetas no cambian con la tabla', () {
      replaceShiftTable(shorterMorning);
      expect(
        shiftViewerLabel(_tuesday(8, 0)),
        'Jornada Mañana (05:30 – 10:51)',
      );
    });

    test('shiftLastMinute y jornadaTerminada siguen coherentes con '
        'getCurrentShift', () {
      replaceShiftTable(shorterMorning);
      expect(shiftLastMinute[Shift.morning], 10 * 60 + 45);
      for (final MapEntry(key: shift, value: last) in shiftLastMinute.entries) {
        final day = shift == Shift.holiday ? _sunday : _tuesday;
        expect(getCurrentShift(day(last ~/ 60, last % 60, 59)), shift);
        expect(
          getCurrentShift(day((last + 1) ~/ 60, (last + 1) % 60)),
          isNot(shift),
        );
      }
      // Bogotá 2026-10-13 10:46 = 15:46 UTC.
      final fin = DateTime.utc(2026, 10, 13, 15, 46);
      expect(jornadaTerminada('2026-10-13', Shift.morning, fin), isTrue);
      expect(
        jornadaTerminada(
          '2026-10-13',
          Shift.morning,
          fin.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });
  });

  group('festivo entre semana (2026-10-12, lunes)', () {
    setUp(() => replaceShiftTable(_withHolidays({'2026-10-12'})));

    test('isHolidayOrSunday: el festivo y el domingo sí; un martes no', () {
      expect(isHolidayOrSunday(_holidayMonday(8, 0)), isTrue);
      expect(isHolidayOrSunday(_sunday(8, 0)), isTrue);
      expect(isHolidayOrSunday(_tuesday(8, 0)), isFalse);
    });

    test('bordes de holiday', () {
      expect(getCurrentShift(_holidayMonday(8, 0)), Shift.holiday);
      expect(getCurrentShift(_holidayMonday(19, 15)), Shift.holiday);
      expect(getCurrentShift(_holidayMonday(19, 15, 59)), Shift.holiday);
      expect(getCurrentShift(_holidayMonday(19, 16)), Shift.outOfShift);
      expect(getCurrentShift(_holidayMonday(5, 59)), Shift.outOfShift);
    });

    test('ningún minuto del día da una jornada de día normal', () {
      for (var minute = 0; minute < 24 * 60; minute++) {
        final shift = getCurrentShift(
          _holidayMonday(minute ~/ 60, minute % 60),
        );
        expect(_dayShifts.contains(shift), isFalse, reason: 'minuto $minute');
      }
    });

    test('se clasifica minuto a minuto igual que un domingo', () {
      for (var minute = 0; minute < 24 * 60; minute++) {
        final h = minute ~/ 60, m = minute % 60;
        expect(
          getCurrentShift(_holidayMonday(h, m)),
          getCurrentShift(_sunday(h, m)),
          reason: 'minuto $minute',
        );
        expect(shiftGapBefore(_holidayMonday(h, m)), isNull);
        expect(
          shiftViewerLabel(_holidayMonday(h, m)),
          shiftViewerLabel(_sunday(h, m)),
          reason: 'minuto $minute',
        );
      }
    });

    test('un día que no es festivo ni domingo no se ve afectado', () {
      for (var minute = 0; minute < 24 * 60; minute++) {
        final h = minute ~/ 60, m = minute % 60;
        final withHolidays = (
          getCurrentShift(_tuesday(h, m)),
          shiftGapBefore(_tuesday(h, m)),
          shiftViewerLabel(_tuesday(h, m)),
        );
        restoreFixedShiftTable();
        final without = (
          getCurrentShift(_tuesday(h, m)),
          shiftGapBefore(_tuesday(h, m)),
          shiftViewerLabel(_tuesday(h, m)),
        );
        replaceShiftTable(_withHolidays({'2026-10-12'}));
        expect(withHolidays, without, reason: 'minuto $minute');
      }
    });
  });

  test('el mismo lunes SIN el festivo cargado es un lunes normal', () {
    expect(isHolidayOrSunday(_holidayMonday(8, 0)), isFalse);
    expect(getCurrentShift(_holidayMonday(8, 0)), Shift.morning);
    expect(getCurrentShift(_holidayMonday(12, 0)), Shift.afternoon1);
    expect(getCurrentShift(_holidayMonday(14, 30)), Shift.afternoon2);
    expect(getCurrentShift(_holidayMonday(20, 0)), Shift.night1);
    expect(getCurrentShift(_holidayMonday(19, 16)), Shift.night1);
    expect(shiftGapBefore(_holidayMonday(10, 55)), Shift.morning);
  });
}
