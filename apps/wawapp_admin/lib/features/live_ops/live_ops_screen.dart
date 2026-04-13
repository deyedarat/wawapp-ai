/**
 * Live Operations Screen – IMPROVED
  *
   * Key fix: The map is ALWAYS rendered even while Firebase data is loading
    * or has an error. Loading and error states are shown as lightweight overlays
     * on top of the map, not as replacement widgets.
      *
       * Additional improvements:
        *  - Firebase errors no longer block the map from rendering.
         *  - A "refresh" action forces stream re-subscription.
          *  - Error banner is non-blocking and dismissible.
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

  final _clockTicker = Stream.periodic(const Duration(seconds: 1));

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(liveDriversStreamProvider);
    final ordersAsync = ref.watch(liveOrdersStreamProvider);
    final stats = ref.watch(liveOpsStatsProvider);
    final anomalousOrders = ref.watch(anomalousOrdersProvider);

    // Always resolve to a list – empty when loading or error
    final drivers = driversAsync.maybeWhen(
      data: (data) => data,
      orElse: () => <LiveDriverMarker>[],
    );
    final orders = ordersAsync.maybeWhen(
      data: (data) => data,
      orElse: () => <LiveOrderMarker>[],
    );

    final isLoading = driversAsync.isLoading || ordersAsync.isLoading;
    final errorMsg = driversAsync.hasError
        ? 'خطأ في تحميل السائقين: ${driversAsync.error}'
        : ordersAsync.hasError
            ? 'خطأ في تحميل الطلبات: ${ordersAsync.error}'
            : null;

    return AdminScaffold(
      title: 'المراقبة الحية',
      actions: [
        // Live clock
        StreamBuilder(
          stream: _clockTicker,
          builder: (context, _) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: AdminSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.circle,
                      size: 8, color: AdminAppColors.successLight),
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
            );
          },
        ),
        // Refresh button
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'تحديث البيانات',
          onPressed: () {
            ref.invalidate(liveDriversStreamProvider);
            ref.invalidate(liveOrdersStreamProvider);
          },
        ),
        // Toggle filter panel
        IconButton(
          icon: Icon(
              _showFilterPanel ? Icons.close_fullscreen : Icons.filter_list),
          onPressed: () => setState(() => _showFilterPanel = !_showFilterPanel),
          tooltip: _showFilterPanel ? 'إخفاء الفلاتر' : 'عرض الفلاتر',
        ),
      ],
      child: Row(
        children: [
          if (_showFilterPanel) const FilterPanel(),
          Expanded(
            child: Column(
              children: [
                _buildStatsBar(context, stats),
                if (anomalousOrders.isNotEmpty)
                  _buildAnomalyAlert(context, anomalousOrders),
                // ── Map is ALWAYS shown ──
                Expanded(
                  child: Stack(
                    children: [
                      LiveMap(
                        drivers: drivers,
                        orders: orders,
                        onDriverTap: (driver) => setState(() {
                          _selectedDriver = driver;
                          _selectedOrder = null;
                        }),
                        onOrderTap: (order) => setState(() {
                          _selectedOrder = order;
                          _selectedDriver = null;
                        }),
                      ),
                      // Loading overlay
                      if (isLoading)
                        Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'جارٍ تحميل البيانات…',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Error banner (non-blocking)
                      if (errorMsg != null)
                        Positioned(
                          bottom: 80,
                          left: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMsg,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh,
                                      color: Colors.white, size: 18),
                                  onPressed: () {
                                    ref.invalidate(liveDriversStreamProvider);
                                    ref.invalidate(liveOrdersStreamProvider);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Selected item info panel
                      if (_selectedDriver != null || _selectedOrder != null)
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: _buildInfoPanel(context),
                        ),
                    ],
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
            bottom: BorderSide(color: AdminAppColors.borderLight, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
              child: _buildStatCard(context,
                  icon: Icons.drive_eta,
                  label: 'سائقون متصلون',
                  value: '${stats.totalOnlineDrivers}',
                  color: AdminAppColors.onlineGreen)),
          SizedBox(width: AdminSpacing.md),
          Expanded(
              child: _buildStatCard(context,
                  icon: Icons.local_shipping,
                  label: 'طلبات نشطة',
                  value: '${stats.totalActiveOrders}',
                  color: AdminAppColors.activeBlue)),
          SizedBox(width: AdminSpacing.md),
          Expanded(
              child: _buildStatCard(context,
                  icon: Icons.pending,
                  label: 'قيد التعيين',
                  value: '${stats.unassignedOrders}',
                  color: AdminAppColors.goldenYellow)),
          SizedBox(width: AdminSpacing.md),
          Expanded(
              child: _buildStatCard(context,
                  icon: Icons.warning,
                  label: 'حالات شاذة',
                  value: '${stats.anomalousOrders}',
                  color: AdminAppColors.errorLight)),
          if (stats.averageAssignmentTimeMinutes != null) ...[
            SizedBox(width: AdminSpacing.md),
            Expanded(
                child: _buildStatCard(context,
                    icon: Icons.timer,
                    label: 'متوسط وقت التعيين',
                    value:
                        '${stats.averageAssignmentTimeMinutes!.toStringAsFixed(1)} د',
                    color: AdminAppColors.infoLight)),
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

  Widget _buildAnomalyAlert(
      BuildContext context, List<LiveOrderMarker> anomalousOrders) {
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
          Icon(Icons.warning_amber, color: AdminAppColors.errorLight, size: 24),
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
            onPressed: () => _showAnomaliesDialog(context, anomalousOrders),
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
                  onPressed: () => setState(() {
                    _selectedDriver = null;
                    _selectedOrder = null;
                  }),
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
        _infoRow('الاسم:', driver.name),
        _infoRow('الهاتف:', driver.phone),
        _infoRow('المشغل:', driver.operatorLabel),
        _infoRow('الحالة:', driver.statusLabel),
        _infoRow('التقييم:', '${driver.rating?.toStringAsFixed(1) ?? '-'} ⭐'),
        _infoRow('إجمالي الرحلات:', '${driver.totalTrips}'),
        if (driver.activeOrderId != null)
          _infoRow('طلب نشط:', driver.activeOrderId!.substring(0, 8)),
      ],
    );
  }

  Widget _buildOrderInfo(BuildContext context, LiveOrderMarker order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow('رقم الطلب:', order.orderId.substring(0, 8)),
        _infoRow('الحالة:', order.statusLabel),
        _infoRow('من:', order.pickupAddress),
        _infoRow('إلى:', order.dropoffAddress),
        if (order.price != null)
          _infoRow('السعر:', '${order.price!.toStringAsFixed(0)} MRU'),
        if (order.distanceKm != null)
          _infoRow('المسافة:', '${order.distanceKm!.toStringAsFixed(1)} كم'),
        _infoRow('العمر:', '${order.ageMinutes} دقيقة'),
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
                Icon(Icons.warning, size: 16, color: AdminAppColors.errorLight),
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

  Widget _infoRow(String label, String value) {
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showAnomaliesDialog(
      BuildContext context, List<LiveOrderMarker> anomalies) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلبات عالقة (حالات شاذة)'),
        content: SizedBox(
          width: 500,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: anomalies.length,
            separatorBuilder: (_, __) => Divider(height: AdminSpacing.md),
            itemBuilder: (context, index) {
              final order = anomalies[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('طلب ${order.orderId.substring(0, 8)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('من: ${order.pickupAddress}'),
                  Text('إلى: ${order.dropoffAddress}'),
                  Text('عالق منذ: ${order.ageMinutes} دقيقة',
                      style: TextStyle(color: AdminAppColors.errorLight)),
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
    return DateFormat('HH:mm:ss', 'en').format(time);
  }
}
