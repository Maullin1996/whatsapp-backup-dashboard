import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/admin_failure.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/group.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

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
  Future<Either<AdminFailure, Unit>> deleteUser({required String uid});
  Future<Either<AdminFailure, Unit>> setUserRole({
    // ← nuevo
    required String uid,
    required String role,
  });
  Future<Either<AdminFailure, Unit>> setReviewRole({
    required String uid,
    required ReviewRole? role,
  });
  Future<Either<AdminFailure, Unit>> updateReviewShifts({
    required String uid,
    required List<ReviewShift> shifts,
  });
}
