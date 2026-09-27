import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/pages/admin_page.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_provider.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';

import '../unit/admin/fake_admin_repository.dart';

/// Quien mira el panel: un superAdmin.
class _FakeAuth extends AuthSessionNotifier {
  @override
  AuthSessionState build() => AuthSessionState.authenticated(
    AuthenticatedUser(
      id: 'me',
      email: 'me@x.com',
      isAdmin: true,
      isSuperAdmin: true,
    ),
  );
}

const _me = AppUser(
  uid: 'me',
  email: 'me@x.com',
  displayName: 'Yo',
  disabled: false,
  allowedGroups: [],
  isAdmin: true,
  isSuperAdmin: true,
);

const _otherSuper = AppUser(
  uid: 'super2',
  email: 'super2@x.com',
  displayName: 'Otro Super',
  disabled: false,
  allowedGroups: ['g1'],
  isAdmin: true,
  isSuperAdmin: true,
);

const _plain = AppUser(
  uid: 'plain',
  email: 'plain@x.com',
  displayName: 'Plain',
  disabled: false,
  allowedGroups: [],
);

Future<ProviderContainer> _pumpAdminPage(WidgetTester tester) async {
  // Layout móvil: apila los botones de cada tarjeta. La fila de escritorio
  // desborda con la fuente de los tests (más ancha que la real).
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminRepositoryProvider.overrideWithValue(
          FakeAdminRepository([_me, _otherSuper, _plain]),
        ),
        authSessionProvider.overrideWith(_FakeAuth.new),
      ],
      child: const MaterialApp(home: AdminPage()),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(AdminPage)));
}

void main() {
  testWidgets('un superAdmin no ofrece "Hacer admin" sobre otro superAdmin; '
      'solo sobre el usuario normal', (tester) async {
    await _pumpAdminPage(tester);

    expect(find.text('SuperAdmin'), findsNWidgets(2));
    expect(find.text('Hacer admin'), findsOneWidget);
    expect(find.text('Quitar admin'), findsNothing);
  });

  testWidgets('deshabilitar a otro superAdmin no le hace aparecer "Hacer '
      'admin" (la secuencia que degradaba el claim en el servidor)', (
    tester,
  ) async {
    await _pumpAdminPage(tester);
    // Tres tarjetas, cada una con su Switch: el de "Otro Super" es el segundo.
    expect(find.byType(Switch), findsNWidgets(3));

    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Switch>(find.byType(Switch).at(1)).value,
      isFalse,
      reason: 'quedó deshabilitado',
    );
    expect(find.text('SuperAdmin'), findsNWidgets(2));
    expect(find.text('Hacer admin'), findsOneWidget);
    expect(find.text('Quitar admin'), findsNothing);
  });

  testWidgets('asignar grupos a otro superAdmin tampoco lo degrada en la '
      'tarjeta', (tester) async {
    final container = await _pumpAdminPage(tester);

    await container
        .read(adminProvider.notifier)
        .updateUserGroups(uid: 'super2', allowedGroups: ['g1', 'g2']);
    await tester.pumpAndSettle();

    expect(find.text('SuperAdmin'), findsNWidgets(2));
    expect(find.text('Hacer admin'), findsOneWidget);
    expect(find.text('Quitar admin'), findsNothing);
  });
}
