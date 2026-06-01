package com.wawapp.driver

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.ProcessLifecycleOwner

/**
 * Helper class for creating high-priority, full-screen intent notifications
 * that behave like incoming phone calls.
 *
 * Sound repetition strategy:
 * - Main notification plays sound once at t=0.
 * - 7 additional plays are scheduled at +8s intervals via Handler + AlarmManager.
 *   Total coverage: ~56s (until driver responds or notification TTL expires).
 * - AlarmManager.setExactAndAllowWhileIdle() ensures delivery in Doze mode.
 * - Repeats are cancelled when notification is tapped/dismissed or order
 *   is accepted/rejected.
 */
object NotificationHelper {

    private const val TAG = "NotificationHelper"

    private const val CHANNEL_ID_NEW_ORDERS = "new_orders_v11"
    private const val CHANNEL_ID_UNASSIGNED_ORDERS = "unassigned_orders_v10"
    private const val CHANNEL_ID_TRIP_REMINDERS = "trip_reminders_v10"
    private const val CHANNEL_ID_ORDER_UPDATES = "order_updates_v2"
    private const val CHANNEL_ID_ACCEPTANCE = "acceptance_confirmations_v2"
    // Silent fallback channel — used ONLY for the notification posted alongside
    // FullScreenNotificationActivity. IMPORTANCE_LOW prevents heads-up banner.
    private const val CHANNEL_ID_SILENT_FULLSCREEN = "silent_fullscreen_v1"

    private const val PREFS_NAME = "sound_repeat_prefs"
    // Sound file (trip_reminder.wav) is ~3 seconds long.
    // Schedule repeats every 8s to avoid overlap (~5s gap between plays).
    private const val REPEAT_INTERVAL_MS = 8000L
    private const val MAX_REPEATS = 7  // 7 repeats × 8s = 56s coverage

    // Fixed notification IDs per type — forces Android to REPLACE (not stack).
    private const val NOTIF_ID_NEW_ORDER = 2000
    private const val NOTIF_ID_UNASSIGNED = 2001
    private const val NOTIF_ID_TRIP_REMINDER = 2002

    // Fixed request code base for sound repeat alarms (new order overwrites old).
    private const val ALARM_RC_REPEAT_BASE = 22000

