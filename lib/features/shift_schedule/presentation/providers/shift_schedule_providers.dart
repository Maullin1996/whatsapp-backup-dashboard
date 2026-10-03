import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/app/providers.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure_log.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/shift_stats_provider.dart';
import 'package:whatsapp_monitor_viewer/features/shift_schedule/data/datasources/shift_schedule_datasource.dart';

/// Único punto donde se instancia el datasource de horarios y festivos.
final shiftScheduleDatasourceProvider = Provider<ShiftScheduleDatasource>(
  (ref) => FirestoreShiftScheduleDatasource(ref.read(firestoreProvider)),
);

/// Carga `jornadas` y `festivos_colombia` UNA VEZ por sesión autenticada (la
/// regla de lectura exige sesión) y reemplaza la tabla activa de
/// `shifts.dart`. Lo dispara un `ref.listen` en `WhatsAppMonitorApp`.
///
/// - Sin sesión: no lee ni registra nada.
/// - Falla: `[JORNADAS] falló (...)` ([failureLogLine]) y queda la tabla que
///   había (la fija si nunca se cargó). Sin reintentos; nunca lanza.
/// - Tabla distinta de la activa: la reemplaza e invalida
///   [shiftStatsProvider] (los conteos de "Imágenes por jornada"). Los
///   mensajes ya cargados NO se reclasifican: su etiqueta cambia al cambiar
///   de chat o de filtro (aceptado por el usuario).
/// - Tabla igual: no hace nada.
final shiftScheduleLoaderProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(reviewerUidProvider);
  if (uid == null) return;

  final result = await ref
      .read(shiftScheduleDatasourceProvider)
      .fetchShiftTable();
  result.fold((failure) => debugPrint(failureLogLine('JORNADAS', failure)), (
    table,
  ) {
    if (replaceShiftTable(table)) ref.invalidate(shiftStatsProvider);
  });
}, retry: (retryCount, error) => null);
