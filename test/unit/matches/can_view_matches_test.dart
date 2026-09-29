import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/can_view_matches.dart';

AuthenticatedUser _user({required bool isAdmin, required bool isSuperAdmin}) =>
    AuthenticatedUser(
      id: 'uid',
      email: 'a@x.com',
      isAdmin: isAdmin,
      isSuperAdmin: isSuperAdmin,
    );

void main() {
  test('admin (sin superAdmin) puede ver Coincidencias', () {
    expect(canViewMatches(_user(isAdmin: true, isSuperAdmin: false)), isTrue);
  });

  test('superAdmin (sin admin) puede ver Coincidencias', () {
    expect(canViewMatches(_user(isAdmin: false, isSuperAdmin: true)), isTrue);
  });

  test('admin y superAdmin a la vez puede ver Coincidencias', () {
    expect(canViewMatches(_user(isAdmin: true, isSuperAdmin: true)), isTrue);
  });

  test('ni admin ni superAdmin no puede ver Coincidencias', () {
    expect(canViewMatches(_user(isAdmin: false, isSuperAdmin: false)), isFalse);
  });
}
