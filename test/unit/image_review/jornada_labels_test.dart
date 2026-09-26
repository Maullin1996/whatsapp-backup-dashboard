import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/helpers/jornada_labels.dart';

void main() {
  group('shortShiftName', () {
    test('quita el prefijo "Jornada" y el rango horario', () {
      expect(shortShiftName(shiftNames[Shift.morning]!), 'Mañana');
      expect(shortShiftName(shiftNames[Shift.afternoon1]!), 'Tarde 1');
      expect(shortShiftName(shiftNames[Shift.afternoon2]!), 'Tarde 2');
      expect(shortShiftName(shiftNames[Shift.holiday]!), 'Domingo / Festivo');
    });

    test('las dos "Noche" se distinguen por su hora de inicio', () {
      expect(shortShiftName(shiftNames[Shift.night1]!), 'Noche (15:24)');
      expect(shortShiftName(shiftNames[Shift.night2]!), 'Noche (22:25)');
    });

    test('"Fuera de las jornadas" queda igual', () {
      expect(
        shortShiftName(shiftNames[Shift.outOfShift]!),
        'Fuera de las jornadas',
      );
    });

    test('un texto con otro formato se devuelve tal cual', () {
      expect(shortShiftName('morning'), 'morning');
    });
  });

  group('jornadaDateLabel', () {
    final now = DateTime(2026, 3, 9, 12);

    test('es null si la fecha es hoy', () {
      expect(jornadaDateLabel('2026-03-09', now: now), isNull);
    });

    test('otro día se muestra como dd/MM/yyyy', () {
      expect(jornadaDateLabel('2026-03-08', now: now), '08/03/2026');
      expect(jornadaDateLabel('2025-12-31', now: now), '31/12/2025');
    });
  });
}
