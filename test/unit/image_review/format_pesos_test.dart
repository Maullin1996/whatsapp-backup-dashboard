import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/helpers/format_pesos.dart';

void main() {
  test('formatPesos usa punto de miles y el signo de pesos', () {
    expect(formatPesos(0), '\$0');
    expect(formatPesos(500), '\$500');
    expect(formatPesos(1000), '\$1.000');
    expect(formatPesos(9000), '\$9.000');
    expect(formatPesos(12000), '\$12.000');
    expect(formatPesos(1234567), '\$1.234.567');
  });

  test('formatPesos con negativos', () {
    expect(formatPesos(-9000), '-\$9.000');
  });
}
