import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_time.dart';

void main() {
  testWidgets('formatTime returns localized time string', (tester) async {
    String? formatted;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final date = DateTime(2024, 1, 2, 9, 15);
            formatted = formatTime(date.millisecondsSinceEpoch, context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(formatted, isNotNull);
    expect(formatted!.isNotEmpty, true);
  });
}
