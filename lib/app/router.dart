//router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/app/auth_redirect.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/pages/admin_page.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/pages/login_page.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/home/presentation/pages/home_page.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/pages/review_session_page.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_session_provider.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/pages/group_winners_page.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/pages/matches_page.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/image_detail_page.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/pages/summary_page.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/pages/summary_role_detail_page.dart';

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
      GoRoute(
        path: '/summary/detail',
        redirect: (_, state) {
          final params = state.uri.queryParameters;
          final valid =
              (params['chat'] ?? '').isNotEmpty &&
              ReviewRole.values.any((r) => r.name == params['role']);
          return valid ? null : '/summary';
        },
        builder: (_, state) => SummaryRoleDetailPage(
          chatJid: state.uri.queryParameters['chat']!,
          rol: ReviewRole.values.byName(state.uri.queryParameters['role']!),
        ),
      ),
      GoRoute(path: '/matches', builder: (_, _) => const MatchesPage()),
      GoRoute(
        path: '/matches/group',
        redirect: (_, state) =>
            (state.uri.queryParameters['chat'] ?? '').isEmpty
            ? '/matches'
            : null,
        builder: (_, state) =>
            GroupWinnersPage(chatJid: state.uri.queryParameters['chat']!),
      ),
      GoRoute(path: '/review', builder: (_, _) => const ReviewSessionPage()),
    ],
    redirect: (context, state) => computeAuthRedirect(
      authState: ref.read(authSessionProvider),
      location: state.matchedLocation,
      reviewSessionActive: ref.read(reviewSessionProvider) != null,
    ),
  );

  // ✅ Escucha cambios y refresca el router directamente
  ref.listen(authSessionProvider, (_, _) {
    router.refresh();
  });
  // Empezar o terminar una sesión de llenado reevalúa el guard: entra a
  // /review o sale de ahí.
  ref.listen(reviewSessionProvider, (_, _) {
    router.refresh();
  });

  return router;
});
