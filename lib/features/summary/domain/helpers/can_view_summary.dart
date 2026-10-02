import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';

/// Acceso al Resumen: solo admin/superAdmin (decisión del usuario). Revisor y
/// Sumador no lo abren: no leen nada de `image_reviews`. Hoy es la misma
/// regla que `canViewMatches`, pero separada para poder divergir. La usan el
/// guard de `router.dart` y el menú, para que nunca diverjan entre sí.
bool canViewSummary(AuthenticatedUser user) =>
    user.isAdmin || user.isSuperAdmin;
