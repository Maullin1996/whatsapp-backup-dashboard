import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/bogota_time.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';

/// Instante UTC en el que en Bogotá (UTC-5) el reloj marca la fecha y hora
/// dadas.
DateTime _bogota(int y, int m, int d, int hour, int minute, [int second = 0]) =>
    DateTime.utc(y, m, d, hour + 5, minute, second);

void main() {
  // 2026-09-28 es lunes y 2026-09-27 es domingo.
  final monday = DateTime(2026, 9, 28);
  final sunday = DateTime(2026, 9, 27);

  DateTime dayOf(Shift shift) => shift == Shift.holiday ? sunday : monday;

  group('shiftLastMinute vs getCurrentShift', () {
    test('cubre todas las jornadas asignables y no outOfShift', () {
      expect(
        shiftLastMinute.keys.toSet(),
        Shift.values.toSet()..remove(Shift.outOfShift),
      );
    });

    for (final entry in shiftLastMinute.entries) {
      final shift = entry.key;
      final lastMinute = entry.value;

      test('$shift: su último minuto inclusivo es de la jornada y el '
          'siguiente no', () {
        final day = dayOf(shift);
        DateTime at(int minutes) =>
            DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

        expect(getCurrentShift(at(lastMinute)), shift);
        expect(getCurrentShift(at(lastMinute + 1)), isNot(shift));
      });
    }
  });

  group('bogotaWallClock', () {
    test('es UTC-5 fijo, sin importar la zona del dispositivo', () {
      final wall = bogotaWallClock(DateTime.utc(2026, 9, 28, 3, 26, 10));

      expect(
        (wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second),
        (2026, 9, 27, 22, 26, 10),
      );
    });

    test('acepta un DateTime local: el instante es el mismo', () {
      final instant = DateTime.utc(2026, 1, 1, 12);

      expect(bogotaWallClock(instant.toLocal()), bogotaWallClock(instant));
    });
  });

  group('jornadaTerminada', () {
    test('cada jornada termina en el minuto siguiente a su último minuto '
        'inclusivo, sin margen', () {
      // (jornada, fecha, hora y minuto de fin exacto)
      final cases = [
        (Shift.morning, (2026, 9, 28), 10, 55),
        (Shift.afternoon1, (2026, 9, 28), 13, 59),
        (Shift.afternoon2, (2026, 9, 28), 15, 24),
        (Shift.night1, (2026, 9, 28), 22, 25),
        (Shift.night2, (2026, 9, 28), 22, 31),
        (Shift.holiday, (2026, 9, 27), 19, 21),
      ];

      for (final (shift, (y, m, d), hour, minute) in cases) {
        final fecha =
            '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
        final justBefore = _bogota(y, m, d, hour, minute - 1, 59);
        final exact = _bogota(y, m, d, hour, minute);

        expect(
          jornadaTerminada(fecha, shift, justBefore),
          isFalse,
          reason: '$shift a las $hour:${minute - 1}:59',
        );
        expect(
          jornadaTerminada(fecha, shift, exact),
          isTrue,
          reason: '$shift a las $hour:$minute:00',
        );
      }
    });

    test('mañana: 10:54:59 no, 10:55:00 sí', () {
      expect(
        jornadaTerminada(
          '2026-09-28',
          Shift.morning,
          _bogota(2026, 9, 28, 10, 54, 59),
        ),
        isFalse,
      );
      expect(
        jornadaTerminada(
          '2026-09-28',
          Shift.morning,
          _bogota(2026, 9, 28, 10, 55),
        ),
        isTrue,
      );
    });

    test('outOfShift nunca termina', () {
      expect(
        jornadaTerminada('2026-01-01', Shift.outOfShift, DateTime.utc(2030)),
        isFalse,
      );
    });

    test('un día anterior a hoy siempre terminó, incluso la última '
        'jornada', () {
      final now = _bogota(2026, 9, 29, 0, 5);

      for (final shift in shiftLastMinute.keys) {
        expect(
          jornadaTerminada('2026-09-28', shift, now),
          isTrue,
          reason: '$shift',
        );
      }
    });

    test('un día futuro nunca terminó', () {
      final now = _bogota(2026, 9, 28, 23, 59, 59);

      for (final shift in shiftLastMinute.keys) {
        expect(
          jornadaTerminada('2026-09-29', shift, now),
          isFalse,
          reason: '$shift',
        );
      }
    });

    test('con un "ahora" en UTC que ya cambió de día, manda la hora de '
        'Bogotá', () {
      // 03:00 UTC del 28 = 22:00 del 27 en Bogotá.
      final now = DateTime.utc(2026, 9, 28, 3);

      // Hoy en Bogotá es el 27: la noche 1 (termina 22:25) sigue en curso y
      // la mañana del 28 es un día futuro.
      expect(jornadaTerminada('2026-09-27', Shift.night1, now), isFalse);
      expect(jornadaTerminada('2026-09-28', Shift.morning, now), isFalse);
      // La mañana y el domingo del 27 ya terminaron.
      expect(jornadaTerminada('2026-09-27', Shift.morning, now), isTrue);
      expect(jornadaTerminada('2026-09-27', Shift.holiday, now), isTrue);

      // 03:26 UTC = 22:26 en Bogotá: ahora sí terminó la noche 1.
      expect(
        jornadaTerminada(
          '2026-09-27',
          Shift.night1,
          DateTime.utc(2026, 9, 28, 3, 26),
        ),
        isTrue,
      );
    });

    test('una fecha con formato inválido no termina', () {
      final now = DateTime.utc(2030);

      expect(jornadaTerminada('27/09/2026', Shift.morning, now), isFalse);
      expect(jornadaTerminada('', Shift.morning, now), isFalse);
    });
  });
}
