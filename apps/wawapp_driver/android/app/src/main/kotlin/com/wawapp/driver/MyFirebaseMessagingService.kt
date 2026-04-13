package com.wawapp.driver

import android.app.ActivityManager
import android.content.Context
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
 * When app is in FOREGROUND, this handler skips native notification
 * because Flutter handles direct navigation to full-screen UI.
 * Native notification in foreground shows as heads-up (Android limitation),
 * so Flutter's direct navigation provides a better UX.
 */
class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val type = message.data["notificationType"]
            ?: message.data["type"]
            ?: return

        val orderId = message.data["orderId"] ?: ""

        Log.d(TAG, "Native FCM received: type=$type, orderId=$orderId, foreground=${isAppInForeground()}")

        // Route notifications based on type and app state
        when {
            // Critical notifications: Full-screen (background only)
            type in listOf(
                "new_order",
                "new_order_nearby",
                "unassigned_order_reminder",
                "trip_start_reminder"
            ) -> {
                if (isAppInForeground()) {
                    Log.d(TAG, "Critical notification in foreground → defer to Flutter")
                    return
                }
                handleCriticalNotification(message, type, orderId)
            }

            // Non-critical notifications: Simple heads-up (all states)
            type in listOf(
                "acceptance_confirmation",
                "order_update"
            ) -> {
                if (isAppInForeground()) {
                    Log.d(TAG, "Non-critical notification in foreground → defer to Flutter")
                    return
                }
                handleSimpleNotification(message, type, orderId)
            }

            else -> {
                Log.d(TAG, "Unknown notification type: $type → ignoring")
            }
        }
    }

    /**
     * Handle critical notifications with full-screen intent (background only).
     * trip_start_reminder uses a heads-up notification so Flutter opens TripStartReminderScreen.
     * new_order / unassigned_order_reminder use full-screen intent via FullScreenNotificationActivity.
     */
    private fun handleCriticalNotification(message: RemoteMessage, type: String, orderId: String) {
        Log.d(TAG, "Handling critical notification: type=$type, orderId=$orderId")

        NotificationHelper.createNotificationChannels(applicationContext)

        val pickupLabel = message.data["pickupLabel"] ?: "موقع الاستلام"
        val dropoffLabel = message.data["dropoffLabel"]
            ?: message.data["destinationLabel"]
            ?: "الوجهة"

        if (type == "trip_start_reminder") {
            val elapsedMinutes = message.data["elapsedMinutes"]?.toIntOrNull() ?: 0
            NotificationHelper.showTripReminderNotification(
                context = applicationContext,
                orderId = orderId,
                title = message.data["title"] ?: "هل وصلت للعميل؟",
                body = "مضى $elapsedMinutes دقائق منذ القبول — $pickupLabel",
                pickupLabel = pickupLabel,
                destinationLabel = dropoffLabel,
                elapsedMinutes = elapsedMinutes
            )
        } else {
            NotificationHelper.showFullScreenNotification(
                context = applicationContext,
                orderId = orderId,
                title = message.data["title"] ?: "طلب جديد قريب منك",
                body = "$pickupLabel → $dropoffLabel",
                pickupLabel = pickupLabel,
                dropoffLabel = dropoffLabel,
                price = message.data["price"]?.toDoubleOrNull() ?: 0.0,
                distance = message.data["distance"]?.toDoubleOrNull() ?: 0.0,
                createdAt = message.data["createdAt"]?.toLongOrNull() ?: System.currentTimeMillis(),
                notificationType = type
            )
        }

        Log.d(TAG, "Notification shown for order $orderId, type=$type")
    }

    /**
     * Handle non-critical notifications with simple heads-up (no full-screen).
     */
    private fun handleSimpleNotification(message: RemoteMessage, type: String, orderId: String) {
        Log.d(TAG, "Handling simple notification: type=$type, orderId=$orderId")

        // Ensure channels exist
        NotificationHelper.createNotificationChannels(applicationContext)

        val title = message.data["title"] ?: when (type) {
            "acceptance_confirmation" -> "تم قبول الطلب"
            "order_update" -> "تحديث الطلب"
            else -> "إشعار"
        }

        val body = message.data["body"] ?: ""

        // Show simple heads-up notification (no full-screen)
        NotificationHelper.showSimpleNotification(
            context = applicationContext,
            orderId = orderId,
            title = title,
            body = body,
            notificationType = type
        )

        Log.d(TAG, "Simple notification shown for order $orderId")
    }

    private fun isAppInForeground(): Boolean {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val appProcesses = am.runningAppProcesses ?: return false
        val packageName = applicationContext.packageName
        return appProcesses.any {
            it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
                it.processName == packageName
        }
    }

    companion object {
        private const val TAG = "MyFCMService"
    }
}
