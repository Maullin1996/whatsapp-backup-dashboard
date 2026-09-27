import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/admin_failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/group.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_providers.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/widgets/assign_groups_dialog.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

import '../unit/admin/fake_admin_repository.dart';

const _groups = [
  Group(chatJid: 'g1', groupName: 'Grupo Uno'),
  Group(chatJid: 'g2', groupName: 'Grupo Dos'),
];

const _plain = AppUser(
  uid: 'plain',
  email: 'plain@x.com',
  displayName: 'Plain',
  disabled: false,
  allowedGroups: [],
);

const _revisorSinHorarios = AppUser(
  uid: 'revisor1',
  email: 'revisor1@x.com',
  displayName: 'Revisor Uno',
  disabled: false,
  allowedGroups: ['g1'],
  reviewRole: ReviewRole.revisor,
);

const _revisorConHorarioEnG1 = AppUser(
  uid: 'revisor1',
  email: 'revisor1@x.com',
  displayName: 'Revisor Uno',
  disabled: false,
  allowedGroups: ['g1'],
  reviewRole: ReviewRole.revisor,
  reviewShifts: [ReviewShift(chatJid: 'g1', shift: Shift.morning)],
);

const _otroRevisorEnG2 = AppUser(
  uid: 'revisor2',
  email: 'revisor2@x.com',
  displayName: 'Revisor Dos',
  disabled: false,
  allowedGroups: ['g2'],
  reviewRole: ReviewRole.revisor,
  reviewShifts: [ReviewShift(chatJid: 'g2', shift: Shift.morning)],
);

const _sumadorEnG2 = AppUser(
  uid: 'sumador1',
  email: 'sumador1@x.com',
  displayName: 'Sumador Uno',
  disabled: false,
  allowedGroups: ['g2'],
  reviewRole: ReviewRole.sumador,
  reviewShifts: [ReviewShift(chatJid: 'g2', shift: Shift.morning)],
);

/// Pumpea el diálogo detrás de un botón, manteniendo vivo `adminProvider`
/// (como en `AdminPage` real) para que `state.groups`/`state.users` ya estén
/// cargados cuando el diálogo los lee.
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
          ref.watch(adminProvider);
          return MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AssignGroupsDialog(user: user),
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
  await tester.pump(); // corre el microtask de loadUsers()/loadGroups()
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return container;
}

