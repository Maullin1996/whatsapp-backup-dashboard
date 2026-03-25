import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/home/presentation/widgets/custom_message_group.dart';

void main() {
  testWidgets('CustomMessageGroup shows empty state message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CustomMessageGroup()),
      ),
    );

    expect(find.text('Selecciona un grupo para continuar'), findsOneWidget);
  });
}
