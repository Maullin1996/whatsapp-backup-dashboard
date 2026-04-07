// lib/features/messages/domain/entities/date_filter.dart

sealed class DateFilter {
  const DateFilter();

  /// Rango [from, to) en milliseconds epoch
  ({int from, int to}) toTimestampRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    return switch (this) {
      DateFilterToday() => (
        from: todayStart.millisecondsSinceEpoch,
        to: tomorrowStart.millisecondsSinceEpoch,
      ),
      DateFilterYesterday() => (
        from: yesterdayStart.millisecondsSinceEpoch,
        to: todayStart.millisecondsSinceEpoch,
      ),
      DateFilterTodayAndYesterday() => (
        from: yesterdayStart.millisecondsSinceEpoch,
        to: tomorrowStart.millisecondsSinceEpoch,
      ),
      DateFilterThisWeek() => (
        from: todayStart
            .subtract(Duration(days: todayStart.weekday - 1))
            .millisecondsSinceEpoch,
        to: tomorrowStart.millisecondsSinceEpoch,
      ),
      DateFilterSpecificDay(date: final d) => (
        from: DateTime(d.year, d.month, d.day).millisecondsSinceEpoch,
        to: DateTime(
          d.year,
          d.month,
          d.day,
        ).add(const Duration(days: 1)).millisecondsSinceEpoch,
      ),
    };
  }

  String get label => switch (this) {
    DateFilterTodayAndYesterday() => 'Hoy y ayer',
    DateFilterToday() => 'Hoy',
    DateFilterYesterday() => 'Ayer',
    DateFilterThisWeek() => 'Esta semana',
    DateFilterSpecificDay(date: final d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}',
  };

  bool get isDefault => this is DateFilterTodayAndYesterday;

  /// El realtime solo tiene sentido si el filtro incluye el día de hoy
  bool get includestoday => switch (this) {
    DateFilterToday() => true,
    DateFilterTodayAndYesterday() => true,
    DateFilterThisWeek() => true,
    DateFilterYesterday() => false,
    DateFilterSpecificDay() => false,
  };
}

final class DateFilterTodayAndYesterday extends DateFilter {
  const DateFilterTodayAndYesterday();
}

final class DateFilterToday extends DateFilter {
  const DateFilterToday();
}

final class DateFilterYesterday extends DateFilter {
  const DateFilterYesterday();
}

final class DateFilterThisWeek extends DateFilter {
  const DateFilterThisWeek();
}

final class DateFilterSpecificDay extends DateFilter {
  final DateTime date;
  const DateFilterSpecificDay({required this.date});
}
