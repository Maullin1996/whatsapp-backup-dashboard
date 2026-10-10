import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/all_groups_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/winning_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/repositories/matches_repository.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/pages/matches_page.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/providers/matches_providers.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/group_matches_tile.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/lottery_results_card.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/matches_skeleton.dart';

/// Repositorio falso: datos por día (`yyyy-MM-dd`), con la opción de
/// detener la respuesta o de fallar.
class _FakeRepo implements MatchesRepository {
  final Map<String, DayMatches> byDate;
  final List<DateTime> requested = [];
  Completer<void>? gate;
  Failure? failure;

  _FakeRepo({this.byDate = const {}});

  @override
  Future<Either<Failure, DayMatches>> getMatches(DateTime date) async {
    requested.add(date);
    await gate?.future;
    final failure = this.failure;
    if (failure != null) return Left(failure);
    final key =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return Right(
      byDate[key] ?? DayMatches(fechaJornada: key, jornadas: const []),
    );
  }
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakeRepo repo,
  bool settle = true,
  List<KnownGroup> groups = const [],
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        matchesRepositoryProvider.overrideWithValue(repo),
        allGroupsProvider.overrideWith((ref) async => groups),
      ],
      child: const MaterialApp(home: MatchesPage()),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

DayMatches _sinGanadores(String fecha) => DayMatches(
  fechaJornada: fecha,
  jornadas: const [
    JornadaMatches(
      shift: 'Jornada Mañana (06:00 – 10:54)',
      winningNumbers: [],
      matches: [],
    ),
    JornadaMatches(
      shift: 'Jornada Tarde 1 (10:55 – 13:58)',
      winningNumbers: [],
      matches: [],
    ),
  ],
);

DayMatches _conGanadores(String fecha) => DayMatches(
  fechaJornada: fecha,
  jornadas: [
    JornadaMatches(
      shift: 'Jornada Mañana (06:00 – 10:54)',
      winningNumbers: const [
        WinningEntry(loteria: 'dorado_manana', numero: '4521'),
      ],
      matches: [
        MatchEntry(
          numero: '4521',
          loteria: 'dorado_manana',
          messageId: 'm1',
          chatJid: 'demo-grupo-norte@g.us',
          groupName: 'Grupo Norte (demo)',
          senderName: 'Ana',
          localTime: '08:15',
          storagePath: 'demo/x/m1.jpg',
          shift: 'Jornada Mañana (06:00 – 10:54)',
          fechaJornada: fecha,
        ),
      ],
    ),
    // Con ganadores pero SIN coincidencias: no debe activar el vacío de
    // página (distinto de "sin ningún número ganador").
    const JornadaMatches(
      shift: 'Jornada Tarde 1 (10:55 – 13:58)',
      winningNumbers: [WinningEntry(loteria: 'medellin', numero: '9999')],
      matches: [],
    ),
  ],
);

