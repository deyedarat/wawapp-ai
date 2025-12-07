import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:core_shared/core_shared.dart';
import 'providers/client_profile_providers.dart';
import '../../l10n/app_localizations.dart';

// NEW THEME IMPORTS
import '../../theme/colors.dart';
import '../../theme/components.dart';
import '../../theme/theme_extensions.dart';

class SavedLocationsScreen extends ConsumerWidget {
  const SavedLocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locationsAsync = ref.watch(savedLocationsStreamProvider);
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.saved_locations),
          centerTitle: true,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/profile/locations/add'),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: Text(l10n.add_location),
        ),
        body: SafeArea(
          child: locationsAsync.when(
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
                      onPressed: () => ref.refresh(savedLocationsStreamProvider),
                      isFullWidth: false,
                    ),
                  ],
                ),
              ),
            ),
            data: (locations) {
              if (locations.isEmpty) {
                return WawEmptyState(
                  icon: Icons.location_off_outlined,
                  title: l10n.no_saved_locations,
                  message: l10n.no_saved_locations_message,
                  action: WawActionButton(
                    label: l10n.add_location,
                    icon: Icons.add,
                    onPressed: () => context.push('/profile/locations/add'),
                    isFullWidth: false,
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsetsDirectional.all(WawAppSpacing.screenPadding),
                itemCount: locations.length,
                itemBuilder: (context, index) {
                  final location = locations[index];
                  return Padding(
                    padding: EdgeInsetsDirectional.only(
                      bottom: WawAppSpacing.sm,
                    ),
                    child: WawCard(
                      onTap: () => context.push('/profile/locations/edit/${location.id}'),
                      padding: EdgeInsetsDirectional.all(WawAppSpacing.md),
                      child: Row(
                        children: [
                          // Icon
                          Container(
                            padding: EdgeInsetsDirectional.all(WawAppSpacing.sm),
                            decoration: BoxDecoration(
                              color: _getTypeColor(location.type).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getTypeIcon(location.type),
                              color: _getTypeColor(location.type),
                              size: 24,
                            ),
                          ),
                          SizedBox(width: WawAppSpacing.md),
                          
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  location.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: WawAppSpacing.xxs),
                                Text(
                                  location.type.toArabicLabel(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _getTypeColor(location.type),
                                  ),
                                ),
                                SizedBox(height: WawAppSpacing.xxs),
                                Text(
                                  location.address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Action Menu
                          PopupMenuButton<String>(
                            onSelected: (value) => _handleMenuAction(
                              context,
                              ref,
                              value,
                              location,
                              l10n,
                            ),
                            icon: Icon(
                              Icons.more_vert,
                              color: theme.colorScheme.primary,
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_outlined, size: 20),
                                    SizedBox(width: WawAppSpacing.xs),
                                    Text(l10n.edit),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                      color: context.errorColor,
                                    ),
                                    SizedBox(width: WawAppSpacing.xs),
                                    Text(
                                      l10n.delete,
                                      style: TextStyle(color: context.errorColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(SavedLocationType type) {
    switch (type) {
      case SavedLocationType.home:
        return WawAppColors.info;
      case SavedLocationType.work:
        return WawAppColors.warning;
      case SavedLocationType.other:
        return WawAppColors.shipmentAppliances;
    }
  }

  IconData _getTypeIcon(SavedLocationType type) {
    switch (type) {
      case SavedLocationType.home:
        return Icons.home_outlined;
      case SavedLocationType.work:
        return Icons.work_outline;
      case SavedLocationType.other:
        return Icons.location_on_outlined;
    }
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    SavedLocation location,
    AppLocalizations l10n,
  ) {
    switch (action) {
      case 'edit':
        context.push('/profile/locations/edit/${location.id}');
        break;
      case 'delete':
        _showDeleteDialog(context, ref, location, l10n);
        break;
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    SavedLocation location,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.delete_location),
        content: Text(l10n.delete_location_confirm(location.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  await ref
                      .read(savedLocationsNotifierProvider.notifier)
                      .deleteLocation(user.uid, location.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.location_deleted_success),
                        backgroundColor: context.successColor,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.error_delete_location),
                        backgroundColor: context.errorColor,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(
              l10n.delete,
              style: TextStyle(color: context.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}
