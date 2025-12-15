import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'breadcrumb_service.dart';
import 'crashlytics_keys_manager.dart';

/// Monitors network connectivity for Phase 2 resilience
class NetworkMonitor {
  static final NetworkMonitor _instance = NetworkMonitor._internal();
  factory NetworkMonitor() => _instance;
  NetworkMonitor._internal();

  final _connectivity = Connectivity();
  final _breadcrumbs = BreadcrumbService();
  final _crashlytics = CrashlyticsKeysManager();
  
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;
  String _networkType = NetworkTypeValues.wifi;

  /// Initialize network monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _updateConnectivity(result);

    // Listen for connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectivity);
  }

  /// Get current online status
  bool get isOnline => _isOnline;

  /// Get current network type
  String get networkType => _networkType;

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    
    // Determine if we have any connection
    _isOnline = results.any((result) => 
      result != ConnectivityResult.none
    );

    // Determine network type
    if (!_isOnline) {
      _networkType = NetworkTypeValues.offline;
    } else if (results.contains(ConnectivityResult.wifi)) {
      _networkType = NetworkTypeValues.wifi;
    } else if (results.contains(ConnectivityResult.mobile)) {
      _networkType = NetworkTypeValues.cellular;
    } else {
      _networkType = NetworkTypeValues.wifi; // Default assumption
    }

    // Log state change
    if (wasOnline != _isOnline) {
      if (_isOnline) {
        _breadcrumbs.add(
          action: BreadcrumbActions.networkRestored,
          screen: 'system',
          metadata: {'network_type': _networkType},
        );
      } else {
        _breadcrumbs.add(
          action: BreadcrumbActions.networkLost,
          screen: 'system',
        );
      }
    }

    // Update Crashlytics context
    _crashlytics.setSessionContext(
      appVersion: '', // Will be set by app initialization
      platform: '', // Will be set by app initialization
      networkType: _networkType,
    );
  }

  /// Check if online before performing critical operations
  /// Returns error message if offline, null if online
  String? checkOnlineOrGetError() {
    if (!_isOnline) {
      _breadcrumbs.add(
        action: BreadcrumbActions.orderCreateFailed,
        screen: 'order_creation',
        metadata: {'reason': 'offline'},
      );
      return 'No internet connection. Please check your network and try again.';
    }
    return null;
  }
}
