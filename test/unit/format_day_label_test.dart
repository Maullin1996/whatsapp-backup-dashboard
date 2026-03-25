import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/helpers/format_day_label.dart';

void main() {
  test('formatDayLabel returns HOY for today', () {
    final now = DateTime.now();
    final label = formatDayLabel(now.millisecondsSinceEpoch);
    expect(label, 'HOY');
  });

  test('formatDayLabel returns AYER for yesterday', () {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final label = formatDayLabel(yesterday.millisecondsSinceEpoch);
    expect(label, 'AYER');
  });

  test('formatDayLabel returns dd/mm/yyyy for older dates', () {
    final date = DateTime(2020, 2, 9, 10, 30);
    final label = formatDayLabel(date.millisecondsSinceEpoch);
    expect(label, '09/02/2020');
  });
}
