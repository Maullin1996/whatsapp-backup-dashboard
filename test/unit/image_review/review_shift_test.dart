import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

void main() {
  group('ReviewShift', () {
    const a = ReviewShift(chatJid: 'c1@g.us', shift: Shift.morning);

    test('dos instancias con los mismos valores son iguales', () {
      const b = ReviewShift(chatJid: 'c1@g.us', shift: Shift.morning);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('difieren si cambia el grupo o la jornada', () {
      expect(a, isNot(a.copyWith(chatJid: 'c2@g.us')));
      expect(a, isNot(a.copyWith(shift: Shift.afternoon1)));
    });
  });
}
