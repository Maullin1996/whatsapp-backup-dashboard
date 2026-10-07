import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/winning_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/repositories/matches_repository.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/pages/group_winners_page.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/pages/matches_page.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/providers/matches_providers.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/image_url_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/image_detail_page.dart';

const _shift = 'Jornada Mañana (05:30 – 10:51)';

MatchEntry _match(
  String id, {
  String numero = '4521',
  String? codigo = 'AB-12',
  String email = 'revisor@correo.com',
}) => MatchEntry(
  numero: numero,
  loteria: 'dorado_manana',
  messageId: id,
  chatJid: 'g1@g.us',
  groupName: 'Grupo Norte',
  senderName: 'Ana',
  localTime: '08:15',
  storagePath: 'x/$id.jpg',
  shift: _shift,
  fechaJornada: '2026-10-05',
  revisorEmail: email,
  codigo: codigo,
);

class _FakeRepo implements MatchesRepository {
  final List<MatchEntry> matches;

  _FakeRepo(this.matches);

  @override
  Future<Either<Failure, DayMatches>> getMatches(DateTime date) async => Right(
    DayMatches(
      fechaJornada: '2026-10-05',
      jornadas: [
        JornadaMatches(
          shift: _shift,
          winningNumbers: const [
            WinningEntry(loteria: 'dorado_manana', numero: '4521'),
          ],
          matches: matches,
        ),
      ],
    ),
  );
}

/// La miniatura muestra un spinner mientras "carga": no hay nada que asentar.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pump(
  WidgetTester tester,
  List<MatchEntry> matches, {
  Size size = const Size(1280, 900),
  String initial = '/',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const MatchesPage()),
      GoRoute(
        path: '/matches/group',
        builder: (_, state) =>
            GroupWinnersPage(chatJid: state.uri.queryParameters['chat']!),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        matchesRepositoryProvider.overrideWithValue(_FakeRepo(matches)),
        imageUrlProvider.overrideWith((ref, path) => 'http://localhost/$path'),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await _settle(tester);
}

void main() {
  testWidgets('tocar la tarjeta del grupo abre sus ganadores', (tester) async {
    await _pump(tester, [_match('m1'), _match('m2', numero: '521')]);

    await tester.tap(find.text('Grupo Norte'));
    await _settle(tester);

    expect(find.byType(GroupWinnersPage), findsOneWidget);
    expect(find.textContaining('2 ganadores'), findsOneWidget);
  });

  testWidgets('cada ganador muestra revisor, fecha, lotería, número y código', (
    tester,
  ) async {
    await _pump(tester, [
      _match('m1'),
    ], initial: groupWinnersLocation('g1@g.us'));

    expect(find.text('revisor@correo.com'), findsOneWidget);
    expect(find.text('05/10/2026 · 08:15'), findsOneWidget);
    expect(find.text('Dorado mañana'), findsOneWidget);
    expect(find.text('4521'), findsOneWidget);
    expect(find.text('AB-12'), findsOneWidget);
    expect(find.byTooltip('Ver imagen'), findsOneWidget);
  });

  testWidgets('sin código ni correo muestra un guion', (tester) async {
    await _pump(tester, [
      _match('m1', codigo: null, email: ''),
    ], initial: groupWinnersLocation('g1@g.us'));

    expect(find.text('—'), findsNWidgets(2));
  });

  testWidgets('tocar la imagen abre el visor de imágenes', (tester) async {
    await _pump(tester, [
      _match('m1'),
      _match('m2'),
    ], initial: groupWinnersLocation('g1@g.us'));

    await tester.tap(find.byTooltip('Ver imagen').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ImageDetailPage), findsOneWidget);
    final page = tester.widget<ImageDetailPage>(find.byType(ImageDetailPage));
    expect(page.initialIndex, 1);
    expect(page.reviewForm, isFalse);
  });

  testWidgets('un grupo sin ganadores ese día muestra el vacío', (
    tester,
  ) async {
    await _pump(tester, [
      _match('m1'),
    ], initial: groupWinnersLocation('otro@g.us'));

    expect(
      find.text('Este grupo no tiene ganadores en esta fecha'),
      findsOneWidget,
    );
  });

  for (final size in [const Size(360, 800), const Size(1280, 900)]) {
    testWidgets('sin desbordes a ${size.width.toInt()} px', (tester) async {
      await _pump(
        tester,
        [_match('m1'), _match('m2')],
        size: size,
        initial: groupWinnersLocation('g1@g.us'),
      );

      expect(tester.takeException(), isNull);
    });
  }
}
