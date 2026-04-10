package com.wawapp.driver

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Helper class for creating high-priority, full-screen intent notifications
 * that behave like incoming phone calls.
 *
 * Features:
 * - Full-screen intent (wakes screen + bypasses lock screen)
 * - Bypasses Do Not Disturb mode
 * - Maximum priority (like phone calls)
 * - Custom sound and vibration
 */
object NotificationHelper {

    private const val CHANNEL_ID_NEW_ORDERS = "new_orders_v6"
    private const val CHANNEL_ID_UNASSIGNED_ORDERS = "unassigned_orders_v6"
    private const val CHANNEL_ID_TRIP_REMINDERS = "trip_reminders_v6"

    /**
     * Creates notification channels with maximum priority and call-like behavior.
     * Must be called before showing any notifications.
     */
    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Delete old channels to force fresh creation with new settings
            deleteOldChannels(notificationManager)

            // Channel 1: New Orders - highest priority
            val newOrdersChannel = NotificationChannel(
                CHANNEL_ID_NEW_ORDERS,
                "7D('* ,/J/) - #HDHJ) B5HI",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "%49'1'* 'D7D('* 'D,/J/) - #HDHJ) E+D 'DEC'DE'* 'DG'*AJ)"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC

                // Custom sound
                val soundUri = Uri.parse("android.resource://${context.packageName}/raw/trip_reminder")
                setSound(soundUri, AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build())

                // Bypass Do Not Disturb (requires ACCESS_NOTIFICATION_POLICY permission)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    setAllowBubbles(true)
                }
                setBypassDnd(true)
            }

            // Channel 2: Unassigned Orders Reminder - highest priority
            val unassignedOrdersChannel = NotificationChannel(
                CHANNEL_ID_UNASSIGNED_ORDERS,
                "*0CJ1 (7D('* E*'-) - #HDHJ) B5HI",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "*0CJ1'* ('D7D('* 'DE*'-) 'DB1J() EFC"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC

                val soundUri = Uri.parse("android.resource://${context.packageName}/raw/trip_reminder")
                setSound(soundUri, AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build())

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    setAllowBubbles(true)
                }
                setBypassDnd(true)
            }

            // Channel 3: Trip Start Reminders - highest priority
            val tripRemindersChannel = NotificationChannel(
                CHANNEL_ID_TRIP_REMINDERS,
                "*0CJ1'* (/! 'D1-D) - #HDHJ) B5HI",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "*0CJ1'* DD3'&B D(/! 'D1-D) (9/ 'DB(HD"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC

                val soundUri = Uri.parse("android.resource://${context.packageName}/raw/trip_reminder")
                setSound(soundUri, AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build())

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    setAllowBubbles(true)
                }
                setBypassDnd(true)
            }

            notificationManager.createNotificationChannel(newOrdersChannel)
            notificationManager.createNotificationChannel(unassignedOrdersChannel)
            notificationManager.createNotificationChannel(tripRemindersChannel)
        }
    }

    /**
     * Delete old notification channels to force fresh creation with updated settings.
     */
    private fun deleteOldChannels(notificationManager: NotificationManager) {
        val oldChannels = listOf(
            "new_orders", "new_orders_v2", "new_orders_v3", "new_orders_v4", "new_orders_v5",
            "unassigned_orders", "unassigned_orders_v2", "unassigned_orders_v3", "unassigned_orders_v4", "unassigned_orders_v5",
            "trip_reminders", "trip_reminders_v5",
            "order_updates", "acceptance_confirmations"
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            oldChannels.forEach { channelId ->
                try {
                    notificationManager.deleteNotificationChannel(channelId)
                } catch (e: Exception) {
                    // Ignore errors - channel may not exist
                }
            }
        }
    }

    /**
     * Creates a PendingIntent that launches FullScreenNotificationActivity
     * with the order data.
     */
    fun createFullScreenPendingIntent(
        context: Context,
        orderId: String,
        pickupLabel: String,
        dropoffLabel: String,
        price: Double,
        distance: Double,
        createdAt: Long,
        notificationType: String
    ): PendingIntent {
        val intent = Intent(context, FullScreenNotificationActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("orderId", orderId)
            putExtra("pickupLabel", pickupLabel)
            putExtra("dropoffLabel", dropoffLabel)
            putExtra("price", price)
            putExtra("distance", distance)
            putExtra("createdAt", createdAt)
            putExtra("notificationType", notificationType)
        }

        return PendingIntent.getActivity(
            context,
            orderId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * Shows a full-screen intent notification with maximum priority.
     * This notification will:
     * - Wake the screen (even if locked)
     * - Show full-screen UI immediately
     * - Bypass Do Not Disturb mode
     * - Play sound 3 times
     * - Vibrate with custom pattern
     */
    fun showFullScreenNotification(
        context: Context,
        orderId: String,
        title: String,
        body: String,
        pickupLabel: String,
        dropoffLabel: String,
        price: Double,
        distance: Double,
        createdAt: Long,
        notificationType: String
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Determine channel based on notification type
        val channelId = when (notificationType) {
            "trip_start_reminder" -> CHANNEL_ID_TRIP_REMINDERS
            "unassigned_order_reminder" -> CHANNEL_ID_UNASSIGNED_ORDERS
            else -> CHANNEL_ID_NEW_ORDERS
        }

        // Create full-screen intent
        val fullScreenIntent = createFullScreenPendingIntent(
            context, orderId, pickupLabel, dropoffLabel, price, distance, createdAt, notificationType
        )

        // Build notification with full-screen intent
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher) // You should use your app's icon
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setFullScreenIntent(fullScreenIntent, true) //  This launches the activity immediately
            .setContentIntent(fullScreenIntent) //  This launches when user taps notification
            .setVibrate(longArrayOf(0, 500, 200, 500, 200, 500))
            .setSound(Uri.parse("android.resource://${context.packageName}/raw/trip_reminder"))
            .setTimeoutAfter(60000) // Auto-dismiss after 60 seconds
            .build()

        // Show notification
        val notificationId = orderId.hashCode()
        notificationManager.notify(notificationId, notification)

        // Repeat sound 2 more times (Android system only plays sound once per notification)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            // Second sound
            val notification2 = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setSound(Uri.parse("android.resource://${context.packageName}/raw/trip_reminder"))
                .setOnlyAlertOnce(false)
                .setAutoCancel(true)
                .build()
            notificationManager.notify(notificationId + 1, notification2)
        }, 1500)

        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            // Third sound
            val notification3 = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setSound(Uri.parse("android.resource://${context.packageName}/raw/trip_reminder"))
                .setOnlyAlertOnce(false)
                .setAutoCancel(true)
                .build()
            notificationManager.notify(notificationId + 2, notification3)

            // Clean up extra notifications after 3 seconds
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                notificationManager.cancel(notificationId + 1)
                notificationManager.cancel(notificationId + 2)
            }, 3000)
        }, 3000)
    }
}