/// `AssignGroupsDialog` usa `Dialog` y el `GroupShiftsDialog` anidado usa
/// `AlertDialog`: con los dos abiertos a la vez hay dos botones "Guardar" en
/// pantalla, así que hay que apuntar al del anidado explícitamente.
Future<void> _tapGuardarEnHorarios(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Guardar'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('regresión: sin rol de revisión, el flujo es igual que antes', () {
    testWidgets('sin rol: no hay botón "Horarios", ni marcado ni '
        'desmarcado', (tester) async {
      final repo = FakeAdminRepository([_plain], groups: _groups);
      await _pumpDialog(tester, user: _plain, repo: repo);

      expect(find.textContaining('Horarios'), findsNothing);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Horarios'), findsNothing);
    });

    testWidgets('marcar/desmarcar y Guardar sigue llamando solo '
        'updateUserGroups (actualización optimista, como antes)', (
      tester,
    ) async {
      final repo = FakeAdminRepository([_plain], groups: _groups);
      final container = await _pumpDialog(tester, user: _plain, repo: repo);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.byType(AssignGroupsDialog), findsNothing);
      expect(
        container
            .read(adminProvider)
            .users
            .firstWhere((u) => u.uid == 'plain')
            .allowedGroups,
        ['g1'],
      );
    });
  });

  group('botón "Horarios"', () {
    testWidgets('aparece solo si el checkbox está marcado Y hay rol activo', (
      tester,
    ) async {
      final repo = FakeAdminRepository([_revisorSinHorarios], groups: _groups);
      await _pumpDialog(tester, user: _revisorSinHorarios, repo: repo);

      // g1 ya viene marcado (allowedGroups: ['g1']) y hay rol -> aparece.
      expect(find.textContaining('Horarios'), findsOneWidget);

      // Desmarcar g1: desaparece.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Horarios'), findsNothing);

      // Volver a marcar: reaparece.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Horarios'), findsOneWidget);
    });
  });

  group('diálogo de horarios (GroupShiftsDialog anidado)', () {
    testWidgets('precarga los horarios ya asignados a ese chatJid', (
      tester,
    ) async {
      final repo = FakeAdminRepository([
        _revisorConHorarioEnG1,
      ], groups: _groups);
      await _pumpDialog(tester, user: _revisorConHorarioEnG1, repo: repo);

      await tester.tap(find.text('Horarios (1)'));
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Mañana'),
      );
      expect(checkbox.value, isTrue);
    });

    testWidgets('checkboxes de otra persona del MISMO rol aparecen '
        'deshabilitados con su email', (tester) async {
      final repo = FakeAdminRepository([
        _revisorSinHorarios,
        _otroRevisorEnG2,
      ], groups: _groups);
      await _pumpDialog(tester, user: _revisorSinHorarios, repo: repo);

      // Marcar g2 para poder abrir sus horarios.
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Horarios').last);
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Mañana'),
      );
      expect(checkbox.onChanged, isNull, reason: 'deshabilitado');
      expect(find.textContaining('revisor2@x.com'), findsOneWidget);
    });

    testWidgets('Revisor y Sumador SÍ pueden compartir chatJid+jornada: no '
        'aparece deshabilitado entre roles distintos', (tester) async {
      final repo = FakeAdminRepository([
        _revisorSinHorarios,
        _sumadorEnG2,
      ], groups: _groups);
      await _pumpDialog(tester, user: _revisorSinHorarios, repo: repo);

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Horarios').last);
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Mañana'),
      );
      expect(
        checkbox.onChanged,
        isNotNull,
        reason: 'sumador no choca con revisor',
      );
    });

    testWidgets('la selección de horarios sobrevive a desmarcar/remarcar el '
        'grupo padre antes de Guardar', (tester) async {
      final repo = FakeAdminRepository([_revisorSinHorarios], groups: _groups);
      await _pumpDialog(tester, user: _revisorSinHorarios, repo: repo);

      await tester.tap(find.text('Horarios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mañana'));
      await _tapGuardarEnHorarios(tester);
      expect(find.text('Horarios (1)'), findsOneWidget);

      // Desmarcar y volver a marcar el grupo g1.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(find.text('Horarios (1)'), findsOneWidget);
    });
  });

  group('Guardar', () {
    testWidgets('envía solo los horarios de grupos que siguen marcados', (
      tester,
    ) async {
      final repo = FakeAdminRepository([_revisorSinHorarios], groups: _groups);
      await _pumpDialog(tester, user: _revisorSinHorarios, repo: repo);

      // Asignar horario a g1 (ya marcado).
      await tester.tap(find.text('Horarios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mañana'));
      await _tapGuardarEnHorarios(tester);

      // Marcar también g2, pero NO asignarle horarios, y desmarcar g1.
      await tester.tap(find.byType(Checkbox).at(1)); // marca g2
      await tester.tap(find.byType(Checkbox).first); // desmarca g1
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(
        repo.users.firstWhere((u) => u.uid == 'revisor1').reviewShifts,
        isEmpty,
        reason: 'g1 se desmarcó antes de Guardar, sus horarios no se envían',
      );
    });

    testWidgets('un conflicto NO cierra el diálogo y muestra el mensaje '
        'dentro de él', (tester) async {
      final repo = FakeAdminRepository([_revisorSinHorarios], groups: _groups)
        ..failUpdateReviewShiftsWith = const AdminFailure.reviewShiftConflict([
          ReviewShift(chatJid: 'g1', shift: Shift.morning),
        ]);
      await _pumpDialog(tester, user: _revisorSinHorarios, repo: repo);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.byType(AssignGroupsDialog), findsOneWidget);
      expect(
        find.text(
          'Ese grupo y esa jornada ya están asignados a otro Revisor/Sumador.',
        ),
        findsOneWidget,
      );
    });
  });
}
