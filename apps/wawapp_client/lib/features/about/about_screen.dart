import 'package:flutter/material.dart';
import '../../core/build_info/build_info.dart';
import '../../l10n/app_localizations.dart';

// NEW THEME IMPORTS
import '../../theme/colors.dart';
import '../../theme/components.dart';
import '../../theme/theme_extensions.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final buildInfo = BuildInfoProvider.instance;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.about_app),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(WawAppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Icon
                Container(
                  padding: EdgeInsetsDirectional.all(WawAppSpacing.lg),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                ),
                SizedBox(height: WawAppSpacing.lg),

                // App Name
                Text(
                  l10n.appTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: WawAppSpacing.xs),

                // App Description
                Text(
                  l10n.app_description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: WawAppSpacing.xl),

                // Version Info Card
                WawCard(
                  elevation: WawAppElevation.medium,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.version_info,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: WawAppSpacing.md),
                      _buildInfoRow(context, l10n.version, buildInfo.version,
                          Icons.info_outline),
                      _buildInfoRow(context, l10n.branch, buildInfo.branch,
                          Icons.account_tree_outlined),
                      _buildInfoRow(
                          context, l10n.commit, buildInfo.commit, Icons.commit),
                      _buildInfoRow(context, l10n.flavor, buildInfo.flavor,
                          Icons.label_outline),
                      _buildInfoRow(context, l10n.flutter_version,
                          buildInfo.flutter, Icons.flutter_dash),
                    ],
                  ),
                ),

                SizedBox(height: WawAppSpacing.md),

                // Features Card
                WawCard(
                  elevation: WawAppElevation.low,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.features,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: WawAppSpacing.md),
                      _buildFeatureRow(context, l10n.feature_realtime_tracking,
                          Icons.my_location),
                      _buildFeatureRow(
                          context, l10n.feature_cargo_types, Icons.category),
                      _buildFeatureRow(context, l10n.feature_instant_quotes,
                          Icons.calculate),
                      _buildFeatureRow(
                          context, l10n.feature_multilingual, Icons.language),
                    ],
                  ),
                ),

                SizedBox(height: WawAppSpacing.xl),

                // Copyright
                Text(
                  l10n.copyright,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: WawAppSpacing.sm),
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

  Widget _buildFeatureRow(BuildContext context, String label, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: WawAppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: EdgeInsetsDirectional.all(WawAppSpacing.xs),
            decoration: BoxDecoration(
              color: context.successColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              size: 16,
              color: context.successColor,
            ),
          ),
          SizedBox(width: WawAppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
