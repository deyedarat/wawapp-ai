import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/status_badge.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  // Dummy data for demonstration
  List<Map<String, dynamic>> get _clients => [
    {
      'id': 'CLT-001',
      'name': 'أحمد ولد محمد',
      'phone': '+222 22 11 22 33',
      'operator': 'موريتل',
      'totalOrders': 15,
      'lastOrder': 'منذ ساعتين',
      'verified': true,
    },
    {
      'id': 'CLT-002',
      'name': 'فاطمة منت علي',
      'phone': '+222 33 44 55 66',
      'operator': 'شنقيتل',
      'totalOrders': 8,
      'lastOrder': 'أمس',
      'verified': true,
    },
    {
      'id': 'CLT-003',
      'name': 'محمد ولد سيدي',
      'phone': '+222 44 55 66 77',
      'operator': 'ماتل',
      'totalOrders': 23,
      'lastOrder': 'منذ 3 أيام',
      'verified': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'إدارة العملاء',
      actions: [
        SizedBox(width: AdminSpacing.md),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Export clients
          },
          icon: const Icon(Icons.download),
          label: const Text('تصدير'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(AdminSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              color: AdminAppColors.activeBlue,
                              size: 24,
                            ),
                            SizedBox(width: AdminSpacing.sm),
                            Text(
                              'إجمالي العملاء',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        SizedBox(height: AdminSpacing.sm),
                        Text(
                          '${_clients.length}',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: AdminAppColors.activeBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: AdminSpacing.md),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(AdminSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified,
                              color: AdminAppColors.successLight,
                              size: 24,
                            ),
                            SizedBox(width: AdminSpacing.sm),
                            Text(
                              'عملاء موثقون',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        SizedBox(height: AdminSpacing.sm),
                        Text(
                          '${_clients.where((c) => c['verified']).length}',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: AdminAppColors.successLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: AdminSpacing.lg),

          // Clients table
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
                      'الرقم',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'الاسم',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'الهاتف',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'المشغل',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'عدد الطلبات',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'آخر طلب',
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
                      'الإجراءات',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
                rows: _clients.map((client) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          client['id'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(client['name'])),
                      DataCell(Text(client['phone'])),
                      DataCell(
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AdminSpacing.sm,
                            vertical: AdminSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: _getOperatorColor(client['operator']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
                          ),
                          child: Text(
                            client['operator'],
                            style: TextStyle(
                              color: _getOperatorColor(client['operator']),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          client['totalOrders'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(client['lastOrder'])),
                      DataCell(
                        client['verified']
                            ? StatusBadge.success('موثق')
                            : StatusBadge(
                                label: 'غير موثق',
                                color: AdminAppColors.warningLight,
                              ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility),
                              onPressed: () {
                                _showClientDetails(context, client);
                              },
                              tooltip: 'عرض التفاصيل',
                              color: AdminAppColors.infoLight,
                            ),
                            IconButton(
                              icon: Icon(
                                client['verified'] ? Icons.verified : Icons.verified_user,
                              ),
                              onPressed: () {
                                _toggleVerification(context, client['name']);
                              },
                              tooltip: client['verified'] ? 'إلغاء التوثيق' : 'توثيق',
                              color: AdminAppColors.successLight,
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
            'عرض ${_clients.length} عميل',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AdminAppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Color _getOperatorColor(String operator) {
    switch (operator) {
      case 'موريتل':
        return AdminAppColors.primaryGreen;
      case 'شنقيتل':
        return AdminAppColors.activeBlue;
      case 'ماتل':
        return AdminAppColors.accentRed;
      default:
        return AdminAppColors.textSecondaryLight;
    }
  }

  void _showClientDetails(BuildContext context, Map<String, dynamic> client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل العميل ${client['name']}'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('الرقم:', client['id']),
              _buildDetailRow('الهاتف:', client['phone']),
              _buildDetailRow('المشغل:', client['operator']),
              _buildDetailRow('عدد الطلبات:', client['totalOrders'].toString()),
              _buildDetailRow('آخر طلب:', client['lastOrder']),
              _buildDetailRow('الحالة:', client['verified'] ? 'موثق' : 'غير موثق'),
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

  void _toggleVerification(BuildContext context, String clientName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تبديل حالة توثيق العميل $clientName'),
        backgroundColor: AdminAppColors.successLight,
      ),
    );
  }
}
