import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';

/// Acceso a la pantalla de Coincidencias: solo admin/superAdmin, sin
/// relación con `reviewRole` ni `reviewShifts` (esos gobiernan el
/// formulario de captura, no esta pantalla — ver `image-review-roles`). La
/// usan el guard de `router.dart` y el menú, para que nunca diverjan.
bool canViewMatches(AuthenticatedUser user) =>
    user.isAdmin || user.isSuperAdmin;
