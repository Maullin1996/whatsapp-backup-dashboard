import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/admin_failure.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/group.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/repositories/admin_repository.dart';

/// Repositorio de administración falso para tests: no toca Firebase. Devuelve
/// [users] al listar y responde `Right` a las acciones, salvo que se pida que
/// [failActions] falle.
class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository(this.users);

  final List<AppUser> users;
  bool failActions = false;

  Either<AdminFailure, Unit> _result() => failActions
      ? const Left(AdminFailure.unknown('falló'))
      : const Right(unit);

  @override
  Future<Either<AdminFailure, List<AppUser>>> listUsers() async =>
      Right(List.of(users));

  @override
  Future<Either<AdminFailure, List<Group>>> listGroups() async =>
      const Right([]);

  @override
  Future<Either<AdminFailure, Unit>> toggleUserStatus({
    required String uid,
    required bool disabled,
  }) async => _result();

  @override
  Future<Either<AdminFailure, Unit>> updateUserGroups({
    required String uid,
    required List<String> allowedGroups,
  }) async => _result();

  @override
  Future<Either<AdminFailure, Unit>> setUserRole({
    required String uid,
    required String role,
  }) async => _result();

  @override
  Future<Either<AdminFailure, Unit>> deleteUser({required String uid}) async =>
      _result();

  @override
  Future<Either<AdminFailure, Unit>> updatePassword({
    required String uid,
    required String newPassword,
  }) async => _result();

  @override
  Future<Either<AdminFailure, AppUser>> createUser({
    required String email,
    required String password,
    required String displayName,
  }) async => Right(
    AppUser(
      uid: 'new',
      email: email,
      displayName: displayName,
      disabled: false,
      allowedGroups: const [],
    ),
  );
}
