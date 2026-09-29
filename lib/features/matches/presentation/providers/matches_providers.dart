import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/mock_matches_repository.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/repositories/matches_repository.dart';

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

/// Único punto donde se instancia el repositorio de Coincidencias. TEMPORAL:
/// datos inventados (ver [MockMatchesRepository]); se reemplaza por uno real
/// cuando exista la Cloud Function puente de números ganadores (paso 7) —
/// cambiar este único archivo alcanza, el resto del feature no se toca.
final matchesRepositoryProvider = Provider<MatchesRepository>(
  (ref) => const MockMatchesRepository(),
);

/// Coincidencias del día elegido, por jornada. Se recalcula al cambiar
/// [matchesDateProvider]; cada fecha se consulta de forma independiente, sin
/// acumular con la anterior (`image-review-domain`, regla 5). Un `Failure`
/// queda como error del `AsyncValue`, sin reintento automático (no es
/// transitorio).
final dayMatchesProvider = FutureProvider<DayMatches>((ref) async {
  final date = ref.watch(matchesDateProvider);
  final result = await ref.watch(matchesRepositoryProvider).getMatches(date);
  return result.fold((failure) => throw failure, (day) => day);
}, retry: (retryCount, error) => null);