void main() {
  group('estados', () {
    testWidgets('mientras carga muestra el skeleton y no las secciones', (
      tester,
    ) async {
      final repo = _FakeRepo()..gate = Completer<void>();
      await _pumpPage(tester, repo: repo, settle: false);

      expect(find.byType(MatchesSkeleton), findsOneWidget);
      expect(find.byType(GroupMatchesTile), findsNothing);

      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(MatchesSkeleton), findsNothing);
    });

    const norte = (chatJid: 'demo-grupo-norte@g.us', groupName: 'Grupo Norte');
    const sur = (chatJid: 'sur@g.us', groupName: 'Grupo Sur');

    testWidgets('un día sin números ganadores muestra igual las tarjetas de '
        'los grupos, con 0 ganadores', (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final key =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final repo = _FakeRepo(byDate: {key: _sinGanadores(key)});
      await _pumpPage(tester, repo: repo, groups: [norte, sur]);

      expect(find.byType(GroupMatchesTile), findsNWidgets(2));
      expect(find.text('0 ganadores'), findsNWidgets(2));
    });

    testWidgets('un día sin datos también lista los grupos con 0', (
      tester,
    ) async {
      await _pumpPage(tester, repo: _FakeRepo(), groups: [norte]);

      expect(find.text('Grupo Norte'), findsOneWidget);
      expect(find.text('0 ganadores'), findsOneWidget);
    });

    testWidgets('sin ningún grupo registrado muestra el vacío de página', (
      tester,
    ) async {
      await _pumpPage(tester, repo: _FakeRepo());

      expect(find.text('Todavía no hay grupos registrados'), findsOneWidget);
    });

    testWidgets('los grupos sin ganadores van después de los que tienen', (
      tester,
    ) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final key =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final repo = _FakeRepo(byDate: {key: _conGanadores(key)});
      await _pumpPage(tester, repo: repo, groups: [sur, norte]);

      expect(find.text('1 ganador'), findsOneWidget);
      expect(find.text('0 ganadores'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Grupo Norte (demo)')).dy,
        lessThan(tester.getTopLeft(find.text('Grupo Sur')).dy),
      );
    });

    testWidgets('una tarjeta por grupo con su cantidad de ganadores, sin '
        'jornadas', (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final key =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final repo = _FakeRepo(byDate: {key: _conGanadores(key)});
      await _pumpPage(tester, repo: repo);

      expect(find.byType(GroupMatchesTile), findsOneWidget);
      expect(find.text('Grupo Norte (demo)'), findsOneWidget);
      expect(find.text('1 ganador'), findsOneWidget);
      expect(find.textContaining('Jornada'), findsNothing);
    });

    testWidgets('arriba muestra el resumen de loterías del día con sus '
        'números', (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final key =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final repo = _FakeRepo(byDate: {key: _conGanadores(key)});
      await _pumpPage(tester, repo: repo, groups: [norte]);

      expect(find.byType(LotteryResultsCard), findsOneWidget);
      expect(find.text('Resultados del día'), findsOneWidget);
      expect(find.text('1 lotería'), findsOneWidget);
      expect(find.text('Dorado mañana'), findsOneWidget);
      expect(find.text('4521'), findsOneWidget);
      // El resumen va antes que las tarjetas de grupo.
      expect(
        tester.getTopLeft(find.text('Resultados del día')).dy,
        lessThan(tester.getTopLeft(find.text('Grupo Norte (demo)')).dy),
      );
    });

    testWidgets('el resumen se puede ocultar y volver a mostrar', (
      tester,
    ) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final key =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final repo = _FakeRepo(byDate: {key: _conGanadores(key)});
      await _pumpPage(tester, repo: repo, groups: [norte]);

      await tester.tap(find.text('Resultados del día'));
      await tester.pumpAndSettle();
      expect(find.text('4521'), findsNothing);
      expect(find.text('Grupo Norte (demo)'), findsOneWidget);

      await tester.tap(find.text('Resultados del día'));
      await tester.pumpAndSettle();
      expect(find.text('4521'), findsOneWidget);
    });

    testWidgets('sin números ganadores el resumen lo dice', (tester) async {
      await _pumpPage(tester, repo: _FakeRepo(), groups: [norte]);

      expect(
        find.text('Todavía no hay números ganadores para esta fecha'),
        findsOneWidget,
      );
    });

    testWidgets('los grupos con más ganadores van primero', (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final key =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      MatchEntry m(String id, String jid, String group) => MatchEntry(
        numero: '4521',
        loteria: 'dorado_manana',
        messageId: id,
        chatJid: jid,
        groupName: group,
        senderName: 'Ana',
        localTime: '08:15',
        storagePath: 'x/$id.jpg',
        shift: 'Jornada Mañana (06:00 – 10:54)',
        fechaJornada: key,
      );
      final repo = _FakeRepo(
        byDate: {
          key: DayMatches(
            fechaJornada: key,
            jornadas: [
              JornadaMatches(
                shift: 'Jornada Mañana (06:00 – 10:54)',
                winningNumbers: const [
                  WinningEntry(loteria: 'dorado_manana', numero: '4521'),
                ],
                matches: [
                  m('a', 'a@g.us', 'Alfa'),
                  m('b1', 'b@g.us', 'Beta'),
                  m('b2', 'b@g.us', 'Beta'),
                ],
              ),
            ],
          ),
        },
      );
      await _pumpPage(tester, repo: repo);

      expect(find.text('2 ganadores'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Beta')).dy,
        lessThan(tester.getTopLeft(find.text('Alfa')).dy),
      );
    });

    testWidgets(
      'error: se muestra con mapFailureToMessage, nunca con toString()',
      (tester) async {
        final repo = _FakeRepo()
          ..failure = const Failure.firestore(message: 'No se pudo leer');
        await _pumpPage(tester, repo: repo);

        expect(find.text('No se pudo leer'), findsOneWidget);
        expect(find.textContaining('Instance of'), findsNothing);
        expect(find.textContaining('Failure'), findsNothing);
        expect(find.text('Reintentar'), findsOneWidget);

        repo.failure = null;
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(find.text('No se pudo leer'), findsNothing);
      },
    );
  });

  testWidgets('cambiar la fecha y volver a "Hoy" recargan', (tester) async {
    final march15 = DateTime(2026, 3, 15);
    final key15 = '2026-03-15';
    final repo = _FakeRepo(byDate: {key15: _conGanadores(key15)});
    await _pumpPage(tester, repo: repo);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    container.read(matchesDateProvider.notifier).select(march15);
    await tester.pumpAndSettle();

    expect(find.byType(GroupMatchesTile), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);

    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();

    expect(find.text('Hoy'), findsNothing);
  });

  testWidgets('renderiza sin desbordes en móvil y escritorio', (tester) async {
    for (final size in [const Size(360, 800), const Size(1280, 900)]) {
      final repo = _FakeRepo();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchesRepositoryProvider.overrideWithValue(repo),
            allGroupsProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(home: MatchesPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Coincidencias'), findsOneWidget);
      expect(find.byTooltip('Volver'), findsOneWidget);
      expect(find.byTooltip('Elegir fecha'), findsOneWidget);
    }
  });
}
