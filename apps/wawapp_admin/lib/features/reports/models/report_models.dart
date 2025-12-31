/// Overview report data model
class OverviewReportData {
  final int totalOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int completionRate;
  final int averageOrderValue;
  final int totalActiveDrivers;
  final int newClients;
  final String periodStart;
  final String periodEnd;

  OverviewReportData({
    required this.totalOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.completionRate,
    required this.averageOrderValue,
    required this.totalActiveDrivers,
    required this.newClients,
    required this.periodStart,
    required this.periodEnd,
  });

  factory OverviewReportData.fromJson(Map<String, dynamic> json) {
    return OverviewReportData(
      totalOrders: json['totalOrders'] as int? ?? 0,
      completedOrders: json['completedOrders'] as int? ?? 0,
      cancelledOrders: json['cancelledOrders'] as int? ?? 0,
      completionRate: json['completionRate'] as int? ?? 0,
      averageOrderValue: json['averageOrderValue'] as int? ?? 0,
      totalActiveDrivers: json['totalActiveDrivers'] as int? ?? 0,
      newClients: json['newClients'] as int? ?? 0,
      periodStart: json['periodStart'] as String? ?? '',
      periodEnd: json['periodEnd'] as String? ?? '',
    );
  }
}

/// Daily financial breakdown
class DailyFinancial {
  final String date;
  final int ordersCount;
  final int grossRevenue;
  final int driverEarnings;
  final int platformCommission;

  DailyFinancial({
    required this.date,
    required this.ordersCount,
    required this.grossRevenue,
    required this.driverEarnings,
    required this.platformCommission,
  });

  factory DailyFinancial.fromJson(Map<String, dynamic> json) {
    return DailyFinancial(
      date: json['date'] as String? ?? '',
      ordersCount: json['ordersCount'] as int? ?? 0,
      grossRevenue: json['grossRevenue'] as int? ?? 0,
      driverEarnings: json['driverEarnings'] as int? ?? 0,
      platformCommission: json['platformCommission'] as int? ?? 0,
    );
  }
}

/// Financial report data model
class FinancialReportData {
  final FinancialSummary summary;
  final List<DailyFinancial> dailyBreakdown;
  final String periodStart;
  final String periodEnd;

  FinancialReportData({
    required this.summary,
    required this.dailyBreakdown,
    required this.periodStart,
    required this.periodEnd,
  });

  factory FinancialReportData.fromJson(Map<String, dynamic> json) {
    return FinancialReportData(
      summary: FinancialSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
      dailyBreakdown: (json['dailyBreakdown'] as List<dynamic>?)
              ?.map((e) => DailyFinancial.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      periodStart: json['periodStart'] as String? ?? '',
      periodEnd: json['periodEnd'] as String? ?? '',
    );
  }
}

/// Financial summary
class FinancialSummary {
  final int totalOrders;
  final int grossRevenue;
  final int totalDriverEarnings;
  final int totalPlatformCommission;
  final int averageCommissionRate;
  // Phase 5.5: Wallet & Payout metrics
  final int totalPayoutsInPeriod;
  final int totalDriverOutstandingBalance;
  final int platformWalletBalance;

  FinancialSummary({
    required this.totalOrders,
    required this.grossRevenue,
    required this.totalDriverEarnings,
    required this.totalPlatformCommission,
    required this.averageCommissionRate,
    this.totalPayoutsInPeriod = 0,
    this.totalDriverOutstandingBalance = 0,
    this.platformWalletBalance = 0,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    return FinancialSummary(
      totalOrders: json['totalOrders'] as int? ?? 0,
      grossRevenue: json['grossRevenue'] as int? ?? 0,
      totalDriverEarnings: json['totalDriverEarnings'] as int? ?? 0,
      totalPlatformCommission: json['totalPlatformCommission'] as int? ?? 0,
      averageCommissionRate: json['averageCommissionRate'] as int? ?? 0,
      // Phase 5.5: Wallet & Payout metrics
      totalPayoutsInPeriod: json['totalPayoutsInPeriod'] as int? ?? 0,
      totalDriverOutstandingBalance: json['totalDriverOutstandingBalance'] as int? ?? 0,
      platformWalletBalance: json['platformWalletBalance'] as int? ?? 0,
    );
  }
}

/// Driver performance data model
class DriverPerformance {
  final String driverId;
  final String name;
  final String phone;
  final String operator;
  final int totalTrips;
  final int totalEarnings;
  final double averageRating;
  final int cancellationRate;
  final int completedTrips;
  final int cancelledTrips;

  DriverPerformance({
    required this.driverId,
    required this.name,
    required this.phone,
    required this.operator,
    required this.totalTrips,
    required this.totalEarnings,
    required this.averageRating,
    required this.cancellationRate,
    required this.completedTrips,
    required this.cancelledTrips,
  });

  factory DriverPerformance.fromJson(Map<String, dynamic> json) {
    return DriverPerformance(
      driverId: json['driverId'] as String? ?? '',
      name: json['name'] as String? ?? 'N/A',
      phone: json['phone'] as String? ?? 'N/A',
      operator: json['operator'] as String? ?? 'Unknown',
      totalTrips: json['totalTrips'] as int? ?? 0,
      totalEarnings: json['totalEarnings'] as int? ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      cancellationRate: json['cancellationRate'] as int? ?? 0,
      completedTrips: json['completedTrips'] as int? ?? 0,
      cancelledTrips: json['cancelledTrips'] as int? ?? 0,
    );
  }
}

/// Driver performance report data model
class DriverPerformanceReportData {
  final List<DriverPerformance> drivers;
  final String periodStart;
  final String periodEnd;
  final int totalDrivers;

  DriverPerformanceReportData({
    required this.drivers,
    required this.periodStart,
    required this.periodEnd,
    required this.totalDrivers,
  });

  factory DriverPerformanceReportData.fromJson(Map<String, dynamic> json) {
    return DriverPerformanceReportData(
      drivers: (json['drivers'] as List<dynamic>?)
              ?.map((e) => DriverPerformance.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      periodStart: json['periodStart'] as String? ?? '',
      periodEnd: json['periodEnd'] as String? ?? '',
      totalDrivers: json['totalDrivers'] as int? ?? 0,
    );
  }
}
