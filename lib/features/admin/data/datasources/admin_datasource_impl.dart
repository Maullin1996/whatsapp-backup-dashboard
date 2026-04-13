import 'package:cloud_functions/cloud_functions.dart';
import 'package:whatsapp_monitor_viewer/features/admin/data/datasources/admin_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/group.dart';

class AdminDatasourceImpl implements AdminDatasource {
  final FirebaseFunctions _functions;

  AdminDatasourceImpl(this._functions);

  HttpsCallable _fn(String name) => _functions.httpsCallable(name);

  @override
  Future<AppUser> createUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await _fn(
      'createUser',
    ).call({'email': email, 'password': password, 'displayName': displayName});
    return AppUser(
      uid: res.data['uid'] as String,
      email: res.data['email'] as String,
      displayName: res.data['displayName'] as String,
      disabled: false,
      allowedGroups: [],
    );
  }

  @override
  Future<List<Group>> listGroups() async {
    final res = await _fn('listGroups').call();
    final groups = res.data['groups'] as List<dynamic>;
    return groups
        .map(
          (g) => Group(
            chatJid: g['chatJid'] as String,
            groupName: g['groupName'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<List<AppUser>> listUsers() async {
    final res = await _fn('listUsers').call();
    final users = res.data['users'] as List<dynamic>;
    return users
        .map(
          (u) => AppUser(
            uid: u['uid'] as String,
            email: u['email'] as String,
            displayName: u['displayName'] as String,
            disabled: u['disabled'] as bool,
            allowedGroups: List<String>.from(u['allowedGroups'] ?? []),
          ),
        )
        .toList();
  }

  @override
  Future<void> toggleUserStatus({
    required String uid,
    required bool disabled,
  }) async {
    await _fn('toggleUserStatus').call({'uid': uid, 'disabled': disabled});
  }

  @override
  Future<void> updatePassword({
    required String uid,
    required String newPassword,
  }) async {
    await _fn(
      'updateUserPassword',
    ).call({'uid': uid, 'newPassword': newPassword});
  }

  @override
  Future<void> updateUserGroups({
    required String uid,
    required List<String> allowedGroups,
  }) async {
    await _fn(
      'updateUserGroups',
    ).call({'uid': uid, 'allowedGroups': allowedGroups});
  }
}
