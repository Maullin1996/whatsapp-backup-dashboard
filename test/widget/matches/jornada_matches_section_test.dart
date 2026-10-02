import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/jornada_matches_section.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/match_detail_dialog.dart';

MatchEntry _entry({
  String numero = '4521',
  String messageId = 'm1',
  String chatJid = 'demo-grupo-norte@g.us',
  String groupName = 'Grupo Norte (demo)',
  String senderName = 'Ana',
  String localTime = '08:15',
}) => MatchEntry(
  numero: numero,
  messageId: messageId,
  chatJid: chatJid,
  groupName: groupName,
  senderName: senderName,
  localTime: localTime,
  storagePath: 'demo/x/$messageId.jpg',
  shift: 'Jornada Mañana (06:00 – 10:54)',
  fechaJornada: '2026-09-28',
);

Future<void> _pump(WidgetTester tester, JornadaMatches jornada) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: JornadaMatchesSection(jornada: jornada),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('jornada con coincidencias', () {
    testWidgets(
      'muestra número, senderName, groupName, chatJid, localTime y "Ver '
      'más" por coincidencia',
      (tester) async {
        final a = _entry(numero: '4521', messageId: 'm1', senderName: 'Ana');
        final b = _entry(
          numero: '4521',
          messageId: 'm2',
          senderName: 'Luis',
          chatJid: 'demo-grupo-centro@g.us',
          groupName: 'Grupo Centro (demo)',
          localTime: '09:40',
        );

        await _pump(
          tester,
          JornadaMatches(
            shift: 'Jornada Mañana (06:00 – 10:54)',
            winningNumbers: const ['4521'],
            matches: [a, b],
          ),
        );

        expect(find.text('4521'), findsNWidgets(3)); // chip + 2 coincidencias
        // Ancho de test por defecto (800x600) = variante de escritorio:
        // número, remitente, grupo(chatJid) y hora en widgets separados.
        expect(find.text('Ana'), findsOneWidget);
        expect(find.text('Luis'), findsOneWidget);
        expect(find.text('Grupo Norte (demo)'), findsOneWidget);
        expect(find.text('Grupo Centro (demo)'), findsOneWidget);
        expect(find.textContaining('demo-grupo-norte@g.us'), findsOneWidget);
        expect(find.textContaining('demo-grupo-centro@g.us'), findsOneWidget);
        expect(find.text('08:15'), findsOneWidget);
        expect(find.text('09:40'), findsOneWidget);
        expect(find.text('Ver más'), findsNWidgets(2));
      },
    );

    testWidgets('"Ver más" abre el diálogo de esa coincidencia', (
      tester,
    ) async {
      final match = _entry(numero: '7788', messageId: 'm9');
      await _pump(
        tester,
        JornadaMatches(
          shift: 'Jornada Mañana (06:00 – 10:54)',
          winningNumbers: const ['7788'],
          matches: [match],
        ),
      );

      await tester.tap(find.text('Ver más'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchDetailDialog), findsOneWidget);
    });
  });

  testWidgets('ganadores sin coincidencias: dice "Todavía no hay ganadores"', (
    tester,
  ) async {
    await _pump(
      tester,
      const JornadaMatches(
        shift: 'Jornada Mañana (06:00 – 10:54)',
        winningNumbers: ['9999'],
        matches: [],
      ),
    );

    expect(find.text('Todavía no hay ganadores'), findsOneWidget);
    expect(find.text('9999'), findsOneWidget); // el ganador sigue visible
  });

  testWidgets('lista de ganadores vacía: el mismo único texto "Todavía no hay '
      'ganadores", sin la fila de números ganadores', (tester) async {
    await _pump(
      tester,
      const JornadaMatches(
        shift: 'Jornada Mañana (06:00 – 10:54)',
        winningNumbers: [],
        matches: [],
      ),
    );

    expect(find.text('Todavía no hay ganadores'), findsOneWidget);
    expect(find.text('Números ganadores:'), findsNothing);
  });

  testWidgets('"0123" y "123" se muestran tal cual, distintos', (tester) async {
    final a = _entry(numero: '0123', messageId: 'm1');
    final b = _entry(numero: '123', messageId: 'm2');

    await _pump(
      tester,
      JornadaMatches(
        shift: 'Jornada Mañana (06:00 – 10:54)',
        winningNumbers: const ['0123', '123'],
        matches: [a, b],
      ),
    );

    // Cada número aparece dos veces: una en el chip de ganadores y otra en
    // la coincidencia — pero "0123" y "123" nunca se confunden entre sí.
    expect(find.text('0123'), findsNWidgets(2));
    expect(find.text('123'), findsNWidgets(2));
  });
}
