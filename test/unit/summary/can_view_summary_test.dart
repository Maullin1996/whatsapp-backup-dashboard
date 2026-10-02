import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/can_view_summary.dart';

AuthenticatedUser _user({
  bool isAdmin = false,
  bool isSuperAdmin = false,
  ReviewRole? reviewRole,
}) => AuthenticatedUser(
  id: 'uid',
  email: 'a@x.com',
  isAdmin: isAdmin,
  isSuperAdmin: isSuperAdmin,
  reviewRole: reviewRole,
);

void main() {
  test('admin (sin superAdmin) puede ver el Resumen', () {
    expect(canViewSummary(_user(isAdmin: true)), isTrue);
  });

  test('superAdmin (sin admin) puede ver el Resumen', () {
    expect(canViewSummary(_user(isSuperAdmin: true)), isTrue);
  });

  test('admin y superAdmin a la vez puede ver el Resumen', () {
    expect(canViewSummary(_user(isAdmin: true, isSuperAdmin: true)), isTrue);
  });

  test('ni admin ni superAdmin no puede ver el Resumen', () {
    expect(canViewSummary(_user()), isFalse);
  });

  for (final rol in ReviewRole.values) {
    test('solo reviewRole ${rol.name} (sin admin) no puede ver el Resumen', () {
      expect(canViewSummary(_user(reviewRole: rol)), isFalse);
    });
  }

  test('admin con reviewRole sí puede (el rol de revisión no resta)', () {
    expect(
      canViewSummary(_user(isAdmin: true, reviewRole: ReviewRole.revisor)),
      isTrue,
    );
  });
}
