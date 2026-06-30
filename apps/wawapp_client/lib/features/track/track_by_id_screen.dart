import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:core_shared/core_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/components.dart';
import 'track_screen.dart';

/// Screen that loads an order by ID and displays it in TrackScreen
///
/// This wrapper screen:
/// 1. Fetches the full Order object from Firestore using the orderId
/// 2. Verifies the user owns the order (security check)
/// 3. Passes the complete Order object to TrackScreen
///
/// This ensures completed orders show full details (driver, vehicle, etc.)
/// instead of the incomplete data from PublicTrackScreen.
class TrackByIdScreen extends ConsumerWidget {
  final String orderId;

  const TrackByIdScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // User not authenticated - redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/login');
        }
      });
      return const Scaffold(
        body: Center(child: WawLoadingIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: WawLoadingIndicator()),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('خطأ')),
            body: WawEmptyState(
              icon: Icons.error_outline,
              title: 'حدث خطأ',
              message: 'فشل تحميل بيانات الطلب',
              action: WawActionButton(
                label: 'العودة',
                isFullWidth: false,
                onPressed: () => context.pop(),
              ),
            ),
          );
        }

        // Order not found
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('غير موجود')),
            body: WawEmptyState(
              icon: Icons.search_off,
              title: 'الطلب غير موجود',
              message: 'لم يتم العثور على الطلب المطلوب',
              action: WawActionButton(
                label: 'العودة',
                isFullWidth: false,
                onPressed: () => context.pop(),
              ),
            ),
          );
        }

        // Parse order data
        final orderData = snapshot.data!.data() as Map<String, dynamic>;
        final order = Order.fromFirestore({...orderData, 'id': orderId});

        // Security check: Verify user owns this order
        if (order.ownerId != currentUser.uid) {
          debugPrint(
            '[TrackById] SECURITY: User tried to access order they do not own: '
            'orderId=$orderId, ownerId=${order.ownerId}, uid=${currentUser.uid}',
          );
          return Scaffold(
            appBar: AppBar(title: const Text('غير مصرح')),
            body: WawEmptyState(
              icon: Icons.lock_outline,
              title: 'غير مصرح',
              message: 'ليس لديك صلاحية لعرض هذا الطلب',
              action: WawActionButton(
                label: 'العودة',
                isFullWidth: false,
                onPressed: () => context.pop(),
              ),
            ),
          );
        }

        // Success: Display the order with full details
        return TrackScreen(order: order);
      },
    );
  }
}
