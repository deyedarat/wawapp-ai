import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/driver_status_service.dart';
import '../../../core/config/testlab_flags.dart';
import '../../auth/providers/auth_service_provider.dart';

/// Provides a stream of the current driver's online status
///
/// Returns:
/// - `true` when driver is online
/// - `false` when driver is offline or not authenticated
/// - Test Lab mode: always returns `false`
final driverOnlineStatusProvider = StreamProvider.autoDispose<bool>((ref) {
  // Return mock status for Test Lab mode
  if (TestLabFlags.safeEnabled) {
    return Stream.value(false);
  }

  final authState = ref.watch(authProvider);
  if (authState.user == null) {
    return Stream.value(false);
  }

  // Watch driver's online status from Firestore (real-time updates)
  return DriverStatusService.instance.watchOnlineStatus(authState.user!.uid);
});
