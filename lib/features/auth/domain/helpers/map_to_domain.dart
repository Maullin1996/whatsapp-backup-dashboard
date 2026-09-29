import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

/// Convierte el claim `reviewRole` ('revisor' | 'sumador' | ausente) al enum.
/// Mismo manejo defensivo que `parseReviewRoleClaim` del lado de admin
/// (`admin_datasource_impl.dart`): un valor que no calce con el enum no
/// rompe el login, se ignora con `debugPrint` y da "sin rol".
ReviewRole? parseReviewRoleClaim(Object? raw) {
  if (raw == null) return null;
  try {
    return ReviewRole.values.byName(raw as String);
  } catch (e) {
    debugPrint('reviewRole con valor inesperado ($raw): se ignora. $e');
    return null;
  }
}

Future<AuthenticatedUser> mapToDomain(User user) async {
  final idTokenResult = await user.getIdTokenResult(true);
  final isAdmin = idTokenResult.claims?['admin'] == true;
  final isSuperAdmin = idTokenResult.claims?['superAdmin'] == true; // ← nuevo
  final reviewRole = parseReviewRoleClaim(idTokenResult.claims?['reviewRole']);

  return AuthenticatedUser(
    id: user.uid,
    email: user.email ?? '',
    isAdmin: isAdmin,
    isSuperAdmin: isSuperAdmin, // ← nuevo
    reviewRole: reviewRole,
  );
}
