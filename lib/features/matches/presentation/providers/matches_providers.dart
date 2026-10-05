import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure_log.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/repositories/matches_repository.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/providers/real_matches_providers.dart';

/// Día de las Coincidencias (solo la fecha, sin hora). Arranca en hoy.
class MatchesDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateUtils.dateOnly(DateTime.now());

  void select(DateTime date) => state = DateUtils.dateOnly(date);

  void today() => state = DateUtils.dateOnly(DateTime.now());
}

final matchesDateProvider = NotifierProvider<MatchesDateNotifier, DateTime>(
  MatchesDateNotifier.new,
);

/// Repositorio de Coincidencias: el real (ganadores de `winning_numbers`,
/// registros del Revisor de `image_reviews`, mensajes y nombres de grupo,
/// ver `real_matches_providers.dart`). Los tests lo sobreescriben.
final matchesRepositoryProvider = Provider<MatchesRepository>(
  (ref) => ref.watch(realMatchesRepositoryProvider),
);

/// Coincidencias del día elegido, por jornada. Se recalcula al cambiar
/// [matchesDateProvider]; cada fecha se consulta de forma independiente, sin
/// acumular con la anterior (`image-review-domain`, regla 5). Un `Failure`
/// queda como error del `AsyncValue`, sin reintento automático (no es
/// transitorio).
final dayMatchesProvider = FutureProvider<DayMatches>((ref) async {
  final date = ref.watch(matchesDateProvider);
  final result = await ref.watch(matchesRepositoryProvider).getMatches(date);
  return result.fold((failure) {
    debugPrint(failureLogLine('COINCIDENCIAS', failure));
    throw failure;
  }, (day) => day);
}, retry: (retryCount, error) => null);
