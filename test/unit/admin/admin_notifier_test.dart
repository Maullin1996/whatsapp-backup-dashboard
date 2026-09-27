import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_providers.dart';

import 'fake_admin_repository.dart';

const _superAdmin = AppUser(
  uid: 'super',
  email: 'super@x.com',
  displayName: 'Super',
  disabled: false,
  allowedGroups: ['g1', 'g2'],
  isAdmin: true,
  isSuperAdmin: true,
);

const _admin = AppUser(
  uid: 'admin',
  email: 'admin@x.com',
  displayName: 'Admin',
  disabled: false,
  allowedGroups: ['g1'],
  isAdmin: true,
);

const _plain = AppUser(
  uid: 'plain',
  email: 'plain@x.com',
  displayName: 'Plain',
  disabled: false,
  allowedGroups: [],
);

void main() {
  late FakeAdminRepository repo;
  late ProviderContainer container;

  setUp(() async {
    repo = FakeAdminRepository([_superAdmin, _admin, _plain]);
    container = ProviderContainer(
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    // build() carga usuarios y grupos en un microtask.
    container.read(adminProvider);
    await pumpEventQueue();
  });

  AppUser userOf(String uid) =>
      container.read(adminProvider).users.firstWhere((u) => u.uid == uid);

  test('la lista inicial trae los usuarios con sus roles', () {
    expect(userOf('super').isSuperAdmin, isTrue);
    expect(userOf('admin').isAdmin, isTrue);
    expect(userOf('plain').isAdmin, isFalse);
  });

  group('secuencia del bug: acción optimista sobre un superAdmin', () {
    test('toggleUserStatus conserva isSuperAdmin e isAdmin', () async {
      await container
          .read(adminProvider.notifier)
          .toggleUserStatus(uid: 'super', disabled: true);

      final user = userOf('super');
      expect(user.isSuperAdmin, isTrue);
      expect(user.isAdmin, isTrue);
      expect(user.disabled, isTrue);
      expect(user.allowedGroups, ['g1', 'g2']);
      expect(user.displayName, 'Super');
    });

    test('updateUserGroups conserva isSuperAdmin e isAdmin', () async {
      await container
          .read(adminProvider.notifier)
          .updateUserGroups(uid: 'super', allowedGroups: ['g9']);

      final user = userOf('super');
      expect(user.isSuperAdmin, isTrue);
      expect(user.isAdmin, isTrue);
      expect(user.allowedGroups, ['g9']);
      expect(user.disabled, isFalse);
    });

    test('si toggleUserStatus falla, el revert también conserva los '
        'roles', () async {
      repo.failActions = true;

      await container
          .read(adminProvider.notifier)
          .toggleUserStatus(uid: 'super', disabled: true);

      final user = userOf('super');
      expect(user.isSuperAdmin, isTrue);
      expect(user.isAdmin, isTrue);
      expect(user.disabled, isFalse, reason: 'se revirtió');
      expect(container.read(adminProvider).error, isNotNull);
    });
  });

  group('un admin (no super) tampoco pierde su rol', () {
    test('toggleUserStatus', () async {
      await container
          .read(adminProvider.notifier)
          .toggleUserStatus(uid: 'admin', disabled: true);

      expect(userOf('admin').isAdmin, isTrue);
      expect(userOf('admin').isSuperAdmin, isFalse);
    });

    test('updateUserGroups', () async {
      await container
          .read(adminProvider.notifier)
          .updateUserGroups(uid: 'admin', allowedGroups: []);

      expect(userOf('admin').isAdmin, isTrue);
      expect(userOf('admin').allowedGroups, isEmpty);
    });
  });

  test('las acciones sobre un usuario no tocan a los demás', () async {
    await container
        .read(adminProvider.notifier)
        .toggleUserStatus(uid: 'plain', disabled: true);

    expect(userOf('plain').disabled, isTrue);
    expect(userOf('super').disabled, isFalse);
    expect(userOf('super').isSuperAdmin, isTrue);
    expect(userOf('admin').isAdmin, isTrue);
  });

  group('setUserRole (sin regresión)', () {
    test('promover cambia solo isAdmin', () async {
      await container
          .read(adminProvider.notifier)
          .setUserRole(uid: 'plain', role: 'admin');

      expect(userOf('plain').isAdmin, isTrue);
      expect(userOf('plain').isSuperAdmin, isFalse);
      expect(userOf('plain').email, 'plain@x.com');
    });

    test('degradar cambia solo isAdmin', () async {
      await container
          .read(adminProvider.notifier)
          .setUserRole(uid: 'admin', role: 'user');

      expect(userOf('admin').isAdmin, isFalse);
      expect(userOf('admin').allowedGroups, ['g1']);
    });
  });

  group('AppUser.copyWith', () {
    test('sin argumentos copia todos los campos', () {
      final copy = _superAdmin.copyWith();

      expect(copy.uid, _superAdmin.uid);
      expect(copy.email, _superAdmin.email);
      expect(copy.displayName, _superAdmin.displayName);
      expect(copy.disabled, _superAdmin.disabled);
      expect(copy.allowedGroups, _superAdmin.allowedGroups);
      expect(copy.isAdmin, _superAdmin.isAdmin);
      expect(copy.isSuperAdmin, _superAdmin.isSuperAdmin);
    });

    test('cada campo se puede reemplazar sin afectar a los demás', () {
      expect(_plain.copyWith(uid: 'x').uid, 'x');
      expect(_plain.copyWith(email: 'x@x.com').email, 'x@x.com');
      expect(_plain.copyWith(displayName: 'X').displayName, 'X');
      expect(_plain.copyWith(disabled: true).disabled, isTrue);
      expect(_plain.copyWith(allowedGroups: ['a']).allowedGroups, ['a']);
      expect(_plain.copyWith(isAdmin: true).isAdmin, isTrue);
      expect(_plain.copyWith(isSuperAdmin: true).isSuperAdmin, isTrue);

      final changed = _superAdmin.copyWith(disabled: true);
      expect(changed.isSuperAdmin, isTrue);
      expect(changed.isAdmin, isTrue);
      expect(changed.email, _superAdmin.email);
    });

    test('permite poner un rol en false explícitamente', () {
      final copy = _superAdmin.copyWith(isAdmin: false, isSuperAdmin: false);

      expect(copy.isAdmin, isFalse);
      expect(copy.isSuperAdmin, isFalse);
    });
  });
}
