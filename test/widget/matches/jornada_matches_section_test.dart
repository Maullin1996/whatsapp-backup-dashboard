import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/winning_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/jornada_matches_section.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/match_detail_dialog.dart';

MatchEntry _entry({
  String numero = '4521',
  String messageId = 'm1',
  String chatJid = 'demo-grupo-norte@g.us',
  String groupName = 'Grupo Norte (demo)',
  String senderName = 'Ana',
  String localTime = '08:15',
  String? loteria = 'dorado_manana',
}) => MatchEntry(
  numero: numero,
  loteria: loteria,
  messageId: messageId,
  chatJid: chatJid,
  groupName: groupName,
  senderName: senderName,
  localTime: localTime,
  storagePath: 'demo/x/$messageId.jpg',
  shift: 'Jornada Mañana (06:00 – 10:54)',
  fechaJornada: '2026-09-28',
);

// Ajuste (comparación por lotería): los ganadores son pares (lotería, número)
// y el chip y la tarjeta muestran "Nombre de la lotería · número". Los casos
// que ya existían usan una sola lotería (`dorado_manana`, "Dorado mañana").
WinningEntry _w(String numero, [String loteria = 'dorado_manana']) =>
    WinningEntry(loteria: loteria, numero: numero);

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
            winningNumbers: [_w('4521')],
            matches: [a, b],
          ),
        );

        // chip + 2 coincidencias
        expect(find.text('Dorado mañana · 4521'), findsNWidgets(3));
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
          winningNumbers: [_w('7788')],
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
        winningNumbers: [WinningEntry(loteria: 'medellin', numero: '9999')],
        matches: [],
      ),
    );

    expect(find.text('Todavía no hay ganadores'), findsOneWidget);
    // el ganador sigue visible, con el nombre de su lotería
    expect(find.text('Medellín · 9999'), findsOneWidget);
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
        winningNumbers: [_w('0123'), _w('123')],
        matches: [a, b],
      ),
    );

    // Cada número aparece dos veces: una en el chip de ganadores y otra en
    // la coincidencia — pero "0123" y "123" nunca se confunden entre sí.
    expect(find.text('Dorado mañana · 0123'), findsNWidgets(2));
    expect(find.text('Dorado mañana · 123'), findsNWidgets(2));
  });

  group('nombre de la lotería', () {
    testWidgets('el chip y la tarjeta muestran el nombre, no el identificador, '
        'y cada ganador el de su lotería', (tester) async {
      final match = _entry(numero: '1288', loteria: 'medellin');

      await _pump(
        tester,
        JornadaMatches(
          shift: 'Jornada Mañana (06:00 – 10:54)',
          winningNumbers: [_w('1288', 'medellin'), _w('1288', 'cruz_roja')],
          matches: [match],
        ),
      );

      // Chip de Medellín + tarjeta; chip de Cruz Roja (sin coincidencia).
      expect(find.text('Medellín · 1288'), findsNWidgets(2));
      expect(find.text('Cruz Roja · 1288'), findsOneWidget);
      expect(find.textContaining('medellin'), findsNothing);
      expect(find.textContaining('cruz_roja'), findsNothing);
    });

    testWidgets('una lotería fuera de la lista se muestra con el mismo texto, '
        'y sin lotería solo el número', (tester) async {
      await _pump(
        tester,
        JornadaMatches(
          shift: 'Jornada Mañana (06:00 – 10:54)',
          winningNumbers: [_w('1111', 'baloto'), _w('2222', '')],
          matches: const [],
        ),
      );

      expect(find.text('baloto · 1111'), findsOneWidget);
      expect(find.text('2222'), findsOneWidget);
    });

    testWidgets('el detalle de la coincidencia muestra la lotería', (
      tester,
    ) async {
      final match = _entry(numero: '7788', messageId: 'm9', loteria: 'valle');
      await _pump(
        tester,
        JornadaMatches(
          shift: 'Jornada Mañana (06:00 – 10:54)',
          winningNumbers: [_w('7788', 'valle')],
          matches: [match],
        ),
      );

      await tester.tap(find.text('Ver más'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Lotería'), findsOneWidget);
      expect(find.textContaining('Valle'), findsWidgets);
    });
  });
}
