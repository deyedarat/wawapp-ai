import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../auth/providers/auth_service_provider.dart';
import '../profile/providers/driver_profile_providers.dart';

class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(driverProfileStreamProvider);
    final blockReason = profileAsync.whenOrNull(
      data: (profile) => profile?.blockReason,
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DriverAppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.block,
                size: 80,
                color: DriverAppColors.errorLight,
              ),
              const SizedBox(height: DriverAppSpacing.lg),
              Text(
                'حسابك محظور',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: DriverAppColors.errorLight,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DriverAppSpacing.md),
              Text(
                'تم تعليق حسابك من قبل الإدارة. لا يمكنك استقبال أو قبول الطلبات حالياً.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: DriverAppColors.textSecondaryLight,
                    ),
                textAlign: TextAlign.center,
              ),
              if (blockReason != null && blockReason.isNotEmpty) ...[
                const SizedBox(height: DriverAppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(DriverAppSpacing.md),
                  decoration: BoxDecoration(
                    color: DriverAppColors.errorLight.withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(DriverAppSpacing.radiusMd),
                    border: Border.all(
                      color: DriverAppColors.errorLight.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'السبب:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: DriverAppSpacing.xs),
                      Text(
                        blockReason,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: DriverAppSpacing.xl),
              Text(
                'للاستفسار أو الاعتراض، تواصل مع الدعم الفني.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DriverAppColors.textSecondaryLight,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DriverAppSpacing.xl),
              DriverActionButton(
                label: 'تسجيل الخروج',
                icon: Icons.logout,
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                },
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
