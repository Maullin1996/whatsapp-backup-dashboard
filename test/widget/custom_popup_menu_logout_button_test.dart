import 'dart:ui';

import 'package:dartz/dartz.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_theme.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_provider.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/widgets/custom_popup_menu_logout_button.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/repositories/matches_repository.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/pages/matches_page.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/providers/matches_providers.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/repositories/summary_repository.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/pages/summary_page.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/providers/summary_providers.dart';

/// Resumen vacío, sin latencia: el test solo navega a `/summary`.
class _EmptySummaryRepository implements SummaryRepository {
  const _EmptySummaryRepository();

  @override
  Future<Either<Failure, List<JornadaSummary>>> getJornadaSummaries(
    DateTime fecha,
  ) async => const Right([]);
}

/// Día sin coincidencias, sin latencia: el test solo navega a `/matches`.
class _EmptyMatchesRepository implements MatchesRepository {
  const _EmptyMatchesRepository();

  @override
  Future<Either<Failure, DayMatches>> getMatches(DateTime date) async =>
      const Right(DayMatches(fechaJornada: '', jornadas: []));
}

class _FakeAuth extends AuthSessionNotifier {
  final bool isAdmin;
  final bool isSuperAdmin;
  final bool noSession;
  final ReviewRole? reviewRole;
  _FakeAuth({
    this.isAdmin = false,
    this.isSuperAdmin = false,
    this.noSession = false,
    this.reviewRole,
  });

  @override
  AuthSessionState build() {
    if (noSession) return const AuthSessionState.unauthenticated();
    return AuthSessionState.authenticated(
      AuthenticatedUser(
        id: 'uid',
        email: 'a@x.com',
        isAdmin: isAdmin,
        isSuperAdmin: isSuperAdmin,
        reviewRole: reviewRole,
      ),
    );
  }
}

/// El menú vive en la pantalla `/`; `/summary` y `/matches` son las páginas
/// reales.
Future<void> pumpMenu(
  WidgetTester tester, {
  bool isAdmin = false,
  bool isSuperAdmin = false,
  bool noSession = false,
  ReviewRole? reviewRole,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          appBar: AppBar(actions: const [CustomPopupMenuLogoutButton()]),
        ),
      ),
      GoRoute(path: '/summary', builder: (_, _) => const SummaryPage()),
      GoRoute(path: '/matches', builder: (_, _) => const MatchesPage()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // El Resumen y Coincidencias reales leerían Firestore: en el test,
        // repositorios falsos vacíos y sin latencia.
        summaryRepositoryProvider.overrideWithValue(
          const _EmptySummaryRepository(),
        ),
        matchesRepositoryProvider.overrideWithValue(
          const _EmptyMatchesRepository(),
        ),
        authSessionProvider.overrideWith(
          () => _FakeAuth(
            isAdmin: isAdmin,
            isSuperAdmin: isSuperAdmin,
            noSession: noSession,
            reviewRole: reviewRole,
          ),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(CupertinoIcons.ellipsis_vertical));
  await tester.pumpAndSettle();
}

/// El contenedor del item (el único con este padding).
Finder itemContainer(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.padding ==
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
  ),
);

Future<void> hover(WidgetTester tester, String text) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(find.text(text)));
  await tester.pump();
}

Color? textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

Color? iconColor(WidgetTester tester, String text) => tester
    .widget<Icon>(
      find.descendant(of: itemContainer(text), matching: find.byType(Icon)),
    )
    .color;

Color? backgroundColor(WidgetTester tester, String text) =>
    tester.widget<Container>(itemContainer(text)).color;

