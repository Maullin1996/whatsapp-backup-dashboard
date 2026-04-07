// lib/features/messages/presentation/providers/date_filter_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/date_filter.dart';

final dateFilterProvider = Provider<DateFilter>(
  (_) => const DateFilterTodayAndYesterday(),
);
