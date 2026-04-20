package com.wawapp.driver

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ProcessLifecycleOwner
import com.google.android.gms.tasks.Tasks
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import java.util.concurrent.TimeUnit

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

    override fun onCreate() {
        super.onCreate()
        // Ensure notification channels exist before any message arrives.
        // Critical for killed-state: Android uses channelId from FCM notification
        // block and needs the channel to already exist.
        NotificationHelper.createNotificationChannels(applicationContext)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        val type = message.data["notificationType"]
            ?: message.data["type"]
            ?: return

        val orderId = message.data["orderId"] ?: ""

        Log.d(TAG, "Native FCM received: type=$type, orderId=$orderId, foreground=${isAppInForeground()}, hasNotification=${message.notification != null}")

        // When app is in foreground and message has a notification block,
        // Android auto-displays it in the system tray. We suppress that here
        // because Flutter handles foreground display directly (full-screen UI).
        // For background/killed state, the notification block is the safety net.

        // Route notifications based on type and app state
        when {
            // Critical notifications: Full-screen (background only)
            type in listOf(
                "new_order",
                "wave_offer",
                "new_order_nearby",
                "unassigned_order_reminder",
                "trip_start_reminder"
            ) -> {
                if (isAppInForeground()) {
                    Log.d(TAG, "Critical notification in foreground → forwarding to Flutter via FcmForegroundBridge")
                    // Cancel any system-displayed notification from the notification block
                    // to prevent duplicate (Flutter handles foreground display directly)
                    if (orderId.isNotBlank()) {
                        val nm = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
                        nm.cancel(orderId.hashCode())
                    }
                    FcmForegroundBridge.sendMessage(message.data)
                    return
                }
                // Verify order is still valid before showing notification (race condition fix)
                if (orderId.isNotBlank()) {
                    Thread {
                        val isValid = when (type) {
                            "trip_start_reminder" -> isOrderStillAccepted(orderId)
                            else -> isOrderStillMatching(orderId)
                        }
                        if (isValid) {
                            handleCriticalNotification(message, type, orderId)
                        } else {
                            Log.d(TAG, "Stale notification dropped: orderId=$orderId, type=$type")
                        }
                    }.start()
                } else {
                    handleCriticalNotification(message, type, orderId)
                }
            }

            // Non-critical notifications: Simple heads-up (all states)
            type in listOf(
                "acceptance_confirmation",
                "order_update"
            ) -> {
                if (isAppInForeground()) {
                    Log.d(TAG, "Non-critical notification in foreground → forwarding to Flutter via FcmForegroundBridge")
                    if (orderId.isNotBlank()) {
                        val nm = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
                        nm.cancel(orderId.hashCode())
                    }
                    FcmForegroundBridge.sendMessage(message.data)
                    return
                }
                handleSimpleNotification(message, type, orderId)
            }

            // Informational notifications: show simple notification
            type in listOf(
                "order_cancelled",
                "order_cancelled_by_client",
                "timeout_expired",
                "order_expired_driver",
                "payment_received",
                "order_completed",
                "trip_cancelled_by_client"
            ) -> {
                if (isAppInForeground()) {
                    if (orderId.isNotBlank()) {
                        val nm = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
                        nm.cancel(orderId.hashCode())
                    }
                    FcmForegroundBridge.sendMessage(message.data)
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

        val messageId = message.data["messageId"]
        val pickupLabel = message.data["pickupLabel"] ?: "موقع الاستلام"
        val dropoffLabel = message.data["dropoffLabel"]
            ?: message.data["destinationLabel"]
            ?: "الوجهة"

        // Use unified CallStyle full-screen notification for all critical types
        val price = message.data["price"]?.toDoubleOrNull() ?: 0.0
        val distance = message.data["distance"]?.toDoubleOrNull() ?: 0.0
        val createdAt = message.data["createdAt"]?.toLongOrNull() ?: System.currentTimeMillis()

        NotificationHelper.showFullScreenNotification(
            context = applicationContext,
            orderId = orderId,
            messageId = messageId,
            title = message.data["title"] ?: when (type) {
                "trip_start_reminder" -> "هل وصلت للعميل؟"
                else -> "طلب جديد قريب منك"
            },
            body = if (type == "trip_start_reminder") {
                val elapsedMinutes = message.data["elapsedMinutes"]?.toIntOrNull() ?: 0
                "مضى $elapsedMinutes دقائق منذ القبول — $pickupLabel"
            } else {
                "$pickupLabel → $dropoffLabel"
            },
            pickupLabel = pickupLabel,
            dropoffLabel = dropoffLabel,
            price = price,
            distance = distance,
            createdAt = createdAt,
            notificationType = type
        )

        Log.d(TAG, "Notification shown for order $orderId, type=$type")

        // Force-launch FullScreenNotificationActivity directly for order types.
        // Android shows heads-up instead of fullScreenIntent when screen is unlocked;
        // this ensures the driver always sees the full-screen UI like a phone call.
        // trip_start_reminder is excluded — it routes through MainActivity via fullScreenIntent.
        if (type != "trip_start_reminder") {
            try {
                val notificationId = (message.data["messageId"] ?: orderId).hashCode()
                val fsIntent = Intent(applicationContext, FullScreenNotificationActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION
                    putExtra("orderId", orderId)
                    putExtra("pickupLabel", pickupLabel)
                    putExtra("dropoffLabel", dropoffLabel)
                    putExtra("price", price)
                    putExtra("distance", distance)
                    putExtra("notificationType", type)
                    putExtra("notificationId", notificationId)
                }
                applicationContext.startActivity(fsIntent)
                Log.d(TAG, "FullScreenNotificationActivity launched directly for order $orderId")
            } catch (e: Exception) {
                Log.w(TAG, "Direct activity launch failed (notification fallback active): ${e.message}")
            }
        } else {
            // trip_start_reminder: launch MainActivity directly so Flutter shows TripStartReminderScreen
            // Mirrors exactly what createFullScreenPendingIntent() does for this type.
            try {
                val reminderIntent = Intent(applicationContext, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION
                    putExtra("action", "trip_start_reminder")
                    putExtra("orderId", orderId)
                    putExtra("pickupLabel", pickupLabel)
                    putExtra("destinationLabel", dropoffLabel)
                    putExtra("createdAt", createdAt.toString())
                }
                applicationContext.startActivity(reminderIntent)
                Log.d(TAG, "MainActivity launched directly for trip_start_reminder: $orderId")
            } catch (e: Exception) {
                Log.w(TAG, "Direct trip reminder launch failed (notification fallback active): ${e.message}")
            }
        }
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
        // ProcessLifecycleOwner uses the same internal mechanism as Firebase SDK,
        // ensuring Kotlin and Flutter always agree on foreground state.
        return ProcessLifecycleOwner.get().lifecycle.currentState
            .isAtLeast(Lifecycle.State.STARTED)
    }

    /**
     * One-time Firestore read to verify order is still in 'matching' status
     * and unassigned. Runs on background thread. Fail-open on error.
     */
    private fun isOrderStillMatching(orderId: String): Boolean {
        return try {
            val task = FirebaseFirestore.getInstance()
                .collection("orders")
                .document(orderId)
                .get()
            val snapshot = Tasks.await(task, 5, TimeUnit.SECONDS)
            val status = snapshot.getString("status")
            val assignedDriverId = snapshot.getString("assignedDriverId")
            val isMatching = status == "matching" && assignedDriverId == null
            Log.d(TAG, "Order check: orderId=$orderId, status=$status, assigned=$assignedDriverId, isMatching=$isMatching")
            isMatching
        } catch (e: Exception) {
            Log.w(TAG, "Order check failed (fail-open): orderId=$orderId, error=${e.message}")
            true // fail open — show notification if check fails
        }
    }

    /**
     * One-time Firestore read to verify order is still in 'accepted' status.
     * Used for trip_start_reminder validation. Runs on background thread. Fail-open on error.
     */
    private fun isOrderStillAccepted(orderId: String): Boolean {
        return try {
            val task = FirebaseFirestore.getInstance()
                .collection("orders")
                .document(orderId)
                .get()
            val snapshot = Tasks.await(task, 5, TimeUnit.SECONDS)
            val status = snapshot.getString("status")
            val isAccepted = status == "accepted"
            Log.d(TAG, "Trip reminder check: orderId=$orderId, status=$status, isAccepted=$isAccepted")
            isAccepted
        } catch (e: Exception) {
            Log.w(TAG, "Trip reminder check failed (fail-open): orderId=$orderId, error=${e.message}")
            true // fail open — show notification if check fails
        }
    }

    companion object {
        private const val TAG = "MyFCMService"
    }
}
