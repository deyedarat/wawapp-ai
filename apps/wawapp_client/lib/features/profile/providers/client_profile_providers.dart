import 'package:auth_shared/auth_shared.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/analytics_service.dart';
import '../../auth/providers/auth_service_provider.dart';
import '../data/client_profile_repository.dart';

final clientProfileRepositoryProvider = Provider<ClientProfileRepository>((ref) {
  return ClientProfileRepository(firestore: FirebaseFirestore.instance);
});

final clientProfileStreamProvider = StreamProvider.autoDispose<ClientProfile?>((ref) {
  final authState = ref.watch(authProvider);

  // CRITICAL: Use the new isStreamsSafeToRun flag to prevent permission errors
  // This flag is set to false BEFORE any auth transitions (OTP, PIN reset, logout)
  if (!authState.isStreamsSafeToRun || authState.user == null) {
    if (kDebugMode && !authState.isStreamsSafeToRun) {
      print('[ClientProfile] Streams disabled by auth system - stopping Firestore stream');
    }
    return Stream.value(null);
  }

  // Defensive: Capture UID in local variable to prevent race condition
  final uid = authState.user!.uid;

  final repository = ref.watch(clientProfileRepositoryProvider);
  return repository.watchProfile(uid).handleError((error) {
    // Gracefully handle permission errors that may occur during race conditions
    if (kDebugMode) {
      print('[ClientProfile] Stream error (likely during transition): $error');
    }
    return null;
  }).map((profile) {
    if (profile != null) {
      // Schedule analytics call after current frame to avoid build-phase side-effects
      // This prevents "setState() called during build" errors
      Future.microtask(() {
        AnalyticsService.instance.setUserProperties(
          userId: uid,
          totalOrders: profile.totalTrips,
        );
      });

      // ANALYTICS VALIDATION:
      // DebugView should show: user_type=client, total_orders, is_verified
    }
    return profile;
  });
});

final savedLocationsStreamProvider = StreamProvider.autoDispose<List<SavedLocation>>((ref) {
  final authState = ref.watch(authProvider);

  // Use the same stream safety check
  if (!authState.isStreamsSafeToRun || authState.user == null) {
    return Stream.value([]);
  }

  final uid = authState.user!.uid;
  final repository = ref.watch(clientProfileRepositoryProvider);
  return repository.watchSavedLocations(uid).handleError((error) {
    if (kDebugMode) {
      print('[SavedLocations] Stream error (likely during transition): $error');
    }
    return <SavedLocation>[];
  });
});

class ClientProfileUpdateState {
  final bool isLoading;
  final String? error;

  const ClientProfileUpdateState({
    this.isLoading = false,
    this.error,
  });

  ClientProfileUpdateState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return ClientProfileUpdateState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ClientProfileNotifier extends StateNotifier<ClientProfileUpdateState> {
  final ClientProfileRepository _repository;

  ClientProfileNotifier(this._repository) : super(const ClientProfileUpdateState());

  Future<void> updateProfile(ClientProfile profile) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.updateProfile(profile);
      state = const ClientProfileUpdateState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updatePhotoUrl(String userId, String photoUrl) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.updatePhotoUrl(userId, photoUrl);
      state = const ClientProfileUpdateState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createProfile(ClientProfile profile) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.createProfile(profile);
      state = const ClientProfileUpdateState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final clientProfileNotifierProvider = StateNotifierProvider<ClientProfileNotifier, ClientProfileUpdateState>((ref) {
  final repository = ref.watch(clientProfileRepositoryProvider);
  return ClientProfileNotifier(repository);
});

class SavedLocationsNotifier extends StateNotifier<ClientProfileUpdateState> {
  final ClientProfileRepository _repository;

  SavedLocationsNotifier(this._repository) : super(const ClientProfileUpdateState());

  Future<void> addLocation(String userId, SavedLocation location) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.addSavedLocation(userId, location);
      state = const ClientProfileUpdateState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateLocation(String userId, SavedLocation location) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.updateSavedLocation(userId, location);
      state = const ClientProfileUpdateState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteLocation(String userId, String locationId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.deleteSavedLocation(userId, locationId);
      state = const ClientProfileUpdateState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final savedLocationsNotifierProvider = StateNotifierProvider<SavedLocationsNotifier, ClientProfileUpdateState>((ref) {
  final repository = ref.watch(clientProfileRepositoryProvider);
  return SavedLocationsNotifier(repository);
});
