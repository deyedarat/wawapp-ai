import 'package:auth_shared/auth_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_service_provider.dart';

class PinGateScreen extends ConsumerWidget {
  const PinGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(authProvider);
    final notifier = ref.read(authProvider.notifier);

    // If not logged in, this screen shouldn't be valid, but we handle it gracefully/safely
    if (st.user == null) {
      return const SizedBox.shrink();
    }

    // If status is unknown, trigger check
    // Using addPostFrameCallback to avoid unsafe provider calls during build
    if (st.pinStatus == PinStatus.unknown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.checkHasPin();
      });
    }

    final isError = st.pinStatus == PinStatus.error;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                isError ? 'تعذر التحقق من الـ PIN. حاول مرة أخرى.' : 'جارٍ التحقق من إعداد الـ PIN…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (isError) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => notifier.checkHasPin(),
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
