package com.wawapp.driver

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Helper class for creating high-priority, full-screen intent notifications
 * that behave like incoming phone calls.
 *
 * Sound repetition strategy:
 * - Main notification plays sound once via channel settings.
 * - 2 additional plays are scheduled via AlarmManager → SoundRepeatReceiver
 *   at +2s and +4s. AlarmManager.setExactAndAllowWhileIdle() ensures
 *   delivery even in Doze mode.
 * - Repeats are cancelled when notification is tapped/dismissed or order
 *   is accepted/rejected.
 */
object NotificationHelper {

    private const val TAG = "NotificationHelper"

    private const val CHANNEL_ID_NEW_ORDERS = "new_orders_v6"
    private const val CHANNEL_ID_UNASSIGNED_ORDERS = "unassigned_orders_v6"
    private const val CHANNEL_ID_TRIP_REMINDERS = "trip_reminders_v6"

    private const val PREFS_NAME = "sound_repeat_prefs"
    private const val REPEAT_DELAY_1_MS = 2000L
    private const val REPEAT_DELAY_2_MS = 4000L

    // =========================================================================
    // Channel creation
    // =========================================================================

    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            deleteOldChannels(nm)

            val soundUri = Uri.parse("android.resource://${context.packageName}/raw/trip_reminder")
            val audioAttrs = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build()

            fun maxChannel(id: String, name: String, desc: String) =
                NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH).apply {
                    description = desc
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    setSound(soundUri, audioAttrs)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) setAllowBubbles(true)
                    setBypassDnd(true)
                }

            nm.createNotificationChannel(
                maxChannel(CHANNEL_ID_NEW_ORDERS, "طلبات جديدة - أولوية قصوى",
                    "إشعارات الطلبات الجديدة مثل المكالمات الهاتفية")
            )
            nm.createNotificationChannel(
                maxChannel(CHANNEL_ID_UNASSIGNED_ORDERS, "تذكير بطلبات متاحة - أولوية قصوى",
                    "تذكيرات بالطلبات المتاحة القريبة منك")
            )
            nm.createNotificationChannel(
                maxChannel(CHANNEL_ID_TRIP_REMINDERS, "تذكيرات بدء الرحلة - أولوية قصوى",
                    "تذكيرات للسائق لبدء الرحلة بعد القبول")
            )
        }
    }

    private fun deleteOldChannels(nm: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        listOf(
            "new_orders", "new_orders_v2", "new_orders_v3", "new_orders_v4", "new_orders_v5",
            "unassigned_orders", "unassigned_orders_v2", "unassigned_orders_v3",
            "unassigned_orders_v4", "unassigned_orders_v5",
            "trip_reminders", "trip_reminders_v5",
            "order_updates", "acceptance_confirmations"
        ).forEach { id ->
            try { nm.deleteNotificationChannel(id) } catch (_: Exception) {}
        }
    }

    // =========================================================================
    // Full-screen notification
    // =========================================================================

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
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val channelId = when (notificationType) {
            "trip_start_reminder" -> CHANNEL_ID_TRIP_REMINDERS
            "unassigned_order_reminder" -> CHANNEL_ID_UNASSIGNED_ORDERS
            else -> CHANNEL_ID_NEW_ORDERS
        }

        val fullScreenIntent = createFullScreenPendingIntent(
            context, orderId, pickupLabel, dropoffLabel, price, distance, createdAt, notificationType
        )

        // Delete intent: cancel sound repeats when notification is dismissed
        val deleteIntent = createDeletePendingIntent(context, orderId)

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setFullScreenIntent(fullScreenIntent, true)
            .setContentIntent(fullScreenIntent)
            .setDeleteIntent(deleteIntent)
            .setVibrate(longArrayOf(0, 500, 200, 500, 200, 500))
            .setSound(Uri.parse("android.resource://${context.packageName}/raw/trip_reminder"))
            .setTimeoutAfter(60000)
            .build()

        val notificationId = orderId.hashCode()
        nm.notify(notificationId, notification)

        Log.d(TAG, "Full-screen notification shown: id=$notificationId, order=$orderId")

        // Schedule 2 sound repeats via AlarmManager (main notification already plays sound once)
        scheduleSoundRepeats(context, orderId, notificationId)
    }

    // =========================================================================
    // PendingIntent builders
    // =========================================================================

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
            context, orderId.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * PendingIntent fired when user swipes away the notification.
     * Cancels pending sound repeats.
     */
    private fun createDeletePendingIntent(context: Context, orderId: String): PendingIntent {
        val intent = Intent(context, NotificationDismissReceiver::class.java).apply {
            action = "com.wawapp.driver.NOTIFICATION_DISMISSED"
            putExtra("orderId", orderId)
        }
        return PendingIntent.getBroadcast(
            context, orderId.hashCode() + 10000, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    // =========================================================================
    // Sound repeat scheduling via AlarmManager
    // =========================================================================

    private fun scheduleSoundRepeats(context: Context, orderId: String, notificationId: Int) {
        // Mark repeats as pending
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean("pending_$orderId", true)
            .apply()

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Schedule repeat 1 at +2s
        scheduleOneRepeat(context, am, orderId, notificationId, REPEAT_DELAY_1_MS, requestCodeOffset = 1)
        // Schedule repeat 2 at +4s
        scheduleOneRepeat(context, am, orderId, notificationId, REPEAT_DELAY_2_MS, requestCodeOffset = 2)

        Log.d(TAG, "Sound repeats scheduled for order $orderId at +${REPEAT_DELAY_1_MS}ms, +${REPEAT_DELAY_2_MS}ms")
    }

    private fun scheduleOneRepeat(
        context: Context,
        am: AlarmManager,
        orderId: String,
        notificationId: Int,
        delayMs: Long,
        requestCodeOffset: Int
    ) {
        val intent = Intent(context, SoundRepeatReceiver::class.java).apply {
            action = SoundRepeatReceiver.ACTION
            putExtra(SoundRepeatReceiver.EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(SoundRepeatReceiver.EXTRA_ORDER_ID, orderId)
        }
        val requestCode = orderId.hashCode() + 20000 + requestCodeOffset
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val triggerAt = SystemClock.elapsedRealtime() + delayMs

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
            } else {
                am.setExact(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
            }
        } catch (e: SecurityException) {
            // Exact alarm permission not granted — fall back to inexact
            Log.w(TAG, "Exact alarm not allowed, using inexact: ${e.message}")
            am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
        }
    }

    // =========================================================================
    // Cancellation
    // =========================================================================

    /**
     * Cancel pending sound repeats for an order.
     * Call when: notification tapped, dismissed, order accepted/rejected.
     */
    fun cancelSoundRepeats(context: Context, orderId: String) {
        // Clear pending flag
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove("pending_$orderId")
            .apply()

        // Cancel AlarmManager PendingIntents
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (offset in 1..2) {
            val intent = Intent(context, SoundRepeatReceiver::class.java).apply {
                action = SoundRepeatReceiver.ACTION
            }
            val requestCode = orderId.hashCode() + 20000 + offset
            val pi = PendingIntent.getBroadcast(
                context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            am.cancel(pi)
            pi.cancel()
        }

        // Also cancel any leftover repeat notifications (legacy cleanup)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(orderId.hashCode() + 1)
        nm.cancel(orderId.hashCode() + 2)

        Log.d(TAG, "Sound repeats cancelled for order $orderId")
    }

    /**
     * Check if an order still has pending sound repeats.
     */
    fun hasPendingRepeats(context: Context, orderId: String): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean("pending_$orderId", false)
    }
}
