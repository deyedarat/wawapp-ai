import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import '../../../services/topup_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Provider for TopupService
final topupServiceProvider = Provider<TopupService>((ref) {
  return TopupService();
});

/// Provider for bank apps configuration
final bankAppsProvider = FutureProvider<List<BankAppConfig>>((ref) async {
  final service = ref.watch(topupServiceProvider);
  return service.getBankApps();
});

/// Provider for top-up requests stream
final topupRequestsStreamProvider = StreamProvider.autoDispose<List<TopupRequestModel>>((ref) {
  final service = ref.watch(topupServiceProvider);
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return Stream.value([]);
  }

  return service.getTopupRequestsStream(user.uid);
});

/// Provider for pending requests count
final pendingTopupsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final service = ref.watch(topupServiceProvider);
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return Stream.value(0);
  }

  return service.getPendingCountStream(user.uid);
});

/// State provider for wizard step
final topupWizardStepProvider = StateProvider<int>((ref) => 0);

/// State provider for selected bank app
final selectedBankAppProvider = StateProvider<BankAppConfig?>((ref) => null);

/// State provider for amount
final topupAmountProvider = StateProvider<int?>((ref) => null);

/// State provider for sender phone
final senderPhoneProvider = StateProvider<String?>((ref) => null);
