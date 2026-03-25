import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';

void main() {
  test('getCurrentShift returns expected ranges for weekdays', () {
    final base = DateTime(2024, 1, 1); // Monday

    expect(getCurrentShift(DateTime(base.year, base.month, base.day, 6, 0)), Shift.morning);
    expect(getCurrentShift(DateTime(base.year, base.month, base.day, 10, 54)), Shift.morning);

    expect(getCurrentShift(DateTime(base.year, base.month, base.day, 10, 55)), Shift.afternoon1);
    expect(getCurrentShift(DateTime(base.year, base.month, base.day, 13, 58)), Shift.afternoon1);

    expect(getCurrentShift(DateTime(base.year, base.month, base.day, 13, 59)), Shift.afternoon2);
    expect(getCurrentShift(DateTime(base.year, base.month, base.day, 15, 23)), Shift.afternoon2);

    expect(getCurrentShift(DateTime(base.year, base.month, base.day, 15, 24)), Shift.night1);
    expect(getCurrentShift(DateTime(base.year, base.month, base.day, 22, 24)), Shift.night1);

    expect(getCurrentShift(DateTime(base.year, base.month, base.day, 22, 25)), Shift.night2);
    expect(getCurrentShift(DateTime(base.year, base.month, base.day, 22, 30)), Shift.night2);

    expect(getCurrentShift(DateTime(base.year, base.month, base.day, 22, 31)), Shift.outOfShift);
    expect(getCurrentShift(DateTime(base.year, base.month, base.day, 5, 59)), Shift.outOfShift);
  });

  test('getCurrentShift returns holiday range for Sundays', () {
    final sunday = DateTime(2024, 1, 7); // Sunday

    expect(getCurrentShift(DateTime(sunday.year, sunday.month, sunday.day, 6, 0)), Shift.holiday);
    expect(getCurrentShift(DateTime(sunday.year, sunday.month, sunday.day, 19, 20)), Shift.holiday);

    expect(getCurrentShift(DateTime(sunday.year, sunday.month, sunday.day, 19, 21)), Shift.outOfShift);
    expect(getCurrentShift(DateTime(sunday.year, sunday.month, sunday.day, 5, 59)), Shift.outOfShift);
  });
}
