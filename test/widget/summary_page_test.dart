import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/fecha_jornada.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/repositories/summary_repository.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/pages/summary_page.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/providers/summary_providers.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/pages/summary_role_detail_page.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/widgets/summary_group_tile.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/widgets/summary_role_card.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/widgets/summary_skeleton.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_long_date.dart';

final _morning = shiftNames[Shift.morning]!;
final _afternoon = shiftNames[Shift.afternoon1]!;

RoleSummary _role(int imagenes, int tickets, int total) => RoleSummary(
  registrado: true,
  cantidadImagenes: imagenes,
  cantidadTickets: tickets,
  totalSuma: total,
);

JornadaSummary _js({
  String jid = 'g1',
  String group = 'Grupo Norte',
  String? shift,
  String fecha = '2026-03-15',
  required RoleSummary revisor,
  required RoleSummary sumador,
  int imagenesEnJornada = 0,
}) => JornadaSummary(
  chatJid: jid,
  groupName: group,
  fechaJornada: fecha,
  shift: shift ?? _morning,
  revisor: revisor,
  sumador: sumador,
  imagenesEnJornada: imagenesEnJornada,
);

/// Repositorio falso: datos por día (`yyyy-MM-dd`), con la opción de
/// detener la respuesta o de fallar.
class _FakeRepo implements SummaryRepository {
  final Map<String, List<JornadaSummary>> byDate;
  final List<DateTime> requested = [];
  Completer<void>? gate;
  Failure? failure;

  _FakeRepo({this.byDate = const {}});

  @override
  Future<Either<Failure, List<JornadaSummary>>> getJornadaSummaries(
    DateTime fecha,
  ) async {
    requested.add(fecha);
    await gate?.future;
    final failure = this.failure;
    if (failure != null) return Left(failure);
    return Right(byDate[fechaJornadaDe(fecha.millisecondsSinceEpoch)] ?? []);
  }
}

Future<ProviderContainer> _pumpPage(
  WidgetTester tester, {
  required _FakeRepo repo,
  Size size = const Size(1280, 800),
  GoRouter? router,
  bool settle = true,
  DateTime? now,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        summaryRepositoryProvider.overrideWithValue(repo),
        if (now != null) clockProvider.overrideWithValue(() => now),
      ],
      child: router == null
          ? const MaterialApp(home: SummaryPage())
          : MaterialApp.router(routerConfig: router),
    ),
  );
  // Con el estado de carga el shimmer anima sin parar: no se puede "asentar".
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Future<void> _selectDate(
  WidgetTester tester,
  ProviderContainer container,
  DateTime date,
) async {
  container.read(summaryDateProvider.notifier).select(date);
  await tester.pumpAndSettle();
}

String _key(DateTime d) => fechaJornadaDe(d.millisecondsSinceEpoch);

