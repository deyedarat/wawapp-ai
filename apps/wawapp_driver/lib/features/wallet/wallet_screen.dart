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
                          // Quick Stats
                          _buildQuickStats(context, theme, l10n, walletData),
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
                          const DriverEmptyState(
                            icon: Icons.receipt_long,
                            message: 'لا توجد معاملات حتى الآن',
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
                  'إجمالي الأرباح',
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

  Widget _buildQuickStats(BuildContext context, ThemeData theme, AppLocalizations l10n, WalletData walletData) {
    return Row(
      children: [
        Expanded(
          child: DriverCard(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(DriverAppSpacing.sm),
                  decoration: BoxDecoration(
                    color: DriverAppColors.successLight.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.today,
                    size: 24,
                    color: DriverAppColors.successLight,
                  ),
                ),
                SizedBox(height: DriverAppSpacing.sm),
                Text(
                  '${walletData.todayEarnings.toStringAsFixed(2)} MRU',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DriverAppColors.successLight,
                  ),
                ),
                SizedBox(height: DriverAppSpacing.xxs),
                Text(
                  l10n.today_earnings,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: DriverAppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: DriverAppSpacing.md),
        Expanded(
          child: DriverCard(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(DriverAppSpacing.sm),
                  decoration: BoxDecoration(
                    color: DriverAppColors.infoLight.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    size: 24,
                    color: DriverAppColors.infoLight,
                  ),
                ),
                SizedBox(height: DriverAppSpacing.sm),
                Text(
                  '${walletData.weekEarnings.toStringAsFixed(2)} MRU',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DriverAppColors.infoLight,
                  ),
                ),
                SizedBox(height: DriverAppSpacing.xxs),
                Text(
                  'هذا الأسبوع',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: DriverAppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
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
