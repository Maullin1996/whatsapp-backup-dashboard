import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/cache/summary_cache.dart';
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

/// Reloj del Resumen: devuelve la hora actual. Inyectable para que los tests
/// fijen "ahora" (el aviso de imágenes sin registrar depende de si la jornada
/// ya terminó).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Único punto donde se instancia el repositorio del resumen. TEMPORAL: datos
/// inventados (ver [MockSummaryRepository]); se reemplaza por uno real.
final summaryRepositoryProvider = Provider<SummaryRepository>(
  (ref) => const MockSummaryRepository(),
);

/// Caché en memoria del Resumen (ver [SummaryCache]: 5 minutos por fecha,
/// solo éxitos). Vive lo que dura la app; se rehace si cambia el repositorio.
final summaryCacheProvider = Provider<SummaryCache>((ref) {
  ref.watch(summaryRepositoryProvider);
  return SummaryCache(now: ref.watch(clockProvider));
});

/// Resúmenes por grupo y jornada del día elegido, pasando por
/// [summaryCacheProvider]. Se recalcula al cambiar [summaryDateProvider]. Un
/// `Failure` queda como error del `AsyncValue`, sin reintento automático (no
/// es transitorio).
final jornadaSummariesProvider = FutureProvider<List<JornadaSummary>>((
  ref,
) async {
  final date = ref.watch(summaryDateProvider);
  final repository = ref.watch(summaryRepositoryProvider);
  final result = await ref
      .watch(summaryCacheProvider)
      .get(date, () => repository.getJornadaSummaries(date));
  return result.fold((failure) => throw failure, (list) => list);
}, retry: (retryCount, error) => null);

/// Recarga la fecha elegida desde la fuente, aunque haya caché vigente
/// ("Actualizar" y "Reintentar").
final reloadJornadaSummariesProvider = Provider<void Function()>(
  (ref) => () {
    ref.read(summaryCacheProvider).invalidate(ref.read(summaryDateProvider));
    ref.invalidate(jornadaSummariesProvider);
  },
);
