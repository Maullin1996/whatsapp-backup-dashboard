import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/admin_failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/admin/data/datasources/admin_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/group.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

/// Datasource falso: cada método lanza lo que le indique el test, sin tocar
/// Firebase real. Solo implementa lo que usan estos tests; el resto no debería
/// llamarse.
class _ThrowingDatasource implements AdminDatasource {
  Object? createUserError;
  Object? setReviewRoleError;
  Object? updateReviewShiftsError;

  @override
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (createUserError != null) throw createUserError!;
    throw UnimplementedError();
  }

  @override
  Future<void> setReviewRole({
    required String uid,
    required ReviewRole? role,
  }) async {
    if (setReviewRoleError != null) throw setReviewRoleError!;
  }

  @override
  Future<void> updateReviewShifts({
    required String uid,
    required List<ReviewShift> shifts,
  }) async {
    if (updateReviewShiftsError != null) throw updateReviewShiftsError!;
  }

  @override
  Future<List<AppUser>> listUsers() => throw UnimplementedError();
  @override
  Future<List<Group>> listGroups() => throw UnimplementedError();
  @override
  Future<void> updatePassword({
    required String uid,
    required String newPassword,
  }) => throw UnimplementedError();
  @override
  Future<void> toggleUserStatus({
    required String uid,
    required bool disabled,
  }) => throw UnimplementedError();
  @override
  Future<void> updateUserGroups({
    required String uid,
    required List<String> allowedGroups,
  }) => throw UnimplementedError();
  @override
  Future<void> deleteUser({required String uid}) => throw UnimplementedError();
  @override
  Future<void> setUserRole({required String uid, required String role}) =>
      throw UnimplementedError();
}

final _alreadyExists = FirebaseFunctionsException(
  code: 'already-exists',
  message: 'already exists',
);

void main() {
  late _ThrowingDatasource datasource;
  late AdminRepositoryImpl repository;

  setUp(() {
    datasource = _ThrowingDatasource();
    repository = AdminRepositoryImpl(datasource);
  });

  group('setReviewRole', () {
    test('propaga el error mapeado genéricamente (sin caso propio)', () async {
      datasource.setReviewRoleError = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'x',
      );

      final result = await repository.setReviewRole(
        uid: 'u1',
        role: ReviewRole.revisor,
      );

      expect(
        result,
        const Left<AdminFailure, Unit>(AdminFailure.permissionDenied()),
      );
    });

    test('éxito da Right(unit)', () async {
      final result = await repository.setReviewRole(uid: 'u1', role: null);

      expect(result, const Right<AdminFailure, Unit>(unit));
    });
  });

  group('updateReviewShifts', () {
    test('already-exists mapea a reviewShiftConflict con las tuplas de '
        'details, no el mensaje genérico', () async {
      datasource.updateReviewShiftsError = FirebaseFunctionsException(
        code: 'already-exists',
        message: 'x',
        details: {
          'conflicts': [
            {'chatJid': 'c1@g.us', 'shift': 'morning'},
            {'chatJid': 'c2@g.us', 'shift': 'night1'},
          ],
        },
      );

      final result = await repository.updateReviewShifts(
        uid: 'u1',
        shifts: const [ReviewShift(chatJid: 'c1@g.us', shift: Shift.morning)],
      );

      expect(
        result,
        const Left<AdminFailure, Unit>(
          AdminFailure.reviewShiftConflict([
            ReviewShift(chatJid: 'c1@g.us', shift: Shift.morning),
            ReviewShift(chatJid: 'c2@g.us', shift: Shift.night1),
          ]),
        ),
      );
      expect(
        result.fold((f) => f.message, (_) => null),
        'Ese grupo y esa jornada ya están asignados a otro Revisor/Sumador.',
      );
    });

    test('already-exists con details ilegibles da conflicts vacío, no '
        'lanza', () async {
      datasource.updateReviewShiftsError = FirebaseFunctionsException(
        code: 'already-exists',
        message: 'x',
        details: 'texto inesperado, no un mapa',
      );

      final result = await repository.updateReviewShifts(
        uid: 'u1',
        shifts: const [],
      );

      expect(
        result,
        const Left<AdminFailure, Unit>(AdminFailure.reviewShiftConflict([])),
      );
    });

    test(
      'otros códigos siguen el mapeo genérico (no reviewShiftConflict)',
      () async {
        datasource.updateReviewShiftsError = FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'x',
        );

        final result = await repository.updateReviewShifts(
          uid: 'u1',
          shifts: const [],
        );

        expect(
          result,
          const Left<AdminFailure, Unit>(AdminFailure.invalidArgument()),
        );
      },
    );
  });

  group('createUser (regresión: no debe verse afectado)', () {
    test('already-exists sigue mapeando a emailAlreadyExists', () async {
      datasource.createUserError = _alreadyExists;

      final result = await repository.createUser(
        email: 'a@x.com',
        password: '123456',
        displayName: 'A',
      );

      expect(
        result,
        const Left<AdminFailure, AppUser>(AdminFailure.emailAlreadyExists()),
      );
      expect(
        result.fold((f) => f.message, (_) => null),
        'El correo ya está registrado',
      );
    });
  });
}
