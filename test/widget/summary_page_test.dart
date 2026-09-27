import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_provider.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/pages/summary_page.dart';

class _FakeAuth extends AuthSessionNotifier {
  final bool loggedIn;
  _FakeAuth({required this.loggedIn});

  @override
  AuthSessionState build() => loggedIn
      ? AuthSessionState.authenticated(
          AuthenticatedUser(
            id: 'uid',
            email: 'a@x.com',
            isAdmin: false,
            isSuperAdmin: false,
          ),
        )
      : const AuthSessionState.unauthenticated();
}

Future<void> pumpPage(
  WidgetTester tester, {
  required Size size,
  bool loggedIn = true,
  GoRouter? router,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(() => _FakeAuth(loggedIn: loggedIn)),
      ],
      child: router == null
          ? const MaterialApp(home: SummaryPage())
          : MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, size) in [
    ('móvil', const Size(360, 800)),
    ('escritorio', const Size(1280, 800)),
  ]) {
    for (final loggedIn in [true, false]) {
      final sesion = loggedIn ? 'con' : 'sin';
      testWidgets('renderiza el estado vacío en $name $sesion sesión', (
        tester,
      ) async {
        await pumpPage(tester, size: size, loggedIn: loggedIn);

        expect(tester.takeException(), isNull);
        expect(find.text('Resumen'), findsOneWidget);
        expect(
          find.text('Todavía no hay reportes para mostrar'),
          findsOneWidget,
        );
        expect(find.byTooltip('Volver'), findsOneWidget);
      });
    }
  }

  testWidgets('"Volver" regresa a la pantalla anterior', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/summary'),
              child: const Text('abrir'),
            ),
          ),
        ),
        GoRoute(path: '/summary', builder: (_, _) => const SummaryPage()),
      ],
    );
    await pumpPage(tester, size: const Size(1280, 800), router: router);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(SummaryPage), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.byType(SummaryPage), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('"Volver" sin historial (enlace directo) va a /home', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/summary',
      routes: [
        GoRoute(path: '/summary', builder: (_, _) => const SummaryPage()),
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
      ],
    );
    await pumpPage(tester, size: const Size(1280, 800), router: router);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}
