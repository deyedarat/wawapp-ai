/**
 * Live Ops Filters Model
 * Holds filter state for the Live Operations screen
 */

enum DriverStatusFilter {
  all,
  onlineOnly,
  offlineOnly,
  blockedOnly,
}

enum OperatorFilter {
  all,
  mauritel,
  chinguitel,
  mattel,
}

enum OrderStatusFilter {
  all,
  assigning,
  accepted,
  onRoute,
  completed,
  cancelled,
}

enum TimeWindowFilter {
  now, // Active orders only
  lastHour,
  today,
  all,
}

class LiveOpsFilters {
  final DriverStatusFilter driverStatus;
  final OperatorFilter operator;
  final OrderStatusFilter orderStatus;
  final TimeWindowFilter timeWindow;
  final bool showAnomaliesOnly;

  const LiveOpsFilters({
    this.driverStatus = DriverStatusFilter.all,
    this.operator = OperatorFilter.all,
    this.orderStatus = OrderStatusFilter.all,
    this.timeWindow = TimeWindowFilter.now,
    this.showAnomaliesOnly = false,
  });

  LiveOpsFilters copyWith({
    DriverStatusFilter? driverStatus,
    OperatorFilter? operator,
    OrderStatusFilter? orderStatus,
    TimeWindowFilter? timeWindow,
    bool? showAnomaliesOnly,
  }) {
    return LiveOpsFilters(
      driverStatus: driverStatus ?? this.driverStatus,
      operator: operator ?? this.operator,
      orderStatus: orderStatus ?? this.orderStatus,
      timeWindow: timeWindow ?? this.timeWindow,
      showAnomaliesOnly: showAnomaliesOnly ?? this.showAnomaliesOnly,
    );
  }

  /// Get cutoff time for time window filter
  DateTime? getTimeWindowCutoff() {
    final now = DateTime.now();
    switch (timeWindow) {
      case TimeWindowFilter.now:
        return null; // Only active orders
      case TimeWindowFilter.lastHour:
        return now.subtract(const Duration(hours: 1));
      case TimeWindowFilter.today:
        return DateTime(now.year, now.month, now.day);
      case TimeWindowFilter.all:
        return null;
    }
  }

  /// Check if filters are at default values
  bool get isDefault {
    return driverStatus == DriverStatusFilter.all &&
        operator == OperatorFilter.all &&
        orderStatus == OrderStatusFilter.all &&
        timeWindow == TimeWindowFilter.now &&
        !showAnomaliesOnly;
  }
}
