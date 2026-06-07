import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

/// Service for handling Firebase Cloud Messaging (push notifications).
class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;
  MessagingService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final NotificationService _notificationService = NotificationService();

  /// Initializes FCM and requests permissions.
  Future<String?> initialize() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }

    // Get FCM token
    final token = await _messaging.getToken();

    // Initialize local notifications
    await _notificationService.initialize();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    return token;
  }

  /// Gets the current FCM token.
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Listens for token refresh.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Subscribes to a topic.
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Unsubscribes from a topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  /// Handles foreground messages by showing local notification.
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _notificationService.showNotification(
        id: message.hashCode,
        title: notification.title ?? '',
        body: notification.body ?? '',
        payload: message.data['orderId'],
      );
    }
  }

  /// Handles when app is opened from a notification.
  void _handleMessageOpenedApp(RemoteMessage message) {
    // Navigate to the relevant order
    // This will be handled by the app-specific implementation
  }
}

/// Top-level function for handling background messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message
  // Firebase is already initialized when this is called
}
