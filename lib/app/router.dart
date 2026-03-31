//router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/pages/login_page.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/home/presentation/pages/home_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
    ],
    redirect: (context, state) {
      final authState = ref.read(authSessionProvider);

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

      final isGoingToLogin = state.matchedLocation == '/login';

      if (!isLoggedIn) return isGoingToLogin ? null : '/login';
      if (isGoingToLogin) return '/home';

      return null;
    },
  );

  // ✅ Escucha cambios y refresca el router directamente
  ref.listen(authSessionProvider, (_, _) {
    router.refresh();
  });

  return router;
});
