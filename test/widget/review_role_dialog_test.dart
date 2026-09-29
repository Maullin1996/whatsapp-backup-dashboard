import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_providers.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/widgets/review_role_dialog.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

import '../unit/admin/fake_admin_repository.dart';

const _plain = AppUser(
  uid: 'plain',
  email: 'plain@x.com',
  displayName: 'Plain',
  disabled: false,
  allowedGroups: [],
);

const _revisorConShifts = AppUser(
  uid: 'revisor1',
  email: 'revisor1@x.com',
  displayName: 'Revisor Uno',
  disabled: false,
  allowedGroups: ['g1'],
  reviewRole: ReviewRole.revisor,
  reviewShifts: [ReviewShift(chatJid: 'g1', shift: Shift.morning)],
);

Future<ProviderContainer> _pumpDialog(
  WidgetTester tester, {
  required AppUser user,
  required FakeAdminRepository repo,
}) async {
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ReviewRoleDialog(user: user),
                  ),
                  child: const Text('abrir'),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('sin rol previo: arranca en "Ninguno", sin advertencia', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      user: _plain,
      repo: FakeAdminRepository([_plain]),
    );

    expect(find.byType(RadioListTile<ReviewRole?>), findsNWidgets(3));
    expect(find.textContaining('borrará'), findsNothing);
  });

  testWidgets('elegir un rol nuevo sin horarios previos no advierte', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      user: _plain,
      repo: FakeAdminRepository([_plain]),
    );

    await tester.tap(find.text('Revisor'));
    await tester.pumpAndSettle();

    expect(find.textContaining('borrará'), findsNothing);
  });

  testWidgets('cambiar el rol de alguien con horarios previos advierte '
      'cuántos se van a borrar', (tester) async {
    await _pumpDialog(
      tester,
      user: _revisorConShifts,
      repo: FakeAdminRepository([_revisorConShifts]),
    );

    await tester.tap(find.text('Sumador'));
    await tester.pumpAndSettle();

    expect(
      find.text('Esto borrará los 1 horarios ya asignados a esta persona.'),
      findsOneWidget,
    );
  });

  testWidgets('reasignar el MISMO rol no advierte, aunque haya horarios '
      'previos', (tester) async {
    await _pumpDialog(
      tester,
      user: _revisorConShifts,
      repo: FakeAdminRepository([_revisorConShifts]),
    );

    // Ya arranca en "Revisor" (su rol actual); no se cambia nada.
    expect(find.textContaining('borrará'), findsNothing);
  });

  testWidgets('volver a "Ninguno" y luego al rol original hace desaparecer '
      'la advertencia', (tester) async {
    await _pumpDialog(
      tester,
      user: _revisorConShifts,
      repo: FakeAdminRepository([_revisorConShifts]),
    );

    await tester.tap(find.text('Ninguno'));
    await tester.pumpAndSettle();
    expect(find.textContaining('borrará'), findsOneWidget);

    await tester.tap(find.text('Revisor'));
    await tester.pumpAndSettle();
    expect(find.textContaining('borrará'), findsNothing);
  });

  testWidgets('Guardar llama setReviewRole y cierra el diálogo de '
      'inmediato (fire-and-forget, como "Hacer admin")', (tester) async {
    final repo = FakeAdminRepository([_plain]);
    final container = await _pumpDialog(tester, user: _plain, repo: repo);

    await tester.tap(find.text('Revisor'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewRoleDialog), findsNothing);
    expect(
      container
          .read(adminProvider)
          .users
          .firstWhere((u) => u.uid == 'plain')
          .reviewRole,
      ReviewRole.revisor,
    );
  });
}
