// lib/features/messages/presentation/providers/shift_stats_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';

/// Imágenes cargadas por jornada, con la lectura del VISOR: una imagen en un
/// hueco de día cuenta en [gapsAfter] (por la jornada que
/// termina justo antes del hueco) y NO en `byShift[Shift.outOfShift]`.
class ShiftStats {
  final Map<Shift, int> byShift;
  final Map<Shift, int> gapsAfter;

  const ShiftStats({required this.byShift, this.gapsAfter = const {}});

  /// Sin imágenes.
  factory ShiftStats.empty() =>
      ShiftStats(byShift: {for (final shift in Shift.values) shift: 0});
}

final shiftStatsProvider = Provider<ShiftStats>((ref) {
  final messagesAsync = ref.watch(messagesProvider);

  final counts = {for (final shift in Shift.values) shift: 0};
  final gaps = <Shift, int>{};

  messagesAsync.whenData((messages) {
    for (final msg in messages) {
      if (!msg.isImage) continue;
      final date = DateTime.fromMillisecondsSinceEpoch(
        msg.messageTimestamp,
      ).toLocal();
      final gap = shiftGapBefore(date);
      if (gap != null) {
        gaps[gap] = (gaps[gap] ?? 0) + 1;
        continue;
      }
      final shift = getCurrentShift(date);
      counts[shift] = (counts[shift] ?? 0) + 1;
    }
  });

  return ShiftStats(byShift: counts, gapsAfter: gaps);
});

/// Una fila de "Imágenes por jornada" del panel de control.
typedef ShiftStatRow = ({String label, int count});

/// Filas de "Imágenes por jornada": las jornadas de la tabla y, solo si
/// tienen imágenes cargadas, cada "Fuera de jornada X" justo después de su
/// jornada. Sin fila de night2: [getCurrentShift] nunca la devuelve, así que
/// nunca tiene imágenes.
List<ShiftStatRow> shiftStatRows(ShiftStats stats) {
  int count(Shift shift) => stats.byShift[shift] ?? 0;

  return [
    for (final shift in Shift.values) ...[
      if (shift != Shift.night2)
        (label: shiftNames[shift]!, count: count(shift)),
      if ((stats.gapsAfter[shift] ?? 0) > 0)
        (label: shiftGapLabels[shift]!, count: stats.gapsAfter[shift]!),
    ],
  ];
}
