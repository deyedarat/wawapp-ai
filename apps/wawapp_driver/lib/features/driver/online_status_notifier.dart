import 'package:flutter_riverpod/flutter_riverpod.dart';

class DriverOnlineNotifier extends StateNotifier<bool> {
  DriverOnlineNotifier() : super(false);

  void toggle() => state = !state;
  void setOnline(bool value) => state = value;
}

final driverOnlineProvider =
    StateNotifierProvider<DriverOnlineNotifier, bool>((ref) {
  return DriverOnlineNotifier();
});
