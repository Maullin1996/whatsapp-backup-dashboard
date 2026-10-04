import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/helpers/jornadas_para_fecha.dart';

const _shifts = [
  ReviewShift(chatJid: 'c1', shift: Shift.night1),
  ReviewShift(chatJid: 'c1', shift: Shift.morning),
  ReviewShift(chatJid: 'c1', shift: Shift.holiday),
  ReviewShift(chatJid: 'c1', shift: Shift.night2),
  ReviewShift(chatJid: 'c1', shift: Shift.morning), // repetida
  ReviewShift(chatJid: 'c2', shift: Shift.afternoon1), // otro chat
];

void main() {
  tearDown(restoreFixedShiftTable);

  test('día normal: las jornadas no festivas de ese chat, en orden del día, '
      'sin repetir y sin night2', () {
    // Lunes 28 de septiembre de 2026.
    expect(jornadasParaFecha(_shifts, 'c1', DateTime(2026, 9, 28)), [
      Shift.morning,
      Shift.night1,
    ]);
  });

  test('domingo: solo holiday', () {
    expect(jornadasParaFecha(_shifts, 'c1', DateTime(2026, 9, 27)), [
      Shift.holiday,
    ]);
  });

  test('festivo entre semana (de la tabla activa): solo holiday', () {
    replaceShiftTable(
      ShiftTable(
        weekdayRanges: fixedShiftTable.weekdayRanges,
        holidayRange: fixedShiftTable.holidayRange,
        holidays: const {'2026-10-12'},
      ),
    );
    expect(jornadasParaFecha(_shifts, 'c1', DateTime(2026, 10, 12)), [
      Shift.holiday,
    ]);
  });

  test('sin asignaciones que apliquen: vacía', () {
    expect(jornadasParaFecha(_shifts, 'c2', DateTime(2026, 9, 27)), isEmpty);
    expect(jornadasParaFecha(const [], 'c1', DateTime(2026, 9, 28)), isEmpty);
  });
}
