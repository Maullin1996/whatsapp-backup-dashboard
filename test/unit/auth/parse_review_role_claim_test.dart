import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/helpers/map_to_domain.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

void main() {
  group('parseReviewRoleClaim', () {
    test('null (claim ausente) da null', () {
      expect(parseReviewRoleClaim(null), isNull);
    });

    test('"revisor" y "sumador" se parsean al enum', () {
      expect(parseReviewRoleClaim('revisor'), ReviewRole.revisor);
      expect(parseReviewRoleClaim('sumador'), ReviewRole.sumador);
    });

    test('un valor que no calza con el enum da null, no lanza (defensivo)', () {
      expect(parseReviewRoleClaim('admin'), isNull);
      expect(parseReviewRoleClaim(123), isNull);
      expect(parseReviewRoleClaim(true), isNull);
    });
  });
}
