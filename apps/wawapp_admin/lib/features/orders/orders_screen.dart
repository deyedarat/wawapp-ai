import 'package:flutter/material.dart';
import 'package:core_shared/core_shared.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/status_badge.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _selectedStatus = 'الكل';
  final List<String> _statusFilters = [
    'الكل',
    'قيد التعيين',
    'مقبول',
    'في الطريق',
    'مكتمل',
    'ملغى'
  ];

  // Dummy data for demonstration
  List<Map<String, dynamic>> get _orders => [
    {
      'id': 'ORD-12345',
      'client': 'أحمد ولد محمد',
      'driver': 'عبدالله ولد أحمد',
      'status': 'في الطريق',
      'pickup': 'نواكشوط - كرفور',
      'dropoff': 'نواكشوط - تفرغ زينه',
      'price': '500 MRU',
      'createdAt': 'منذ 15 دقيقة',
    },
    {
      'id': 'ORD-12344',
      'client': 'فاطمة منت علي',
      'driver': 'محمد ولد سيدي',
      'status': 'مقبول',
      'pickup': 'نواكشوط - تفرغ زينه',
      'dropoff': 'نواكشوط - عرفات',
      'price': '450 MRU',
      'createdAt': 'منذ 30 دقيقة',
    },
    {
      'id': 'ORD-12343',
      'client': 'علي ولد محمود',
      'driver': 'غير معيّن',
      'status': 'قيد التعيين',
      'pickup': 'نواكشوط - السوق الكبير',
      'dropoff': 'نواكشوط - الميناء',
      'price': '800 MRU',
      'createdAt': 'منذ ساعة',
    },
    {
      'id': 'ORD-12342',
      'client': 'مريم منت أحمد',
      'driver': 'حسن ولد عمر',
      'status': 'مكتمل',
      'pickup': 'نواكشوط - المطار',
      'dropoff': 'نواكشوط - الرئاسة',
      'price': '1200 MRU',
      'createdAt': 'منذ ساعتين',
    },
  ];

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedStatus == 'الكل') return _orders;
    return _orders.where((order) => order['status'] == _selectedStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'إدارة الطلبات',
      actions: [
        SizedBox(width: AdminSpacing.md),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Export orders
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
                  children: _statusFilters.map((status) {
                    final isSelected = _selectedStatus == status;
                    return FilterChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatus = status;
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

          // Orders table
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                      'الإجراءات',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
                rows: _filteredOrders.map((order) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          order['id'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(order['client'])),
                      DataCell(Text(order['driver'])),
                      DataCell(_buildStatusBadge(order['status'])),
                      DataCell(
                        Text(
                          order['pickup'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        Text(
                          order['dropoff'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        Text(
                          order['price'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AdminAppColors.primaryGreen,
                          ),
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
                            IconButton(
                              icon: const Icon(Icons.cancel),
                              onPressed: () {
                                _showCancelDialog(context, order['id']);
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

          SizedBox(height: AdminSpacing.md),

          // Summary
          Text(
            'عرض ${_filteredOrders.length} من أصل ${_orders.length} طلب',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AdminAppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    switch (status) {
      case 'قيد التعيين':
        return StatusBadge.pending(status);
      case 'مقبول':
        return StatusBadge.active(status);
      case 'في الطريق':
        return StatusBadge(label: status, color: AdminAppColors.activeBlue);
      case 'مكتمل':
        return StatusBadge.success(status);
      case 'ملغى':
        return StatusBadge.error(status);
      default:
        return StatusBadge(label: status);
    }
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل الطلب ${order['id']}'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('العميل:', order['client']),
              _buildDetailRow('السائق:', order['driver']),
              _buildDetailRow('الحالة:', order['status']),
              _buildDetailRow('نقطة الاستلام:', order['pickup']),
              _buildDetailRow('نقطة التسليم:', order['dropoff']),
              _buildDetailRow('السعر:', order['price']),
              _buildDetailRow('وقت الإنشاء:', order['createdAt']),
            ],
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
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: Text('هل أنت متأكد من إلغاء الطلب $orderId؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Cancel order
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم إلغاء الطلب $orderId'),
                  backgroundColor: AdminAppColors.successLight,
                ),
              );
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
