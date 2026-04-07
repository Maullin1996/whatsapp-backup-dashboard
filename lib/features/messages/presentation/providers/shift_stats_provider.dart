// lib/features/messages/presentation/providers/shift_stats_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';

final shiftStatsProvider = Provider<Map<Shift, int>>((ref) {
  final messagesAsync = ref.watch(messagesProvider);

  final counts = {for (final shift in Shift.values) shift: 0};

  messagesAsync.whenData((messages) {
    for (final msg in messages) {
      if (!msg.isImage) continue;
      final date = DateTime.fromMillisecondsSinceEpoch(
        msg.messageTimestamp,
      ).toLocal();
      final shift = getCurrentShift(date);
      counts[shift] = (counts[shift] ?? 0) + 1;
    }
  });

  return counts;
});
