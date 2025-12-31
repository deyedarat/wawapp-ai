import 'package:flutter/foundation.dart';

/// Time window presets for report filtering
enum TimeWindow {
  today,
  last7Days,
  last30Days,
  custom,
}

/// Reports filter state for time range and optional filters
@immutable
class ReportsFilterState {
  final DateTime startDate;
  final DateTime endDate;
  final TimeWindow timeWindow;
  final String? city;
  final String? operator;

  const ReportsFilterState({
    required this.startDate,
    required this.endDate,
    required this.timeWindow,
    this.city,
    this.operator,
  });

  /// Default filter: Today
  factory ReportsFilterState.today() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return ReportsFilterState(
      startDate: startOfDay,
      endDate: endOfDay,
      timeWindow: TimeWindow.today,
    );
  }

  /// Last 7 days filter
  factory ReportsFilterState.last7Days() {
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final startDate = endOfDay.subtract(const Duration(days: 6));

    return ReportsFilterState(
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: endOfDay,
      timeWindow: TimeWindow.last7Days,
    );
  }

  /// Last 30 days filter
  factory ReportsFilterState.last30Days() {
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final startDate = endOfDay.subtract(const Duration(days: 29));

    return ReportsFilterState(
      startDate: DateTime(startDate.year, startDate.month, startDate.day),
      endDate: endOfDay,
      timeWindow: TimeWindow.last30Days,
    );
  }

  /// Custom date range filter
  factory ReportsFilterState.custom({
    required DateTime startDate,
    required DateTime endDate,
    String? city,
    String? operator,
  }) {
    return ReportsFilterState(
      startDate: startDate,
      endDate: endDate,
      timeWindow: TimeWindow.custom,
      city: city,
      operator: operator,
    );
  }

  ReportsFilterState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    TimeWindow? timeWindow,
    String? city,
    String? operator,
  }) {
    return ReportsFilterState(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      timeWindow: timeWindow ?? this.timeWindow,
      city: city ?? this.city,
      operator: operator ?? this.operator,
    );
  }

  String get timeWindowLabel {
    switch (timeWindow) {
      case TimeWindow.today:
        return 'اليوم';
      case TimeWindow.last7Days:
        return 'آخر 7 أيام';
      case TimeWindow.last30Days:
        return 'آخر 30 يوم';
      case TimeWindow.custom:
        return 'نطاق مخصص';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ReportsFilterState &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.timeWindow == timeWindow &&
        other.city == city &&
        other.operator == operator;
  }

  @override
  int get hashCode {
    return Object.hash(
      startDate,
      endDate,
      timeWindow,
      city,
      operator,
    );
  }
}
