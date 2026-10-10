import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/lottery_results.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/lottery_results_card.dart';

final _results = [
  for (var i = 0; i < 40; i++)
    LotteryResult(
      loteria: i.isEven ? 'antioquenita_dia' : 'cafeterito_tarde',
      numeros: const ['4871', '0871', '871', '0123'],
      conGanadores: const {'4871'},
    ),
];

void main() {
  for (final width in [320.0, 360.0, 800.0, 1280.0]) {
    testWidgets(
      'muchas loterías y números sin desbordes a ${width.toInt()} px',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(12),
                children: [LotteryResultsCard(results: _results)],
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('40 loterías'), findsOneWidget);
      },
    );
  }
}
