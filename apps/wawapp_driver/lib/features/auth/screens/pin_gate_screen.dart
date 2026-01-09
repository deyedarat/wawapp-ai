import 'package:auth_shared/auth_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_service_provider.dart';

class PinGateScreen extends ConsumerWidget {
  const PinGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(authProvider);
    final notifier = ref.read(authProvider.notifier);

    if (kDebugMode) {
      debugPrint(
          '[PIN_GATE] Building screen | user=${st.user?.uid ?? 'null'} | pinStatus=${st.pinStatus}');
    }

    // If not logged in, this screen shouldn't be valid, but we handle it gracefully/safely
    if (st.user == null) {
      if (kDebugMode) {
        debugPrint('[PIN_GATE] No user - returning empty widget');
      }
      return const SizedBox.shrink();
    }

    // If status is unknown, trigger check
    // Using addPostFrameCallback to avoid unsafe provider calls during build
    if (st.pinStatus == PinStatus.unknown) {
      if (kDebugMode) {
        debugPrint('[PIN_GATE] PinStatus is unknown - scheduling PIN check');
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (kDebugMode) {
          debugPrint('[PIN_GATE] Triggering PIN check via notifier');
        }
        notifier.checkHasPin();
      });
    }

    final isError = st.pinStatus == PinStatus.error;

    return Scaffold(
      key: const ValueKey('screen_pin_gate'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                isError
                    ? 'تعذر التحقق من الـ PIN. حاول مرة أخرى.'
                    : 'جارٍ التحقق من إعداد الـ PIN…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (isError) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (kDebugMode) {
                      debugPrint('[PIN_GATE] User requested retry');
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
