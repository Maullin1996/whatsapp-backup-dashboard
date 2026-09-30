import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/widgets/group_shifts_dialog.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/shift_stats_provider.dart';

/// Lunes 5 de octubre de 2026 y el sábado y domingo alrededor (hora local).
DateTime _monday(int h, int m, [int s = 0]) => DateTime(2026, 10, 5, h, m, s);
DateTime _saturday(int h, int m) => DateTime(2026, 10, 3, h, m);
DateTime _sunday(int h, int m, [int s = 0]) => DateTime(2026, 10, 11, h, m, s);

/// Corte de prueba: medianoche local del lunes (en la app es una constante;
/// en los tests se pasa como parámetro).
final _cut = DateTime(2026, 10, 5).millisecondsSinceEpoch;

Shift _shift(DateTime d) => getCurrentShift(d, effectiveFromMs: _cut);
String _label(DateTime d) => shiftViewerLabel(d, effectiveFromMs: _cut);

void main() {
  test('las fechas de prueba caen en el día de la semana esperado', () {
    expect(_monday(0, 0).weekday, DateTime.monday);
    expect(_saturday(0, 0).weekday, DateTime.saturday);
    expect(_sunday(0, 0).weekday, DateTime.sunday);
  });

  group('constante en null: todo igual que hoy', () {
    test('la constante de la app está en null', () {
      expect(newShiftsEffectiveFromMs, isNull);
      expect(usesNewShiftTable(DateTime(2099).millisecondsSinceEpoch), isFalse);
    });

    test('un día después de cualquier corte sigue con la tabla vieja', () {
      // 10:54 es mañana en la vieja y un hueco en la nueva.
      expect(getCurrentShift(_monday(10, 54)), Shift.morning);
      expect(getCurrentShift(_monday(22, 27)), Shift.night2);
      expect(getCurrentShift(_monday(5, 45)), Shift.outOfShift);
      expect(shiftGapBefore(_monday(10, 55)), isNull);
      expect(shiftNamesAt(_monday(12, 0).millisecondsSinceEpoch), shiftNames);
    });

    test('la etiqueta del visor es la vieja de siempre, en todo el día', () {
      for (var minute = 0; minute < 24 * 60; minute++) {
        final date = _monday(minute ~/ 60, minute % 60);
        expect(
          shiftViewerLabel(date),
          shiftNames[getCurrentShift(date)],
          reason: '$date',
        );
      }
    });

    test('las jornadas asignables incluyen night2, como hoy', () {
      expect(assignableShiftsAt(_monday(12, 0).millisecondsSinceEpoch), [
        Shift.morning,
        Shift.afternoon1,
        Shift.afternoon2,
        Shift.night1,
        Shift.night2,
        Shift.holiday,
      ]);
    });
  });

  group('con el corte fijado', () {
    test('un mensaje anterior usa la tabla vieja y uno posterior la nueva', () {
      expect(usesNewShiftTable(_cut - 1, effectiveFromMs: _cut), isFalse);
      expect(usesNewShiftTable(_cut, effectiveFromMs: _cut), isTrue);

      // Sábado (antes del corte): tabla vieja.
      expect(_shift(_saturday(10, 54)), Shift.morning);
      expect(_label(_saturday(10, 54)), shiftNames[Shift.morning]);
      expect(_shift(_saturday(22, 27)), Shift.night2);
      expect(_label(_saturday(22, 27)), shiftNames[Shift.night2]);

      // Lunes (después del corte): tabla nueva.
      expect(_shift(_monday(10, 54)), Shift.outOfShift);
      expect(_shift(_monday(22, 27)), Shift.outOfShift);
      expect(_label(_monday(9, 0)), newShiftNames[Shift.morning]);
      expect(
        shiftNamesAt(
          _monday(9, 0).millisecondsSinceEpoch,
          effectiveFromMs: _cut,
        ),
        newShiftNames,
      );
    });

    group('bordes de la tabla nueva (fin inclusivo, se trunca al minuto)', () {
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
        (_monday(22, 30, 0), Shift.outOfShift),
      ];
      for (final (date, expected) in cases) {
        test(
          '${date.hour}:${date.minute}:${date.second} -> ${expected.name}',
          () {
            expect(_shift(date), expected);
          },
        );
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
        expect(_shift(date), Shift.outOfShift, reason: '$date');
        expect(shiftGapBefore(date, effectiveFromMs: _cut), before);
        expect(_label(date), label, reason: '$date');
        expect(shiftFromLabel(label), Shift.outOfShift);
      }
    });

    test('un mensaje a las 10:55: outOfShift para reportes, "Fuera de jornada '
        'Mañana" en el visor, y esa etiqueta se traduce a outOfShift', () {
      final date = _monday(10, 55);
      expect(_shift(date), Shift.outOfShift);
      expect(_label(date), 'Fuera de jornada Mañana');
      expect(shiftFromLabel('Fuera de jornada Mañana'), Shift.outOfShift);
    });

    test('la madrugada no es hueco: 22:16 y 05:29 son "Fuera de las '
        'jornadas"', () {
      for (final date in [_monday(22, 16), _monday(23, 59), _monday(5, 29)]) {
        expect(_shift(date), Shift.outOfShift);
        expect(shiftGapBefore(date, effectiveFromMs: _cut), isNull);
        expect(_label(date), 'Fuera de las jornadas', reason: '$date');
      }
    });

    test('domingo: holiday 06:00-19:15 con la tabla nueva; lo demás "Fuera '
        'de las jornadas", sin grupo', () {
      expect(_shift(_sunday(5, 59, 59)), Shift.outOfShift);
      expect(_shift(_sunday(6, 0)), Shift.holiday);
      expect(_shift(_sunday(19, 15, 59)), Shift.holiday);
      expect(_shift(_sunday(19, 16)), Shift.outOfShift);
      expect(_label(_sunday(12, 0)), 'Domingo / Festivo (06:00 – 19:15)');
      // A la hora de un hueco de semana, un domingo no es hueco.
      expect(shiftGapBefore(_sunday(10, 55), effectiveFromMs: _cut), isNull);
      expect(_label(_sunday(19, 16)), 'Fuera de las jornadas');
    });

    test('newShiftLastMinute coincide con los bordes de la tabla nueva', () {
      expect(newShiftLastMinute.keys, isNot(contains(Shift.night2)));
      for (final MapEntry(key: shift, value: last)
          in newShiftLastMinute.entries) {
        final base = shift == Shift.holiday ? _sunday(0, 0) : _monday(0, 0);
        final atLast = base.add(Duration(minutes: last, seconds: 59));
        final after = base.add(Duration(minutes: last + 1));
        expect(_shift(atLast), shift, reason: shift.name);
        expect(_shift(after), isNot(shift), reason: shift.name);
      }
    });

    test('ya no se ofrece night2 como jornada asignable', () {
      expect(
        assignableShiftsAt(
          _monday(12, 0).millisecondsSinceEpoch,
          effectiveFromMs: _cut,
        ),
        [
          Shift.morning,
          Shift.afternoon1,
          Shift.afternoon2,
          Shift.night1,
          Shift.holiday,
        ],
      );
    });
  });

  group('shiftFromLabel', () {
    test('reconoce las etiquetas viejas y las nuevas con la misma clave', () {
      for (final MapEntry(key: shift, value: label) in shiftNames.entries) {
        expect(shiftFromLabel(label), shift, reason: label);
      }
      for (final MapEntry(key: shift, value: label) in newShiftNames.entries) {
        expect(shiftFromLabel(label), shift, reason: label);
      }
      expect(
        shiftFromLabel('Jornada Mañana (06:00 – 10:54)'),
        shiftFromLabel('Jornada Mañana (05:30 – 10:51)'),
      );
    });

    test('una etiqueta vieja de night2 sigue dando night2', () {
      expect(shiftFromLabel('Jornada Noche (22:25 – 22:30)'), Shift.night2);
    });

    test('las etiquetas de hueco dan outOfShift; una desconocida, null', () {
      for (final label in newShiftGapLabels.values) {
        expect(shiftFromLabel(label), Shift.outOfShift, reason: label);
      }
      expect(shiftFromLabel('Jornada Madrugada (01:00 – 05:00)'), isNull);
    });
  });

  group('jornadaTerminada elige la tabla por el día de la jornada', () {
    // Corte a la medianoche de Bogotá del lunes 5 (05:00 UTC).
    final cutBogota = DateTime.utc(2026, 10, 5, 5).millisecondsSinceEpoch;
    // Hora de Bogotá expresada como instante UTC (UTC-5 fijo).
    DateTime bogota(int d, int h, int m) => DateTime.utc(2026, 10, d, h + 5, m);

    bool terminada(String fecha, Shift shift, DateTime now) =>
        jornadaTerminada(fecha, shift, now, effectiveFromMs: cutBogota);

    test(
      'un día antes del corte: tabla vieja (mañana termina a las 10:55)',
      () {
        expect(
          terminada('2026-10-03', Shift.morning, bogota(3, 10, 54)),
          isFalse,
        );
        expect(
          terminada('2026-10-03', Shift.morning, bogota(3, 10, 55)),
          isTrue,
        );
        expect(
          terminada('2026-10-03', Shift.night2, bogota(3, 22, 31)),
          isTrue,
        );
      },
    );

    test('el día del corte en adelante: tabla nueva (mañana termina a las '
        '10:52)', () {
      expect(
        terminada('2026-10-05', Shift.morning, bogota(5, 10, 51)),
        isFalse,
      );
      expect(terminada('2026-10-05', Shift.morning, bogota(5, 10, 52)), isTrue);
      expect(terminada('2026-10-05', Shift.night1, bogota(5, 22, 16)), isTrue);
      expect(terminada('2026-10-05', Shift.night1, bogota(5, 22, 15)), isFalse);
    });

    test('night2 no existe en un día de la tabla nueva: nunca termina', () {
      expect(terminada('2026-10-05', Shift.night2, bogota(6, 12, 0)), isFalse);
    });

    test('con la constante en null, siempre la tabla vieja', () {
      expect(
        jornadaTerminada('2026-10-05', Shift.morning, bogota(5, 10, 52)),
        isFalse,
      );
      expect(
        jornadaTerminada('2026-10-05', Shift.morning, bogota(5, 10, 55)),
        isTrue,
      );
    });
  });

  group('shortShiftName con las dos tablas', () {
    test('la única "Noche" de la tabla nueva queda "Noche"', () {
      expect(shortShiftName(newShiftNames[Shift.night1]!), 'Noche');
      expect(shortShiftName(newShiftNames[Shift.morning]!), 'Mañana');
    });

    test('las dos "Noche" viejas se siguen distinguiendo por su hora', () {
      expect(shortShiftName(shiftNames[Shift.night1]!), 'Noche (15:24)');
      expect(shortShiftName(shiftNames[Shift.night2]!), 'Noche (22:25)');
    });

    test('una etiqueta de hueco se muestra tal cual', () {
      expect(
        shortShiftName('Fuera de jornada Tarde 1'),
        'Fuera de jornada Tarde 1',
      );
    });
  });

  group('shiftStatRows (panel de control)', () {
    final stats = ShiftStats(
      byShift: {
        for (final s in Shift.values) s: 0,
        Shift.morning: 4,
        Shift.night2: 2,
        Shift.outOfShift: 1,
      },
      gapsAfter: {Shift.morning: 3},
    );
    final nowMs = _monday(12, 0).millisecondsSinceEpoch;

    test('tabla vieja: las 7 filas de siempre, con las etiquetas viejas', () {
      final rows = shiftStatRows(ShiftStats.empty(), nowMs: nowMs);
      expect(rows.map((r) => r.label), [
        for (final s in Shift.values) shiftNames[s],
      ]);
      expect(rows.every((r) => r.count == 0), isTrue);
    });

    test('tabla nueva: sin night2 ni huecos si no tienen imágenes', () {
      final rows = shiftStatRows(
        ShiftStats.empty(),
        nowMs: nowMs,
        effectiveFromMs: _cut,
      );
      expect(rows.map((r) => r.label), [
        newShiftNames[Shift.morning],
        newShiftNames[Shift.afternoon1],
        newShiftNames[Shift.afternoon2],
        newShiftNames[Shift.night1],
        newShiftNames[Shift.holiday],
        newShiftNames[Shift.outOfShift],
      ]);
    });

    test('tabla nueva: el hueco va justo después de su jornada y night2 '
        'aparece con su etiqueta vieja solo si tiene imágenes', () {
      final rows = shiftStatRows(stats, nowMs: nowMs, effectiveFromMs: _cut);
      expect(rows, [
        (label: newShiftNames[Shift.morning]!, count: 4),
        (label: 'Fuera de jornada Mañana', count: 3),
        (label: newShiftNames[Shift.afternoon1]!, count: 0),
        (label: newShiftNames[Shift.afternoon2]!, count: 0),
        (label: newShiftNames[Shift.night1]!, count: 0),
        (label: shiftNames[Shift.night2]!, count: 2),
        (label: newShiftNames[Shift.holiday]!, count: 0),
        (label: newShiftNames[Shift.outOfShift]!, count: 1),
      ]);
    });
  });
}
