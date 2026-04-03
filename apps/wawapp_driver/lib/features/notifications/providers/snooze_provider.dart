import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SnoozeState {
  const SnoozeState({
    this.pendingReminders = const {},
    this.snoozedOrderIds = const [],
  });

  final Map<String, Timer> pendingReminders;
  final List<String> snoozedOrderIds;

  SnoozeState copyWith({
    Map<String, Timer>? pendingReminders,
    List<String>? snoozedOrderIds,
  }) {
    return SnoozeState(
      pendingReminders: pendingReminders ?? this.pendingReminders,
      snoozedOrderIds: snoozedOrderIds ?? this.snoozedOrderIds,
    );
  }
}

class SnoozeNotifier extends StateNotifier<SnoozeState> {
  SnoozeNotifier() : super(const SnoozeState());

  static const _snoozeDuration = Duration(minutes: 5);

  void scheduleReminder(String orderId, VoidCallback onShowAgain) {
    // Cancel existing timer for this order if any
    state.pendingReminders[orderId]?.cancel();

    final timer = Timer(_snoozeDuration, () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .get();

        if (doc.exists && doc.data()!['status'] == 'matching') {
          onShowAgain();
        }
      } on Object catch (e) {
        debugPrint('[SnoozeProvider] Error checking order $orderId: $e');
      }

      // Clean up after execution
      _removeReminder(orderId);
    });

    state = state.copyWith(
      pendingReminders: {...state.pendingReminders, orderId: timer},
      snoozedOrderIds: [...state.snoozedOrderIds, orderId],
    );
  }

  void cancelReminder(String orderId) {
    state.pendingReminders[orderId]?.cancel();
    _removeReminder(orderId);
  }

  void cancelAllReminders() {
    for (final timer in state.pendingReminders.values) {
      timer.cancel();
    }
    state = const SnoozeState();
  }

  void _removeReminder(String orderId) {
    final reminders = Map<String, Timer>.from(state.pendingReminders)
      ..remove(orderId);
    final ids = state.snoozedOrderIds.where((id) => id != orderId).toList();
    state = state.copyWith(
      pendingReminders: reminders,
      snoozedOrderIds: ids,
    );
  }

  @override
  void dispose() {
    cancelAllReminders();
    super.dispose();
  }
}

final snoozeProvider =
    StateNotifierProvider<SnoozeNotifier, SnoozeState>((ref) {
  return SnoozeNotifier();
});
