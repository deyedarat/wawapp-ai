import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import '../data/driver_earnings_repository.dart';

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
  late final StreamSubscription<List<Order>> _earningsSubscription;

  DriverEarningsNotifier(this._repository)
      : super(const DriverEarningsState()) {
    _loadEarnings();
  }

  void _loadEarnings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      state = state.copyWith(error: 'User not authenticated');
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
    _earningsSubscription.cancel();
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
  return DriverEarningsNotifier(repository);
});
