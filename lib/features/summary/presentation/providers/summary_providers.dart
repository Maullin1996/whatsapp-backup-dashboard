import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure_log.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/cache/summary_cache.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/summary_overview.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/repositories/summary_repository.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/providers/real_summary_providers.dart';

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

/// Filtro del panel del Resumen (las tarjetas de cifras). Se conserva al
/// cambiar de fecha y se pierde al salir de la pantalla.
class SummaryFilterNotifier extends Notifier<SummaryFilter> {
  @override
  SummaryFilter build() => SummaryFilter.todas;

  /// Elige [filter]; elegir el que ya está activo vuelve a "todas".
  void toggle(SummaryFilter filter) =>
      state = state == filter ? SummaryFilter.todas : filter;

  void clear() => state = SummaryFilter.todas;
}

final summaryFilterProvider =
    NotifierProvider.autoDispose<SummaryFilterNotifier, SummaryFilter>(
      SummaryFilterNotifier.new,
    );

/// Reloj del Resumen: devuelve la hora actual. Inyectable para que los tests
/// fijen "ahora" (el aviso de imágenes sin registrar depende de si la jornada
/// ya terminó).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Repositorio del Resumen: el real (registros de `image_reviews`,
/// contadores de `shift_image_counts` y nombres de `group_stats`, ver
/// `real_summary_providers.dart`). Los tests lo sobreescriben.
final summaryRepositoryProvider = Provider<SummaryRepository>(
  (ref) => ref.watch(realSummaryRepositoryProvider),
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
  return result.fold((failure) {
    debugPrint(summaryFailureLog(failure));
    throw failure;
  }, (list) => list);
}, retry: (retryCount, error) => null);

/// Línea de log de una lectura fallida del Resumen (ver [failureLogLine]:
/// texto completo solo para Firestore y permisos; nunca datos).
String summaryFailureLog(Failure failure) => failureLogLine('RESUMEN', failure);

/// Recarga la fecha elegida desde la fuente, aunque haya caché vigente
/// ("Actualizar" y "Reintentar").
final reloadJornadaSummariesProvider = Provider<void Function()>(
  (ref) => () {
    ref.read(summaryCacheProvider).invalidate(ref.read(summaryDateProvider));
    ref.invalidate(jornadaSummariesProvider);
  },
);
