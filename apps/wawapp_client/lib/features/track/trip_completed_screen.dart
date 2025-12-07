import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:intl/intl.dart';
import 'package:core_shared/core_shared.dart';
import 'data/orders_repository.dart';
import '../../l10n/app_localizations.dart';

import 'providers/order_tracking_provider.dart';
import '../../widgets/error_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/fcm_service.dart';

// NEW THEME IMPORTS
import '../../theme/colors.dart';
import '../../theme/components.dart';
import '../../theme/theme_extensions.dart';

class TripCompletedScreen extends ConsumerStatefulWidget {
  final String orderId;

  const TripCompletedScreen({super.key, required this.orderId});

  @override
  ConsumerState<TripCompletedScreen> createState() =>
      _TripCompletedScreenState();
}

class _TripCompletedScreenState extends ConsumerState<TripCompletedScreen> {
  int? _selectedRating;
  bool _isSubmitting = false;
  bool _hasLoggedView = false;

  @override
  void initState() {
    super.initState();
    // Log trip completed view once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoggedView) {
        _hasLoggedView = true;
        AnalyticsService.instance
            .logTripCompletedViewed(orderId: widget.orderId);
      }
    });
  }

  Future<void> _submitRating() async {
    if (_selectedRating == null) return;

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(ordersRepositoryProvider);
      await repository.rateDriver(
        orderId: widget.orderId,
        rating: _selectedRating!,
      );

      // Check if user arrived via notification
      final notificationSource = FCMService.instance.getNotificationSource(widget.orderId);
      if (notificationSource == 'trip_completed') {
        // Track conversion: notification → rating
        AnalyticsService.instance.logDriverRatedFromNotification(
          orderId: widget.orderId,
          rating: _selectedRating!,
        );
      }

      // Log analytics event
      AnalyticsService.instance.logDriverRated(
        orderId: widget.orderId,
        rating: _selectedRating!,
      );

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.rating_thank_you),
            backgroundColor: context.successColor,
          ),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.error_submit_rating),
            backgroundColor: context.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final orderAsync = ref.watch(orderTrackingProvider(widget.orderId));

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.trip_completed),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: orderAsync.when(
            loading: () => const WawLoadingIndicator(),
            error: (error, stack) {
              final appError = AppError.from(error);
              return ErrorScreen(
                message: appError.toUserMessage(),
                onRetry: () => ref.refresh(orderTrackingProvider(widget.orderId)),
              );
            },
            data: (snapshot) {
              final data = snapshot?.data() as Map<String, dynamic>?;
              if (data == null) {
                return WawEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: l10n.order_not_found,
                );
              }

              final order = Order.fromFirestore({...data, 'id': widget.orderId});
              final completedAt = data['completedAt'] as Timestamp?;
              final dateStr = completedAt != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(completedAt.toDate())
                  : '';

              return SingleChildScrollView(
                padding: EdgeInsetsDirectional.all(WawAppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Success Icon
                    Icon(
                      Icons.check_circle,
                      size: 80,
                      color: context.successColor,
                    ),
                    SizedBox(height: WawAppSpacing.lg),
                    
                    // Success Message
                    Text(
                      l10n.trip_completed_success,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: WawAppSpacing.xl),
                    
                    // Trip Details Card
                    WawCard(
                      elevation: WawAppElevation.medium,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.trip_details,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: WawAppSpacing.md),
                          
                          _buildDetailRow(context, l10n, Icons.location_on_outlined, l10n.from, order.pickupAddress),
                          SizedBox(height: WawAppSpacing.sm),
                          _buildDetailRow(context, l10n, Icons.place_outlined, l10n.to, order.dropoffAddress),
                          SizedBox(height: WawAppSpacing.sm),
                          Divider(color: context.wawAppTheme.dividerColor),
                          SizedBox(height: WawAppSpacing.sm),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildInfoColumn(
                                context,
                                l10n,
                                icon: Icons.straighten,
                                label: l10n.distance,
                                value: '${order.distanceKm.toStringAsFixed(1)} ${l10n.km}',
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: context.wawAppTheme.dividerColor,
                              ),
                              _buildInfoColumn(
                                context,
                                l10n,
                                icon: Icons.payments_outlined,
                                label: l10n.total_cost,
                                value: '${order.price.round()} ${l10n.currency}',
                              ),
                            ],
                          ),
                          
                          if (dateStr.isNotEmpty) ...[
                            SizedBox(height: WawAppSpacing.sm),
                            Divider(color: context.wawAppTheme.dividerColor),
                            SizedBox(height: WawAppSpacing.sm),
                            _buildDetailRow(context, l10n, Icons.access_time, l10n.completed_at, dateStr),
                          ],
                        ],
                      ),
                    ),
                    
                    SizedBox(height: WawAppSpacing.xl),
                    
                    // Rating Section
                    WawCard(
                      elevation: WawAppElevation.low,
                      child: Column(
                        children: [
                          Text(
                            l10n.rate_driver,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: WawAppSpacing.xs),
                          Text(
                            l10n.rate_driver_subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: WawAppSpacing.lg),
                          
                          // Star Rating
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final rating = index + 1;
                              return IconButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => setState(() => _selectedRating = rating),
                                icon: Icon(
                                  rating <= (_selectedRating ?? 0)
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 48,
                                  color: rating <= (_selectedRating ?? 0)
                                      ? WawAppColors.secondary
                                      : theme.colorScheme.outline,
                                ),
                                padding: EdgeInsetsDirectional.symmetric(
                                  horizontal: WawAppSpacing.xs,
                                ),
                              );
                            }),
                          ),
                          
                          SizedBox(height: WawAppSpacing.lg),
                          
                          // Submit Button
                          WawActionButton(
                            label: l10n.submit_rating,
                            icon: Icons.send,
                            onPressed: _selectedRating != null && !_isSubmitting
                                ? _submitRating
                                : null,
                            isLoading: _isSubmitting,
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: WawAppSpacing.md),
                    
                    // Skip Button
                    WawSecondaryButton(
                      label: l10n.skip,
                      onPressed: () => context.go('/'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, AppLocalizations l10n, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }

  Widget _buildInfoColumn(BuildContext context, AppLocalizations l10n, {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 28),
        SizedBox(height: WawAppSpacing.xs),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
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
}
