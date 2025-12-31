import 'package:auth_shared/auth_shared.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/testlab_flags.dart';
import '../../../core/config/testlab_mock_data.dart';
import '../../../services/analytics_service.dart';
import '../../auth/providers/auth_service_provider.dart';
import '../data/driver_profile_repository.dart';

final driverProfileRepositoryProvider =
    Provider<DriverProfileRepository>((ref) {
  return DriverProfileRepository(firestore: FirebaseFirestore.instance);
});

final driverProfileStreamProvider =
    StreamProvider.autoDispose<DriverProfile?>((ref) {
  // Return mock profile for Test Lab mode
  if (TestLabFlags.safeEnabled) {
    return Stream.value(TestLabMockData.mockDriverProfile);
  }

  final authState = ref.watch(authProvider);

  // CRITICAL: Use the new isStreamsSafeToRun flag to prevent permission errors
  // This flag is set to false BEFORE any auth transitions (OTP, PIN reset, logout)
  if (!authState.isStreamsSafeToRun || authState.user == null) {
    if (kDebugMode && !authState.isStreamsSafeToRun) {
      print(
          '[DriverProfile] Streams disabled by auth system - stopping Firestore stream');
    }
    return Stream.value(null);
  }

  // Defensive: Capture UID in local variable to prevent race condition
  final uid = authState.user!.uid;

  final repository = ref.watch(driverProfileRepositoryProvider);
  return repository.watchProfile(uid).handleError((error) {
    // Gracefully handle permission errors that may occur during race conditions
    if (kDebugMode) {
      print('[DriverProfile] Stream error (likely during transition): $error');
    }
    return null;
  }).map((profile) {
    if (profile != null) {
      // Update driver-specific properties when profile loads
      AnalyticsService.instance.setUserProperties(
        userId: uid,
        totalTrips: profile.totalTrips,
        averageRating: profile.rating,
        isVerified: profile.isVerified,
      );

      // ANALYTICS VALIDATION:
      // DebugView should show: user_type=driver, total_trips, average_rating, is_verified
    }
    return profile;
  });
});

class DriverProfileUpdateState {
  final bool isLoading;
  final String? error;

  const DriverProfileUpdateState({
    this.isLoading = false,
    this.error,
  });

  DriverProfileUpdateState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return DriverProfileUpdateState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DriverProfileNotifier extends StateNotifier<DriverProfileUpdateState> {
  final DriverProfileRepository _repository;

  DriverProfileNotifier(this._repository)
      : super(const DriverProfileUpdateState());

  Future<void> updateProfile(DriverProfile profile) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.updateProfile(profile);
      state = const DriverProfileUpdateState();
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updatePhotoUrl(String driverId, String photoUrl) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.updatePhotoUrl(driverId, photoUrl);
      state = const DriverProfileUpdateState();
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createProfile(DriverProfile profile) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.createProfile(profile);
      state = const DriverProfileUpdateState();
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final driverProfileNotifierProvider =
    StateNotifierProvider<DriverProfileNotifier, DriverProfileUpdateState>(
        (ref) {
  final repository = ref.watch(driverProfileRepositoryProvider);
  return DriverProfileNotifier(repository);
});
