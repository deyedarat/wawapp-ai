import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../providers/finance_providers.dart';
import '../models/wallet_models.dart';

class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final payoutsAsync = _statusFilter == 'all'
        ? ref.watch(payoutsProvider)
        : ref.watch(payoutsByStatusProvider(_statusFilter));

    return AdminScaffold(
      title: 'إدارة الدفعات',
      body: Column(
        children: [
          // Filter bar
          _buildFilterBar(),

          // Payouts table
          Expanded(
            child: payoutsAsync.when(
              data: (payouts) => _buildPayoutsTable(payouts),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('خطأ: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreatePayoutDialog,
        backgroundColor: AdminAppColors.primaryGreen,
        label: const Text('طلب دفعة جديدة'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: AdminAppColors.borderLight)),
      ),
      child: Wrap(
        spacing: AdminSpacing.sm,
        children: [
          _buildFilterChip('الكل', 'all'),
          _buildFilterChip('قيد الانتظار', 'requested'),
          _buildFilterChip('معتمد', 'approved'),
          _buildFilterChip('قيد المعالجة', 'processing'),
          _buildFilterChip('مكتمل', 'completed'),
          _buildFilterChip('مرفوض', 'rejected'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String status) {
    final isSelected = _statusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _statusFilter = status);
      },
      backgroundColor: AdminAppColors.backgroundLight,
      selectedColor: AdminAppColors.primaryGreen,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AdminAppColors.textPrimaryLight,
      ),
    );
  }

  Widget _buildPayoutsTable(List<PayoutModel> payouts) {
    if (payouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: AdminAppColors.textSecondaryLight),
            SizedBox(height: AdminSpacing.md),
            const Text('لا توجد دفعات'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Container(
        margin: EdgeInsets.all(AdminSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
          border: Border.all(color: AdminAppColors.borderLight),
        ),
        child: DataTable(
          headingRowColor:
              MaterialStateProperty.all(AdminAppColors.backgroundLight),
          columns: const [
            DataColumn(label: Text('التاريخ')),
            DataColumn(label: Text('معرف السائق')),
            DataColumn(label: Text('المبلغ')),
            DataColumn(label: Text('الطريقة')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('الإجراءات')),
          ],
          rows: payouts.map((payout) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    payout.createdAt != null
                        ? DateFormat('dd/MM/yyyy').format(payout.createdAt!)
                        : '-',
                  ),
                ),
                DataCell(Text(payout.driverId)),
                DataCell(
                  Text(
                    '${_formatCurrency(payout.amount)} MRU',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(Text(_getMethodLabel(payout.method))),
                DataCell(_buildStatusBadge(payout.status)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: () => _showPayoutDetails(payout),
                        tooltip: 'عرض',
                      ),
                      if (payout.status == 'requested' || payout.status == 'approved')
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) =>
                              _updatePayoutStatus(payout.id, value),
                          itemBuilder: (context) => [
                            if (payout.status == 'requested')
                              const PopupMenuItem(
                                value: 'approved',
                                child: Text('اعتماد'),
                              ),
                            const PopupMenuItem(
                              value: 'completed',
                              child: Text('إتمام'),
                            ),
                            const PopupMenuItem(
                              value: 'rejected',
                              child: Text('رفض'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'requested':
        color = Colors.orange;
        label = 'قيد الانتظار';
        break;
      case 'approved':
        color = Colors.blue;
        label = 'معتمد';
        break;
      case 'processing':
        color = Colors.purple;
        label = 'قيد المعالجة';
        break;
      case 'completed':
        color = Colors.green;
        label = 'مكتمل';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'مرفوض';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AdminSpacing.sm,
        vertical: AdminSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showPayoutDetails(PayoutModel payout) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفاصيل الدفعة'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('معرف الدفعة', payout.id),
              _buildDetailRow('معرف السائق', payout.driverId),
              _buildDetailRow('المبلغ', '${_formatCurrency(payout.amount)} MRU'),
              _buildDetailRow('الطريقة', _getMethodLabel(payout.method)),
              _buildDetailRow('الحالة', payout.status),
              if (payout.note != null) _buildDetailRow('ملاحظة', payout.note!),
              if (payout.rejectionReason != null)
                _buildDetailRow('سبب الرفض', payout.rejectionReason!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AdminSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showCreatePayoutDialog() {
    final driverIdController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String selectedMethod = 'bank_transfer';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلب دفعة جديدة'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: driverIdController,
                decoration: const InputDecoration(
                  labelText: 'معرف السائق',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: AdminSpacing.md),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'المبلغ (MRU)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: AdminSpacing.md),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                decoration: const InputDecoration(
                  labelText: 'طريقة الدفع',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'bank_transfer', child: Text('تحويل بنكي')),
                  DropdownMenuItem(value: 'manual', child: Text('يدوي')),
                  DropdownMenuItem(value: 'mobile_money', child: Text('محفظة إلكترونية')),
                ],
                onChanged: (value) {
                  if (value != null) selectedMethod = value;
                },
              ),
              SizedBox(height: AdminSpacing.md),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final driverId = driverIdController.text.trim();
              final amount = int.tryParse(amountController.text.trim());
              final note = noteController.text.trim();

              if (driverId.isEmpty || amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى ملء جميع الحقول بشكل صحيح')),
                );
                return;
              }

              try {
                await ref.read(payoutServiceProvider).createPayoutRequest(
                      driverId: driverId,
                      amount: amount,
                      method: selectedMethod,
                      note: note.isNotEmpty ? note : null,
                    );

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إنشاء طلب الدفعة بنجاح')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e')),
                  );
                }
              }
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePayoutStatus(String payoutId, String newStatus) async {
    try {
      await ref
          .read(payoutServiceProvider)
          .updatePayoutStatus(payoutId: payoutId, newStatus: newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث حالة الدفعة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,###');
    return formatter.format(amount);
  }

  String _getMethodLabel(String method) {
    switch (method) {
      case 'bank_transfer':
        return 'تحويل بنكي';
      case 'manual':
        return 'يدوي';
      case 'mobile_money':
        return 'محفظة إلكترونية';
      case 'wise':
        return 'Wise';
      case 'stripe':
        return 'Stripe';
      default:
        return method;
    }
  }
}
