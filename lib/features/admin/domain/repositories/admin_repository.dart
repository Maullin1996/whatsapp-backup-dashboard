import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/admin_failure.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/group.dart';

abstract class AdminRepository {
  Future<Either<AdminFailure, List<AppUser>>> listUsers();
  Future<Either<AdminFailure, List<Group>>> listGroups();
  Future<Either<AdminFailure, AppUser>> createUser({
    required String email,
    required String password,
    required String displayName,
  });
  Future<Either<AdminFailure, Unit>> updatePassword({
    required String uid,
    required String newPassword,
  });
  Future<Either<AdminFailure, Unit>> toggleUserStatus({
    required String uid,
    required bool disabled,
  });
  Future<Either<AdminFailure, Unit>> updateUserGroups({
    required String uid,
    required List<String> allowedGroups,
  });
}
