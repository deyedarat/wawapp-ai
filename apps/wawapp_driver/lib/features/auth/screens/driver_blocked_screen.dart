import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_service_provider.dart';

class DriverBlockedScreen extends ConsumerWidget {
  const DriverBlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'تم تعليق حسابك',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'تواصل مع الدعم لمزيد من المعلومات',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
