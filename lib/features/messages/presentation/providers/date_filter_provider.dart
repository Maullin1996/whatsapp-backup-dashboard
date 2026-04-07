// lib/features/messages/presentation/providers/date_filter_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/date_filter.dart';

class DateFilterNotifier extends Notifier<DateFilter> {
  @override
  DateFilter build() => const DateFilterTodayAndYesterday();

  void setFilter(DateFilter filter) => state = filter;

  void reset() => state = const DateFilterTodayAndYesterday();
}

final dateFilterProvider = NotifierProvider<DateFilterNotifier, DateFilter>(
  DateFilterNotifier.new,
);
