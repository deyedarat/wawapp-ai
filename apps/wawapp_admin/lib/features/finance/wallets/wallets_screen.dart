import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../../providers/finance_providers.dart';
import '../models/wallet_models.dart';

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  String _searchQuery = '';
  String? _selectedWalletId;

  @override
  Widget build(BuildContext context) {
    final driverWalletsAsync = ref.watch(driverWalletsProvider);
    final platformWalletAsync = ref.watch(platformWalletProvider);

    return AdminScaffold(
      title: 'الأرصدة والمحافظ',
      body: Column(
        children: [
          // Search and filters
          _buildSearchBar(),

          // Platform wallet summary
          platformWalletAsync.when(
            data: (wallet) => wallet != null
                ? _buildPlatformWalletCard(wallet)
                : const SizedBox.shrink(),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Driver wallets table
          Expanded(
            child: driverWalletsAsync.when(
              data: (wallets) => _buildWalletsTable(
                wallets.where((w) {
                  if (_searchQuery.isEmpty) return true;
                  // Filter would need driver data join
                  return true;
                }).toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('خطأ: ${error.toString()}'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: AdminAppColors.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث عن سائق...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AdminSpacing.md,
                  vertical: AdminSpacing.sm,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformWalletCard(WalletModel wallet) {
    return Container(
      margin: EdgeInsets.all(AdminSpacing.md),
      padding: EdgeInsets.all(AdminSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AdminAppColors.primaryGreen, AdminAppColors.accentBlue],
        ),
        borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet,
              size: 48, color: Colors.white),
          SizedBox(width: AdminSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رصيد المنصة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: AdminSpacing.xs),
                Text(
                  '${_formatCurrency(wallet.balance)} MRU',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'إجمالي الإيرادات',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              Text(
                '${_formatCurrency(wallet.totalCredited)} MRU',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletsTable(List<WalletModel> wallets) {
    if (wallets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wallet, size: 64, color: AdminAppColors.textSecondaryLight),
            SizedBox(height: AdminSpacing.md),
            const Text('لا توجد محافظ'),
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
            DataColumn(label: Text('معرف السائق')),
            DataColumn(label: Text('الرصيد المتاح')),
            DataColumn(label: Text('معلق')),
            DataColumn(label: Text('إجمالي الأرباح')),
            DataColumn(label: Text('إجمالي المسحوبات')),
            DataColumn(label: Text('الإجراءات')),
          ],
          rows: wallets.map((wallet) {
            return DataRow(
              cells: [
                DataCell(Text(wallet.ownerId ?? wallet.id)),
                DataCell(
                  Text(
                    '${_formatCurrency(wallet.availableBalance)} MRU',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                DataCell(
                  wallet.pendingPayout > 0
                      ? Text(
                          '${_formatCurrency(wallet.pendingPayout)} MRU',
                          style: const TextStyle(color: Colors.orange),
                        )
                      : const Text('-'),
                ),
                DataCell(Text('${_formatCurrency(wallet.totalCredited)} MRU')),
                DataCell(Text('${_formatCurrency(wallet.totalDebited)} MRU')),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: () => _showWalletDetails(wallet),
                    tooltip: 'عرض التفاصيل',
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showWalletDetails(WalletModel wallet) {
    setState(() => _selectedWalletId = wallet.id);

    showDialog(
      context: context,
      builder: (context) => _WalletDetailsDialog(walletId: wallet.id),
    );
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,###');
    return formatter.format(amount);
  }
}

class _WalletDetailsDialog extends ConsumerWidget {
  final String walletId;

  const _WalletDetailsDialog({required this.walletId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(walletTransactionsProvider(walletId));

    return Dialog(
      child: Container(
        width: 800,
        padding: EdgeInsets.all(AdminSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AdminAppColors.primaryGreen),
                SizedBox(width: AdminSpacing.sm),
                Text(
                  'سجل المعاملات',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: AdminSpacing.md),
            Expanded(
              child: transactionsAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return const Center(child: Text('لا توجد معاملات'));
                  }
                  return ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final txn = transactions[index];
                      return _buildTransactionTile(txn);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('خطأ: $error')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(TransactionModel txn) {
    final isCredit = txn.type == 'credit';
    final formatter = NumberFormat('#,###');

    return ListTile(
      leading: Icon(
        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
        color: isCredit ? Colors.green : Colors.red,
      ),
      title: Text(txn.note ?? _getSourceLabel(txn.source)),
      subtitle: Text(
        txn.createdAt != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(txn.createdAt!)
            : '-',
      ),
      trailing: Text(
        '${isCredit ? '+' : '-'}${formatter.format(txn.amount)} MRU',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isCredit ? Colors.green : Colors.red,
          fontSize: 16,
        ),
      ),
    );
  }

  String _getSourceLabel(String source) {
    switch (source) {
      case 'order_settlement':
        return 'تسوية طلب';
      case 'payout':
        return 'سحب رصيد';
      case 'manual_adjustment':
        return 'تعديل يدوي';
      default:
        return source;
    }
  }
}
