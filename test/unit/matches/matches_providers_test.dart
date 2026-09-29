import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/repositories/matches_repository.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/providers/matches_providers.dart';

DayMatches _day(String fecha) =>
    DayMatches(fechaJornada: fecha, jornadas: const []);

/// Repositorio falso: datos por día (`yyyy-MM-dd`), con la opción de
/// detener la respuesta o de fallar. Registra las fechas pedidas.
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
    return Right(byDate[key] ?? _day(key));
  }
}

void main() {
  late _FakeRepo repo;
  late ProviderContainer container;

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [matchesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    repo = _FakeRepo(byDate: {});
    container = makeContainer();
  });

  group('matchesDateProvider', () {
    test('la fecha por defecto es hoy, sin hora', () {
      // Calculado en la misma línea que la aserción: ventana mínima, igual
      // que `summary_page_test.dart`.
      final today = DateUtils.dateOnly(DateTime.now());

      expect(container.read(matchesDateProvider), today);
    });

    test('select normaliza a solo día (año, mes, día)', () {
      container
          .read(matchesDateProvider.notifier)
          .select(DateTime(2026, 3, 15, 23, 59));

      expect(container.read(matchesDateProvider), DateTime(2026, 3, 15));
    });

    test('today() vuelve a la fecha de hoy', () {
      container.read(matchesDateProvider.notifier).select(DateTime(2020, 1, 1));

      container.read(matchesDateProvider.notifier).today();

      expect(
        container.read(matchesDateProvider),
        DateUtils.dateOnly(DateTime.now()),
      );
    });
  });

  group('dayMatchesProvider', () {
    test('un Right llega como datos', () async {
      repo.byDate['2026-03-15'] = _day('2026-03-15');
      container
          .read(matchesDateProvider.notifier)
          .select(DateTime(2026, 3, 15));

      final result = await container.read(dayMatchesProvider.future);

      expect(result.fechaJornada, '2026-03-15');
    });

    test('un Left llega como error del AsyncValue', () async {
      repo.failure = const Failure.firestore(message: 'No se pudo leer');
      container
          .read(matchesDateProvider.notifier)
          .select(DateTime(2026, 3, 15));

      await expectLater(
        container.read(dayMatchesProvider.future),
        throwsA(isA<Failure>()),
      );

      final state = container.read(dayMatchesProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<Failure>());
    });

    test('cambiar la fecha dispara una nueva consulta con esa fecha', () async {
      await container.read(dayMatchesProvider.future); // fecha inicial (hoy)

      container
          .read(matchesDateProvider.notifier)
          .select(DateTime(2026, 5, 20));
      await container.read(dayMatchesProvider.future);

      expect(repo.requested, hasLength(2));
      expect(DateUtils.dateOnly(repo.requested.last), DateTime(2026, 5, 20));
    });

    test('cambiar de fecha no arrastra datos de la anterior', () async {
      repo.byDate['2026-03-15'] = _day('2026-03-15');
      repo.byDate['2026-03-16'] = _day('2026-03-16');

      container
          .read(matchesDateProvider.notifier)
          .select(DateTime(2026, 3, 15));
      final first = await container.read(dayMatchesProvider.future);
      expect(first.fechaJornada, '2026-03-15');

      container
          .read(matchesDateProvider.notifier)
          .select(DateTime(2026, 3, 16));
      final second = await container.read(dayMatchesProvider.future);

      expect(second.fechaJornada, '2026-03-16');
      expect(second, isNot(first));
    });

    test('no reintenta solo, y consulta de nuevo tras invalidar', () async {
      repo.failure = const Failure.firestore(message: 'falló');
      container
          .read(matchesDateProvider.notifier)
          .select(DateTime(2026, 3, 15));

      try {
        await container.read(dayMatchesProvider.future);
      } catch (_) {
        // Se verifica más abajo, con el AsyncValue ya resuelto.
      }
      expect(repo.requested, hasLength(1));

      // Sin cambiar de fecha ni invalidar, no hay una segunda consulta.
      container.read(dayMatchesProvider);
      expect(repo.requested, hasLength(1));

      repo.failure = null;
      container.invalidate(dayMatchesProvider);
      final result = await container.read(dayMatchesProvider.future);

      expect(repo.requested, hasLength(2));
      expect(result.fechaJornada, '2026-03-15');
    });

    test('el estado se recalcula en cuanto cambia la fecha, aunque nadie '
        'haya leído el .future todavía', () async {
      repo.gate = Completer<void>();
      container
          .read(matchesDateProvider.notifier)
          .select(DateTime(2026, 3, 15));

      final loading = container.read(dayMatchesProvider);
      expect(loading, isA<AsyncLoading<DayMatches>>());

      repo.gate!.complete();
      await container.read(dayMatchesProvider.future);
      expect(repo.requested, hasLength(1));
    });
  });
}
