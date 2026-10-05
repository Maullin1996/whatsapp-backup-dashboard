import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/widgets/group_shifts_dialog.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/shift_stats_provider.dart';

/// Lunes 5 y domingo 11 de octubre de 2026 (hora local).
DateTime _monday(int h, int m, [int s = 0]) => DateTime(2026, 10, 5, h, m, s);
DateTime _sunday(int h, int m, [int s = 0]) => DateTime(2026, 10, 11, h, m, s);

void main() {
  test('las fechas de prueba caen en el día de la semana esperado', () {
    expect(_monday(0, 0).weekday, DateTime.monday);
    expect(_sunday(0, 0).weekday, DateTime.sunday);
  });

  group('bordes de la tabla (fin inclusivo, se trunca al minuto)', () {
    final cases = <(DateTime, Shift)>[
      (_monday(5, 29, 59), Shift.outOfShift),
      (_monday(5, 30, 0), Shift.morning),
      (_monday(10, 51, 59), Shift.morning),
      (_monday(10, 52, 0), Shift.outOfShift),
      (_monday(10, 57, 59), Shift.outOfShift),
      (_monday(10, 58, 0), Shift.afternoon1),
      (_monday(13, 55, 59), Shift.afternoon1),
      (_monday(13, 56, 0), Shift.outOfShift),
      (_monday(14, 0, 59), Shift.outOfShift),
      (_monday(14, 1, 0), Shift.afternoon2),
      (_monday(15, 20, 59), Shift.afternoon2),
      (_monday(15, 21, 0), Shift.outOfShift),
      (_monday(15, 27, 59), Shift.outOfShift),
      (_monday(15, 28, 0), Shift.night1),
      (_monday(22, 15, 59), Shift.night1),
      (_monday(22, 16, 0), Shift.outOfShift),
      // Lo que antes era night2 ya no es ninguna jornada.
      (_monday(22, 27, 0), Shift.outOfShift),
      (_sunday(5, 59, 59), Shift.outOfShift),
      (_sunday(6, 0, 0), Shift.holiday),
      (_sunday(19, 15, 59), Shift.holiday),
      (_sunday(19, 16, 0), Shift.outOfShift),
    ];
    for (final (date, expected) in cases) {
      test('${date.weekday == DateTime.sunday ? 'domingo' : 'lunes'} '
          '${date.hour}:${date.minute}:${date.second} -> ${expected.name}', () {
        expect(getCurrentShift(date), expected);
      });
    }
  });

  test('getCurrentShift nunca devuelve night2, en ningún minuto de la '
      'semana', () {
    for (var day = 5; day <= 11; day++) {
      for (var minute = 0; minute < 24 * 60; minute++) {
        final date = DateTime(2026, 10, day, minute ~/ 60, minute % 60);
        expect(getCurrentShift(date), isNot(Shift.night2), reason: '$date');
      }
    }
  });

  test('los huecos de día: outOfShift para reportes y "Fuera de jornada X" '
      'para el visor', () {
    final gaps = <(DateTime, Shift, String)>[
      (_monday(10, 52), Shift.morning, 'Fuera de jornada Mañana'),
      (_monday(10, 55), Shift.morning, 'Fuera de jornada Mañana'),
      (_monday(10, 57), Shift.morning, 'Fuera de jornada Mañana'),
      (_monday(13, 56), Shift.afternoon1, 'Fuera de jornada Tarde 1'),
      (_monday(14, 0), Shift.afternoon1, 'Fuera de jornada Tarde 1'),
      (_monday(15, 21), Shift.afternoon2, 'Fuera de jornada Tarde 2'),
      (_monday(15, 27), Shift.afternoon2, 'Fuera de jornada Tarde 2'),
    ];
    for (final (date, before, label) in gaps) {
      expect(getCurrentShift(date), Shift.outOfShift, reason: '$date');
      expect(shiftGapBefore(date), before, reason: '$date');
      expect(shiftViewerLabel(date), label, reason: '$date');
      expect(shiftFromLabel(label), Shift.outOfShift);
    }
  });

  test('un mensaje a las 10:55 del lunes: outOfShift para reportes y '
      '"Fuera de jornada Mañana" en el visor', () {
    final date = _monday(10, 55);
    expect(getCurrentShift(date), Shift.outOfShift);
    expect(shiftViewerLabel(date), 'Fuera de jornada Mañana');
  });

  test('22:16 y la madrugada no son hueco: "Fuera de las jornadas"', () {
    for (final date in [
      _monday(22, 16),
      _monday(23, 59),
      _monday(0, 0),
      _monday(3, 0),
      _monday(5, 29),
    ]) {
      expect(getCurrentShift(date), Shift.outOfShift, reason: '$date');
      expect(shiftGapBefore(date), isNull, reason: '$date');
      expect(shiftViewerLabel(date), 'Fuera de las jornadas', reason: '$date');
    }
  });

  test('domingo: holiday con su etiqueta; fuera de horario, "Fuera de las '
      'jornadas" y nunca un hueco', () {
    expect(
      shiftViewerLabel(_sunday(12, 0)),
      'Domingo / Festivo (06:00 – 19:15)',
    );
    expect(shiftGapBefore(_sunday(10, 55)), isNull);
    expect(shiftViewerLabel(_sunday(10, 55)), shiftNames[Shift.holiday]);
    expect(shiftViewerLabel(_sunday(19, 16)), 'Fuera de las jornadas');
    expect(shiftViewerLabel(_sunday(5, 59)), 'Fuera de las jornadas');
  });

  test('dentro de una jornada, la etiqueta del visor es la de la tabla', () {
    expect(shiftViewerLabel(_monday(9, 0)), 'Jornada Mañana (05:30 – 10:51)');
    expect(shiftViewerLabel(_monday(12, 0)), 'Jornada Tarde 1 (10:58 – 13:55)');
    expect(shiftViewerLabel(_monday(15, 0)), 'Jornada Tarde 2 (14:01 – 15:20)');
    expect(shiftViewerLabel(_monday(20, 0)), 'Jornada Noche (15:28 – 22:15)');
  });

  test('ningún minuto del día recibe una etiqueta vieja', () {
    final legacyOnly = legacyShiftNames.values.toSet()
      ..removeAll(shiftNames.values);
    for (var minute = 0; minute < 24 * 60; minute++) {
      for (final day in [5, 11]) {
        final date = DateTime(2026, 10, day, minute ~/ 60, minute % 60);
        expect(
          legacyOnly.contains(shiftViewerLabel(date)),
          isFalse,
          reason: '$date',
        );
      }
    }
  });

  group('shiftFromLabel', () {
    test('reconoce las etiquetas de la tabla', () {
      for (final MapEntry(key: shift, value: label) in shiftNames.entries) {
        expect(shiftFromLabel(label), shift, reason: label);
      }
    });

    test('reconoce las etiquetas viejas con la misma clave, incluida la de '
        'night2', () {
      for (final MapEntry(key: shift, value: label)
          in legacyShiftNames.entries) {
        expect(shiftFromLabel(label), shift, reason: label);
      }
      expect(shiftFromLabel('Jornada Mañana (06:00 – 10:54)'), Shift.morning);
      expect(shiftFromLabel('Jornada Noche (22:25 – 22:30)'), Shift.night2);
    });

    test('las etiquetas de hueco dan outOfShift', () {
      for (final label in shiftGapLabels.values) {
        expect(shiftFromLabel(label), Shift.outOfShift, reason: label);
      }
    });

    test('una etiqueta que no coincide con ninguna da null, no lanza', () {
      expect(shiftFromLabel('Jornada Madrugada (01:00 – 05:00)'), isNull);
      expect(shiftFromLabel('Jornada Inexistente'), isNull);
      expect(shiftFromLabel(''), isNull);
      // Un atajo de prueba (sin el rango horario) no debe "casi matchear".
      expect(shiftFromLabel('Jornada Mañana'), isNull);
    });
  });

  group('shortShiftName', () {
    test('la única "Noche" de la tabla queda "Noche"', () {
      expect(shortShiftName(shiftNames[Shift.night1]!), 'Noche');
      expect(shortShiftName(shiftNames[Shift.morning]!), 'Mañana');
    });

    test('las dos "Noche" viejas se siguen distinguiendo por su hora', () {
      expect(shortShiftName(legacyShiftNames[Shift.night1]!), 'Noche (15:24)');
      expect(shortShiftName(legacyShiftNames[Shift.night2]!), 'Noche (22:25)');
    });

    test('una etiqueta de hueco se muestra tal cual', () {
      expect(
        shortShiftName('Fuera de jornada Tarde 1'),
        'Fuera de jornada Tarde 1',
      );
    });
  });

  test('jornadas asignables: sin night2 ni outOfShift', () {
    expect(assignableShifts, [
      Shift.morning,
      Shift.afternoon1,
      Shift.afternoon2,
      Shift.night1,
      Shift.holiday,
    ]);
  });

  group('shiftStatRows (panel de control)', () {
    test('sin huecos con imágenes: las jornadas de la tabla y "Fuera de las '
        'jornadas", sin night2', () {
      final rows = shiftStatRows(ShiftStats.empty());
      expect(rows.map((r) => r.label), [
        shiftNames[Shift.morning],
        shiftNames[Shift.afternoon1],
        shiftNames[Shift.afternoon2],
        shiftNames[Shift.night1],
        shiftNames[Shift.holiday],
        shiftNames[Shift.outOfShift],
      ]);
      expect(rows.every((r) => r.count == 0), isTrue);
    });

    test('el hueco va justo después de su jornada, solo si tiene '
        'imágenes', () {
      final stats = ShiftStats(
        byShift: {
          for (final s in Shift.values) s: 0,
          Shift.morning: 4,
          Shift.outOfShift: 1,
        },
        gapsAfter: {Shift.morning: 3},
      );
      expect(shiftStatRows(stats), [
        (label: shiftNames[Shift.morning]!, count: 4),
        (label: 'Fuera de jornada Mañana', count: 3),
        (label: shiftNames[Shift.afternoon1]!, count: 0),
        (label: shiftNames[Shift.afternoon2]!, count: 0),
        (label: shiftNames[Shift.night1]!, count: 0),
        (label: shiftNames[Shift.holiday]!, count: 0),
        (label: shiftNames[Shift.outOfShift]!, count: 1),
      ]);
    });
  });
}
