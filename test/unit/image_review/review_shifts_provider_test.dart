import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_shifts_firestore_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';

class _FakeReviewShiftsDatasource implements ReviewShiftsDatasource {
  final List<ReviewShift> shifts;
  int calls = 0;

  _FakeReviewShiftsDatasource(this.shifts);

  @override
  Future<List<ReviewShift>> fetchReviewShifts(String uid) async {
    calls++;
    return shifts;
  }
}

void main() {
  group('parseReviewShiftsField', () {
    test('null (sin datos) da lista vacía', () {
      expect(parseReviewShiftsField(null), isEmpty);
    });

    test('una lista completa se parsea con Shift tipado', () {
      final result = parseReviewShiftsField([
        {'chatJid': 'c1@g.us', 'shift': 'afternoon1'},
        {'chatJid': 'c2@g.us', 'shift': 'holiday'},
      ]);

      expect(result, [
        const ReviewShift(chatJid: 'c1@g.us', shift: Shift.afternoon1),
        const ReviewShift(chatJid: 'c2@g.us', shift: Shift.holiday),
      ]);
    });

    test('una entrada corrupta se descarta sin afectar a las demás', () {
      final result = parseReviewShiftsField([
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

  group('reviewShiftsProvider', () {
    test(
      'sin sesión (uid null), lista vacía sin llamar al datasource',
      () async {
        final datasource = _FakeReviewShiftsDatasource([
          const ReviewShift(chatJid: 'c1@g.us', shift: Shift.morning),
        ]);
        final container = ProviderContainer(
          overrides: [
            reviewerUidProvider.overrideWithValue(null),
            currentReviewRoleProvider.overrideWithValue(ReviewRole.revisor),
            reviewShiftsDatasourceProvider.overrideWithValue(datasource),
          ],
        );
        addTearDown(container.dispose);

        expect(await container.read(reviewShiftsProvider.future), isEmpty);
        expect(datasource.calls, 0);
      },
    );

    test('con sesión pero sin rol activo, lista vacía sin llamar al '
        'datasource', () async {
      final datasource = _FakeReviewShiftsDatasource([
        const ReviewShift(chatJid: 'c1@g.us', shift: Shift.morning),
      ]);
      final container = ProviderContainer(
        overrides: [
          reviewerUidProvider.overrideWithValue('uid-a'),
          currentReviewRoleProvider.overrideWithValue(null),
          reviewShiftsDatasourceProvider.overrideWithValue(datasource),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(reviewShiftsProvider.future), isEmpty);
      expect(datasource.calls, 0);
    });

    test(
      'con sesión y rol activo, lee del datasource con el uid actual',
      () async {
        final shifts = [
          const ReviewShift(chatJid: 'c1@g.us', shift: Shift.morning),
          const ReviewShift(chatJid: 'c2@g.us', shift: Shift.night1),
        ];
        final datasource = _FakeReviewShiftsDatasource(shifts);
        final container = ProviderContainer(
          overrides: [
            reviewerUidProvider.overrideWithValue('uid-a'),
            currentReviewRoleProvider.overrideWithValue(ReviewRole.revisor),
            reviewShiftsDatasourceProvider.overrideWithValue(datasource),
          ],
        );
        addTearDown(container.dispose);

        expect(await container.read(reviewShiftsProvider.future), shifts);
        expect(datasource.calls, 1);
      },
    );
  });
}
