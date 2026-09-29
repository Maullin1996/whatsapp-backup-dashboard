//router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/app/auth_redirect.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/pages/admin_page.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/pages/login_page.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/home/presentation/pages/home_page.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/pages/matches_page.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/image_detail_page.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/pages/summary_page.dart';

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
      GoRoute(path: '/summary', builder: (_, _) => const SummaryPage()),
      GoRoute(path: '/matches', builder: (_, _) => const MatchesPage()),
    ],
    redirect: (context, state) => computeAuthRedirect(
      authState: ref.read(authSessionProvider),
      location: state.matchedLocation,
    ),
  );

  // ✅ Escucha cambios y refresca el router directamente
  ref.listen(authSessionProvider, (_, _) {
    router.refresh();
  });

  return router;
});
