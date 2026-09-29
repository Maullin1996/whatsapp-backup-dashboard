import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/can_view_matches.dart';

/// Decisión pura del guard global de `router.dart`, separada de `redirect:`
/// (y de este archivo aparte del propio `router.dart`) para poder testearla
/// sin GoRouter ni las páginas destino. Importar `router.dart` en un test ya
/// no cargaba desde antes de `/matches`: arrastra `HomePage` (vía
/// `MessageList`/`MessageBubble`), que usa `ExtendedImage`/`package:web`, y
/// eso no compila en tests de VM (mismo problema conocido de
/// `message_bubble_test.dart`/`message_list_test.dart`, confirmado
/// importando el `router.dart` previo a este cambio en un test aislado).
String? computeAuthRedirect({
  required AuthSessionState authState,
  required String location,
}) {
  // ✅ Maneja el estado loading — no redirigir todavía
  final isLoading = authState.maybeWhen(
    loading: () => true,
    orElse: () => false,
  );
  if (isLoading) return null;

  final isLoggedIn = authState.maybeWhen(
    authenticated: (_) => true,
    orElse: () => false,
  );

  final isAdmin = authState.maybeWhen(
    orElse: () => false,
    authenticated: (user) => user.isAdmin,
  );

  // Acceso a /matches: admin o superAdmin (ver canViewMatches). Aparte de
  // isAdmin porque /admin no cubre superAdmin y no se toca ese
  // comportamiento existente.
  final canGoToMatches = authState.maybeWhen(
    orElse: () => false,
    authenticated: (user) => canViewMatches(user),
  );

  final isGoingToLogin = location == '/login';
  final isGoingToAdmin = location == '/admin';
  final isGoingToMatches = location == '/matches';

  if (!isLoggedIn) return isGoingToLogin ? null : '/login';
  if (isGoingToLogin) return '/home';
  if (isGoingToAdmin && !isAdmin) return '/home';
  if (isGoingToMatches && !canGoToMatches) return '/home';
  // `/summary` solo exige sesión iniciada (ya cubierto arriba): a propósito,
  // sin `isAdmin` ni rol de revisor/sumador, porque esos claims reales
  // todavía no existen (ver image-review-roles, "Rol activo TEMPORAL"). Se
  // acotará cuando existan.

  return null;
}
