import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

class AuthenticatedUser {
  final String id;
  final String email;
  final bool isAdmin;
  final bool isSuperAdmin; // ← nuevo

  /// Rol de revisión de imágenes ('revisor'/'sumador'), leído del custom
  /// claim `reviewRole`; `null` si no tiene ninguno. Fuente real de
  /// `currentReviewRoleProvider` cuando hay sesión autenticada.
  final ReviewRole? reviewRole;

  AuthenticatedUser({
    required this.id,
    required this.email,
    required this.isAdmin,
    required this.isSuperAdmin, // ← nuevo
    this.reviewRole,
  });
}
