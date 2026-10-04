import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_session_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/fill_forms_button.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_long_date.dart';

class _Chat extends ActiveChatProvider {
  @override
  Chat? build() => Chat(
    chatJid: 'c1',
    groupName: 'Grupo Norte',
    lastMessageAt: 0,
    totalImages: 0,
  );
}

/// Todas las jornadas de c1 (normales y holiday): el diálogo filtra por día.
const _allShifts = [
  ReviewShift(chatJid: 'c1', shift: Shift.morning),
  ReviewShift(chatJid: 'c1', shift: Shift.afternoon1),
  ReviewShift(chatJid: 'c1', shift: Shift.holiday),
];

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  double width = 1280,
  ReviewRole? rol = ReviewRole.revisor,
  Future<List<ReviewShift>> Function()? shifts,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      activeChatProvider.overrideWith(_Chat.new),
      currentReviewRoleProvider.overrideWithValue(rol),
      reviewerUidProvider.overrideWithValue('uid'),
      reviewShiftsProvider.overrideWith(
        (ref) => (shifts ?? () async => _allShifts)(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: FillFormsButton())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

final _button = find.text('Llenar formularios');

/// Abre el diálogo (el título repite el texto del botón).
Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ElevatedButton, 'Llenar formularios'));
  await tester.pumpAndSettle();
}

void main() {
  final today = DateUtils.dateOnly(DateTime.now());

  group('visibilidad (misma condición que el panel del formulario)', () {
    testWidgets('ancho >= 840, rol y una asignación del chat: aparece', (
      tester,
    ) async {
      await _pump(tester);
      expect(_button, findsOneWidget);
    });

    testWidgets('ancho < 840: no aparece', (tester) async {
      await _pump(tester, width: 839);
      expect(_button, findsNothing);
    });

    testWidgets('sin rol: no aparece', (tester) async {
      await _pump(tester, rol: null);
      expect(_button, findsNothing);
    });

    testWidgets('sin asignaciones para el chat abierto: no aparece', (
      tester,
    ) async {
      await _pump(
        tester,
        shifts: () async => const [
          ReviewShift(chatJid: 'otro', shift: Shift.morning),
        ],
      );
      expect(_button, findsNothing);
    });

    testWidgets('mientras reviewShifts carga: no aparece', (tester) async {
      final gate = Completer<List<ReviewShift>>();
      await _pump(tester, shifts: () => gate.future);
      expect(_button, findsNothing);
      gate.complete(_allShifts);
      await tester.pumpAndSettle();
      expect(_button, findsOneWidget);
    });

    testWidgets('si reviewShifts falla: no aparece', (tester) async {
      await _pump(tester, shifts: () async => throw Exception('sin red'));
      expect(_button, findsNothing);
      // reviewShiftsProvider (ya existente) usa el reintento automático de
      // Riverpod 3: se dejan correr los reintentos; sigue sin aparecer.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 7));
      }
      expect(_button, findsNothing);
    });
  });

  group('diálogo', () {
    testWidgets('arranca hoy, sin flecha derecha; la izquierda va al día '
        'anterior y entonces aparece la derecha', (tester) async {
      await _pump(tester);
      await _openDialog(tester);

      expect(find.text(formatLongDate(today)), findsOneWidget);
      expect(find.byTooltip('Día siguiente'), findsNothing);

      await tester.tap(find.byTooltip('Día anterior'));
      await tester.pumpAndSettle();
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      expect(find.text(formatLongDate(yesterday)), findsOneWidget);
      expect(find.byTooltip('Día siguiente'), findsOneWidget);

      await tester.tap(find.byTooltip('Día siguiente'));
      await tester.pumpAndSettle();
      expect(find.text(formatLongDate(today)), findsOneWidget);
      expect(find.byTooltip('Día siguiente'), findsNothing);
    });

    testWidgets('domingo: solo Domingo / Festivo; día normal: las demás', (
      tester,
    ) async {
      await _pump(tester);
      await _openDialog(tester);

      // Retrocede hasta el domingo más reciente (hoy incluido).
      var date = today;
      while (date.weekday != DateTime.sunday) {
        await tester.tap(find.byTooltip('Día anterior'));
        await tester.pumpAndSettle();
        date = DateTime(date.year, date.month, date.day - 1);
      }
      expect(find.text(formatLongDate(date)), findsOneWidget);
      expect(find.text('Domingo / Festivo'), findsOneWidget);
      expect(find.text('Mañana'), findsNothing);

      // El sábado anterior (día normal, salvo que sea festivo cargado: en el
      // test la tabla es la fija, sin festivos).
      await tester.tap(find.byTooltip('Día anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Domingo / Festivo'), findsNothing);
      expect(find.text('Mañana'), findsOneWidget);
      expect(find.text('Tarde 1'), findsOneWidget);
      expect(find.text('05:30 – 10:51'), findsOneWidget);
    });

    testWidgets('sin jornadas que apliquen ese día: mensaje', (tester) async {
      await _pump(
        tester,
        shifts: () async => const [
          ReviewShift(chatJid: 'c1', shift: Shift.holiday),
        ],
      );
      await _openDialog(tester);
      // Busca un día normal (hoy o hacia atrás).
      var date = today;
      while (date.weekday == DateTime.sunday) {
        await tester.tap(find.byTooltip('Día anterior'));
        await tester.pumpAndSettle();
        date = DateTime(date.year, date.month, date.day - 1);
      }
      expect(
        find.text('No tienes jornadas asignadas en este grupo para este día.'),
        findsOneWidget,
      );
    });

    testWidgets('tocar una jornada cierra el diálogo y empieza la sesión con '
        'esa jornada, esa fecha y el grupo', (tester) async {
      final container = await _pump(tester);
      await _openDialog(tester);
      // Un día normal: el sábado más reciente antes de hoy.
      var date = today;
      do {
        await tester.tap(find.byTooltip('Día anterior'));
        await tester.pumpAndSettle();
        date = DateTime(date.year, date.month, date.day - 1);
      } while (date.weekday != DateTime.saturday);

      await tester.tap(find.text('Mañana'));
      await tester.pumpAndSettle();

      expect(find.byType(FillFormsDialog), findsNothing);
      final session = container.read(reviewSessionProvider);
      expect(session, isNotNull);
      expect(session!.groupName, 'Grupo Norte');
      expect(session.jornada.chatJid, 'c1');
      expect(session.jornada.shift, Shift.morning);
      expect(session.jornada.date, date);
    });

    testWidgets('Cancelar cierra sin empezar sesión', (tester) async {
      final container = await _pump(tester);
      await _openDialog(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(FillFormsDialog), findsNothing);
      expect(container.read(reviewSessionProvider), isNull);
    });
  });
}
