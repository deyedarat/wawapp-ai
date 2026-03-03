import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PIN attempt tracking state
class PinAttemptState {
  final int attempts;
  final DateTime? lockoutUntil;

  const PinAttemptState({
    required this.attempts,
    this.lockoutUntil,
  });

  bool get isLocked {
    if (lockoutUntil == null) return false;
    return DateTime.now().isBefore(lockoutUntil!);
  }

  int get remainingAttempts => 5 - attempts;

  Duration get lockoutDuration {
    if (lockoutUntil == null) return Duration.zero;
    final remaining = lockoutUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Provider for PIN attempt tracking
class PinAttemptNotifier extends StateNotifier<PinAttemptState> {
  PinAttemptNotifier() : super(const PinAttemptState(attempts: 0));

  static const _maxAttempts = 5;
  static const _lockoutDuration = Duration(minutes: 15);
  static const _prefKey = 'pin_attempts';
  static const _lockoutKey = 'pin_lockout_until';

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = prefs.getInt(_prefKey) ?? 0;
    final lockoutMillis = prefs.getInt(_lockoutKey);
    
    DateTime? lockoutUntil;
    if (lockoutMillis != null) {
      lockoutUntil = DateTime.fromMillisecondsSinceEpoch(lockoutMillis);
      // If lockout expired, reset
      if (DateTime.now().isAfter(lockoutUntil)) {
        await reset();
        return;
      }
    }

    state = PinAttemptState(
      attempts: attempts,
      lockoutUntil: lockoutUntil,
    );
  }

  Future<void> recordFailedAttempt() async {
    final newAttempts = state.attempts + 1;
    
    if (newAttempts >= _maxAttempts) {
      // Lock the account
      final lockoutUntil = DateTime.now().add(_lockoutDuration);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lockoutKey, lockoutUntil.millisecondsSinceEpoch);
      await prefs.setInt(_prefKey, newAttempts);
      
      state = PinAttemptState(
        attempts: newAttempts,
        lockoutUntil: lockoutUntil,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, newAttempts);
      
      state = PinAttemptState(
        attempts: newAttempts,
        lockoutUntil: null,
      );
    }
  }

  Future<void> recordSuccessfulAttempt() async {
    await reset();
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    await prefs.remove(_lockoutKey);
    state = const PinAttemptState(attempts: 0);
  }
}

/// Provider instance
final pinAttemptProvider = StateNotifierProvider<PinAttemptNotifier, PinAttemptState>((ref) {
  final notifier = PinAttemptNotifier();
  notifier.loadState();
  return notifier;
});