void main() {
  final today = DateUtils.dateOnly(DateTime.now());
  final march15 = DateTime(2026, 3, 15);

  group('estados', () {
    testWidgets('mientras carga muestra el skeleton y no las tarjetas', (
      tester,
    ) async {
      final repo = _FakeRepo()..gate = Completer<void>();
      await _pumpPage(tester, repo: repo, settle: false);

      expect(find.byType(SummarySkeleton), findsOneWidget);
      expect(find.byType(SummaryGroupTile), findsNothing);

      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SummarySkeleton), findsNothing);
    });

    testWidgets('lista vacía: "No hay reportes registrados para esta fecha"', (
      tester,
    ) async {
      await _pumpPage(tester, repo: _FakeRepo());

      expect(
        find.text('No hay reportes registrados para esta fecha'),
        findsOneWidget,
      );
      expect(find.byType(SummaryGroupTile), findsNothing);
    });

    testWidgets('error: muestra el mensaje del Failure y Reintentar vuelve a '
        'pedir los datos', (tester) async {
      final repo = _FakeRepo()
        ..failure = const Failure.firestore(message: 'No se pudo leer');
      await _pumpPage(tester, repo: repo);

      expect(find.text('No se pudo leer'), findsOneWidget);
      expect(repo.requested, hasLength(1));

      repo.failure = null;
      repo.byDate.isEmpty; // sin datos: tras reintentar queda el vacío
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.requested, hasLength(2));
      expect(find.text('No se pudo leer'), findsNothing);
      expect(
        find.text('No hay reportes registrados para esta fecha'),
        findsOneWidget,
      );
    });
  });

  group('contenido', () {
    final repo = _FakeRepo(
      byDate: {
        _key(today): [
          _js(
            fecha: _key(today),
            revisor: _role(12, 34, 135000),
            sumador: _role(12, 34, 135000),
          ),
          _js(
            fecha: _key(today),
            shift: _afternoon,
            revisor: _role(3, 8, 90000),
            sumador: _role(3, 8, 81000),
          ),
          _js(
            jid: 'g2',
            group: 'Grupo Sur',
            fecha: _key(today),
            revisor: _role(1, 1, 5000),
            sumador: RoleSummary.sinRegistrar,
          ),
          _js(
            jid: 'g2',
            group: 'Grupo Sur',
            shift: _afternoon,
            fecha: _key(today),
            revisor: RoleSummary.sinRegistrar,
            sumador: RoleSummary.sinRegistrar,
          ),
        ],
      },
    );

    testWidgets('una fila por grupo con las tarjetas de Revisor y Sumador', (
      tester,
    ) async {
      await _pumpPage(tester, repo: repo);

      expect(find.byType(SummaryGroupTile), findsNWidgets(2));
      expect(find.byType(SummaryRoleCard), findsNWidgets(4));
      expect(find.text('Revisor'), findsNWidgets(2));
      expect(find.text('Sumador'), findsNWidgets(2));
    });

    testWidgets('los grupos van uno debajo del otro también en escritorio', (
      tester,
    ) async {
      await _pumpPage(tester, repo: repo);
      final tiles = find.byType(SummaryGroupTile);
      expect(
        tester.getTopLeft(tiles.at(1)).dy,
        greaterThan(tester.getBottomLeft(tiles.at(0)).dy),
      );
    });

    testWidgets('los grupos con descuadre van antes que los que cuadran', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        size: const Size(360, 1600),
        repo: _FakeRepo(
          byDate: {
            _key(today): [
              _js(
                group: 'Grupo Bien',
                fecha: _key(today),
                revisor: _role(1, 1, 1000),
                sumador: _role(1, 1, 1000),
              ),
              _js(
                jid: 'g2',
                group: 'Grupo Mal',
                fecha: _key(today),
                revisor: _role(1, 1, 2000),
                sumador: _role(1, 1, 1000),
              ),
            ],
          },
        ),
      );

      expect(
        tester.getTopLeft(find.text('Grupo Mal')).dy,
        lessThan(tester.getTopLeft(find.text('Grupo Bien')).dy),
      );
    });

    testWidgets('cada tarjeta muestra el total sumado y las jornadas', (
      tester,
    ) async {
      await _pumpPage(tester, repo: repo);

      // Norte: Revisor 135.000 + 90.000, Sumador 135.000 + 81.000.
      expect(find.text('\$225.000'), findsOneWidget);
      expect(find.text('\$216.000'), findsOneWidget);
      // Sur: el Revisor solo sumó la mañana; el Sumador no registró nada.
      expect(find.text('\$5.000'), findsOneWidget);
      expect(find.text('Sin registrar'), findsOneWidget);
      expect(find.text('Mañana'), findsNWidgets(4));
      expect(find.text('Tarde 1'), findsNWidgets(4));
    });

    testWidgets('la pastilla del grupo muestra lo más grave', (tester) async {
      await _pumpPage(tester, repo: repo);

      expect(find.text('1 descuadre'), findsOneWidget);
      expect(find.text('2 pendientes'), findsOneWidget);
    });

    testWidgets('sin problemas: "Todo cuadra"', (tester) async {
      await _pumpPage(
        tester,
        repo: _FakeRepo(
          byDate: {
            _key(today): [
              _js(
                fecha: _key(today),
                revisor: _role(1, 1, 1000),
                sumador: _role(1, 1, 1000),
              ),
            ],
          },
        ),
      );

      expect(find.text('Todo cuadra'), findsOneWidget);
    });
  });

  group('detalle por rol', () {
    final day = DateTime(2026, 9, 28);
    final repo = _FakeRepo(
      byDate: {
        '2026-09-28': [
          JornadaSummary(
            chatJid: 'g1',
            groupName: 'Grupo Norte',
            fechaJornada: '2026-09-28',
            shift: _morning,
            revisor: _role(7, 14, 90000),
            sumador: _role(10, 20, 90000),
            imagenesEnJornada: 10,
          ),
          JornadaSummary(
            chatJid: 'g1',
            groupName: 'Grupo Norte',
            fechaJornada: '2026-09-28',
            shift: _afternoon,
            revisor: _role(2, 3, 30000),
            sumador: RoleSummary.sinRegistrar,
            imagenesEnJornada: 2,
          ),
        ],
      },
    );
    // Después del fin de la mañana (15:51 UTC), antes de la tarde 1.
    final now = DateTime.utc(2026, 9, 28, 15, 52);

    GoRouter detailRouter(String chat, ReviewRole rol) => GoRouter(
      initialLocation: summaryRoleDetailLocation(chat, rol),
      routes: [
        GoRoute(
          path: '/summary/detail',
          builder: (_, state) => SummaryRoleDetailPage(
            chatJid: state.uri.queryParameters['chat']!,
            rol: ReviewRole.values.byName(state.uri.queryParameters['role']!),
          ),
        ),
      ],
    );

    Future<void> pumpDetail(
      WidgetTester tester,
      String chat,
      ReviewRole rol,
    ) async {
      final container = await _pumpPage(
        tester,
        repo: repo,
        router: detailRouter(chat, rol),
        now: now,
      );
      await _selectDate(tester, container, day);
    }

    testWidgets('tocar la tarjeta del Revisor abre su detalle', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SummaryPage()),
          GoRoute(
            path: '/summary/detail',
            builder: (_, state) => SummaryRoleDetailPage(
              chatJid: state.uri.queryParameters['chat']!,
              rol: ReviewRole.values.byName(state.uri.queryParameters['role']!),
            ),
          ),
        ],
      );
      final container = await _pumpPage(
        tester,
        repo: repo,
        router: router,
        now: now,
      );
      await _selectDate(tester, container, day);

      await tester.tap(find.text('Revisor'));
      await tester.pumpAndSettle();

      expect(find.byType(SummaryRoleDetailPage), findsOneWidget);
      // Total de las dos jornadas.
      expect(find.text('\$120.000'), findsOneWidget);
      expect(find.text('Por jornada'), findsOneWidget);
      expect(find.text('Registrada'), findsNWidgets(2));
      expect(find.text('Falta por llenar'), findsNothing);
    });

    testWidgets('el Sumador ve qué jornada le falta por llenar', (
      tester,
    ) async {
      await pumpDetail(tester, 'g1', ReviewRole.sumador);

      expect(find.text('Le falta llenar la jornada Tarde 1'), findsOneWidget);
      expect(find.text('Falta por llenar'), findsOneWidget);
      expect(find.text('Registrada'), findsOneWidget);
    });

    testWidgets('aviso de imágenes sin registrar con la jornada terminada', (
      tester,
    ) async {
      await pumpDetail(tester, 'g1', ReviewRole.revisor);

      // Mañana: el contador dice 10 y el Revisor registró 7.
      expect(find.text('Faltan 3 imágenes por registrar'), findsOneWidget);
    });

    testWidgets('un grupo sin datos ese día muestra el vacío', (tester) async {
      await pumpDetail(tester, 'otro', ReviewRole.revisor);

      expect(
        find.text('No hay reportes de este grupo en esta fecha'),
        findsOneWidget,
      );
    });
  });

  group('fecha', () {
    late _FakeRepo repo;

    setUp(() {
      repo = _FakeRepo(
        byDate: {
          _key(today): [
            _js(
              fecha: _key(today),
              revisor: _role(2, 4, 40000),
              sumador: _role(2, 4, 40000),
            ),
          ],
          _key(march15): [
            _js(
              group: 'Grupo Marzo',
              fecha: _key(march15),
              revisor: _role(5, 9, 70000),
              sumador: _role(5, 9, 61000),
            ),
            _js(
              group: 'Grupo Marzo',
              shift: _afternoon,
              fecha: _key(march15),
              revisor: _role(1, 2, 8000),
              sumador: _role(1, 2, 8000),
            ),
          ],
        },
      );
    });

    testWidgets('arranca en hoy, en español y sin el acceso "Hoy"', (
      tester,
    ) async {
      await _pumpPage(tester, repo: repo);

      expect(find.text(formatLongDate(today)), findsOneWidget);
      expect(find.text('Hoy'), findsNothing);
      expect(repo.requested.map(DateUtils.dateOnly), [today]);
      expect(find.byType(SummaryGroupTile), findsOneWidget);
    });

    testWidgets('cambiar la fecha recarga las tarjetas y muestra el acceso '
        '"Hoy"', (tester) async {
      final container = await _pumpPage(tester, repo: repo);

      await _selectDate(tester, container, march15);

      expect(find.text('15 de marzo de 2026'), findsOneWidget);
      expect(find.text('Grupo Marzo'), findsOneWidget);
      expect(find.byType(SummaryGroupTile), findsOneWidget);
      expect(find.text('1 descuadre'), findsOneWidget);
      expect(repo.requested.map(DateUtils.dateOnly), [today, march15]);
      expect(find.text('Hoy'), findsOneWidget);
    });

    testWidgets('"Hoy" vuelve a la fecha de hoy, desde la caché (vigente)', (
      tester,
    ) async {
      final container = await _pumpPage(tester, repo: repo);
      await _selectDate(tester, container, march15);

      await tester.tap(find.text('Hoy'));
      await tester.pumpAndSettle();

      expect(find.text(formatLongDate(today)), findsOneWidget);
      expect(find.text('Hoy'), findsNothing);
      expect(find.text('Grupo Marzo'), findsNothing);
      expect(find.byType(SummaryGroupTile), findsOneWidget);
      // Hoy ya se había leído hace menos de 5 minutos: no se vuelve a pedir.
      expect(repo.requested.map(DateUtils.dateOnly), [today, march15]);
    });

    testWidgets('durante la recarga se ve el skeleton', (tester) async {
      final container = await _pumpPage(tester, repo: repo);
      repo.gate = Completer<void>();

      container.read(summaryDateProvider.notifier).select(march15);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(SummarySkeleton), findsOneWidget);

      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SummarySkeleton), findsNothing);
      expect(find.byType(SummaryGroupTile), findsOneWidget);
    });

    testWidgets('el botón de calendario abre el selector y elegir un día '
        'recarga', (tester) async {
      final container = await _pumpPage(tester, repo: repo);
      // Un día a mitad de mes: el calendario abre en marzo de 2026 y el 20
      // siempre es elegible.
      await _selectDate(tester, container, march15);

      await tester.tap(find.byTooltip('Elegir fecha'));
      await tester.pumpAndSettle();
      expect(find.text('Seleccionar fecha'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(CalendarDatePicker),
          matching: find.text('20'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Seleccionar'));
      await tester.pumpAndSettle();

      expect(container.read(summaryDateProvider), DateTime(2026, 3, 20));
      expect(find.text('20 de marzo de 2026'), findsOneWidget);
      expect(
        repo.requested.map(DateUtils.dateOnly).last,
        DateTime(2026, 3, 20),
      );
    });

    testWidgets('"Actualizar" vuelve a pedir la fecha elegida aunque haya '
        'caché vigente', (tester) async {
      final container = await _pumpPage(tester, repo: repo);
      await _selectDate(tester, container, march15);
      expect(repo.requested.map(DateUtils.dateOnly), [today, march15]);

      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();

      expect(repo.requested.map(DateUtils.dateOnly), [today, march15, march15]);
      expect(find.byType(SummaryGroupTile), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('"Reintentar" tras un error va a la fuente, aunque la fecha '
        'estuviera en caché antes', (tester) async {
      await _pumpPage(tester, repo: repo);
      expect(repo.requested, hasLength(1));

      repo.failure = const Failure.firestore(message: 'No se pudo leer');
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo leer'), findsOneWidget);
      expect(repo.requested, hasLength(2));

      repo.failure = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.requested, hasLength(3));
      expect(find.text('No se pudo leer'), findsNothing);
      expect(find.byType(SummaryGroupTile), findsOneWidget);
    });

    testWidgets('cancelar el selector no cambia la fecha', (tester) async {
      final container = await _pumpPage(tester, repo: repo);
      await _selectDate(tester, container, march15);
      final calls = repo.requested.length;

      await tester.tap(find.byTooltip('Elegir fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(container.read(summaryDateProvider), march15);
      expect(repo.requested, hasLength(calls));
    });
  });

  group('responsive y navegación', () {
    for (final (name, size) in [
      ('móvil', const Size(360, 800)),
      ('escritorio', const Size(1280, 800)),
    ]) {
      testWidgets('renderiza sin desbordes en $name', (tester) async {
        final repo = _FakeRepo(
          byDate: {
            _key(today): [
              _js(
                fecha: _key(today),
                revisor: _role(12, 34, 1350000),
                sumador: _role(12, 34, 1260000),
              ),
              _js(
                shift: shiftNames[Shift.night1]!,
                fecha: _key(today),
                revisor: RoleSummary.sinRegistrar,
                sumador: RoleSummary.sinRegistrar,
              ),
            ],
          },
        );
        await _pumpPage(tester, repo: repo, size: size);

        expect(tester.takeException(), isNull);
        expect(find.text('Resumen'), findsOneWidget);
        expect(find.byType(SummaryGroupTile), findsOneWidget);
        expect(find.byTooltip('Volver'), findsOneWidget);
        expect(find.byTooltip('Elegir fecha'), findsOneWidget);
      });
    }

    testWidgets('"Volver" regresa a la pantalla anterior', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/summary'),
                child: const Text('abrir'),
              ),
            ),
          ),
          GoRoute(path: '/summary', builder: (_, _) => const SummaryPage()),
        ],
      );
      await _pumpPage(tester, repo: _FakeRepo(), router: router);

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.byType(SummaryPage), findsOneWidget);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.byType(SummaryPage), findsNothing);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('"Volver" sin historial (enlace directo) va a /home', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/summary',
        routes: [
          GoRoute(path: '/summary', builder: (_, _) => const SummaryPage()),
          GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        ],
      );
      await _pumpPage(tester, repo: _FakeRepo(), router: router);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
    });
  });
}
