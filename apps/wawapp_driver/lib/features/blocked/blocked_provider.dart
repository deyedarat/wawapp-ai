import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/testlab_flags.dart';
import '../auth/providers/auth_service_provider.dart';
import '../profile/providers/driver_profile_providers.dart';

/// Watches driver's blocked status from the profile stream.
/// Returns true if driver is blocked, false otherwise.
final driverBlockedProvider = Provider.autoDispose<bool>((ref) {
  if (TestLabFlags.safeEnabled) return false;

  final authState = ref.watch(authProvider);
  if (authState.user == null) return false;

  final profileAsync = ref.watch(driverProfileStreamProvider);
  return profileAsync.whenOrNull(
        data: (profile) => profile?.isBlocked ?? false,
      ) ??
      false;
});
