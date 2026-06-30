import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'driver_status_service.dart';
import 'tracking_service.dart';

/// Service to monitor network connectivity and handle Firestore reconnection
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasOffline = false;

  /// Callback fired when connectivity is lost (for UI notification)
  VoidCallback? onConnectivityLost;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      // Check initial connectivity status
      final result = await _connectivity.checkConnectivity();
      final isOnline = result.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);

      if (kDebugMode) {
        print(
            '📡 Initial connectivity: ${result.join(", ")} (Online: $isOnline)');
      }

      // If online at startup, trigger initial Firestore connection after delay
      if (isOnline) {
        // Wait 2 seconds for DNS to be ready, then force reconnect
        Future.delayed(const Duration(seconds: 2), () {
          _reconnectFirestore();
        });
      }

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _handleConnectivityChange,
        onError: (error) {
          if (kDebugMode) {
            print('⚠️ Connectivity monitoring error: $error');
          }
        },
      );

      if (kDebugMode) {
        print('✅ Connectivity monitoring initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to initialize connectivity monitoring: $e');
      }
    }
  }

  /// Handle connectivity changes
  Future<void> _handleConnectivityChange(List<ConnectivityResult> results) async {
    final isOnline = results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);

    if (kDebugMode) {
      print(
          '📡 Connectivity changed: ${results.join(", ")} (Online: $isOnline)');
    }

    if (isOnline && _wasOffline) {
      // Device came back online - force Firestore to reconnect
      _reconnectFirestore();
      _wasOffline = false;

      // Do NOT call setOnline() here. Driver online status is controlled
      // ONLY by the manual toggle. If the driver was online before losing
      // connectivity, resume tracking so location stays fresh.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final wasOnline = await DriverStatusService.instance.getOnlineStatus(uid);
        if (wasOnline) {
          await TrackingService.instance.startTracking();
          if (kDebugMode) {
            print('📡 Connectivity restored — resuming tracking (driver was online)');
          }
        }
      }
    } else if (!isOnline) {
      _wasOffline = true;
      if (kDebugMode) {
        print('📴 Device offline - stopping tracking');
      }
      // Stop tracking to avoid stale writes, but do NOT change isOnline.
      // isOnline is controlled ONLY by the manual toggle.
      TrackingService.instance.stopTracking();
      onConnectivityLost?.call();
    }
  }

  /// Force Firestore to reconnect by disabling/enabling network
  void _reconnectFirestore() {
    if (kDebugMode) {
      print('🔄 Reconnecting Firestore...');
    }

    try {
      // Disable network briefly to clear stale connections
      FirebaseFirestore.instance.disableNetwork().then((_) {
        // Re-enable network to establish fresh connection
        FirebaseFirestore.instance.enableNetwork().then((_) {
          if (kDebugMode) {
            print('✅ Firestore reconnected successfully');
          }
        }).catchError((error) {
          if (kDebugMode) {
            print('⚠️ Failed to enable Firestore network: $error');
          }
        });
      }).catchError((error) {
        if (kDebugMode) {
          print('⚠️ Failed to disable Firestore network: $error');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Firestore reconnection error: $e');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    if (kDebugMode) {
      print('🛑 Connectivity monitoring disposed');
    }
  }
}
