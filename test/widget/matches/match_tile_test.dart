import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/winning_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/jornada_matches_section.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/match_detail_dialog.dart';

const _chatJidLargo = '120363012345678901@g.us';
const _groupNameLargo = 'Grupo Norte Sector Industrial Zona Franca';

// Ajuste (comparación por lotería): el chip y la tarjeta muestran
// "Dorado mañana · número" (ver `loteriaNumeroLabel`).
String _label(MatchEntry m) => 'Dorado mañana · ${m.numero}';

MatchEntry _entry({String numero = '4521'}) => MatchEntry(
  numero: numero,
  loteria: 'dorado_manana',
  messageId: 'm1',
  chatJid: _chatJidLargo,
  groupName: _groupNameLargo,
  senderName: 'Ana',
  localTime: '08:15',
  storagePath: 'demo/x/m1.jpg',
  shift: 'Jornada Mañana (06:00 – 10:54)',
  fechaJornada: '2026-09-28',
);

Future<void> _pumpAt(WidgetTester tester, Size size, MatchEntry match) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: JornadaMatchesSection(
            jornada: JornadaMatches(
              shift: 'Jornada Mañana (06:00 – 10:54)',
              winningNumbers: [
                WinningEntry(loteria: 'dorado_manana', numero: match.numero),
              ],
              matches: [match],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('_MatchTile a 360 px (móvil)', () {
    testWidgets(
      'usa la variante móvil; el chatJid completo está en pantalla, sin '
      'ellipsis y sin overflow',
      (tester) async {
        final match = _entry();
        await _pumpAt(tester, const Size(360, 900), match);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('match_tile_mobile')), findsOneWidget);
        expect(find.byKey(const Key('match_tile_desktop')), findsNothing);

        final chatJidFinder = find.text(match.chatJid);
        expect(chatJidFinder, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(chatJidFinder);
        expect(paragraph.text.toPlainText(), match.chatJid);
      },
    );

    testWidgets('muestra todos los datos y dispara "Ver más"', (tester) async {
      final match = _entry();
      await _pumpAt(tester, const Size(360, 900), match);

      expect(find.text(match.senderName), findsOneWidget);
      expect(find.text(match.groupName), findsOneWidget);
      expect(find.text(match.localTime), findsOneWidget);
      expect(find.text(_label(match)), findsWidgets); // chip + tile

      await tester.tap(find.text('Ver más'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchDetailDialog), findsOneWidget);
    });
  });

  group('_MatchTile a 1280 px (escritorio)', () {
    testWidgets(
      'usa la variante de escritorio; chatJid y número se ven completos',
      (tester) async {
        final match = _entry();
        await _pumpAt(tester, const Size(1280, 900), match);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('match_tile_desktop')), findsOneWidget);
        expect(find.byKey(const Key('match_tile_mobile')), findsNothing);

        expect(find.textContaining(match.chatJid), findsOneWidget);
        expect(find.text(_label(match)), findsWidgets); // chip + tile
      },
    );

    testWidgets('muestra todos los datos y dispara "Ver más"', (tester) async {
      final match = _entry();
      await _pumpAt(tester, const Size(1280, 900), match);

      expect(find.text(match.senderName), findsOneWidget);
      expect(find.text(match.groupName), findsOneWidget);
      expect(find.text(match.localTime), findsOneWidget);

      await tester.tap(find.text('Ver más'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchDetailDialog), findsOneWidget);
    });
  });

  testWidgets('ceros a la izquierda intactos en ambas variantes', (
    tester,
  ) async {
    final match = _entry(numero: '0042');

    await _pumpAt(tester, const Size(360, 900), match);
    expect(find.text('Dorado mañana · 0042'), findsWidgets);

    await _pumpAt(tester, const Size(1280, 900), match);
    expect(find.text('Dorado mañana · 0042'), findsWidgets);
  });
}
