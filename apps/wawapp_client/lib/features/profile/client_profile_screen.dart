import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core_shared/core_shared.dart';
import 'providers/client_profile_providers.dart';
import '../../l10n/app_localizations.dart';

// NEW THEME IMPORTS
import '../../theme/colors.dart';
import '../../theme/components.dart';
import '../../theme/theme_extensions.dart';

class ClientProfileScreen extends ConsumerWidget {
  const ClientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                padding: EdgeInsetsDirectional.all(WawAppSpacing.screenPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: context.errorColor,
                    ),
                    SizedBox(height: WawAppSpacing.md),
                    Text(
                      l10n.error_loading_data,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: WawAppSpacing.xs),
                    Text(
                      '$error',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: WawAppSpacing.lg),
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
              return _buildProfileView(context, l10n, profile);
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

  Widget _buildProfileView(BuildContext context, AppLocalizations l10n, ClientProfile profile) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.all(WawAppSpacing.screenPadding),
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
                  backgroundImage: profile.photoUrl != null
                      ? NetworkImage(profile.photoUrl!)
                      : null,
                  child: profile.photoUrl == null
                      ? Icon(
                          Icons.person,
                          size: 50,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
                SizedBox(height: WawAppSpacing.md),
                
                // Name
                Text(
                  profile.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: WawAppSpacing.xs),
                
                // Phone
                Text(
                  profile.phone,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: WawAppSpacing.lg),
                
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
                SizedBox(height: WawAppSpacing.lg),
                
                // Edit Button
                WawActionButton(
                  label: l10n.edit_profile,
                  icon: Icons.edit_outlined,
                  onPressed: () => context.push('/profile/edit'),
                ),
              ],
            ),
          ),
          
          SizedBox(height: WawAppSpacing.md),
          
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
                SizedBox(height: WawAppSpacing.md),
                _buildInfoRow(context, l10n, Icons.language, l10n.language, _getLanguageLabel(l10n, profile.preferredLanguage)),
              ],
            ),
          ),
          
          SizedBox(height: WawAppSpacing.md),
          
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
                SizedBox(height: WawAppSpacing.md),
                _buildActionTile(
                  context,
                  l10n,
                  icon: Icons.location_on_outlined,
                  title: l10n.saved_locations,
                  subtitle: l10n.saved_locations_subtitle,
                  onTap: () => context.push('/profile/locations'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 28),
        SizedBox(height: WawAppSpacing.xs),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(height: WawAppSpacing.xxs),
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
      padding: EdgeInsetsDirectional.symmetric(vertical: WawAppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          SizedBox(width: WawAppSpacing.sm),
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
                SizedBox(height: WawAppSpacing.xxs),
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
  }) {
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WawAppSpacing.radiusSm),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(vertical: WawAppSpacing.xs),
        child: Row(
          children: [
            Container(
              padding: EdgeInsetsDirectional.all(WawAppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(WawAppSpacing.radiusSm),
              ),
              child: Icon(
                icon,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            SizedBox(width: WawAppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: WawAppSpacing.xxs),
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
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
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
