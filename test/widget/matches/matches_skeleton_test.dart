import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/jornada_matches_section.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/matches_skeleton.dart';

MatchEntry _entry(String numero) => MatchEntry(
  numero: numero,
  messageId: 'm-$numero',
  chatJid: 'demo-grupo-norte@g.us',
  groupName: 'Grupo Norte (demo)',
  senderName: 'Ana',
  localTime: '08:15',
  storagePath: 'demo/x/$numero.jpg',
  shift: 'Jornada Mañana (06:00 – 10:54)',
  fechaJornada: '2026-09-28',
  messageEdited: false,
);

/// Misma forma que aproxima el skeleton: ganadores + 2 coincidencias.
final _typicalJornada = JornadaMatches(
  shift: 'Jornada Mañana (06:00 – 10:54)',
  winningNumbers: const ['4521', '0123'],
  matches: [_entry('4521'), _entry('0123')],
);

/// Mide [child] con alto NO acotado (como el primer hijo de un `ListView`
/// real): un `Container`/`Column` sin `Expanded` se mide por su contenido,
/// no por el alto disponible. Sirve para `JornadaMatchesSection`, que no
/// trae su propio `ListView`.
Future<Size> _measureUnbounded(
  WidgetTester tester,
  Widget child,
  Finder find,
  double width,
) async {
  tester.view.physicalSize = Size(width, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.getSize(find);
}

/// Mide [child] con alto acotado pero grande (como el `Expanded` real de
/// `_MatchesContent`). Necesario para `MatchesSkeleton`, que trae su propio
/// `ListView` (un viewport necesita un alto acotado); el primer ítem de esa
/// lista igual se mide por su contenido (todo hijo de `ListView` recibe alto
/// no acotado por su cuenta).
Future<Size> _measureBounded(
  WidgetTester tester,
  Widget child,
  Finder find,
  double width,
) async {
  tester.view.physicalSize = Size(width, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(width: width, child: child),
      ),
    ),
  );
  await tester.pump();
  return tester.getSize(find);
}

void main() {
  // `_MatchTile` real tiene forma distinta en móvil (apilado) y escritorio
  // (una fila) — el skeleton la sigue (ver matches_skeleton.dart), así que
  // la comparación corre en los dos anchos, no solo en el de escritorio.
  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'la altura del skeleton de una sección se acerca a la de una sección '
      'real con ganadores y 2 coincidencias, a ${width.toInt()}px '
      '(tolerancia explícita)',
      (tester) async {
        final realSize = await _measureUnbounded(
          tester,
          JornadaMatchesSection(jornada: _typicalJornada),
          find.byType(JornadaMatchesSection),
          width,
        );

        // `_SectionSkeleton` no se exporta: se mide dentro del
        // `MatchesSkeleton` completo, tomando el primero de los 3 bloques
        // que dibuja.
        final skeletonSize = await _measureBounded(
          tester,
          const MatchesSkeleton(),
          find.byType(Container).first,
          width,
        );

        // Tolerancia explícita: el skeleton aproxima UNA forma representativa
        // (winners + 2 coincidencias), no cada combinación real posible —
        // igual que `SummarySkeleton` con `JornadaSummaryCard`. 12 px cubre
        // el redondeo de fuente/línea entre el bloque sólido del skeleton y
        // el texto real, sin dejar pasar un salto de layout grande como el
        // de AdminPage.
        const tolerance = 12.0;
        expect(
          (skeletonSize.height - realSize.height).abs(),
          lessThanOrEqualTo(tolerance),
          reason:
              'width=$width skeleton=${skeletonSize.height} '
              'real=${realSize.height} (tolerancia $tolerance)',
        );
      },
    );
  }
}
