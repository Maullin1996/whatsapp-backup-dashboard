//router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/pages/admin_page.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/pages/login_page.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/home/presentation/pages/home_page.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/image_detail_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
      GoRoute(
        path: '/home/viewer/:initialIndex',
        builder: (context, state) {
          final initialIndex = int.parse(state.pathParameters['initialIndex']!);
          return ImageDetailPage(initialIndex: initialIndex);
        },
      ),
      GoRoute(path: '/admin', builder: (_, _) => const AdminPage()),
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

      final isAdmin = authState.maybeWhen(
        orElse: () => false,
        authenticated: (user) => user.isAdmin,
      );

      final location = state.matchedLocation;

      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToAdmin = location == '/admin';

      if (!isLoggedIn) return isGoingToLogin ? null : '/login';
      if (isGoingToLogin) return '/home';
      if (isGoingToAdmin && !isAdmin) return '/home';

      return null;
    },
  );

  // ✅ Escucha cambios y refresca el router directamente
  ref.listen(authSessionProvider, (_, _) {
    router.refresh();
  });

  return router;
});
