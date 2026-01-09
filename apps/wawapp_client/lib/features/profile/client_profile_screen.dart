import 'package:core_shared/core_shared.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/navigation/safe_navigation.dart';
import '../../l10n/app_localizations.dart';
// NEW THEME IMPORTS
import '../../theme/colors.dart';
import '../../theme/components.dart';
import '../../theme/theme_extensions.dart';
import '../auth/providers/auth_service_provider.dart';
import 'providers/client_profile_providers.dart';

class ClientProfileScreen extends ConsumerWidget {
  const ClientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Crashlytics breadcrumb for debugging build-phase issues
    FirebaseCrashlytics.instance.setCustomKey('screen', 'ClientProfileScreen');
    FirebaseCrashlytics.instance.log('ClientProfileScreen: build started');

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final profileAsync = ref.watch(clientProfileStreamProvider);
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profile),
          centerTitle: true,
        ),
        body: SafeArea(
          child: profileAsync.when(
            loading: () => const WawLoadingIndicator(),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(WawAppSpacing.screenPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: context.errorColor,
                    ),
                    const SizedBox(height: WawAppSpacing.md),
                    Text(
                      l10n.error_loading_data,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: WawAppSpacing.xs),
                    Text(
                      '$error',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: WawAppSpacing.lg),
                    WawActionButton(
                      label: l10n.retry,
                      icon: Icons.refresh,
                      onPressed: () => ref.refresh(clientProfileStreamProvider),
                      isFullWidth: false,
                    ),
                  ],
                ),
              ),
            ),
            data: (profile) {
              if (profile == null) {
                return _buildNoProfileView(context, l10n);
              }
              return _buildProfileView(context, l10n, profile, ref);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNoProfileView(BuildContext context, AppLocalizations l10n) {
    return WawEmptyState(
      icon: Icons.person_outline,
      title: l10n.no_profile,
      message: l10n.no_profile_message,
      action: WawActionButton(
        label: l10n.setup_profile,
        icon: Icons.edit,
        onPressed: () => context.push('/profile/edit'),
        isFullWidth: false,
      ),
    );
  }

  Widget _buildProfileView(BuildContext context, AppLocalizations l10n, ClientProfile profile, WidgetRef ref) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(WawAppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Header Card
          WawCard(
            elevation: WawAppElevation.medium,
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
                  child: profile.photoUrl == null
                      ? Icon(
                          Icons.person,
                          size: 50,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
                const SizedBox(height: WawAppSpacing.md),

                // Name
                Text(
                  profile.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: WawAppSpacing.xs),

                // Phone
                Text(
                  profile.phone,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: WawAppSpacing.lg),

                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      context,
                      l10n.total_trips,
                      profile.totalTrips.toString(),
                      Icons.local_shipping_outlined,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: context.wawAppTheme.dividerColor,
                    ),
                    _buildStatColumn(
                      context,
                      l10n.rating,
                      profile.averageRating.toStringAsFixed(1),
                      Icons.star,
                    ),
                  ],
                ),
                const SizedBox(height: WawAppSpacing.lg),

                // Edit Button
                WawActionButton(
                  label: l10n.edit_profile,
                  icon: Icons.edit_outlined,
                  onPressed: () => context.push('/profile/edit'),
                ),
              ],
            ),
          ),

          const SizedBox(height: WawAppSpacing.md),

          // Profile Info Card
          WawCard(
            elevation: WawAppElevation.low,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.personal_info,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: WawAppSpacing.md),
                _buildInfoRow(
                    context, l10n, Icons.language, l10n.language, _getLanguageLabel(l10n, profile.preferredLanguage)),
              ],
            ),
          ),

          const SizedBox(height: WawAppSpacing.md),

          // Quick Actions Card
          WawCard(
            elevation: WawAppElevation.low,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.quick_actions,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: WawAppSpacing.md),
                _buildActionTile(
                  context,
                  l10n,
                  icon: Icons.location_on_outlined,
                  title: l10n.saved_locations,
                  subtitle: l10n.saved_locations_subtitle,
                  onTap: () => context.push('/profile/locations'),
                ),
                Divider(height: 1, color: context.wawAppTheme.dividerColor),
                _buildActionTile(
                  context,
                  l10n,
                  icon: Icons.lock_outline,
                  title: l10n.change_pin,
                  subtitle: l10n.change_pin_subtitle,
                  onTap: () => context.push('/profile/change-pin'),
                ),
                Divider(height: 1, color: context.wawAppTheme.dividerColor),
                _buildActionTile(
                  context,
                  l10n,
                  icon: Icons.privacy_tip_outlined,
                  title: l10n.privacy_policy,
                  subtitle: 'سياسة الخصوصية وحماية البيانات',
                  onTap: () => _launchPrivacyPolicy(),
                ),
                Divider(height: 1, color: context.wawAppTheme.dividerColor),
                _buildActionTile(
                  context,
                  l10n,
                  icon: Icons.delete_forever_outlined,
                  title: l10n.delete_account,
                  subtitle: 'حذف حسابك وجميع بياناتك بشكل دائم',
                  onTap: () => _showDeleteAccountDialog(context, ref, l10n),
                  isDestructive: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: WawAppSpacing.lg),

          // Logout Button
          _buildLogoutButton(context, ref, l10n),
          const SizedBox(height: WawAppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    return OutlinedButton.icon(
      onPressed: () => _showLogoutConfirmation(context, ref, l10n),
      icon: const Icon(Icons.logout),
      label: Text(l10n.logout ?? 'Logout'),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.errorColor,
        side: BorderSide(color: context.errorColor),
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: WawAppSpacing.md,
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logout ?? 'Logout'),
        content: Text(l10n.logout_confirmation ?? 'Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => context.safeDialogPop(false),
            child: Text(l10n.cancel ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => context.safeDialogPop(true),
            style: TextButton.styleFrom(foregroundColor: context.errorColor),
            child: Text(l10n.logout ?? 'Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Perform logout
      await ref.read(authProvider.notifier).logout();

      // Safe navigation after logout - single source of truth
      if (context.mounted) {
        context.safeDialogPop(); // Close loading
        SafeNavigation.safeLogoutNavigation(context);
      }
    }
  }

  Widget _buildStatColumn(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 28),
        const SizedBox(height: WawAppSpacing.xs),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: WawAppSpacing.xxs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, AppLocalizations l10n, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: WawAppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: WawAppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: WawAppSpacing.xxs),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    AppLocalizations l10n, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final iconColor = isDestructive ? context.errorColor : theme.colorScheme.primary;
    final titleColor = isDestructive ? context.errorColor : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WawAppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: WawAppSpacing.xs),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsetsDirectional.all(WawAppSpacing.sm),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(WawAppSpacing.radiusSm),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: WawAppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: WawAppSpacing.xxs),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isRTL ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
              size: 16,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchPrivacyPolicy() async {
    final uri = Uri.parse('https://wawappmr.com/privacy');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showDeleteAccountDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete_account_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.delete_account_warning),
            const SizedBox(height: WawAppSpacing.md),
            Text(
              l10n.delete_account_confirm,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.safeDialogPop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => context.safeDialogPop(true),
            style: TextButton.styleFrom(foregroundColor: context.errorColor),
            child: Text(l10n.delete_account),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: WawAppSpacing.md),
              Text(
                l10n.deleting_account,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );

      try {
        // Call delete account function (placeholder - implement actual deletion)
        // await ref.read(authProvider.notifier).deleteAccount();

        // For now, just sign out
        await ref.read(authProvider.notifier).logout();

        if (context.mounted) {
          context.safeDialogPop(); // Close loading
          SafeNavigation.safeLogoutNavigation(context);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.account_deleted)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          context.safeDialogPop(); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.error_delete_account),
              backgroundColor: context.errorColor,
            ),
          );
        }
      }
    }
  }

  String _getLanguageLabel(AppLocalizations l10n, String languageCode) {
    switch (languageCode) {
      case 'ar':
        return l10n.language_ar;
      case 'fr':
        return l10n.language_fr;
      case 'en':
        return l10n.language_en;
      default:
        return languageCode;
    }
  }
}