    // Track current active orderId for cancellation
    @Volatile
    private var activeOrderId: String? = null

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

            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID_ORDER_UPDATES,
                    "تحديثات الطلبات",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "تحديثات حالة الطلب"
                    enableVibration(true)
                }
            )
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID_ACCEPTANCE,
                    "تأكيد القبول",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "تأكيدات قبول الطلبات"
                    enableVibration(true)
                }
            )

            // Silent channel for fullscreen fallback notification.
            // IMPORTANCE_LOW = no sound, no vibration, no heads-up banner.
            // The actual UX is FullScreenNotificationActivity + manual sound.
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID_SILENT_FULLSCREEN,
                    "إشعار صامت (خلفي)",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "إشعار خلفي صامت يظهر فقط في شريط الإشعارات"
                    enableVibration(false)
                    setSound(null, null)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
            )
        }
    }

    private fun deleteOldChannels(nm: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        // Delete ALL previous channel versions. Android channels are immutable once
        // created — the only way to fix sound/vibration on existing installs is to
        // delete the old channel and create a new one with a bumped ID.
        listOf(
            // new_orders: v1 through v9
            "new_orders", "new_orders_v2", "new_orders_v3", "new_orders_v4",
            "new_orders_v5", "new_orders_v6", "new_orders_v7", "new_orders_v8", "new_orders_v9",
            // unassigned_orders: v1 through v9
            "unassigned_orders", "unassigned_orders_v2", "unassigned_orders_v3",
            "unassigned_orders_v4", "unassigned_orders_v5", "unassigned_orders_v6",
            "unassigned_orders_v7", "unassigned_orders_v8", "unassigned_orders_v9",
            // trip_reminders: v1 through v9
            "trip_reminders", "trip_reminders_v2", "trip_reminders_v3",
            "trip_reminders_v4", "trip_reminders_v5", "trip_reminders_v6",
            "trip_reminders_v7", "trip_reminders_v8", "trip_reminders_v9",
            // order_updates & acceptance: v1
            "order_updates", "order_updates_v1",
            "acceptance_confirmations", "acceptance_confirmations_v1",
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
        messageId: String?,
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
            else -> CHANNEL_ID_SILENT_FULLSCREEN  // Silent fallback — no heads-up
        }

        // Fixed notification ID per type — forces Android to REPLACE the previous
        // notification instead of stacking. This eliminates the "layers of orders" bug.
        val notificationId = when (notificationType) {
            "trip_start_reminder" -> NOTIF_ID_TRIP_REMINDER
            "unassigned_order_reminder" -> NOTIF_ID_UNASSIGNED
            else -> NOTIF_ID_NEW_ORDER
        }

        // Cancel sound repeats for the previous order before replacing
        val previousOrderId = activeOrderId
        if (previousOrderId != null && previousOrderId != orderId) {
            cancelSoundRepeats(context, previousOrderId)
        }
        activeOrderId = orderId

        // Check permission
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            if (!nm.canUseFullScreenIntent()) {
                Log.w(TAG, "⚠️ USE_FULL_SCREEN_INTENT permission not granted on Android 14+")
            } else {
                Log.d(TAG, "✓ USE_FULL_SCREEN_INTENT permission granted")
            }
        }

        // Build a SILENT notification (no sound, no heads-up).
        // Purpose: fallback only if FullScreenNotificationActivity fails to launch.
        // The actual UX is the full-screen activity + manual sound playback.
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            buildCallStyleNotification(
                context, orderId, title, body, pickupLabel, dropoffLabel,
                price, distance, createdAt, notificationType, channelId, notificationId
            )
        } else {
            buildLegacyFullScreenNotification(
                context, orderId, title, body, pickupLabel, dropoffLabel,
                price, distance, createdAt, notificationType, channelId
            )
        }

        nm.notify(notificationId, notification)
        Log.d(TAG, "✓ Silent fallback notification posted: id=$notificationId, order=$orderId")
        Log.d("WAWAPP_TEST", "NOTIFICATION_POSTED id=$notificationId, order=$orderId, channel=$channelId, type=$notificationType")
        Log.i("WAWAPP_EVENT", "{\"event\":\"NOTIFICATION_POSTED\",\"ts\":${System.currentTimeMillis()},\"phase\":\"runtime\",\"data\":{\"notificationId\":$notificationId,\"orderId\":\"$orderId\",\"channel\":\"$channelId\",\"type\":\"$notificationType\"}}")

        // FIX: Play sound immediately at t=0 on Android 12+ where notification is silent.
        // Android < 12 gets t=0 sound from the channel via buildLegacyFullScreenNotification.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            playSoundOnce(context)
        }

        // Schedule sound repeats (played via MediaPlayer, NOT via notification channel)
        scheduleSoundRepeats(context, orderId, notificationId)
    }

    /**
     * Build modern CallStyle notification (Android 12+).
     * This is the Uber/Careem pattern - bypasses BAL restrictions.
     * Works for both new_order and trip_start_reminder with full-screen intent.
     */
    private fun buildCallStyleNotification(
        context: Context,
        orderId: String,
        title: String,
        body: String,
        pickupLabel: String,
        dropoffLabel: String,
        price: Double,
        distance: Double,
        createdAt: Long,
        notificationType: String,
        channelId: String,
        notificationId: Int
    ): Notification {
        // Build a MINIMAL notification — no sound, no heads-up.
        // FullScreenNotificationActivity is launched directly by MyFirebaseMessagingService.
        // This notification exists ONLY as a silent fallback for lock-screen fullScreenIntent.
        val contentTitle = if (notificationType == "trip_start_reminder") title else "$pickupLabel → $dropoffLabel"
        val contentText = if (notificationType == "trip_start_reminder") body else "${price.toInt()} أوقية • ${String.format("%.1f", distance)} كم"

        val foreground = isForeground(context)
        val isOrderOffer = notificationType == "new_order" || notificationType == "unassigned_order_reminder"

        val fullScreenPendingIntent = createFullScreenPendingIntent(
            context, orderId, pickupLabel, dropoffLabel, price, distance, createdAt, notificationType
        )
        val contentPendingIntent = if (foreground && isOrderOffer) {
            createForegroundContentIntent(context, orderId, notificationType)
        } else null
        val deleteIntent = createDeletePendingIntent(context, orderId)

        // Snooze action — carries all order data so OrderActionReceiver can schedule alarm
        val snoozeIntent = Intent(context, OrderActionReceiver::class.java).apply {
            action = OrderActionReceiver.ACTION_SNOOZE
            putExtra("orderId", orderId)
            putExtra("notificationId", notificationId)
            putExtra("offerId", orderId) // fallback; real offerId set by caller if available
            putExtra("pickupLabel", pickupLabel)
            putExtra("dropoffLabel", dropoffLabel)
            putExtra("price", price)
            putExtra("distance", distance)
            putExtra("createdAt", createdAt)
        }
        val snoozePendingIntent = PendingIntent.getBroadcast(
            context, orderId.hashCode() + 30000, snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = Notification.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setCategory(Notification.CATEGORY_CALL)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setDeleteIntent(deleteIntent)
            .setTimeoutAfter(60000)
            .addAction(Notification.Action.Builder(
                null, "لاحقاً", snoozePendingIntent
            ).build())

        if (foreground && isOrderOffer) {
            builder.setContentIntent(contentPendingIntent)
        } else {
            builder.setFullScreenIntent(fullScreenPendingIntent, true)
        }

        val notification = builder.build()

        // Remove sound and vibration flags to prevent heads-up
        notification.sound = null
        notification.vibrate = null
        notification.defaults = 0

        return notification
    }

    /**
     * Fallback for Android < 12: traditional full-screen intent notification.
     */
    private fun buildLegacyFullScreenNotification(
        context: Context,
        orderId: String,
        title: String,
        body: String,
        pickupLabel: String,
        dropoffLabel: String,
        price: Double,
        distance: Double,
        createdAt: Long,
        notificationType: String,
        channelId: String
    ): Notification {
        val foreground = isForeground(context)
        val isOrderOffer = notificationType == "new_order" || notificationType == "unassigned_order_reminder"

        val fullScreenIntent = createFullScreenPendingIntent(
            context, orderId, pickupLabel, dropoffLabel, price, distance, createdAt, notificationType
        )
        val contentIntent = if (foreground && isOrderOffer) {
            createForegroundContentIntent(context, orderId, notificationType)
        } else fullScreenIntent
        val deleteIntent = createDeletePendingIntent(context, orderId)

        // Snooze action — carries all order data so OrderActionReceiver can schedule alarm
        val snoozeIntent = Intent(context, OrderActionReceiver::class.java).apply {
            action = OrderActionReceiver.ACTION_SNOOZE
            putExtra("orderId", orderId)
            putExtra("notificationId", orderId.hashCode())
            putExtra("offerId", orderId)
            putExtra("pickupLabel", pickupLabel)
            putExtra("dropoffLabel", dropoffLabel)
            putExtra("price", price)
            putExtra("distance", distance)
            putExtra("createdAt", createdAt)
        }
        val snoozePendingIntent = PendingIntent.getBroadcast(
            context, orderId.hashCode() + 30000, snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setContentIntent(contentIntent)
            .setDeleteIntent(deleteIntent)
            .setVibrate(longArrayOf(0, 500, 200, 500, 200, 500))
            .setSound(Uri.parse("android.resource://${context.packageName}/raw/trip_reminder"))
            .setTimeoutAfter(60000)
            .addAction(R.mipmap.ic_launcher, "لاحقاً", snoozePendingIntent)

        if (!(foreground && isOrderOffer)) {
            builder.setFullScreenIntent(fullScreenIntent, true)
        }

        return builder.build()
    }

    /**
     * Show a simple heads-up notification (no full-screen intent, no sound repeats).
     * Used for non-critical notifications like acceptance_confirmation and order_update.
     */
    fun showSimpleNotification(
        context: Context,
        orderId: String,
        title: String,
        body: String,
        notificationType: String
    ) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Use the same channels but without full-screen intent
        val channelId = when (notificationType) {
            "acceptance_confirmation" -> CHANNEL_ID_ACCEPTANCE
            "order_update" -> CHANNEL_ID_ORDER_UPDATES
            else -> CHANNEL_ID_ORDER_UPDATES
        }

        // Create tap intent to open MainActivity
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("orderId", orderId)
            putExtra("notificationType", notificationType)
            putExtra("action", "view_order")
        }
        val tapPendingIntent = PendingIntent.getActivity(
            context, orderId.hashCode() + 4000, tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(tapPendingIntent)
            .setVibrate(longArrayOf(0, 300, 200, 300))
            .setTimeoutAfter(30000)
            .build()

        val notificationId = (orderId + "_" + notificationType).hashCode()
        nm.notify(notificationId, notification)
        Log.d(TAG, "✓ Simple notification shown: id=$notificationId, order=$orderId, type=$notificationType")
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
        // For trip_start_reminder, open TripReminderActivity (amber full-screen)
        // For new_order, open FullScreenNotificationActivity
        val intent = if (notificationType == "trip_start_reminder") {
            Intent(context, TripReminderActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION
                putExtra("orderId", orderId)
                putExtra("pickupLabel", pickupLabel)
                putExtra("dropoffLabel", dropoffLabel)
                putExtra("elapsedMinutes", 0)
            }
        } else {
            Intent(context, FullScreenNotificationActivity::class.java).apply {
                // Android 14+ requires FLAG_ACTIVITY_NO_USER_ACTION for full-screen intent
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION
                putExtra("orderId", orderId)
                putExtra("pickupLabel", pickupLabel)
                putExtra("dropoffLabel", dropoffLabel)
                putExtra("price", price)
                putExtra("distance", distance)
                putExtra("createdAt", createdAt)
                putExtra("notificationType", notificationType)
            }
        }
        return PendingIntent.getActivity(
            context, orderId.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * PendingIntent that brings MainActivity to foreground without creating a new Activity.
     * Used when app is already in foreground for order offer notifications.
     */
    private fun createForegroundContentIntent(
        context: Context,
        orderId: String,
        notificationType: String
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra("orderId", orderId)
            putExtra("notificationType", notificationType)
            putExtra("action", "view_order")
        }
        return PendingIntent.getActivity(
            context, orderId.hashCode() + 50000, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * Check if the app process is currently in the foreground.
     */
    private fun isForeground(@Suppress("UNUSED_PARAMETER") context: Context): Boolean {
        return ProcessLifecycleOwner.get().lifecycle.currentState
            .isAtLeast(Lifecycle.State.STARTED)
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

    fun scheduleSoundRepeats(context: Context, orderId: String, notificationId: Int) {
        val appContext = context.applicationContext

        // Mark all repeat slots as pending
        val editor = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putBoolean("pending_$orderId", true)
        for (i in 1..MAX_REPEATS) {
            editor.putBoolean("played_${i}_$orderId", false)
        }
        editor.apply()

        // PRIMARY: Handler.postDelayed fires reliably while process is alive
        val handler = Handler(Looper.getMainLooper())
        for (i in 1..MAX_REPEATS) {
            val delayMs = REPEAT_INTERVAL_MS * i
            handler.postDelayed({
                if (consumePendingRepeat(appContext, orderId, i)) {
                    Log.d(TAG, "Handler repeat $i/$MAX_REPEATS playing for order $orderId")
                    playSoundOnce(appContext)
                }
            }, delayMs)
        }

        // BACKUP: AlarmManager fires even if process is killed.
        val am = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 1..MAX_REPEATS) {
            scheduleOneRepeat(appContext, am, orderId, notificationId, REPEAT_INTERVAL_MS * i, repeatNum = i)
        }

        Log.d(TAG, "Sound repeats scheduled ($MAX_REPEATS repeats, Handler + AlarmManager) for order $orderId")
        Log.d("WAWAPP_TEST", "ALARM_SCHEDULED repeats=$MAX_REPEATS, interval=${REPEAT_INTERVAL_MS}ms, order=$orderId")
    }

    /**
     * Atomically consume a repeat slot. Returns true (and marks slot as played)
     * if the slot was pending and not yet consumed. Returns false if already
     * played (by Handler or AlarmManager) or if the order was cancelled.
     */
    fun consumePendingRepeat(context: Context, orderId: String, repeatNum: Int): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("pending_$orderId", false)) return false  // cancelled
        val playedKey = "played_${repeatNum}_$orderId"
        if (prefs.getBoolean(playedKey, false)) return false  // already played
        prefs.edit().putBoolean(playedKey, true).apply()
        return true
    }

    /**
     * Play trip_reminder.wav once using USAGE_ALARM to bypass DND.
     */
    fun playSoundOnce(context: Context) {
        try {
            val soundUri = Uri.parse("android.resource://${context.packageName}/raw/trip_reminder")
            MediaPlayer().apply {
                setDataSource(context, soundUri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                )
                setOnCompletionListener { it.release() }
                setOnErrorListener { mp, _, _ -> mp.release(); true }
                prepare()
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error playing sound: ${e.message}")
        }
    }

    private fun scheduleOneRepeat(
        context: Context,
        am: AlarmManager,
        orderId: String,
        notificationId: Int,
        delayMs: Long,
        repeatNum: Int
    ) {
        val intent = Intent(context, SoundRepeatReceiver::class.java).apply {
            action = SoundRepeatReceiver.ACTION
            putExtra(SoundRepeatReceiver.EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(SoundRepeatReceiver.EXTRA_ORDER_ID, orderId)
            putExtra(SoundRepeatReceiver.EXTRA_REPEAT_NUM, repeatNum)
        }
        // Fixed request codes per slot: new order's alarms overwrite old via FLAG_UPDATE_CURRENT.
        val requestCode = ALARM_RC_REPEAT_BASE + repeatNum
        val pi = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val triggerAt = SystemClock.elapsedRealtime() + delayMs

        // FIX: Proactively check exact alarm permission on Android 12+ before attempting.
        // Avoids SecurityException throw/catch and logs the reason clearly.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
            Log.w(TAG, "Exact alarm permission not granted — using inexact for repeat $repeatNum")
            am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
            return
        }

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
        // Clear pending flag and all played flags
        val editor = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .remove("pending_$orderId")
        for (i in 1..MAX_REPEATS) {
            editor.remove("played_${i}_$orderId")
        }
        editor.apply()

        // Cancel all AlarmManager PendingIntents
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 1..MAX_REPEATS) {
            val intent = Intent(context, SoundRepeatReceiver::class.java).apply {
                action = SoundRepeatReceiver.ACTION
            }
            val pi = PendingIntent.getBroadcast(
                context, ALARM_RC_REPEAT_BASE + i, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            am.cancel(pi)
            pi.cancel()
        }

        if (activeOrderId == orderId) activeOrderId = null
        Log.d(TAG, "Sound repeats cancelled for order $orderId")
    }

    /**
     * Cancel notification and sound repeats for an order.
     * Call when order is no longer relevant (accepted, expired, etc.).
     */
    fun cancelOrderNotification(context: Context, orderId: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Cancel by fixed IDs (covers all types)
        nm.cancel(NOTIF_ID_NEW_ORDER)
        nm.cancel(NOTIF_ID_UNASSIGNED)
        nm.cancel(NOTIF_ID_TRIP_REMINDER)
        // Also cancel by legacy hashCode in case old notifications linger
        nm.cancel(orderId.hashCode())
        cancelSoundRepeats(context, orderId)
        // Cancel snooze alarm for this order
        SnoozeScheduler.cancel(context, orderId)
        Log.d(TAG, "Notification cancelled for order $orderId")
    }
}
