import 'package:auth_shared/auth_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_service_provider.dart';

/// PinGateScreen: Resolves the PIN status from unknown/loading/error to a known state.
///
/// This screen is shown when:
/// - PinStatus is unknown (initial state before checking)
/// - PinStatus is loading (actively checking Firestore for PIN)
/// - PinStatus is error (check failed, retry available)
///
/// The router redirects away once PinStatus becomes hasPin or noPin.
class PinGateScreen extends ConsumerWidget {
  const PinGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final notifier = ref.read(authProvider.notifier);

    // If no user, render nothing (should not happen, router should redirect)
    if (authState.user == null) {
      if (kDebugMode) {
        print('[PIN_GATE] ⚠️ No user present - should redirect to /login');
      }
      return const SizedBox.shrink();
    }

    // If pinStatus is unknown, trigger a check once
    if (authState.pinStatus == PinStatus.unknown) {
      if (kDebugMode) {
        print('[PIN_GATE] 🔍 PinStatus unknown, triggering checkHasPin');
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.checkHasPin();
      });
    }

    final isError = authState.pinStatus == PinStatus.error;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                isError
                    ? 'تعذر التحقق من الـ PIN. حاول مرة أخرى.'
                    : 'جارٍ التحقق من إعداد الـ PIN…',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (isError) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (kDebugMode) {
                      print('[PIN_GATE] 🔄 User requested retry');
                    }
                    notifier.checkHasPin();
                  },
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
