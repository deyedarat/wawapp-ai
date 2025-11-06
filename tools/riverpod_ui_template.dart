import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Replace BlocBuilder with Consumer
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    
    // Replace BlocListener with ref.listen
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    if (state.loading) return const CircularProgressIndicator();

    return ElevatedButton(
      onPressed: () => ref.read(authControllerProvider.notifier).login(
        phone: 'phone',
        pin: 'pin',
      ),
      child: const Text('Login'),
    );
  }
}
