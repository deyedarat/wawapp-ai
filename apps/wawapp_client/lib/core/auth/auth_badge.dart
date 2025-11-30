import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_service_provider.dart';

class AuthBadge extends ConsumerWidget {
  const AuthBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final short = authState.user?.uid.substring(0, 6) ?? 'none';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('anon:$short', style: const TextStyle(color: Colors.white)),
    );
  }
}

// Legacy function for backward compatibility
Widget authBadge() => const AuthBadge();
