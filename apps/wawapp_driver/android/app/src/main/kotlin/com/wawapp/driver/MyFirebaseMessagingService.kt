package com.wawapp.driver

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Native FCM handler that calls NotificationHelper.kt directly.
 *
 * This runs BEFORE Flutter's background handler, ensuring:
 * - Proper fullScreenIntent via FullScreenNotificationActivity
 * - Sound repetition via SoundRepeatReceiver (AlarmManager)
 * - bypassDnd via v6 channels
 * - Works even when app is killed or screen is locked
 *
 * Flutter's _firebaseMessagingBackgroundHandler still runs for logging/analytics.
 */
class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val type = message.data["notificationType"]
            ?: message.data["type"]
            ?: return

        val orderId = message.data["orderId"] ?: ""

        // Only handle critical order notifications via Native path.
        // Other types (acceptance_confirmation, order_updates) are handled by Flutter.
        if (type !in listOf(
                "new_order",
                "new_order_nearby",
                "unassigned_order_reminder",
                "trip_start_reminder"
            )
        ) {
            return
        }

        Log.d(TAG, "Native FCM: type=$type, orderId=$orderId")

        // Ensure channels exist (idempotent — safe to call multiple times)
        NotificationHelper.createNotificationChannels(applicationContext)

        val pickupLabel = message.data["pickupLabel"] ?: "موقع الاستلام"
        val dropoffLabel = message.data["dropoffLabel"]
            ?: message.data["destinationLabel"]
            ?: "الوجهة"

        val isTripReminder = type == "trip_start_reminder"
        val title = if (isTripReminder) {
            message.data["title"] ?: "هل وصلت للعميل؟"
        } else {
            message.data["title"] ?: "طلب جديد قريب منك"
        }
        val body = if (isTripReminder) {
            "مضى ${message.data["elapsedMinutes"] ?: "?"} دقائق منذ القبول — $pickupLabel"
        } else {
            "$pickupLabel → $dropoffLabel"
        }

        NotificationHelper.showFullScreenNotification(
            context = applicationContext,
            orderId = orderId,
            title = title,
            body = body,
            pickupLabel = pickupLabel,
            dropoffLabel = dropoffLabel,
            price = message.data["price"]?.toDoubleOrNull() ?: 0.0,
            distance = message.data["distance"]?.toDoubleOrNull() ?: 0.0,
            createdAt = message.data["createdAt"]?.toLongOrNull()
                ?: System.currentTimeMillis(),
            notificationType = type
        )

        Log.d(TAG, "Native notification shown for order $orderId")
    }

    companion object {
        private const val TAG = "MyFCMService"
    }
}
