import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/date_filter.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/date_filter_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/shift_stats_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/chat_drawer.dart';

/// Pruebas de caracterización del selector de "Día específico…" del drawer
/// (rama no-web: bottom sheet con `CalendarDatePicker`). La rama web
/// (`showDatePicker`) no se puede ejercitar aquí porque `kIsWeb` es const.
void main() {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  Future<ProviderContainer> pumpDrawer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [shiftStatsProvider.overrideWithValue(ShiftStats.empty())],
        child: MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            drawer: const ChatDrawer(),
            body: const SizedBox(),
          ),
        ),
      ),
    );
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  Future<void> openSpecificDay(WidgetTester tester) async {
    await tester.tap(find.text('Día específico…'));
    await tester.pumpAndSettle();
  }

  testWidgets('abre el bottom sheet "Seleccionar fecha" con el calendario', (
    tester,
  ) async {
    await pumpDrawer(tester);
    await openSpecificDay(tester);

    expect(find.text('Seleccionar fecha'), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Seleccionar'), findsOneWidget);
  });

  testWidgets('sin filtro de día previo el calendario arranca en hoy', (
    tester,
  ) async {
    await pumpDrawer(tester);
    await openSpecificDay(tester);

    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    final now = DateTime.now();
    expect(DateUtils.dateOnly(picker.initialDate!), DateUtils.dateOnly(now));
    expect(picker.firstDate, DateTime(2020));
  });

  testWidgets('con un día ya elegido el calendario arranca en ese día', (
    tester,
  ) async {
    final container = await pumpDrawer(tester);
    final previous = DateTime(2024, 3, 10);
    container
        .read(dateFilterProvider.notifier)
        .setFilter(DateFilterSpecificDay(date: previous));
    await tester.pumpAndSettle();
    await openSpecificDay(tester);

    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(picker.initialDate, previous);
  });

  testWidgets('Cancelar cierra solo el sheet: el drawer sigue abierto y el '
      'filtro no cambia', (tester) async {
    final container = await pumpDrawer(tester);
    await openSpecificDay(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Seleccionar fecha'), findsNothing);
    expect(find.text('Panel de control'), findsOneWidget);
    expect(
      container.read(dateFilterProvider),
      isA<DateFilterTodayAndYesterday>(),
    );
  });

  testWidgets('Seleccionar con la fecha inicial aplica ese día y cierra sheet '
      'y drawer', (tester) async {
    final container = await pumpDrawer(tester);
    await openSpecificDay(tester);

    await tester.tap(find.text('Seleccionar'));
    await tester.pumpAndSettle();

    final filter = container.read(dateFilterProvider);
    expect(filter, isA<DateFilterSpecificDay>());
    expect(
      DateUtils.dateOnly((filter as DateFilterSpecificDay).date),
      DateUtils.dateOnly(DateTime.now()),
    );
    expect(find.text('Seleccionar fecha'), findsNothing);
    expect(find.text('Panel de control'), findsNothing);
  });

  testWidgets('elegir otro día en el calendario y Seleccionar lo aplica', (
    tester,
  ) async {
    final now = DateTime.now();
    if (now.day == 1) {
      // Sin un día anterior seleccionable en el mes visible: cubierto por la
      // prueba anterior.
      return;
    }
    final container = await pumpDrawer(tester);
    await openSpecificDay(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('1'),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Seleccionar'));
    await tester.pumpAndSettle();

    final filter = container.read(dateFilterProvider) as DateFilterSpecificDay;
    expect(DateUtils.dateOnly(filter.date), DateTime(now.year, now.month, 1));
    expect(find.text('Panel de control'), findsNothing);
  });

  testWidgets('los otros filtros siguen aplicando y cerrando el drawer', (
    tester,
  ) async {
    final container = await pumpDrawer(tester);

    await tester.tap(find.text('Ayer'));
    await tester.pumpAndSettle();

    expect(container.read(dateFilterProvider), isA<DateFilterYesterday>());
    expect(find.text('Panel de control'), findsNothing);
  });
}
