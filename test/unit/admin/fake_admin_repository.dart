import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/admin_failure.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/group.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/repositories/admin_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

/// Repositorio de administración falso para tests: no toca Firebase. Devuelve
/// [users] al listar y responde `Right` a las acciones, salvo que se pida que
/// [failActions] falle.
class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository(this.users, {this.groups = const []});

  List<AppUser> users;
  List<Group> groups;
  bool failActions = false;

  /// Si no es null, `updateReviewShifts` devuelve este fallo en vez de
  /// aplicar el cambio (para simular un conflicto de unicidad sin usar
  /// [failActions], que afectaría también a las demás acciones).
  AdminFailure? failUpdateReviewShiftsWith;

  Either<AdminFailure, Unit> _result() => failActions
      ? const Left(AdminFailure.unknown('falló'))
      : const Right(unit);

  @override
  Future<Either<AdminFailure, List<AppUser>>> listUsers() async =>
      Right(List.of(users));

  @override
  Future<Either<AdminFailure, List<Group>>> listGroups() async =>
      Right(List.of(groups));

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

  /// A diferencia de las demás acciones falsas, SÍ muta [users]: el
  /// `AdminNotifier` real recarga desde el servidor tras terminar (éxito o
  /// fallo), así que la próxima `listUsers()` debe reflejar el cambio.
  @override
  Future<Either<AdminFailure, Unit>> setReviewRole({
    required String uid,
    required ReviewRole? role,
  }) async {
    if (failActions) return _result();

    users = [
      for (final u in users)
        if (u.uid == uid) u.copyWith(reviewRole: role) else u,
    ];
    return const Right(unit);
  }

  /// A diferencia de las demás acciones falsas, SÍ muta [users] al tener
  /// éxito (mismo motivo que [setReviewRole]).
  @override
  Future<Either<AdminFailure, Unit>> updateReviewShifts({
    required String uid,
    required List<ReviewShift> shifts,
  }) async {
    final conflict = failUpdateReviewShiftsWith;
    if (conflict != null) return Left(conflict);
    if (failActions) return _result();

    users = [
      for (final u in users)
        if (u.uid == uid) u.copyWith(reviewShifts: shifts) else u,
    ];
    return const Right(unit);
  }

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
