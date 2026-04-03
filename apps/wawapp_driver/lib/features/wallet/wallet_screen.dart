import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../auth/providers/auth_service_provider.dart';
import 'wallet_provider.dart';
import 'topup_request_provider.dart';
import 'topup_request_dialog.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final theme = Theme.of(context);
    final topupState = ref.watch(topupRequestProvider);
    
    // Get current user ID
    final authState = ref.watch(authProvider);
    final driverId = authState.user?.uid;
    
    // Watch wallet data
    final walletDataAsync = driverId != null 
        ? ref.watch(walletDataProvider(driverId))
        : null;

    final transactionsAsync = driverId != null
        ? ref.watch(driverTransactionsProvider(driverId))
        : null;

    // Listen for success/error messages
    ref.listen<TopupRequestState>(topupRequestProvider, (previous, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: DriverAppColors.successLight,
          ),
        );
        ref.read(topupRequestProvider.notifier).clearMessages();
      } else if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: DriverAppColors.errorLight,
          ),
        );
        ref.read(topupRequestProvider.notifier).clearMessages();
      }
    });

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.wallet),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                // Navigate to transaction history
              },
            ),
          ],
        ),
        body: driverId == null
            ? const Center(child: Text('يرجى تسجيل الدخول'))
            : walletDataAsync == null
                ? const Center(child: Text('يرجى تسجيل الدخول'))
                : walletDataAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Text('خطأ في تحميل البيانات: $error'),
                    ),
                    data: (walletData) => SingleChildScrollView(
                      padding: EdgeInsets.all(DriverAppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Main Balance Card
                          _buildBalanceCard(context, theme, walletData.totalBalance),
                          SizedBox(height: DriverAppSpacing.lg),

                          // Top-up Request Button
                          _buildTopupButton(context, ref, topupState),

                          SizedBox(height: DriverAppSpacing.lg),
                          // Recent Transactions
                          Text(
                            'المعاملات الأخيرة',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: DriverAppSpacing.md),
                          if (transactionsAsync == null)
                            const DriverEmptyState(icon: Icons.receipt_long, message: 'لا توجد معاملات')
                          else
                            transactionsAsync.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (_, __) => const DriverEmptyState(
                                  icon: Icons.receipt_long,
                                  message: 'لا توجد معاملات حتى الآن'),
                              data: (transactions) => transactions.isEmpty
                                  ? const DriverEmptyState(
                                      icon: Icons.receipt_long,
                                      message: 'لا توجد معاملات حتى الآن')
                                  : Column(
                                      children: transactions
                                          .map((tx) => _buildTransactionItem(context, theme, tx))
                                          .toList(),
                                    ),
                            ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, ThemeData theme, double balance) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            DriverAppColors.primaryLight,
            DriverAppColors.secondaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DriverAppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: DriverAppColors.primaryLight.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(DriverAppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إجمالي الرصيد',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(DriverAppSpacing.xs),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
            SizedBox(height: DriverAppSpacing.md),
            Text(
              '${balance.toStringAsFixed(2)} MRU',
              style: theme.textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 48,
              ),
            ),
            SizedBox(height: DriverAppSpacing.xs),
            Text(
              'رصيد المحفظة',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
      BuildContext context, ThemeData theme, WalletTransaction tx) {
    final isCredit = tx.type == 'credit';
    final color =
        isCredit ? DriverAppColors.successLight : DriverAppColors.errorLight;
    final sign = isCredit ? '+' : '-';
    return Card(
      margin: EdgeInsets.only(bottom: DriverAppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: 20,
          ),
        ),
        title: Text(tx.source, style: theme.textTheme.bodyMedium),
        subtitle: tx.note != null
            ? Text(tx.note!, style: theme.textTheme.bodySmall)
            : null,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$sign${tx.amount.toStringAsFixed(2)} MRU',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: DriverAppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopupButton(BuildContext context, WidgetRef ref, TopupRequestState topupState) {
    return ElevatedButton.icon(
      onPressed: topupState.isLoading
          ? null
          : () async {
              final amount = await showTopupRequestDialog(context);
              if (amount != null && context.mounted) {
                await ref
                    .read(topupRequestProvider.notifier)
                    .createTopupRequest(amount);
              }
            },
      icon: topupState.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.add_card),
      label: Text(topupState.isLoading ? 'جاري الإرسال...' : 'طلب شحن رصيد'),
      style: ElevatedButton.styleFrom(
        backgroundColor: DriverAppColors.primaryLight,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: DriverAppSpacing.lg,
          vertical: DriverAppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
        ),
      ),
    );
  }
}
