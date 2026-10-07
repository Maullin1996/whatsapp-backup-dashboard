import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/can_view_matches.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/can_view_summary.dart';

/// Decisión pura del guard global de `router.dart`, separada de `redirect:`
/// (y de este archivo aparte del propio `router.dart`) para poder testearla
/// sin GoRouter ni las páginas destino. Importar `router.dart` en un test ya
/// no cargaba desde antes de `/matches`: arrastra `HomePage` (vía
/// `MessageList`/`MessageBubble`), que usa `ExtendedImage`/`package:web`, y
/// eso no compila en tests de VM (mismo problema conocido de
/// `message_bubble_test.dart`/`message_list_test.dart`, confirmado
/// importando el `router.dart` previo a este cambio en un test aislado).
///
/// [reviewSessionActive]: hay una sesión de llenado de formularios en curso
/// (`reviewSessionProvider`). Con sesión, toda ruta lleva a `/review` (ni el
/// botón "atrás" del navegador saca de ahí: solo "Cerrar" o recargar); sin
/// sesión, `/review` lleva a `/home`.
String? computeAuthRedirect({
  required AuthSessionState authState,
  required String location,
  bool reviewSessionActive = false,
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

  // Acceso a /summary: admin o superAdmin (ver canViewSummary). Revisor y
  // Sumador no la abren: no leen nada de `image_reviews`.
  final canGoToSummary = authState.maybeWhen(
    orElse: () => false,
    authenticated: (user) => canViewSummary(user),
  );

  final isGoingToLogin = location == '/login';
  final isGoingToAdmin = location == '/admin';
  final isGoingToMatches =
      location == '/matches' || location == '/matches/group';
  final isGoingToSummary =
      location == '/summary' || location == '/summary/detail';
  final isGoingToReview = location == '/review';

  if (!isLoggedIn) return isGoingToLogin ? null : '/login';
  if (reviewSessionActive) return isGoingToReview ? null : '/review';
  if (isGoingToReview) return '/home';
  if (isGoingToLogin) return '/home';
  if (isGoingToAdmin && !isAdmin) return '/home';
  if (isGoingToMatches && !canGoToMatches) return '/home';
  if (isGoingToSummary && !canGoToSummary) return '/home';

  return null;
}
