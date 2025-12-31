import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import '../../../services/in_app_notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Provider for InAppNotificationService
final inAppNotificationServiceProvider = Provider<InAppNotificationService>((ref) {
  return InAppNotificationService();
});

/// Provider for notifications list stream
final notificationsStreamProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final service = ref.watch(inAppNotificationServiceProvider);
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return Stream.value([]);
  }

  return service.getNotificationsStream(user.uid);
});

/// Provider for unread count stream
final unreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final service = ref.watch(inAppNotificationServiceProvider);
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return Stream.value(0);
  }

  return service.getUnreadCountStream(user.uid);
});
