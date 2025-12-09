/**
 * Live Operations Screen
 * Real-time command center for monitoring drivers and orders
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import 'models/live_driver_marker.dart';
import 'models/live_order_marker.dart';
import 'providers/live_ops_providers.dart';
import 'widgets/live_map.dart';
import 'widgets/filter_panel.dart';

class LiveOpsScreen extends ConsumerStatefulWidget {
  const LiveOpsScreen({super.key});

  @override
  ConsumerState<LiveOpsScreen> createState() => _LiveOpsScreenState();
}

class _LiveOpsScreenState extends ConsumerState<LiveOpsScreen> {
  LiveDriverMarker? _selectedDriver;
  LiveOrderMarker? _selectedOrder;
  bool _showFilterPanel = true;

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(liveDriversStreamProvider);
    final ordersAsync = ref.watch(liveOrdersStreamProvider);
    final stats = ref.watch(liveOpsStatsProvider);
    final anomalousOrders = ref.watch(anomalousOrdersProvider);

    return AdminScaffold(
      title: 'المراقبة الحية',
      actions: [
        // Refresh indicator
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AdminSpacing.md),
          child: Row(
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: AdminAppColors.successLight,
              ),
              SizedBox(width: AdminSpacing.xs),
              Text(
                'مباشر',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AdminAppColors.successLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: AdminSpacing.sm),
              Text(
                _formatTime(DateTime.now()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AdminAppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        
        // Toggle filter panel
        IconButton(
          icon: Icon(_showFilterPanel ? Icons.close_fullscreen : Icons.filter_list),
          onPressed: () {
            setState(() {
              _showFilterPanel = !_showFilterPanel;
            });
          },
          tooltip: _showFilterPanel ? 'إخفاء الفلاتر' : 'عرض الفلاتر',
        ),
      ],
      child: Row(
        children: [
          // Filter Panel (collapsible)
          if (_showFilterPanel) const FilterPanel(),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Statistics Bar
                _buildStatsBar(context, stats),

                // Anomalous Orders Alert
                if (anomalousOrders.isNotEmpty)
                  _buildAnomalyAlert(context, anomalousOrders),

                // Map
                Expanded(
                  child: driversAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text('خطأ في تحميل البيانات: $error'),
                        ],
                      ),
                    ),
                    data: (drivers) {
                      return ordersAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (error, stack) => Center(
                          child: Text('خطأ في تحميل الطلبات: $error'),
                        ),
                        data: (orders) {
                          if (drivers.isEmpty && orders.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 64,
                                    color: AdminAppColors.textSecondaryLight,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'لا توجد بيانات للعرض',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'لا يوجد سائقون أو طلبات نشطة حالياً',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AdminAppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Stack(
                            children: [
                              LiveMap(
                                drivers: drivers,
                                orders: orders,
                                onDriverTap: (driver) {
                                  setState(() {
                                    _selectedDriver = driver;
                                    _selectedOrder = null;
                                  });
                                },
                                onOrderTap: (order) {
                                  setState(() {
                                    _selectedOrder = order;
                                    _selectedDriver = null;
                                  });
                                },
                              ),

                              // Info panel (overlay)
                              if (_selectedDriver != null || _selectedOrder != null)
                                Positioned(
                                  bottom: 16,
                                  left: 16,
                                  right: 16,
                                  child: _buildInfoPanel(context),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(BuildContext context, LiveOpsStats stats) {
    return Container(
      padding: EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminAppColors.backgroundLight,
        border: Border(
          bottom: BorderSide(
            color: AdminAppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context,
              icon: Icons.drive_eta,
              label: 'سائقون متصلون',
              value: '${stats.totalOnlineDrivers}',
              color: AdminAppColors.onlineGreen,
            ),
          ),
          SizedBox(width: AdminSpacing.md),
          Expanded(
            child: _buildStatCard(
              context,
              icon: Icons.local_shipping,
              label: 'طلبات نشطة',
              value: '${stats.totalActiveOrders}',
              color: AdminAppColors.activeBlue,
            ),
          ),
          SizedBox(width: AdminSpacing.md),
          Expanded(
            child: _buildStatCard(
              context,
              icon: Icons.pending,
              label: 'قيد التعيين',
              value: '${stats.unassignedOrders}',
              color: AdminAppColors.goldenYellow,
            ),
          ),
          SizedBox(width: AdminSpacing.md),
          Expanded(
            child: _buildStatCard(
              context,
              icon: Icons.warning,
              label: 'حالات شاذة',
              value: '${stats.anomalousOrders}',
              color: AdminAppColors.errorLight,
            ),
          ),
          if (stats.averageAssignmentTimeMinutes != null) ...[
            SizedBox(width: AdminSpacing.md),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.timer,
                label: 'متوسط وقت التعيين',
                value: '${stats.averageAssignmentTimeMinutes!.toStringAsFixed(1)} د',
                color: AdminAppColors.infoLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AdminSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: AdminSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AdminAppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomalyAlert(BuildContext context, List<LiveOrderMarker> anomalousOrders) {
    return Container(
      margin: EdgeInsets.all(AdminSpacing.md),
      padding: EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminAppColors.errorLight.withOpacity(0.1),
        border: Border.all(color: AdminAppColors.errorLight),
        borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber,
            color: AdminAppColors.errorLight,
            size: 24,
          ),
          SizedBox(width: AdminSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيه: طلبات عالقة',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AdminAppColors.errorLight,
                  ),
                ),
                Text(
                  '${anomalousOrders.length} طلب عالق في حالة "قيد التعيين" لأكثر من 10 دقائق',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // Show details dialog
              _showAnomaliesDialog(context, anomalousOrders);
            },
            child: const Text('عرض التفاصيل'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    return Card(
      elevation: 8,
      child: Container(
        padding: EdgeInsets.all(AdminSpacing.md),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDriver != null ? 'معلومات السائق' : 'معلومات الطلب',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedDriver = null;
                      _selectedOrder = null;
                    });
                  },
                  iconSize: 20,
                ),
              ],
            ),
            Divider(height: AdminSpacing.md),
            if (_selectedDriver != null)
              _buildDriverInfo(context, _selectedDriver!)
            else if (_selectedOrder != null)
              _buildOrderInfo(context, _selectedOrder!),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfo(BuildContext context, LiveDriverMarker driver) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('الاسم:', driver.name),
        _buildInfoRow('الهاتف:', driver.phone),
        _buildInfoRow('المشغل:', driver.operatorLabel),
        _buildInfoRow('الحالة:', driver.statusLabel),
        _buildInfoRow('التقييم:', '${driver.rating?.toStringAsFixed(1) ?? '-'} ⭐'),
        _buildInfoRow('إجمالي الرحلات:', '${driver.totalTrips}'),
        if (driver.activeOrderId != null)
          _buildInfoRow('طلب نشط:', driver.activeOrderId!.substring(0, 8)),
      ],
    );
  }

  Widget _buildOrderInfo(BuildContext context, LiveOrderMarker order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('رقم الطلب:', order.orderId.substring(0, 8)),
        _buildInfoRow('الحالة:', order.statusLabel),
        _buildInfoRow('من:', order.pickupAddress),
        _buildInfoRow('إلى:', order.dropoffAddress),
        if (order.price != null)
          _buildInfoRow('السعر:', '${order.price!.toStringAsFixed(0)} MRU'),
        if (order.distanceKm != null)
          _buildInfoRow('المسافة:', '${order.distanceKm!.toStringAsFixed(1)} كم'),
        _buildInfoRow('العمر:', '${order.ageMinutes} دقيقة'),
        if (order.isAnomalous())
          Container(
            margin: EdgeInsets.only(top: AdminSpacing.sm),
            padding: EdgeInsets.all(AdminSpacing.sm),
            decoration: BoxDecoration(
              color: AdminAppColors.errorLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning,
                  size: 16,
                  color: AdminAppColors.errorLight,
                ),
                SizedBox(width: AdminSpacing.xs),
                Expanded(
                  child: Text(
                    'تحذير: عالق لأكثر من 10 دقائق',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AdminAppColors.errorLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AdminSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AdminAppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showAnomaliesDialog(BuildContext context, List<LiveOrderMarker> anomalies) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلبات عالقة (حالات شاذة)'),
        content: SizedBox(
          width: 500,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: anomalies.length,
            separatorBuilder: (context, index) => Divider(height: AdminSpacing.md),
            itemBuilder: (context, index) {
              final order = anomalies[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'طلب ${order.orderId.substring(0, 8)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('من: ${order.pickupAddress}'),
                  Text('إلى: ${order.dropoffAddress}'),
                  Text(
                    'عالق منذ: ${order.ageMinutes} دقيقة',
                    style: TextStyle(color: AdminAppColors.errorLight),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm:ss', 'ar').format(time);
  }
}
