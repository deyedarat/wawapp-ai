import 'dart:async';
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../l10n/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/driver_status_service.dart';
import '../../services/notification_service.dart';
import '../../services/orders_service.dart';
import '../nearby/providers/dispatch_offers_provider.dart';
import '../orders/models/dispatch_offer.dart';
import '../permissions/permission_helper.dart';
import '../permissions/permission_setup_screen.dart';
import '../../services/location_service.dart';
import '../../services/tracking_service.dart';
import '../auth/providers/auth_service_provider.dart';
import '../blocked/blocked_provider.dart';
import '../active/providers/active_order_provider.dart';
import '../profile/providers/driver_profile_providers.dart';
import '../wallet/wallet_provider.dart';
import 'providers/driver_status_provider.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

// ---------------------------------------------------------------------------
// Rate-limited nudge helper (in-memory, per message key)
// ---------------------------------------------------------------------------
final Map<String, DateTime> _nudgeLastShown = {};
const _nudgeMinInterval = Duration(minutes: 2);

bool _canShowNudge(String key) {
  final last = _nudgeLastShown[key];
  if (last != null && DateTime.now().difference(last) < _nudgeMinInterval) {
    return false;
  }
  _nudgeLastShown[key] = DateTime.now();
  return true;
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  bool _isTogglingStatus = false;

  bool _trackingResumed = false;
  StreamSubscription<ServiceStatus>? _locationServiceSubscription;
  StreamSubscription<Position>? _accuracyNudgeSubscription;

  /// Dedup set for offers handled via Firestore backup listener
  final Set<String> _firestoreHandledOffers = {};

  /// Polling timer as last-resort fallback when FCM + Firestore listener both fail
  Timer? _offerPollingTimer;

  /// Handle a dispatch offer detected via Firestore realtime listener
  /// (backup path when FCM is delayed).
  Future<void> _handleFirestoreOffer(DispatchOffer offer) async {
    if (!mounted) return;
    final order = await ref.read(ordersServiceProvider).getOrder(offer.orderId);
    if (!mounted || order == null) return;

    if (kDebugMode) {
      dev.log('[DriverHome] 🔔 Firestore backup: routing offer ${offer.offerId} to handleIncomingOffer');
    }

    await NotificationService().handleIncomingOffer({
      'type': 'wave_offer',
      'offerId': offer.offerId,
      'orderId': offer.orderId,
      'pickupLabel': order.pickupAddress,
      'dropoffLabel': order.dropoffAddress,
      'price': order.price.toString(),
      'distance': offer.distance.toString(),
      'createdAt': offer.sentAt.millisecondsSinceEpoch.toString(),
      'round': offer.round.toString(),
    }, source: 'firestore');
  }

  /// Start polling for dispatch offers every 30 seconds (HTTPS fallback).
  /// This catches offers when both FCM and Firestore WebSocket fail
  /// (common on some mobile networks that throttle persistent connections).
  void _startOfferPolling() {
    _offerPollingTimer?.cancel();
    _offerPollingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;

      final authState = ref.read(authProvider);
      final uid = authState.user?.uid;
      if (uid == null) return;

      // Only poll if driver is online
      final isOnline = await DriverStatusService.instance.getOnlineStatus(uid);
      if (!isOnline) return;

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('dispatch_offers')
            .where('driverId', isEqualTo: uid)
            .where('status', isEqualTo: 'sent')
            .orderBy('sentAt', descending: true)
            .limit(1)
            .get(const GetOptions(source: Source.server));

        if (snapshot.docs.isEmpty || !mounted) return;

        final doc = snapshot.docs.first;
        final offer = DispatchOffer.fromFirestore(doc);

        // Skip expired or already handled
        if (!offer.isValid) return;
        if (_firestoreHandledOffers.contains(offer.offerId)) return;

        _firestoreHandledOffers.add(offer.offerId);

        if (kDebugMode) {
          dev.log('[DriverHome] 📡 Polling fallback: found offer ${offer.offerId}');
        }

        await _handleFirestoreOffer(offer);
      } catch (e) {
        // Non-fatal: polling is best-effort
        if (kDebugMode) {
          dev.log('[DriverHome] Polling error (non-fatal): $e');
        }
      }
    });
  }

  /// Stop polling.
  void _stopOfferPolling() {
    _offerPollingTimer?.cancel();
    _offerPollingTimer = null;
  }

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      dev.log('[DriverHome] Screen initialized');
    }
    // Resume tracking if driver was already online from a previous session
    _resumeTrackingIfOnline();
    // Show permission setup on first launch
    _checkPermissionSetup();
    // Listen for internet loss
    ConnectivityService().onForcedOffline = _onInternetLost;
    // Check eligibility nudges after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkEligibilityNudges());
    // Start polling fallback for offer detection (HTTPS, works on all networks)
    _startOfferPolling();
  }

  @override
  void dispose() {
    _accuracyNudgeSubscription?.cancel();
    _stopLocationMonitoring();
    _stopOfferPolling();
    ConnectivityService().onForcedOffline = null;
    super.dispose();
  }

  // ── Eligibility nudges (lightweight, no backend writes) ──────────

  /// Check all nudge conditions once (on screen open / app resume).
  Future<void> _checkEligibilityNudges() async {
    final authState = ref.read(authProvider);
    final uid = authState.user?.uid;
    if (uid == null || !mounted) return;

    final isOnline = await DriverStatusService.instance.getOnlineStatus(uid);
    if (!isOnline) return;

    // Nudge 1: tracking stopped while online
    if (!TrackingService.instance.isTracking) {
      _wasTrackingStopped = true; // track for recovery detection
      return;
    }

    // Nudge 2: stale location (>5 min)
    try {
      final locDoc = await FirebaseFirestore.instance.collection('driver_locations').doc(uid).get();
      if (locDoc.exists) {
        final updatedAt = locDoc.data()?['updatedAt'];
        if (updatedAt is Timestamp) {
          final age = DateTime.now().difference(updatedAt.toDate());
          if (age.inMinutes >= 5 && _canShowNudge('stale_location')) {
            _showNudge('افتح التطبيق لتحديث موقعك واستلام الطلبات', Icons.update);
            return;
          }
          // Detect recovery: location was stale, now fresh (app just resumed)
          // If we reach here, location is fresh — trigger boost
          if (age.inMinutes < 5 && _wasTrackingStopped) {
            _markDriverRecovered();
          }
        }
      }
    } catch (_) {}

    // Nudge 3: start listening for weak GPS accuracy
    _startAccuracyNudgeListener();
  }

  /// Listen to position stream and nudge if accuracy > 800m.
  /// Also detects recovery: accuracy transitions from >800 → ≤800.
  double _lastAccuracy = 0;
  bool _wasTrackingStopped = false;

  void _startAccuracyNudgeListener() {
    _accuracyNudgeSubscription?.cancel();
    _accuracyNudgeSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 50),
        ).listen((position) {
          if (!mounted) return;

          // Detect recovery: accuracy improved from bad → good
          if (_lastAccuracy > 800 && position.accuracy <= 800) {
            _markDriverRecovered();
          }
          _lastAccuracy = position.accuracy;

          if (position.accuracy > 800 && _canShowNudge('weak_gps')) {
            _showNudge('دقة الموقع ضعيفة — اخرج لمكان مفتوح للحصول على الطلبات', Icons.gps_not_fixed);
          }
        }, onError: (_) {});
  }

  /// Display a non-blocking snackbar nudge.
  void _showNudge(String message, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ── Recovery boost (writes to existing drivers/{id} doc) ────────

  /// Write a short-lived priority boost when driver recovers from
  /// bad GPS / stale location / stopped tracking.
  /// TTL is enforced at read time in selectors.ts (120s).
  Future<void> _markDriverRecovered() async {
    final uid = ref.read(authProvider).user?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'priorityBoost': true,
        'priorityBoostAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) {
        dev.log('[DriverHome] ✅ Recovery boost written for $uid');
      }
    } catch (e) {
      if (kDebugMode) {
        dev.log('[DriverHome] Recovery boost write failed (non-fatal): $e');
      }
    }
  }

  void _onInternetLost() {
    if (!mounted) return;
    _stopLocationMonitoring();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('انقطع الاتصال'),
        content: const Text(
          'تم فقدان الاتصال بالإنترنت.\n'
          'لن تصلك طلبات حتى يعود الاتصال.\n\n'
          'أنت لا تزال في وضع "متصل".',
        ),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
      ),
    );
  }

  Future<void> _resumeTrackingIfOnline() async {
    if (_trackingResumed) return;
    final authState = ref.read(authProvider);
    final uid = authState.user?.uid;
    if (uid == null) return;

    final isOnline = await DriverStatusService.instance.getOnlineStatus(uid);
    if (isOnline && mounted) {
      _trackingResumed = true;
      if (kDebugMode) {
        dev.log('[DriverHome] Driver was online, verifying location before resuming...');
      }

      // Same prerequisite check as manual toggle
      final locationError = await LocationService.instance.verifyLocationPrerequisites();
      if (locationError != null) {
        if (kDebugMode) {
          dev.log('[DriverHome] Location prerequisites failed on resume: $locationError');
          dev.log('[DriverHome] isOnline preserved — driver intent unchanged');
        }
        // Do NOT call setOffline() — driver intent remains online.
        // Dispatch engine will skip via location freshness / accuracy filters.
        if (mounted) {
          _showLocationPrerequisitesDialog(locationError);
        }
        return;
      }

      try {
        await TrackingService.instance.startTracking();
        _startLocationMonitoring();

        // Detect recovery: tracking was stopped → now active
        if (_wasTrackingStopped) {
          _wasTrackingStopped = false;
          _markDriverRecovered();
        }
      } catch (e) {
        if (kDebugMode) {
          dev.log('[DriverHome] Failed to resume tracking: $e');
          dev.log('[DriverHome] isOnline preserved — driver intent unchanged');
        }
        // Do NOT call setOffline() — driver intent remains online.
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('تعذر تشغيل التتبع: $e'), backgroundColor: Colors.orange));
        }
      }
    }
  }

  /// Monitor location service status while driver is online.
  /// Auto-sets driver offline if GPS is disabled mid-session.
  void _startLocationMonitoring() {
    _locationServiceSubscription?.cancel();
    _locationServiceSubscription = Geolocator.getServiceStatusStream().listen((ServiceStatus status) async {
      if (status == ServiceStatus.disabled) {
        if (kDebugMode) {
          dev.log('[DriverHome] ⚠️ Location services disabled mid-session');
          dev.log('[DriverHome] isOnline preserved — driver intent unchanged');
        }
        final authState = ref.read(authProvider);
        final uid = authState.user?.uid;
        if (uid == null) return;

        final isOnline = await DriverStatusService.instance.getOnlineStatus(uid);
        if (!isOnline) return;

        // Stop tracking but do NOT call setOffline().
        // Driver intent remains online. Dispatch engine will skip
        // via stale location / accuracy filters.
        TrackingService.instance.stopTracking();

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('الموقع غير متاح'),
              content: const Text(
                'تم تعطيل خدمات الموقع (GPS).\n'
                'لن تصلك طلبات حتى تعيد تفعيل الموقع.\n\n'
                'أنت لا تزال في وضع "متصل".',
              ),
              actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
            ),
          );
        }
      }
    });
  }

  void _stopLocationMonitoring() {
    _locationServiceSubscription?.cancel();
    _locationServiceSubscription = null;
  }

  Future<void> _checkPermissionSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(kPermissionSetupCompleted) ?? false;
    if (done) return;

    final allGranted = await PermissionHelper.areAllCriticalPermissionsGranted();
    if (allGranted) {
      await prefs.setBool(kPermissionSetupCompleted, true);
      return;
    }

    if (!mounted) return;
    // Show permission setup as a full-screen modal
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const PermissionSetupScreen()));
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    final authState = ref.read(authProvider);
    if (authState.user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ: المستخدم غير مسجل الدخول')));
      }
      return;
    }

    if (_isTogglingStatus) return;

    setState(() {
      _isTogglingStatus = true;
    });

    try {
      // Check if driver is blocked before going online
      if (value) {
        final profileAsync = await ref.read(driverProfileStreamProvider.future);
        if (profileAsync != null && profileAsync.isBlocked) {
          if (mounted) {
            context.go('/blocked');
            setState(() {
              _isTogglingStatus = false;
            });
          }
          return;
        }
      }

      // Check location disclosure acceptance before any location checks
      if (value) {
        final disclosureAccepted = await _checkLocationDisclosure();
        if (!disclosureAccepted) {
          if (mounted) {
            setState(() {
              _isTogglingStatus = false;
            });
          }
          return;
        }
      }

      // Check profile completeness before going online
      if (value) {
        final profileAsync = await ref.read(driverProfileStreamProvider.future);
        if (profileAsync == null || !_isProfileComplete(profileAsync)) {
          if (mounted) {
            _showProfileIncompleteDialog();
          }
          setState(() {
            _isTogglingStatus = false;
          });
          return;
        }

        // CRITICAL: Verify GPS/location prerequisites before going online
        if (kDebugMode) {
          dev.log('[DriverHome] Verifying location prerequisites...');
        }

        final locationError = await LocationService.instance.verifyLocationPrerequisites();
        if (locationError != null) {
          if (kDebugMode) {
            dev.log('[DriverHome] Location prerequisites failed: $locationError');
          }

          if (mounted) {
            _showLocationPrerequisitesDialog(locationError);
          }
          setState(() {
            _isTogglingStatus = false;
          });
          return;
        }

        if (kDebugMode) {
          dev.log('[DriverHome] ✅ Location prerequisites verified');
        }
      }

      // Set online/offline status
      if (value) {
        await DriverStatusService.instance.setOnline(authState.user!.uid);

        // Start tracking when going online (this will get first GPS fix)
        try {
          await TrackingService.instance.startTracking();
          _startLocationMonitoring();

          if (kDebugMode) {
            dev.log('[DriverHome] ✅ Tracking started with first GPS fix');
          }
        } on Object catch (trackingError) {
          if (kDebugMode) {
            dev.log('[DriverHome] ❌ Failed to start tracking: $trackingError');
            dev.log('[DriverHome] isOnline preserved — driver intent set, tracking will retry');
          }

          // Do NOT revert isOnline. Driver pressed "متصل" — intent is online.
          // Dispatch engine will skip via stale location filters.
          // Tracking will retry on next app resume via _resumeTrackingIfOnline().

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تعذر الحصول على موقعك. لن تصلك طلبات حتى يتوفر GPS.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
            setState(() {
              _isTogglingStatus = false;
            });
          }
          return;
        }
      } else {
        await DriverStatusService.instance.setOffline(authState.user!.uid);
        // Stop tracking when going offline
        TrackingService.instance.stopTracking();
        _stopLocationMonitoring();
      }

      if (mounted) {
        setState(() {
          _isTogglingStatus = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'أنت الآن متصل ومتاح للطلبات' : 'أنت الآن غير متصل'),
            backgroundColor: value ? Colors.green : Colors.grey,
          ),
        );
      }

      if (kDebugMode) {
        dev.log('[DriverHome] Driver toggled online status to: $value');
      }
    } on Object catch (e) {
      if (kDebugMode) {
        dev.log('[DriverHome] Error toggling status: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحديث الحالة: $e')));
        setState(() {
          _isTogglingStatus = false;
        });
      }
    }
  }

  Future<bool> _checkLocationDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('location_disclosure_accepted') ?? false;

    if (accepted) return true;

    if (!mounted) return false;

    // Show Prominent Disclosure
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('استخدام الموقع الجغرافي'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Icon(Icons.location_on, size: 48, color: DriverAppColors.primaryLight)),
            SizedBox(height: 16),
            Text(
              'يجمع تطبيق WawApp Driver بيانات موقعك الجغرافي لتمكين:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• استقبال طلبات النقل القريبة منك'),
            Text('• تتبع مسار الرحلة وتوجيه الركاب'),
            Text('• حساب المسافة والتكلفة بدقة'),
            SizedBox(height: 8),
            Text(
              'يتم جمع هذه البيانات حتى عندما يكون التطبيق مغلقاً أو غير مستخدم، مادمت في وضع "متصل".',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('رفض'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('موافق والمتابعة'),
          ),
        ],
      ),
    );

    if (result == true) {
      await prefs.setBool('location_disclosure_accepted', true);
      return true;
    }

    return false;
  }

  bool _isProfileComplete(DriverProfile profile) {
    return profile.name.isNotEmpty &&
        profile.vehicleType != null &&
        profile.vehicleType!.isNotEmpty &&
        profile.vehiclePlate != null &&
        profile.vehiclePlate!.isNotEmpty &&
        profile.city != null &&
        profile.city!.isNotEmpty;
  }

  void _showProfileIncompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('أكمل ملفك الشخصي'),
        content: const Text(
          'يجب عليك إكمال ملفك الشخصي قبل الاتصال. '
          'الرجاء ملء: الاسم، نوع السيارة، رقم اللوحة، والمدينة.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/profile/edit');
            },
            child: const Text('تعديل الملف الشخصي'),
          ),
        ],
      ),
    );
  }

  void _showLocationPrerequisitesDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('تفعيل الموقع مطلوب'),
        content: Text(
          '$errorMessage\n\n'
          'يجب تفعيل خدمات الموقع (GPS) والسماح للتطبيق بالوصول إلى موقعك '
          'حتى تتمكن من الاتصال واستقبال الطلبات.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // BLOCKED CHECK: redirect to /blocked if driver is blocked
    final isBlocked = ref.watch(driverBlockedProvider);
    if (isBlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/blocked');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Watch active orders — show banner if driver has an active trip
    final activeOrdersAsync = ref.watch(activeOrdersProvider);

    // Watch the online status stream (non-blocking, real-time)
    final onlineStatusAsync = ref.watch(driverOnlineStatusProvider);

    // Extract boolean value with default fallback
    final isOnline = onlineStatusAsync.when(
      data: (status) => status,
      loading: () => false, // Show offline during load
      error: (_, __) => false, // Show offline on error
    );

    // Get current user ID for daily summary
    final authState = ref.watch(authProvider);
    final driverId = authState.user?.uid;

    // Watch daily summary
    final dailySummaryAsync = driverId != null ? ref.watch(dailySummaryProvider(driverId)) : null;

    // ── Firestore backup listener: catch new dispatch offers when FCM is delayed ──
    ref.listen<AsyncValue<List<DispatchOffer>>>(dispatchOffersProvider, (previous, next) {
      final offers = next.asData?.value;
      if (offers == null || offers.isEmpty) return;
      if (!isOnline) return;
      final activeOrders = activeOrdersAsync.asData?.value ?? [];
      if (activeOrders.isNotEmpty) return;

      for (final offer in offers) {
        if (_firestoreHandledOffers.contains(offer.offerId)) continue;
        _firestoreHandledOffers.add(offer.offerId);
        _handleFirestoreOffer(offer);
        break; // handle one at a time; next offer processed on next emission
      }
    });

    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        key: const ValueKey('screen_home'),
        appBar: AppBar(
          title: Text(l10n.title),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.account_balance_wallet), onPressed: () => context.push('/wallet')),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'profile') {
                  context.push('/profile');
                } else if (value == 'signout') {
                  if (kDebugMode) {
                    dev.log('[DriverHome] Logout initiated by user');
                  }

                  await AnalyticsService.instance.logLogoutClicked();

                  // Use AuthNotifier.logout() instead of FirebaseAuth.signOut()
                  // This ensures proper state reset and cleanup
                  await ref.read(authProvider.notifier).logout();

                  if (kDebugMode) {
                    dev.log('[DriverHome] Logout complete, auth state reset');
                  }

                  // Navigation is handled by AuthGate watching authProvider
                  // No need for explicit context.go('/') which causes race condition
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'profile', child: Text('الملف الشخصي')),
                const PopupMenuItem(value: 'signout', child: Text('تسجيل الخروج')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Active Order Banner
            activeOrdersAsync.whenOrNull(
                  data: (orders) {
                    if (orders.isEmpty) return null;
                    final order = orders.first;
                    return GestureDetector(
                      onTap: () => context.push('/active-order'),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(
                          DriverAppSpacing.md,
                          DriverAppSpacing.md,
                          DriverAppSpacing.md,
                          0,
                        ),
                        padding: const EdgeInsets.all(DriverAppSpacing.md),
                        decoration: BoxDecoration(
                          color: order.status == 'onRoute' ? DriverAppColors.primaryLight : Colors.orange,
                          borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping, color: Colors.white),
                            const SizedBox(width: DriverAppSpacing.sm),
                            Expanded(
                              child: Text(
                                order.status == 'onRoute'
                                    ? 'لديك رحلة جارية — اضغط للعودة'
                                    : 'لديك طلب مقبول — اضغط لبدء الرحلة',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ) ??
                const SizedBox.shrink(),
            // Status Card
            Container(
              margin: const EdgeInsets.all(DriverAppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isOnline
                      ? [DriverAppColors.onlineGreen, DriverAppColors.onlineGreen.withOpacity(0.8)]
                      : [DriverAppColors.offlineGrey, DriverAppColors.offlineGrey.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(DriverAppSpacing.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: (isOnline ? DriverAppColors.onlineGreen : DriverAppColors.offlineGrey).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(DriverAppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnline ? l10n.online : l10n.offline,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: DriverAppSpacing.xxs),
                        Text(
                          isOnline ? 'جاهز لاستقبال الطلبات' : 'اذهب إلى الإنترنت لاستقبال الطلبات',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.9)),
                        ),
                      ],
                    ),
                    Switch(
                      value: isOnline,
                      onChanged: _isTogglingStatus ? null : _toggleOnlineStatus,
                      activeThumbColor: Colors.white,
                      activeTrackColor: Colors.white.withOpacity(0.5),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.white.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DriverAppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Quick Actions
                    Text(
                      'الإجراءات السريعة',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: DriverAppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: DriverCard(
                            onTap: () => context.push('/nearby'),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(DriverAppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: DriverAppColors.primaryLight.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.local_shipping,
                                    size: 32,
                                    color: DriverAppColors.primaryLight,
                                  ),
                                ),
                                const SizedBox(height: DriverAppSpacing.sm),
                                Text(
                                  'الطلبات القريبة',
                                  style: Theme.of(context).textTheme.titleSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: DriverAppSpacing.md),
                        Expanded(
                          child: DriverCard(
                            onTap: () => context.push('/earnings'),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(DriverAppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: DriverAppColors.secondaryLight.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet,
                                    size: 32,
                                    color: DriverAppColors.secondaryLight,
                                  ),
                                ),
                                const SizedBox(height: DriverAppSpacing.sm),
                                Text(
                                  'الأرباح',
                                  style: Theme.of(context).textTheme.titleSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DriverAppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: DriverCard(
                            onTap: () => context.push('/history'),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(DriverAppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: DriverAppColors.infoLight.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.history, size: 32, color: DriverAppColors.infoLight),
                                ),
                                const SizedBox(height: DriverAppSpacing.sm),
                                Text(
                                  'السجل',
                                  style: Theme.of(context).textTheme.titleSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: DriverAppSpacing.md),
                        Expanded(
                          child: DriverCard(
                            onTap: () => context.push('/wallet'),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(DriverAppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: DriverAppColors.successLight.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.wallet, size: 32, color: DriverAppColors.successLight),
                                ),
                                const SizedBox(height: DriverAppSpacing.sm),
                                Text(
                                  'المحفظة',
                                  style: Theme.of(context).textTheme.titleSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DriverAppSpacing.lg),
                    // Today's Summary
                    Text(
                      'ملخص اليوم',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: DriverAppSpacing.md),
                    dailySummaryAsync == null
                        ? DriverCard(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'عدد الرحلات',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.copyWith(color: DriverAppColors.textSecondaryLight),
                                        ),
                                        const SizedBox(height: DriverAppSpacing.xxs),
                                        Text(
                                          '0',
                                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: DriverAppColors.primaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(DriverAppSpacing.sm),
                                      decoration: BoxDecoration(
                                        color: DriverAppColors.primaryLight.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.local_shipping,
                                        size: 28,
                                        color: DriverAppColors.primaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: DriverAppSpacing.lg),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'الأرباح',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.copyWith(color: DriverAppColors.textSecondaryLight),
                                        ),
                                        const SizedBox(height: DriverAppSpacing.xxs),
                                        Text(
                                          '0 MRU',
                                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: DriverAppColors.successLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(DriverAppSpacing.sm),
                                      decoration: BoxDecoration(
                                        color: DriverAppColors.successLight.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.monetization_on,
                                        size: 28,
                                        color: DriverAppColors.successLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : dailySummaryAsync.when(
                            loading: () => const DriverCard(child: Center(child: CircularProgressIndicator())),
                            error: (error, stack) => DriverCard(child: Center(child: Text('خطأ: $error'))),
                            data: (summary) => DriverCard(
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'عدد الرحلات',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.copyWith(color: DriverAppColors.textSecondaryLight),
                                          ),
                                          const SizedBox(height: DriverAppSpacing.xxs),
                                          Text(
                                            '${summary.tripsCount}',
                                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: DriverAppColors.primaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(DriverAppSpacing.sm),
                                        decoration: BoxDecoration(
                                          color: DriverAppColors.primaryLight.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.local_shipping,
                                          size: 28,
                                          color: DriverAppColors.primaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: DriverAppSpacing.lg),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'الأرباح',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.copyWith(color: DriverAppColors.textSecondaryLight),
                                          ),
                                          const SizedBox(height: DriverAppSpacing.xxs),
                                          Text(
                                            '${summary.earnings.toStringAsFixed(2)} MRU',
                                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: DriverAppColors.successLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(DriverAppSpacing.sm),
                                        decoration: BoxDecoration(
                                          color: DriverAppColors.successLight.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.monetization_on,
                                          size: 28,
                                          color: DriverAppColors.successLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
