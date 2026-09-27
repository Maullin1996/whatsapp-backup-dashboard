import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/mock_summary_repository.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/repositories/summary_repository.dart';

/// Día del resumen (solo la fecha, sin hora). Arranca en hoy.
class SummaryDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateUtils.dateOnly(DateTime.now());

  void select(DateTime date) => state = DateUtils.dateOnly(date);

  void today() => state = DateUtils.dateOnly(DateTime.now());
}

final summaryDateProvider = NotifierProvider<SummaryDateNotifier, DateTime>(
  SummaryDateNotifier.new,
);

/// Único punto donde se instancia el repositorio del resumen. TEMPORAL: datos
/// inventados (ver [MockSummaryRepository]); se reemplaza por uno real.
final summaryRepositoryProvider = Provider<SummaryRepository>(
  (ref) => const MockSummaryRepository(),
);

/// Resúmenes por grupo y jornada del día elegido. Se recalcula al cambiar
/// [summaryDateProvider]. Un `Failure` queda como error del `AsyncValue`, sin
/// reintento automático (no es transitorio).
final jornadaSummariesProvider = FutureProvider<List<JornadaSummary>>((
  ref,
) async {
  final date = ref.watch(summaryDateProvider);
  final result = await ref
      .watch(summaryRepositoryProvider)
      .getJornadaSummaries(date);
  return result.fold((failure) => throw failure, (list) => list);
}, retry: (retryCount, error) => null);
