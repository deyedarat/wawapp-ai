import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import '../data/driver_profile_repository.dart';

final driverProfileRepositoryProvider = Provider<DriverProfileRepository>((ref) {
  return DriverProfileRepository(firestore: FirebaseFirestore.instance);
});

final driverProfileStreamProvider = StreamProvider<DriverProfile?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value(null);
  }

  final repository = ref.watch(driverProfileRepositoryProvider);
  return repository.watchProfile(user.uid);
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
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updatePhotoUrl(String driverId, String photoUrl) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.updatePhotoUrl(driverId, photoUrl);
      state = const DriverProfileUpdateState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createProfile(DriverProfile profile) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.createProfile(profile);
      state = const DriverProfileUpdateState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final driverProfileNotifierProvider =
    StateNotifierProvider<DriverProfileNotifier, DriverProfileUpdateState>((ref) {
  final repository = ref.watch(driverProfileRepositoryProvider);
  return DriverProfileNotifier(repository);
});
