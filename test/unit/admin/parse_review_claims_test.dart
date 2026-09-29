import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/admin/data/datasources/admin_datasource_impl.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

void main() {
  group('parseReviewRoleClaim', () {
    test('null (sin rol) da null', () {
      expect(parseReviewRoleClaim(null), isNull);
    });

    test('revisor y sumador se parsean', () {
      expect(parseReviewRoleClaim('revisor'), ReviewRole.revisor);
      expect(parseReviewRoleClaim('sumador'), ReviewRole.sumador);
    });

    test('un valor que no calza con el enum da null, no lanza', () {
      expect(parseReviewRoleClaim('admin'), isNull);
      expect(parseReviewRoleClaim(123), isNull);
    });
  });

  group('parseReviewShifts', () {
    test('null (sin datos) da lista vacía', () {
      expect(parseReviewShifts(null), isEmpty);
    });

    test('una lista completa se parsea con Shift tipado', () {
      final result = parseReviewShifts([
        {'chatJid': 'c1@g.us', 'shift': 'afternoon1'},
        {'chatJid': 'c2@g.us', 'shift': 'holiday'},
      ]);

      expect(result, [
        const ReviewShift(chatJid: 'c1@g.us', shift: Shift.afternoon1),
        const ReviewShift(chatJid: 'c2@g.us', shift: Shift.holiday),
      ]);
    });

    test('una entrada corrupta se descarta sin afectar a las demás', () {
      final result = parseReviewShifts([
        {'chatJid': 'c1@g.us', 'shift': 'morning'},
        {'chatJid': 'c2@g.us', 'shift': 'jornada-inexistente'}, // corrupta
        {'shift': 'holiday'}, // sin chatJid, corrupta
        {'chatJid': 'c3@g.us', 'shift': 'night1'},
      ]);

      expect(result, [
        const ReviewShift(chatJid: 'c1@g.us', shift: Shift.morning),
        const ReviewShift(chatJid: 'c3@g.us', shift: Shift.night1),
      ]);
    });
  });

  group('parseReviewShiftConflicts', () {
    test('forma esperada se parsea con Shift tipado', () {
      final result = parseReviewShiftConflicts({
        'conflicts': [
          {'chatJid': 'c1@g.us', 'shift': 'morning'},
          {'chatJid': 'c2@g.us', 'shift': 'night1'},
        ],
      });

      expect(result, [
        const ReviewShift(chatJid: 'c1@g.us', shift: Shift.morning),
        const ReviewShift(chatJid: 'c2@g.us', shift: Shift.night1),
      ]);
    });

    test('details null o con forma inesperada da lista vacía, no lanza', () {
      expect(parseReviewShiftConflicts(null), isEmpty);
      expect(parseReviewShiftConflicts('texto'), isEmpty);
      expect(parseReviewShiftConflicts({'conflicts': 'no es lista'}), isEmpty);
    });
  });
}
