import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/group.dart';

abstract class AdminDatasource {
  Future<List<AppUser>> listUsers();
  Future<List<Group>> listGroups();
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> updatePassword({
    required String uid,
    required String newPassword,
  });
  Future<void> toggleUserStatus({required String uid, required bool disabled});
  Future<void> updateUserGroups({
    required String uid,
    required List<String> allowedGroups,
  });
}
