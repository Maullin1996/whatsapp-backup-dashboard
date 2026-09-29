import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/widgets/loading_widget.dart';

/// Prueba estructural (no de píxeles): confirma que el skeleton incluye un
/// placeholder por cada elemento estructural de `_UserCard` real (avatar, 2
/// líneas de encabezado, fila de chips de grupo, línea de estado de
/// revisión, N placeholders de botón) — no compara alturas exactas, sería
/// frágil. Ver `loading_widget.dart` y `admin_page.dart` (`_UserCard`).
/// Los placeholders repetidos (chips de grupo, botones) llevan un índice en
/// la key (`shimmerGroupChip_0`, `_1`, ...) porque Flutter no permite keys
/// duplicadas entre hermanos de un mismo `Row`/`Column`/`Wrap`; este finder
/// los agrupa de nuevo por prefijo para contarlos como un solo elemento
/// estructural.
Finder _byKeyPrefix(String prefix) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith(prefix);
});

void _expectCardStructure(WidgetTester tester) {
  final firstCard = find.byKey(const ValueKey('shimmerCard')).first;

  expect(
    find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey('shimmerTitleLine')),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey('shimmerSubtitleLine')),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(of: firstCard, matching: _byKeyPrefix('shimmerGroupChip_')),
    findsNWidgets(3),
  );
  expect(
    find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey('shimmerStatusLine')),
    ),
    findsOneWidget,
    reason: 'debe aproximar la línea de _ReviewAssignmentStatus',
  );
  expect(
    find.descendant(
      of: firstCard,
      matching: _byKeyPrefix('shimmerButtonPlaceholder_'),
    ),
    findsNWidgets(5),
    reason:
        'debe aproximar el máximo real de botones de _UserCard '
        '(contraseña, grupos, revisión, rol, eliminar)',
  );
}

void main() {
  testWidgets('desktop: el skeleton tiene un placeholder por cada elemento '
      'estructural de la tarjeta real', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoadingWidget()));

    expect(tester.takeException(), isNull);
    _expectCardStructure(tester);
  });

  testWidgets('mobile: el skeleton tiene un placeholder por cada elemento '
      'estructural de la tarjeta real', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoadingWidget()));

    expect(tester.takeException(), isNull);
    _expectCardStructure(tester);
  });
}
