import 'package:flutter_riverpod/flutter_riverpod.dart';

// State class
class AuthState {
  final bool loading;
  final String? error;
  const AuthState({this.loading = false, this.error});
  AuthState copyWith({bool? loading, String? error}) =>
      AuthState(loading: loading ?? this.loading, error: error);
}

// Controller
class AuthController extends StateNotifier<AuthState> {
  AuthController(): super(const AuthState());

  Future<void> login({required String phone, required String pin}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      // TODO: Move Bloc logic here
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }
}

// Provider
final authControllerProvider =
  StateNotifierProvider<AuthController, AuthState>((ref) => AuthController());