void main() {
  group('hover: solo "Cerrar sesión" es rojo', () {
    testWidgets('"Cerrar sesión" usa AppColors.errorMessage', (tester) async {
      await pumpMenu(tester, isAdmin: false);
      await hover(tester, 'Cerrar sesión');

      expect(textColor(tester, 'Cerrar sesión'), AppColors.errorMessage);
      expect(iconColor(tester, 'Cerrar sesión'), AppColors.errorMessage);
      expect(
        backgroundColor(tester, 'Cerrar sesión'),
        AppColors.errorMessage.withValues(alpha: 0.12),
      );
    });

    testWidgets('"Resumen" usa AppColors.primaryGreen, no rojo', (
      tester,
    ) async {
      await pumpMenu(tester, isAdmin: true);
      await hover(tester, 'Resumen');

      expect(textColor(tester, 'Resumen'), AppColors.primaryGreen);
      expect(iconColor(tester, 'Resumen'), AppColors.primaryGreen);
      expect(
        backgroundColor(tester, 'Resumen'),
        AppColors.primaryGreen.withValues(alpha: 0.12),
      );
    });

    testWidgets('"Panel de administración" usa AppColors.primaryGreen, no '
        'rojo (el bug del parámetro isAdmin que nunca se leía)', (
      tester,
    ) async {
      await pumpMenu(tester, isAdmin: true);
      await hover(tester, 'Panel de administración');

      expect(
        textColor(tester, 'Panel de administración'),
        AppColors.primaryGreen,
      );
      expect(
        iconColor(tester, 'Panel de administración'),
        AppColors.primaryGreen,
      );
      expect(
        backgroundColor(tester, 'Panel de administración'),
        AppColors.primaryGreen.withValues(alpha: 0.12),
      );
    });

    testWidgets('sin hover ningún item es rojo ni verde y el fondo es '
        'transparente', (tester) async {
      await pumpMenu(tester, isAdmin: true);

      for (final text in [
        'Panel de administración',
        'Resumen',
        'Cerrar sesión',
      ]) {
        expect(textColor(tester, text), isNot(AppColors.errorMessage));
        expect(textColor(tester, text), isNot(AppColors.primaryGreen));
        expect(backgroundColor(tester, text), Colors.transparent);
      }
    });
  });

  group('items y orden', () {
    testWidgets('un usuario no-admin no ve "Resumen" ni el panel de '
        'administración', (tester) async {
      await pumpMenu(tester, isAdmin: false);

      expect(find.text('Resumen'), findsNothing);
      expect(find.text('Panel de administración'), findsNothing);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('admin: Panel → Resumen → divisor → Cerrar sesión', (
      tester,
    ) async {
      await pumpMenu(tester, isAdmin: true);

      final admin = tester.getCenter(find.text('Panel de administración')).dy;
      final summary = tester.getCenter(find.text('Resumen')).dy;
      final divider = tester.getCenter(find.byType(PopupMenuDivider)).dy;
      final logout = tester.getCenter(find.text('Cerrar sesión')).dy;

      expect(admin, lessThan(summary));
      expect(summary, lessThan(divider));
      expect(divider, lessThan(logout));
    });

    testWidgets('no-admin: divisor → Cerrar sesión', (tester) async {
      await pumpMenu(tester, isAdmin: false);

      final divider = tester.getCenter(find.byType(PopupMenuDivider)).dy;
      final logout = tester.getCenter(find.text('Cerrar sesión')).dy;

      expect(divider, lessThan(logout));
    });

    testWidgets('el icono de "Resumen" es fact_check_rounded', (tester) async {
      await pumpMenu(tester, isAdmin: true);

      expect(
        find.descendant(
          of: itemContainer('Resumen'),
          matching: find.byIcon(Icons.fact_check_rounded),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('tocar "Resumen" navega a /summary', (tester) async {
    await pumpMenu(tester, isAdmin: true);

    await tester.tap(find.text('Resumen'));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryPage), findsOneWidget);
    expect(find.text('Resumen'), findsOneWidget);
  });

  group('"Resumen" (canViewSummary: admin o superAdmin)', () {
    testWidgets('aparece con isAdmin', (tester) async {
      await pumpMenu(tester, isAdmin: true);
      expect(find.text('Resumen'), findsOneWidget);
    });

    testWidgets('aparece con solo isSuperAdmin (sin isAdmin)', (tester) async {
      await pumpMenu(tester, isSuperAdmin: true);
      expect(find.text('Resumen'), findsOneWidget);
    });

    for (final rol in ReviewRole.values) {
      testWidgets('NO aparece para ${rol.name} sin admin', (tester) async {
        await pumpMenu(tester, reviewRole: rol);
        expect(find.text('Resumen'), findsNothing);
      });
    }

    testWidgets('NO aparece con un usuario sin claims', (tester) async {
      await pumpMenu(tester);
      expect(find.text('Resumen'), findsNothing);
    });

    testWidgets('NO aparece sin sesión', (tester) async {
      await pumpMenu(tester, noSession: true);
      expect(find.text('Resumen'), findsNothing);
    });
  });

  group('"Coincidencias" (canViewMatches: admin o superAdmin)', () {
    testWidgets('aparece con isAdmin', (tester) async {
      await pumpMenu(tester, isAdmin: true);
      expect(find.text('Coincidencias'), findsOneWidget);
    });

    testWidgets('aparece con solo isSuperAdmin (sin isAdmin)', (tester) async {
      await pumpMenu(tester, isSuperAdmin: true);
      expect(find.text('Coincidencias'), findsOneWidget);
    });

    testWidgets('NO aparece con un usuario normal', (tester) async {
      await pumpMenu(tester);
      expect(find.text('Coincidencias'), findsNothing);
    });

    for (final rol in ReviewRole.values) {
      testWidgets('NO aparece para ${rol.name} sin admin', (tester) async {
        await pumpMenu(tester, reviewRole: rol);
        expect(find.text('Coincidencias'), findsNothing);
      });
    }

    testWidgets('NO aparece sin sesión', (tester) async {
      await pumpMenu(tester, noSession: true);
      expect(find.text('Coincidencias'), findsNothing);
    });

    testWidgets('va después de "Resumen" y antes del divisor', (tester) async {
      await pumpMenu(tester, isAdmin: true);

      final summary = tester.getCenter(find.text('Resumen')).dy;
      final matches = tester.getCenter(find.text('Coincidencias')).dy;
      final divider = tester.getCenter(find.byType(PopupMenuDivider)).dy;

      expect(summary, lessThan(matches));
      expect(matches, lessThan(divider));
    });

    testWidgets('tocarla navega a /matches', (tester) async {
      await pumpMenu(tester, isAdmin: true);

      await tester.tap(find.text('Coincidencias'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchesPage), findsOneWidget);
    });
  });
}
