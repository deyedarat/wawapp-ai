import 'dart:collection';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'waw_log.dart';

/// Breadcrumb system for Phase 2 observability
/// Maintains last 50 actions before crash for debugging
class BreadcrumbService {
  static final BreadcrumbService _instance = BreadcrumbService._internal();
  factory BreadcrumbService() => _instance;
  BreadcrumbService._internal();

  final Queue<Breadcrumb> _breadcrumbs = Queue<Breadcrumb>();
  static const int _maxBreadcrumbs = 50;

  /// Add a breadcrumb with required Phase 2 fields
  void add({
    required String action,
    required String screen,
    String? userId,
    Map<String, dynamic>? metadata,
  }) {
    final breadcrumb = Breadcrumb(
      timestamp: DateTime.now(),
      action: action,
      screen: screen,
      userId: userId,
      metadata: metadata ?? {},
    );

    _breadcrumbs.addLast(breadcrumb);
    if (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeFirst();
    }

    // Log to Crashlytics
    FirebaseCrashlytics.instance.log(breadcrumb.toString());
    
    // Also log to console for debugging
    WawLog.d('Breadcrumb', breadcrumb.toString());
  }

  /// Get all breadcrumbs (for debugging or crash reports)
  List<Breadcrumb> getAll() => _breadcrumbs.toList();

  /// Get breadcrumbs as formatted string
  String getFormattedHistory() {
    return _breadcrumbs.map((b) => b.toString()).join('\n');
  }

  /// Clear all breadcrumbs (typically not used, but available for testing)
  void clear() {
    _breadcrumbs.clear();
  }
}

/// Breadcrumb data model
class Breadcrumb {
  final DateTime timestamp;
  final String action;
  final String screen;
  final String? userId;
  final Map<String, dynamic> metadata;

  Breadcrumb({
    required this.timestamp,
    required this.action,
    required this.screen,
    this.userId,
    required this.metadata,
  });

  @override
  String toString() {
    final userInfo = userId != null ? ' [user:$userId]' : '';
    final meta = metadata.isNotEmpty ? ' meta:$metadata' : '';
    return '[${timestamp.toIso8601String()}] $screen > $action$userInfo$meta';
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'action': action,
    'screen': screen,
    if (userId != null) 'userId': userId,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
}

/// Phase 2 required breadcrumb actions (as constants for consistency)
class BreadcrumbActions {
  // Auth
  static const phoneVerificationStarted = 'phone_verification_started';
  static const otpRequested = 'otp_requested';
  static const otpEntered = 'otp_entered';
  static const tokenRefreshAttempt = 'token_refresh_attempt';
  static const tokenRefreshSuccess = 'token_refresh_success';
  static const tokenRefreshFailed = 'token_refresh_failed';
  static const loginSuccess = 'login_success';
  static const loginFailed = 'login_failed';
  static const logout = 'logout';
  static const logoutWithActiveOrder = 'logout_with_active_order';
  static const authVerificationInterrupted = 'auth_verification_interrupted';

  // Orders (Client)
  static const orderFormOpened = 'order_form_opened';
  static const pickupLocationSelected = 'pickup_location_selected';
  static const dropoffLocationSelected = 'dropoff_location_selected';
  static const orderCreateInitiated = 'order_create_initiated';
  static const orderCreateSuccess = 'order_create_success';
  static const orderCreateFailed = 'order_create_failed';
  static const orderCancelled = 'order_cancelled';
  static const orderStateRestored = 'order_state_restored';

  // Orders (Driver)
  static const orderListViewed = 'order_list_viewed';
  static const orderAcceptTapped = 'order_accept_tapped';
  static const orderAccepted = 'order_accepted';
  static const tripStarted = 'trip_started';
  static const tripCompleted = 'trip_completed';
  static const driverToggledOnline = 'driver_toggled_online';
  static const driverToggledOffline = 'driver_toggled_offline';
  static const goOfflineBlocked = 'go_offline_blocked';
  static const activeOrderRestored = 'active_order_restored';

  // App Lifecycle
  static const appForegrounded = 'app_foregrounded';
  static const appBackgrounded = 'app_backgrounded';
  static const appKilledDetected = 'app_killed_detected';
  static const appKilledWithActiveOrder = 'app_killed_with_active_order';
  static const appForceStoppedDetected = 'app_force_stopped';

  // Network
  static const networkLost = 'network_lost';
  static const networkRestored = 'network_restored';
  static const firestoreWriteFailed = 'firestore_write_failed';
  static const firestoreListenerDisconnected = 'firestore_listener_disconnected';
  static const listenersReconnected = 'listeners_reconnected';

  // Stuck States
  static const orderStuckPending = 'order_stuck_pending';
  static const orderStuckAccepting = 'order_stuck_accepting';
  static const actionTimeout = 'action_timeout';
  static const driverToggleTimeout = 'driver_toggle_timeout';
  static const paymentTimeout = 'payment_timeout';
}
