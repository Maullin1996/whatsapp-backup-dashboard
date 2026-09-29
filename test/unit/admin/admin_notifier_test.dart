import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/admin_failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

import 'fake_admin_repository.dart';

const _shifts = [ReviewShift(chatJid: 'c1@g.us', shift: Shift.morning)];

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

  group('setReviewRole (optimista, pero SIEMPRE recarga)', () {
    test('éxito: el rol queda seteado tras recargar', () async {
      await container
          .read(adminProvider.notifier)
          .setReviewRole(uid: 'plain', role: ReviewRole.revisor);

      expect(userOf('plain').reviewRole, ReviewRole.revisor);
    });

    test('null desactiva el rol', () async {
      await container
          .read(adminProvider.notifier)
          .setReviewRole(uid: 'plain', role: ReviewRole.revisor);
      expect(userOf('plain').reviewRole, isNotNull);

      await container
          .read(adminProvider.notifier)
          .setReviewRole(uid: 'plain', role: null);

      expect(userOf('plain').reviewRole, isNull);
    });

    test('un fallo también recarga (a diferencia de setUserRole, que solo '
        'recarga si falla — acá siempre)', () async {
      repo.failActions = true;

      await container
          .read(adminProvider.notifier)
          .setReviewRole(uid: 'plain', role: ReviewRole.revisor);

      // El fake no muta `users` si `failActions` es true: que el estado
      // siga reflejando `null` confirma que loadUsers() se ejecutó (si no
      // recargara, quedaría el valor optimista `revisor`).
      expect(userOf('plain').reviewRole, isNull);
      expect(container.read(adminProvider).error, isNotNull);
    });
  });

  group('updateReviewShifts (no optimista, siempre recarga)', () {
    test(
      'éxito recarga el usuario con los horarios desde el servidor',
      () async {
        final result = await container
            .read(adminProvider.notifier)
            .updateReviewShifts(uid: 'plain', shifts: _shifts);

        expect(result.isRight(), isTrue);
        expect(userOf('plain').reviewShifts, _shifts);
      },
    );

    test('un fallo NO cambia el usuario en el estado local, pero sí '
        'recarga', () async {
      repo.failUpdateReviewShiftsWith = const AdminFailure.reviewShiftConflict(
        _shifts,
      );

      final result = await container
          .read(adminProvider.notifier)
          .updateReviewShifts(uid: 'plain', shifts: _shifts);

      expect(
        result,
        const Left<AdminFailure, Unit>(
          AdminFailure.reviewShiftConflict(_shifts),
        ),
      );
      expect(userOf('plain').reviewShifts, isEmpty, reason: 'no se tocó');
      expect(container.read(adminProvider).error, isNotNull);
    });

    test('reemplaza la lista completa (no combina con la anterior)', () async {
      await container
          .read(adminProvider.notifier)
          .updateReviewShifts(uid: 'plain', shifts: _shifts);
      expect(userOf('plain').reviewShifts, _shifts);

      final result = await container
          .read(adminProvider.notifier)
          .updateReviewShifts(uid: 'plain', shifts: const []);

      expect(result.isRight(), isTrue);
      expect(userOf('plain').reviewShifts, isEmpty);
    });

    test(
      'el método devuelve el resultado, no solo lo refleja en error/successMessage',
      () async {
        final ok = await container
            .read(adminProvider.notifier)
            .updateReviewShifts(uid: 'admin', shifts: _shifts);
        expect(ok, const Right<AdminFailure, Unit>(unit));
      },
    );
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

    test('no pasar reviewRole conserva el valor actual', () {
      final withRole = _plain.copyWith(reviewRole: ReviewRole.revisor);
      expect(withRole.copyWith().reviewRole, ReviewRole.revisor);
      expect(withRole.copyWith(disabled: true).reviewRole, ReviewRole.revisor);
    });

    test('pasar reviewRole: null SÍ lo limpia (a diferencia del resto de '
        'los campos, donde null significa "no cambiar")', () {
      final withRole = _plain.copyWith(reviewRole: ReviewRole.revisor);

      final cleared = withRole.copyWith(reviewRole: null);

      expect(cleared.reviewRole, isNull);
    });

    test('reviewShifts se reemplaza igual que allowedGroups', () {
      final copy = _plain.copyWith(reviewShifts: _shifts);
      expect(copy.reviewShifts, _shifts);
      expect(copy.copyWith().reviewShifts, _shifts);
    });
  });
}
