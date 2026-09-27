import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_long_date.dart';

void main() {
  test('fecha en español sin ceros a la izquierda', () {
    expect(formatLongDate(DateTime(2026, 9, 26)), '26 de septiembre de 2026');
    expect(formatLongDate(DateTime(2026, 1, 5)), '5 de enero de 2026');
  });

  test('los 12 meses', () {
    const expected = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    for (var m = 1; m <= 12; m++) {
      expect(
        formatLongDate(DateTime(2025, m, 10)),
        '10 de ${expected[m - 1]} de 2025',
      );
    }
  });

  test('la hora no influye', () {
    expect(
      formatLongDate(DateTime(2026, 9, 26, 23, 59)),
      '26 de septiembre de 2026',
    );
  });
}
