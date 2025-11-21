import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import '../data/client_profile_repository.dart';
import '../../../services/analytics_service.dart';

final clientProfileRepositoryProvider = Provider<ClientProfileRepository>((ref) {
  return ClientProfileRepository(firestore: FirebaseFirestore.instance);
});

final clientProfileStreamProvider = StreamProvider<ClientProfile?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value(null);
  }

  final repository = ref.watch(clientProfileRepositoryProvider);
  return repository.watchProfile(user.uid).map((profile) {
    if (profile != null) {
      // Update user properties when profile loads
      AnalyticsService.instance.setUserProperties(
        userId: user.uid,
        totalOrders: profile.totalOrders,
        isVerified: profile.isVerified,
      );
      
      // ANALYTICS VALIDATION:
      // DebugView should show: user_type=client, total_orders, is_verified
    }
    return profile;
  });
});

final savedLocationsStreamProvider = StreamProvider<List<SavedLocation>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(clientProfileRepositoryProvider);
  return repository.watchSavedLocations(user.uid);
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

  ClientProfileNotifier(this._repository)
      : super(const ClientProfileUpdateState());

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

final clientProfileNotifierProvider =
    StateNotifierProvider<ClientProfileNotifier, ClientProfileUpdateState>((ref) {
  final repository = ref.watch(clientProfileRepositoryProvider);
  return ClientProfileNotifier(repository);
});

class SavedLocationsNotifier extends StateNotifier<ClientProfileUpdateState> {
  final ClientProfileRepository _repository;

  SavedLocationsNotifier(this._repository)
      : super(const ClientProfileUpdateState());

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

final savedLocationsNotifierProvider =
    StateNotifierProvider<SavedLocationsNotifier, ClientProfileUpdateState>((ref) {
  final repository = ref.watch(clientProfileRepositoryProvider);
  return SavedLocationsNotifier(repository);
});