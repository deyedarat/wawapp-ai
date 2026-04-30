import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../l10n/app_localizations.dart';
import '../../services/location_service.dart';
import '../blocked/blocked_provider.dart';
import '../orders/widgets/dispatch_offer_card.dart';
import 'providers/dispatch_offers_provider.dart';

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  final _locationService = LocationService.instance;
  Position? _currentPosition;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (kDebugMode) {
      print('[NEARBY_SCREEN] 🚀 Initializing location');
    }

    // Clear previous error
    if (mounted) {
      setState(() {
        _error = null;
      });
    }

    try {
      _currentPosition = await _locationService.getCurrentPosition();
      if (kDebugMode) {
        print(
            '[NEARBY_SCREEN] ✅ Location obtained: lat=${_currentPosition!.latitude.toStringAsFixed(4)}, lng=${_currentPosition!.longitude.toStringAsFixed(4)}');
      }
      if (mounted) {
        setState(() {
          _error = null; // Clear any previous errors
        });
      }
      if (kDebugMode) {
        print('[NEARBY_SCREEN] 🔄 setState called, should trigger rebuild');
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[NEARBY_SCREEN] ❌ Location error: $e');
      }

      // Provide user-friendly error message
      String errorMessage = 'خطأ في الحصول على الموقع';
      if (e.toString().contains('permission')) {
        errorMessage = 'يرجى منح صلاحية الموقع للتطبيق من الإعدادات';
      } else if (e.toString().contains('disabled')) {
        errorMessage = 'يرجى تفعيل خدمات الموقع (GPS) على الجهاز';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'انتهت مهلة الحصول على الموقع. يرجى المحاولة مرة أخرى';
      }

      if (mounted) {
        setState(() {
          _error = errorMessage;
          _currentPosition = null; // Ensure position is null on error
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // BLOCKED CHECK: redirect away if blocked
    final isBlocked = ref.watch(driverBlockedProvider);
    if (isBlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/blocked');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/');
              }
            },
          ),
          title: Text(l10n.nearby_requests),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _initLocation,
            ),
          ],
        ),
        body: _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error,
                        size: 64, color: DriverAppColors.errorLight),
                    SizedBox(height: DriverAppSpacing.md),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: DriverAppSpacing.lg),
                      child: Text(
                        'خطأ في الموقع: $_error',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    SizedBox(height: DriverAppSpacing.md),
                    DriverActionButton(
                      label: 'إعادة المحاولة',
                      icon: Icons.refresh,
                      onPressed: _initLocation,
                    ),
                  ],
                ),
              )
            : _currentPosition == null
                ? const Center(child: CircularProgressIndicator())
                : _buildOrdersList(),
      ),
    );
  }

  Widget _buildOrdersList() {
    if (kDebugMode) {
      print('[NEARBY_SCREEN] 📋 Building orders list widget');
      print(
          '[NEARBY_SCREEN] 📍 Position: lat=${_currentPosition!.latitude.toStringAsFixed(6)}, lng=${_currentPosition!.longitude.toStringAsFixed(6)}');
    }

    final offersAsync = ref.watch(dispatchOffersProvider);

    return Column(
      children: [
        // ============================================================================
        // SECTION 1: DISPATCH OFFERS (v2.0) - Priority display at top
        // ============================================================================
        offersAsync.when(
          data: (offers) {
            if (offers.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(DriverAppSpacing.md),
                  color: DriverAppColors.primaryLight.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notification_important,
                        color: DriverAppColors.primaryLight,
                      ),
                      SizedBox(width: DriverAppSpacing.sm),
                      Text(
                        'عروض جديدة (${offers.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DriverAppColors.primaryLight,
                            ),
                      ),
                    ],
                  ),
                ),
                // Offers list
                ...offers.map((offer) => DispatchOfferCard(offer: offer)),
                // Divider
                Divider(
                  height: DriverAppSpacing.lg * 2,
                  thickness: 8,
                  color: DriverAppColors.backgroundLight,
                ),
              ],
            );
          },
          loading: () => Padding(
            padding: EdgeInsets.all(DriverAppSpacing.md),
            child: const LinearProgressIndicator(),
          ),
          error: (e, st) => Padding(
            padding: EdgeInsets.all(DriverAppSpacing.md),
            child: Text(
              'خطأ في تحميل العروض',
              style: TextStyle(color: DriverAppColors.errorLight),
            ),
          ),
        ),

        // Empty state when no offers
        Expanded(
          child: offersAsync.when(
            data: (offers) {
              if (offers.isEmpty) {
                return const DriverEmptyState(
                  icon: Icons.inbox,
                  message: 'لا توجد طلبات قريبة في الوقت الحالي',
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
