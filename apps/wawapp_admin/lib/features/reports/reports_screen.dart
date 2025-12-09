import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import 'widgets/reports_filter_bar.dart';
import 'widgets/overview_report_tab.dart';
import 'widgets/financial_report_tab.dart';
import 'widgets/driver_performance_report_tab.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'التقارير والتحليلات',
      body: Column(
        children: [
          // Filter bar
          const ReportsFilterBar(),

          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: AdminAppColors.borderLight),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AdminAppColors.primaryGreen,
              unselectedLabelColor: AdminAppColors.textSecondaryLight,
              indicatorColor: AdminAppColors.primaryGreen,
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  icon: Icon(Icons.dashboard),
                  text: 'نظرة عامة',
                ),
                Tab(
                  icon: Icon(Icons.attach_money),
                  text: 'التقرير المالي',
                ),
                Tab(
                  icon: Icon(Icons.drive_eta),
                  text: 'أداء السائقين',
                ),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                OverviewReportTab(),
                FinancialReportTab(),
                DriverPerformanceReportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
