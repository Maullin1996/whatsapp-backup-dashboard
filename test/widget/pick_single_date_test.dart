import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/shared/widget/pick_single_date.dart';

/// Guarda lo que devuelve `pickSingleDate` para poder comprobarlo.
class _Harness {
  DateTime? result;
  bool completed = false;
}

Future<_Harness> _pumpPicker(
  WidgetTester tester, {
  required DateTime initialDate,
  bool? isWeb,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final harness = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              harness.result = await pickSingleDate(
                context,
                initialDate: initialDate,
                isWeb: isWeb,
              );
              harness.completed = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  final initial = DateTime(2026, 3, 15);

  group('no-web: bottom sheet con CalendarDatePicker', () {
    testWidgets('muestra el sheet y arranca en la fecha inicial', (
      tester,
    ) async {
      await _pumpPicker(tester, initialDate: initial, isWeb: false);

      expect(find.text('Seleccionar fecha'), findsOneWidget);
      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(picker.initialDate, initial);
      expect(picker.firstDate, DateTime(2020));
    });

    testWidgets('Seleccionar sin tocar nada devuelve la fecha inicial', (
      tester,
    ) async {
      final harness = await _pumpPicker(
        tester,
        initialDate: initial,
        isWeb: false,
      );

      await tester.tap(find.text('Seleccionar'));
      await tester.pumpAndSettle();

      expect(harness.result, initial);
      expect(find.text('Seleccionar fecha'), findsNothing);
    });

    testWidgets('elegir otro día y Seleccionar devuelve ese día', (
      tester,
    ) async {
      final harness = await _pumpPicker(
        tester,
        initialDate: initial,
        isWeb: false,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('20'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Seleccionar'));
      await tester.pumpAndSettle();

      expect(DateUtils.dateOnly(harness.result!), DateTime(2026, 3, 20));
    });

    testWidgets('Cancelar devuelve null', (tester) async {
      final harness = await _pumpPicker(
        tester,
        initialDate: initial,
        isWeb: false,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(harness.completed, isTrue);
      expect(harness.result, isNull);
    });

    testWidgets('descartar el sheet tocando fuera devuelve null', (
      tester,
    ) async {
      final harness = await _pumpPicker(
        tester,
        initialDate: initial,
        isWeb: false,
      );

      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();

      expect(harness.completed, isTrue);
      expect(harness.result, isNull);
    });
  });

  testWidgets('en una pantalla de celular pequeña el sheet no se desborda y '
      'los botones se pueden pulsar', (tester) async {
    final harness = _Harness();
    // Poco alto (como un celular). El ancho es mayor que el de un celular
    // porque la fuente de los tests es más ancha que la real.
    tester.view.physicalSize = const Size(500, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                harness.result = await pickSingleDate(
                  context,
                  initialDate: initial,
                  isWeb: false,
                );
                harness.completed = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Seleccionar'));
    await tester.pumpAndSettle();
    expect(harness.result, initial);
  });

  group('web: showDatePicker nativo', () {
    testWidgets('abre el diálogo de Material y OK devuelve la fecha', (
      tester,
    ) async {
      final harness = await _pumpPicker(
        tester,
        initialDate: initial,
        isWeb: true,
      );

      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('Seleccionar fecha'), findsNothing);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(DateUtils.dateOnly(harness.result!), initial);
    });

    testWidgets('Cancelar devuelve null', (tester) async {
      final harness = await _pumpPicker(
        tester,
        initialDate: initial,
        isWeb: true,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(harness.completed, isTrue);
      expect(harness.result, isNull);
    });
  });
}
