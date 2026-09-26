import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/fecha_jornada.dart';

void main() {
  group('fechaJornadaDe', () {
    int ts(int y, int mo, int d, [int h = 12, int mi = 0]) =>
        DateTime(y, mo, d, h, mi).millisecondsSinceEpoch;

    test('formato yyyy-MM-dd con ceros a la izquierda', () {
      expect(fechaJornadaDe(ts(2026, 3, 5)), '2026-03-05');
      expect(fechaJornadaDe(ts(2026, 11, 30)), '2026-11-30');
    });

    test('usa la hora local (mismo criterio que la jornada)', () {
      // 23:59 sigue siendo el mismo día; 00:00 ya es el siguiente.
      expect(fechaJornadaDe(ts(2026, 12, 31, 23, 59)), '2026-12-31');
      expect(fechaJornadaDe(ts(2027, 1, 1, 0, 0)), '2027-01-01');
    });

    test('la jornada de la noche y de la mañana caen en su propio día', () {
      expect(fechaJornadaDe(ts(2026, 4, 6, 6, 0)), '2026-04-06');
      expect(fechaJornadaDe(ts(2026, 4, 6, 22, 30)), '2026-04-06');
    });

    test('no es la hora del mensaje (Message.messageDate guarda "HH:mm")', () {
      expect(fechaJornadaDe(ts(2026, 1, 15, 15, 24)), isNot(contains(':')));
    });
  });
}
