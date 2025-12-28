import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final theme = Theme.of(context);

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
        body: SingleChildScrollView(
          padding: EdgeInsets.all(DriverAppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main Balance Card
              Container(
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
                            l10n.total_earnings,
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
                        '0 MRU',
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
              ),
              SizedBox(height: DriverAppSpacing.lg),
              // Quick Stats
              Row(
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
                            '0 MRU',
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
                            '0 MRU',
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
              ),
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
    );
  }
}
