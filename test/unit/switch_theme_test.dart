import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_theme.dart';

void main() {
  final theme = AppTheme.light.switchTheme;

  for (final (name, states) in [
    ('encendido', <WidgetState>{WidgetState.selected}),
    ('apagado', <WidgetState>{}),
  ]) {
    test('switch $name: la perilla se distingue del track', () {
      final thumb = theme.thumbColor!.resolve(states)!;
      final track = theme.trackColor!.resolve(states)!;

      expect(thumb, isNot(track));
    });
  }

  test('switch encendido: perilla blanca; apagado: borde visible', () {
    expect(theme.thumbColor!.resolve({WidgetState.selected}), Colors.white);
    expect(
      theme.trackOutlineColor!.resolve(<WidgetState>{}),
      isNot(Colors.transparent),
    );
  });

  testWidgets('el Switch sin colores propios usa la perilla del tema', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Switch(value: true, onChanged: (_) {})),
      ),
    );

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.activeThumbColor, isNull);
  });
}
