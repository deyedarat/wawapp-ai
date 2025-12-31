import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import '../data/driver_earnings_repository.dart';
import '../../auth/providers/auth_service_provider.dart';
import '../../../core/config/testlab_flags.dart';
import '../../../core/config/testlab_mock_data.dart';

class DriverEarningsState {
  final List<Order> completedOrders;
  final int todayTotal;
  final int weekTotal;
  final int monthTotal;
  final bool isLoading;
  final String? error;

  const DriverEarningsState({
    this.completedOrders = const [],
    this.todayTotal = 0,
    this.weekTotal = 0,
    this.monthTotal = 0,
    this.isLoading = false,
    this.error,
  });

  DriverEarningsState copyWith({
    List<Order>? completedOrders,
    int? todayTotal,
    int? weekTotal,
    int? monthTotal,
    bool? isLoading,
    String? error,
  }) {
    return DriverEarningsState(
      completedOrders: completedOrders ?? this.completedOrders,
      todayTotal: todayTotal ?? this.todayTotal,
      weekTotal: weekTotal ?? this.weekTotal,
      monthTotal: monthTotal ?? this.monthTotal,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class DriverEarningsNotifier extends StateNotifier<DriverEarningsState> {
  final DriverEarningsRepository _repository;
  final Ref _ref;
  StreamSubscription<List<Order>>? _earningsSubscription;
  ProviderSubscription? _authSubscription;

  DriverEarningsNotifier(this._repository, this._ref)
      : super(const DriverEarningsState()) {
    _watchAuth();
  }

  void _watchAuth() {
    _authSubscription = _ref.listen(authProvider, (previous, next) {
      _loadEarnings(next.user);
    });
    // Load initial earnings
    final authState = _ref.read(authProvider);
    _loadEarnings(authState.user);
  }

  void _loadEarnings(User? user) {
    _earningsSubscription?.cancel();
    
    if (user == null) {
      state = const DriverEarningsState();
      return;
    }

    // Return mock earnings for Test Lab mode
    if (TestLabFlags.safeEnabled) {
      final mockOrders = TestLabMockData.mockCompletedOrders;
      state = DriverEarningsState(
        completedOrders: mockOrders,
        todayTotal: 1500, // Mock today's earnings
        weekTotal: 8400, // Mock week's earnings
        monthTotal: 32100, // Mock month's earnings
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    _earningsSubscription = _repository.watchCompletedOrdersForDriver(user.uid).listen(
      (orders) {
        final todayTotal = _repository.totalForToday(orders);
        final weekTotal = _repository.totalForCurrentWeek(orders);
        final monthTotal = _repository.totalForCurrentMonth(orders);

        state = state.copyWith(
          completedOrders: orders,
          todayTotal: todayTotal,
          weekTotal: weekTotal,
          monthTotal: monthTotal,
          isLoading: false,
        );
      },
      onError: (error) {
        state = state.copyWith(
          isLoading: false,
          error: error.toString(),
        );
      },
    );
  }

  @override
  void dispose() {
    _earningsSubscription?.cancel();
    _authSubscription?.close();
    super.dispose();
  }
}

final driverEarningsRepositoryProvider =
    Provider<DriverEarningsRepository>((ref) {
  return DriverEarningsRepository();
});

final driverEarningsProvider =
    StateNotifierProvider.autoDispose<DriverEarningsNotifier, DriverEarningsState>((ref) {
  final repository = ref.watch(driverEarningsRepositoryProvider);
  return DriverEarningsNotifier(repository, ref);
});
