import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/admin/data/datasources/admin_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/group.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

/// Convierte el `reviewRole` que devuelve `listUsers` ('revisor' | 'sumador'
/// | null) en el enum tipado. Defensivo: un valor que no calce con el enum
/// (dato corrupto o de una versión futura) se avisa con `debugPrint` y da
/// `null`, en vez de tirar una excepción que tumbaría la carga completa de
/// usuarios por culpa de una sola cuenta.
ReviewRole? parseReviewRoleClaim(Object? raw) {
  if (raw == null) return null;
  try {
    return ReviewRole.values.byName(raw as String);
  } catch (e) {
    debugPrint('reviewRole con valor inesperado ($raw): se ignora. $e');
    return null;
  }
}

/// Convierte el `reviewShifts` que devuelve `listUsers` (lista de
/// `{chatJid, shift}`, o ausente) en la lista tipada. Cada entrada se valida
/// por separado: una entrada corrupta se descarta con `debugPrint` sin
/// afectar a las demás ni a los demás usuarios de la lista.
List<ReviewShift> parseReviewShifts(Object? raw) {
  if (raw == null) return const [];
  final list = raw as List<dynamic>;
  final result = <ReviewShift>[];
  for (final entry in list) {
    try {
      final map = entry as Map<Object?, Object?>;
      result.add(
        ReviewShift(
          chatJid: map['chatJid'] as String,
          shift: Shift.values.byName(map['shift'] as String),
        ),
      );
    } catch (e) {
      debugPrint('Entrada de reviewShifts inválida ($entry): se descarta. $e');
    }
  }
  return result;
}

/// Convierte los `details` de un error `already-exists` de
/// `updateReviewShifts` (`{ conflicts: [{chatJid, shift}] }`) en la lista
/// tipada de tuplas en conflicto. Defensivo: cualquier forma inesperada da
/// una lista vacía en vez de lanzar — el mensaje base de
/// `AdminFailure.reviewShiftConflict` sigue siendo útil aunque no se puedan
/// resaltar las tuplas exactas.
List<ReviewShift> parseReviewShiftConflicts(Object? details) {
  try {
    final map = details as Map<Object?, Object?>;
    final conflicts = map['conflicts'] as List<dynamic>;
    return conflicts.map((c) {
      final entry = c as Map<Object?, Object?>;
      return ReviewShift(
        chatJid: entry['chatJid'] as String,
        shift: Shift.values.byName(entry['shift'] as String),
      );
    }).toList();
  } catch (e) {
    debugPrint('No se pudieron leer los conflictos de updateReviewShifts: $e');
    return const [];
  }
}

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

  // En listUsers, actualizar el mapeo para leer isAdmin e isSuperAdmin:
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
            isAdmin: u['isAdmin'] as bool? ?? false, // ← nuevo
            isSuperAdmin: u['isSuperAdmin'] as bool? ?? false, // ← nuevo
            reviewRole: parseReviewRoleClaim(u['reviewRole']),
            reviewShifts: parseReviewShifts(u['reviewShifts']),
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

  @override
  Future<void> deleteUser({required String uid}) async {
    await _fn('deleteUser').call({'uid': uid});
  }

  @override
  Future<void> setUserRole({required String uid, required String role}) async {
    await _fn('setUserRole').call({'uid': uid, 'role': role});
  }

  @override
  Future<void> setReviewRole({
    required String uid,
    required ReviewRole? role,
  }) async {
    await _fn('setReviewRole').call({'uid': uid, 'role': role?.name});
  }

  @override
  Future<void> updateReviewShifts({
    required String uid,
    required List<ReviewShift> shifts,
  }) async {
    await _fn('updateReviewShifts').call({
      'uid': uid,
      'shifts': [
        for (final s in shifts) {'chatJid': s.chatJid, 'shift': s.shift.name},
      ],
    });
  }
}
