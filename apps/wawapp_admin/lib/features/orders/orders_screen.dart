import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/status_badge.dart';
import '../../providers/admin_data_providers.dart';
import '../../services/admin_orders_service.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String? _selectedStatusFilter;
  
  final Map<String, String> _statusFilterMap = {
    'الكل': '',
    'قيد التعيين': 'assigning',
    'مقبول': 'accepted',
    'في الطريق': 'on_route',
    'مكتمل': 'completed',
    'ملغى': 'cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(
      ordersStreamProvider(_selectedStatusFilter).stream,
    );

    return AdminScaffold(
      title: 'إدارة الطلبات',
      actions: [
        SizedBox(width: AdminSpacing.md),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Export orders to CSV
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تصدير CSV قريباً')),
            );
          },
          icon: const Icon(Icons.download),
          label: const Text('تصدير'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters
          Row(
            children: [
              Text(
                'تصفية حسب الحالة:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(width: AdminSpacing.md),
              Expanded(
                child: Wrap(
                  spacing: AdminSpacing.sm,
                  runSpacing: AdminSpacing.sm,
                  children: _statusFilterMap.keys.map((label) {
                    final value = _statusFilterMap[label]!;
                    final isSelected = (_selectedStatusFilter ?? '') == value;
                    
                    return FilterChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter = value.isEmpty ? null : value;
                        });
                      },
                      backgroundColor: AdminAppColors.surfaceLight,
                      selectedColor: AdminAppColors.primaryGreen.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AdminAppColors.primaryGreen
                            : AdminAppColors.textPrimaryLight,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          SizedBox(height: AdminSpacing.lg),

          // Orders table with real-time data
          Expanded(
            child: StreamBuilder<List<Order>>(
              stream: ordersAsync,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('خطأ في تحميل الطلبات: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }

                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: AdminAppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد طلبات',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedStatusFilter != null
                              ? 'لا توجد طلبات بهذه الحالة'
                              : 'لا توجد طلبات في النظام',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AdminAppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Orders table
                    Expanded(
                      child: Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                AdminAppColors.backgroundLight,
                              ),
                              columns: [
                                DataColumn(
                                  label: Text(
                                    'رقم الطلب',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'العميل',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'السائق',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'الحالة',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'نقطة الاستلام',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'نقطة التسليم',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'السعر',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'التاريخ',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'الإجراءات',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                              ],
                              rows: orders.map((order) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        order.id.substring(0, 8).toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(order.ownerId.substring(0, 8)),
                                    ),
                                    DataCell(
                                      Text(
                                        order.assignedDriverId != null
                                            ? order.assignedDriverId!.substring(0, 8)
                                            : 'غير معيّن',
                                        style: TextStyle(
                                          color: order.assignedDriverId == null
                                              ? AdminAppColors.textSecondaryLight
                                              : null,
                                        ),
                                      ),
                                    ),
                                    DataCell(_buildStatusBadge(order.status)),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          order.pickupAddress,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          order.dropoffAddress,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${order.price?.toStringAsFixed(0) ?? '0'} MRU',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AdminAppColors.primaryGreen,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatDate(order.createdAt),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility),
                                            onPressed: () {
                                              _showOrderDetails(context, order);
                                            },
                                            tooltip: 'عرض التفاصيل',
                                            color: AdminAppColors.infoLight,
                                          ),
                                          if (order.status != 'completed' &&
                                              order.status != 'cancelled')
                                            IconButton(
                                              icon: const Icon(Icons.cancel),
                                              onPressed: () {
                                                _showCancelDialog(context, order);
                                              },
                                              tooltip: 'إلغاء الطلب',
                                              color: AdminAppColors.errorLight,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: AdminSpacing.md),

                    // Summary
                    Text(
                      'عرض ${orders.length} طلب',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AdminAppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    switch (status) {
      case 'assigning':
        return StatusBadge.pending('قيد التعيين');
      case 'accepted':
        return StatusBadge.active('مقبول');
      case 'on_route':
        return StatusBadge(label: 'في الطريق', color: AdminAppColors.activeBlue);
      case 'completed':
        return StatusBadge.success('مكتمل');
      case 'cancelled':
      case 'cancelled_by_driver':
      case 'cancelled_by_client':
      case 'cancelled_by_admin':
        return StatusBadge.error('ملغى');
      default:
        return StatusBadge(label: status);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final formatter = DateFormat('yyyy-MM-dd HH:mm', 'ar');
    return formatter.format(date);
  }

  void _showOrderDetails(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل الطلب ${order.id.substring(0, 8)}'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('رقم الطلب:', order.id),
                _buildDetailRow('معرف العميل:', order.ownerId),
                _buildDetailRow(
                  'معرف السائق:',
                  order.assignedDriverId ?? 'غير معيّن',
                ),
                _buildDetailRow('الحالة:', order.status),
                _buildDetailRow('نقطة الاستلام:', order.pickupAddress),
                _buildDetailRow('نقطة التسليم:', order.dropoffAddress),
                _buildDetailRow(
                  'المسافة:',
                  order.distanceKm != null
                      ? '${order.distanceKm!.toStringAsFixed(1)} كم'
                      : '-',
                ),
                _buildDetailRow(
                  'السعر:',
                  order.price != null
                      ? '${order.price!.toStringAsFixed(0)} MRU'
                      : '-',
                ),
                _buildDetailRow('وقت الإنشاء:', _formatDate(order.createdAt)),
                if (order.updatedAt != null)
                  _buildDetailRow('آخر تحديث:', _formatDate(order.updatedAt)),
                if (order.completedAt != null)
                  _buildDetailRow('وقت الاكتمال:', _formatDate(order.completedAt)),
              ],
            ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AdminSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AdminAppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, Order order) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت متأكد من إلغاء الطلب ${order.id.substring(0, 8)}؟'),
            SizedBox(height: AdminSpacing.md),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جارٍ إلغاء الطلب...')),
              );

              // Cancel order
              final service = ref.read(adminOrdersServiceProvider);
              final success = await service.cancelOrder(
                order.id,
                reason: reasonController.text.isNotEmpty
                    ? reasonController.text
                    : null,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'تم إلغاء الطلب ${order.id.substring(0, 8)}'
                          : 'فشل إلغاء الطلب',
                    ),
                    backgroundColor: success
                        ? AdminAppColors.successLight
                        : AdminAppColors.errorLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminAppColors.errorLight,
            ),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
  }
}
