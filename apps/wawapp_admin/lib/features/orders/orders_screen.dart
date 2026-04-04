import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/status_badge.dart';
import '../../providers/admin_data_providers.dart';
import '../../services/admin_drivers_service.dart';
import '../../services/admin_clients_service.dart';
import 'create_order_screen.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String? _selectedStatusFilter;
  String _searchQuery = '';
  final ScrollController _tableHorizontalController = ScrollController();

  @override
  void dispose() {
    _tableHorizontalController.dispose();
    super.dispose();
  }

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
      onSearchChanged: (query) {
        setState(() {
          _searchQuery = query;
        });
      },
      actions: [
        const SizedBox(width: AdminSpacing.md),
        ElevatedButton.icon(
          onPressed: () {
            debugPrint('Add Order button pressed');
            _showAddOrderDialog(context);
          },
          icon: const Icon(Icons.add),
          label: const Text('إضافة طلب'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminAppColors.primaryGreen,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: AdminSpacing.md),
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
              const SizedBox(width: AdminSpacing.md),
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
                        color: isSelected ? AdminAppColors.primaryGreen : AdminAppColors.textPrimaryLight,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: AdminSpacing.lg),

          // Orders table with real-time data
          SizedBox(
            height: ResponsiveHelper.getTableHeight(context),
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

                // Filter orders by search query
                final filteredOrders = _searchQuery.isEmpty
                    ? orders
                    : orders.where((order) {
                        final q = _searchQuery.toLowerCase();
                        return (order.id ?? '').toLowerCase().contains(q) ||
                            (order.ownerId ?? '').toLowerCase().contains(q) ||
                            order.pickupAddress.toLowerCase().contains(q) ||
                            order.dropoffAddress.toLowerCase().contains(q) ||
                            order.pickup.label.toLowerCase().contains(q) ||
                            order.dropoff.label.toLowerCase().contains(q) ||
                            (order.status ?? '').toLowerCase().contains(q);
                      }).toList();

                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: AdminAppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد طلبات',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddOrderDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('إضافة أول طلب'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedStatusFilter != null ? 'لا توجد طلبات بهذه الحالة' : 'لا توجد طلبات في النظام',
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
                        child: Scrollbar(
                          controller: _tableHorizontalController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _tableHorizontalController,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1400),
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
                              rows: filteredOrders.map((order) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        (order.id ?? 'N/A').substring(0, 8).toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      InkWell(
                                        onTap: order.ownerId != null
                                            ? () => _showClientQuickInfo(context, order.ownerId!)
                                            : null,
                                        child: Text(
                                          (order.ownerId ?? 'N/A').substring(0, 8),
                                          style: const TextStyle(
                                            decoration: TextDecoration.underline,
                                            color: AdminAppColors.activeBlue,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      order.assignedDriverId != null
                                          ? InkWell(
                                              onTap: () => _showDriverQuickInfo(context, order.assignedDriverId!),
                                              child: Text(
                                                order.assignedDriverId!.substring(0, 8),
                                                style: const TextStyle(
                                                  decoration: TextDecoration.underline,
                                                  color: AdminAppColors.activeBlue,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            )
                                          : const Text(
                                              'غير معيّن',
                                              style: TextStyle(color: AdminAppColors.textSecondaryLight),
                                            ),
                                    ),
                                    DataCell(_buildStatusBadge(order.status ?? 'unknown')),
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
                                        '${order.price.toStringAsFixed(0)} MRU',
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
                                          if (order.status != 'completed' && order.status != 'cancelled')
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
                    ),

                    const SizedBox(height: AdminSpacing.md),

                    // Summary
                    Text(
                      'عرض ${filteredOrders.length} من ${orders.length} طلب',
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
        return const StatusBadge(label: 'في الطريق', color: AdminAppColors.activeBlue);
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
    final formatter = DateFormat('yyyy-MM-dd HH:mm', 'en');
    return formatter.format(date);
  }

  void _showOrderDetails(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل الطلب ${(order.id ?? 'N/A').substring(0, 8)}'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('رقم الطلب:', order.id ?? 'N/A'),
                _buildDetailRow('معرف العميل:', order.ownerId ?? 'N/A'),
                _buildDetailRow(
                  'معرف السائق:',
                  order.assignedDriverId ?? 'غير معيّن',
                ),
                _buildDetailRow('الحالة:', order.status ?? 'غير معروف'),
                _buildDetailRow('نقطة الاستلام:', order.pickupAddress),
                _buildDetailRow('نقطة التسليم:', order.dropoffAddress),
                _buildDetailRow(
                  'المسافة:',
                  '${order.distanceKm.toStringAsFixed(1)} كم',
                ),
                _buildDetailRow(
                  'السعر:',
                  '${order.price.toStringAsFixed(0)} MRU',
                ),
                _buildDetailRow('وقت الإنشاء:', _formatDate(order.createdAt)),
                if (order.updatedAt != null) _buildDetailRow('آخر تحديث:', _formatDate(order.updatedAt)),
                if (order.completedAt != null) _buildDetailRow('وقت الاكتمال:', _formatDate(order.completedAt)),
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
      padding: const EdgeInsets.symmetric(vertical: AdminSpacing.xs),
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
            const Text('هل أنت متأكد من إلغاء هذا الطلب؟ لا يمكن التراجع عن هذا الإجراء.'),
            const SizedBox(height: AdminSpacing.md),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('رجوع'),
          ),
          ElevatedButton(
            onPressed: () async {
              final service = ref.read(adminOrdersServiceProvider);
              final success = await service.cancelOrder(
                order.id!,
                reason: reasonController.text,
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'تم إلغاء الطلب بنجاح' : 'فشل إلغاء الطلب'),
                    backgroundColor: success ? AdminAppColors.successLight : AdminAppColors.errorLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminAppColors.errorLight,
              foregroundColor: Colors.white,
            ),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );
  }

  void _showAddOrderDialog(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateOrderScreen(),
      ),
    );

    // Refresh the list if order was created
    if (result == true && mounted) {
      setState(() {});
    }
  }

  void _showDriverQuickInfo(BuildContext context, String driverId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معلومات السائق'),
        content: FutureBuilder(
          future: AdminDriversService().getDriverById(driverId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final driver = snapshot.data;
            if (driver == null) {
              return const Text('تعذّر تحميل بيانات السائق');
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('الاسم:', driver.name),
                _buildDetailRow('الهاتف:', driver.phone),
                _buildDetailRow('رقم اللوحة:', driver.vehiclePlate ?? '-'),
                _buildDetailRow('نوع السيارة:', driver.vehicleType ?? '-'),
              ],
            );
          },
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

  void _showClientQuickInfo(BuildContext context, String clientId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معلومات العميل'),
        content: FutureBuilder(
          future: AdminClientsService().getClientById(clientId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final client = snapshot.data;
            if (client == null) {
              return const Text('تعذّر تحميل بيانات العميل');
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('الاسم:', client.name),
                _buildDetailRow('الهاتف:', client.phone),
              ],
            );
          },
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
}
