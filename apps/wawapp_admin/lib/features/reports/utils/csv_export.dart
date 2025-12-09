// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'package:intl/intl.dart';

import '../models/report_models.dart';

class CsvExportUtil {
  /// Export overview report to CSV
  static void exportOverviewReport(OverviewReportData data) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final startDate = DateTime.parse(data.periodStart);
    final endDate = DateTime.parse(data.periodEnd);

    final csv = StringBuffer();
    csv.writeln('WawApp Overview Report');
    csv.writeln('Period: ${dateFormat.format(startDate)} to ${dateFormat.format(endDate)}');
    csv.writeln('');
    csv.writeln('Metric,Value');
    csv.writeln('Total Orders,${data.totalOrders}');
    csv.writeln('Completed Orders,${data.completedOrders}');
    csv.writeln('Cancelled Orders,${data.cancelledOrders}');
    csv.writeln('Completion Rate,${data.completionRate}%');
    csv.writeln('Average Order Value,${data.averageOrderValue} MRU');
    csv.writeln('Total Active Drivers,${data.totalActiveDrivers}');
    csv.writeln('New Clients,${data.newClients}');

    final filename = 'wawapp_overview_report_'
        '${dateFormat.format(startDate)}_to_${dateFormat.format(endDate)}.csv';

    _downloadCsv(csv.toString(), filename);
  }

  /// Export financial report to CSV
  static void exportFinancialReport(FinancialReportData data) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final startDate = DateTime.parse(data.periodStart);
    final endDate = DateTime.parse(data.periodEnd);

    final csv = StringBuffer();
    csv.writeln('WawApp Financial Report');
    csv.writeln('Period: ${dateFormat.format(startDate)} to ${dateFormat.format(endDate)}');
    csv.writeln('');
    csv.writeln('Summary');
    csv.writeln('Metric,Value');
    csv.writeln('Total Orders,${data.summary.totalOrders}');
    csv.writeln('Gross Revenue,${data.summary.grossRevenue} MRU');
    csv.writeln('Total Driver Earnings,${data.summary.totalDriverEarnings} MRU');
    csv.writeln('Platform Commission,${data.summary.totalPlatformCommission} MRU');
    csv.writeln('Average Commission Rate,${data.summary.averageCommissionRate}%');
    csv.writeln('');
    csv.writeln('Daily Breakdown');
    csv.writeln('Date,Orders Count,Gross Revenue (MRU),Driver Earnings (MRU),Platform Commission (MRU)');

    for (final day in data.dailyBreakdown) {
      csv.writeln('${day.date},${day.ordersCount},${day.grossRevenue},'
          '${day.driverEarnings},${day.platformCommission}');
    }

    final filename = 'wawapp_financial_report_'
        '${dateFormat.format(startDate)}_to_${dateFormat.format(endDate)}.csv';

    _downloadCsv(csv.toString(), filename);
  }

  /// Export driver performance report to CSV
  static void exportDriverPerformanceReport(DriverPerformanceReportData data) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final startDate = DateTime.parse(data.periodStart);
    final endDate = DateTime.parse(data.periodEnd);

    final csv = StringBuffer();
    csv.writeln('WawApp Driver Performance Report');
    csv.writeln('Period: ${dateFormat.format(startDate)} to ${dateFormat.format(endDate)}');
    csv.writeln('Total Drivers Analyzed: ${data.totalDrivers}');
    csv.writeln('');
    csv.writeln('Driver ID,Name,Phone,Operator,Total Trips,Completed Trips,'
        'Cancelled Trips,Total Earnings (MRU),Average Rating,Cancellation Rate (%)');

    for (final driver in data.drivers) {
      csv.writeln('${driver.driverId},${_escapeCsv(driver.name)},'
          '${driver.phone},${driver.operator},${driver.totalTrips},'
          '${driver.completedTrips},${driver.cancelledTrips},'
          '${driver.totalEarnings},${driver.averageRating.toStringAsFixed(1)},'
          '${driver.cancellationRate}');
    }

    final filename = 'wawapp_driver_performance_report_'
        '${dateFormat.format(startDate)}_to_${dateFormat.format(endDate)}.csv';

    _downloadCsv(csv.toString(), filename);
  }

  /// Download CSV file
  static void _downloadCsv(String csvContent, String filename) {
    final bytes = utf8.encode(csvContent);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  /// Escape CSV values that contain commas, quotes, or newlines
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
