import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/shipment_type.dart';
import 'shipment_type_provider.dart';
import '../../l10n/app_localizations.dart';

// NEW THEME IMPORTS
import '../../theme/colors.dart';
import '../../theme/components.dart';
import '../../theme/theme_extensions.dart';

class ShipmentTypeScreen extends ConsumerWidget {
  const ShipmentTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    // All 6 shipment types
    final shipmentTypes = ShipmentType.values;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.choose_shipment_type),
          centerTitle: true,
          automaticallyImplyLeading:
              false, // Remove back button since this is the entry screen
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(WawAppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                WawCard(
                  elevation: WawAppElevation.medium,
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsetsDirectional.all(WawAppSpacing.md),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius:
                              BorderRadius.circular(WawAppSpacing.radiusMd),
                        ),
                        child: Icon(
                          Icons.local_shipping,
                          size: 40,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      SizedBox(width: WawAppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.cargo_delivery_service,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: WawAppSpacing.xxs),
                            Text(
                              l10n.cargo_delivery_subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: WawAppSpacing.lg),

                // Grid Title
                Text(
                  l10n.select_cargo_type,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: WawAppSpacing.md),

                // Grid of shipment type cards
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: WawAppSpacing.sm,
                    mainAxisSpacing: WawAppSpacing.sm,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: shipmentTypes.length,
                  itemBuilder: (context, index) {
                    final type = shipmentTypes[index];
                    return _ShipmentTypeCard(
                      type: type,
                      onTap: () {
                        // Save the selected type
                        ref.read(selectedShipmentTypeProvider.notifier).state =
                            type;

                        // Navigate to home/map screen
                        context.go('/');
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShipmentTypeCard extends StatelessWidget {
  final ShipmentType type;
  final VoidCallback onTap;

  const _ShipmentTypeCard({
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WawAppSpacing.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WawAppSpacing.radiusLg),
            border: Border.all(
              color: type.color.withOpacity(0.3),
              width: 2,
            ),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                type.color.withOpacity(0.05),
                type.color.withOpacity(0.15),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: type.color.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.all(WawAppSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with circular background
                Container(
                  padding: EdgeInsetsDirectional.all(WawAppSpacing.md),
                  decoration: BoxDecoration(
                    color: type.color.withOpacity(0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: type.color.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    type.icon,
                    size: 40,
                    color: type.color,
                  ),
                ),
                SizedBox(height: WawAppSpacing.md),

                // Label
                Text(
                  isRTL ? type.arabicLabel : type.frenchLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: type.color,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
