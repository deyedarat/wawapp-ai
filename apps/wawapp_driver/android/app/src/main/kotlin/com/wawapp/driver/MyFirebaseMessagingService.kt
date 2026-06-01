package com.wawapp.driver

import android.content.Context
import android.content.Intent
import android.os.Build
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

    // ── Offer-level dedup (SharedPreferences, survives process death) ──
    // Thread-safe: onMessageReceived is called from a background thread pool.
    private val dedupLock = Any()

    private fun isOfferAlreadySeen(context: Context, key: String, sentTime: Long = 0L): Boolean {
        if (key.isBlank()) return false
        // Drop messages older than 60 minutes (delayed/ghost FCM)
        if (sentTime > 0 && System.currentTimeMillis() - sentTime > DEDUP_TTL_MS) {
            Log.d(TAG, "⛔ FCM message too old (sentTime=${sentTime}), dropping: key=$key")
            return true
        }
        val prefs = context.getSharedPreferences("fcm_dedup", Context.MODE_PRIVATE)
        val ts = prefs.getLong(key, 0L)
        if (ts == 0L) return false
        return System.currentTimeMillis() - ts < DEDUP_TTL_MS
    }

    private fun markOfferSeen(context: Context, key: String) {
        if (key.isBlank()) return
        val prefs = context.getSharedPreferences("fcm_dedup", Context.MODE_PRIVATE)
        prefs.edit().putLong(key, System.currentTimeMillis()).apply()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        // ── WAWAPP_TEST: Certification marker for FCM delivery validation ──
        Log.d("WAWAPP_TEST", "PUSH_RECEIVED raw_type=${message.data["notificationType"] ?: message.data["type"]}, keys=${message.data.keys}, sentTime=${message.sentTime}")
        Log.i("WAWAPP_EVENT", "{\"event\":\"PUSH_PROCESSED\",\"ts\":${System.currentTimeMillis()},\"phase\":\"runtime\",\"data\":{\"type\":\"${message.data["notificationType"] ?: message.data["type"] ?: "null"}\",\"orderId\":\"${message.data["orderId"] ?: ""}\",\"sentTime\":${message.sentTime},\"foreground\":${isAppInForeground()}}}")
        writeCertificationMarker(message)

        val type = message.data["notificationType"]
            ?: message.data["type"]
            ?: return

        val orderId = message.data["orderId"] ?: ""
        val offerId = message.data["offerId"] ?: ""

        // ── Native dedup: prevent duplicate display for same offer ──
        // trip_start_reminder is excluded — it's a recurring reminder from the
        // backend (every 3 min) and must never be deduped by orderId.
        if (type != "trip_start_reminder") {
            val dedupKey = offerId.ifBlank { "${orderId}_${message.data["round"] ?: "1"}" }
            synchronized(dedupLock) {
                if (isOfferAlreadySeen(applicationContext, dedupKey, message.sentTime)) {
                    Log.d(TAG, "⛔ DEDUP: offer already seen, dropping: key=$dedupKey")
                    return
                }
                markOfferSeen(applicationContext, dedupKey)
            }
        }

        Log.d(TAG, "Native FCM received: type=$type, orderId=$orderId, offerId=$offerId, foreground=${isAppInForeground()}, hasNotification=${message.notification != null}")

        // When app is in foreground and message has a notification block,
        // Android auto-displays it in the system tray. We suppress that here
        // because Flutter handles foreground display directly (full-screen UI).
        // For background/killed state, the notification block is the safety net.

        // Route notifications based on type and app state
        when {
            // Critical notifications: Full-screen (unified path for foreground + background)
            type in listOf(
                "new_order",
                "wave_offer",
                "new_order_nearby",
                "unassigned_order_reminder",
                "trip_start_reminder"
            ) -> {
                if (isAppInForeground()) {
                    // Rejected order guard (foreground path)
                    if (type != "trip_start_reminder" && orderId.isNotBlank() && isOrderRejected(applicationContext, orderId)) {
                        Log.d(TAG, "⛔ Order already rejected (foreground) — suppressing: orderId=$orderId")
                        return
                    }
                    // Cancel any system-displayed notification from the notification block
                    if (orderId.isNotBlank()) {
                        val nm = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
                        nm.cancel(orderId.hashCode())
                        nm.cancel(2000) // NOTIF_ID_NEW_ORDER
                        nm.cancel(2001) // NOTIF_ID_UNASSIGNED
                    }
                    // Also forward to Flutter for dedup tracking
                    FcmForegroundBridge.sendMessage(message.data)
                    Log.d(TAG, "Critical notification in foreground → using unified native path (same as background)")
                }
                // Verify order is still valid before showing notification (race condition fix)
                if (orderId.isNotBlank()) {
                    Thread {
                        val isValid = when (type) {
                            "trip_start_reminder" -> isOrderStillAccepted(offerId)
                            else -> isOrderStillMatching(offerId)
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
                    // return removed to always build native notification
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
                    // return removed to always build native notification
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
        val offerId = message.data["offerId"] ?: ""
        Log.d(TAG, "Handling critical notification: type=$type, orderId=$orderId")

        // ── Active trip guard: suppress new-order offers when driver is busy ──
        // trip_start_reminder is excluded — it targets the active trip itself.
        if (type != "trip_start_reminder" && isDriverOnActiveTrip(applicationContext)) {
            Log.d(TAG, "⛔ Driver has active trip — suppressing new offer: orderId=$orderId")
            return
        }

        // ── Rejected order guard: suppress offers for orders driver already rejected ──
        if (type != "trip_start_reminder" && orderId.isNotBlank() && isOrderRejected(applicationContext, orderId)) {
            Log.d(TAG, "⛔ Order already rejected — suppressing: orderId=$orderId")
            return
        }

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
                val notificationId = orderId.hashCode()
                val km = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
                val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                val isLocked = km.isKeyguardLocked
                val isScreenOn = pm.isInteractive
                Log.d(TAG, "Launch context: locked=$isLocked, screenOn=$isScreenOn, sdk=${Build.VERSION.SDK_INT}")

                val fsIntent = Intent(applicationContext, FullScreenNotificationActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("orderId", orderId)
                    putExtra("pickupLabel", pickupLabel)
                    putExtra("dropoffLabel", dropoffLabel)
                    putExtra("price", price)
                    putExtra("distance", distance)
                    putExtra("createdAt", createdAt)
                    putExtra("notificationType", type)
                    putExtra("notificationId", notificationId)
                    putExtra("offerId", offerId)
                }

                // On Android 12+: startActivity from background requires SYSTEM_ALERT_WINDOW
                // OR the notification's fullScreenIntent must handle it.
                // On locked screen: fullScreenIntent fires automatically (no overlay needed).
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S
                    && !android.provider.Settings.canDrawOverlays(applicationContext)
                    && !isLocked) {
                    Log.d(TAG, "Overlay not granted + screen unlocked — relying on fullScreenIntent/heads-up fallback")
                } else {
                    applicationContext.startActivity(fsIntent)
                    Log.d(TAG, "FullScreenNotificationActivity launched directly: orderId=$orderId, locked=$isLocked")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Direct activity launch failed (notification fallback active): ${e.message}")
            }
        } else {
            // trip_start_reminder: launch TripReminderActivity directly (full-screen amber UI)
            try {
                val elapsedMinutes = message.data["elapsedMinutes"]?.toIntOrNull() ?: 0
                val reminderNotifId = (message.data["messageId"] ?: orderId).hashCode()
                val reminderIntent = Intent(applicationContext, TripReminderActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION
                    putExtra("orderId", orderId)
                    putExtra("pickupLabel", pickupLabel)
                    putExtra("dropoffLabel", dropoffLabel)
                    putExtra("elapsedMinutes", elapsedMinutes)
                    putExtra("notificationId", reminderNotifId)
                }
                applicationContext.startActivity(reminderIntent)
                Log.d(TAG, "TripReminderActivity launched directly for order $orderId")
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
     * One-time Firestore read on dispatch_offers/{offerId} to verify the offer
     * is still in 'pending' status. Runs on background thread. Fail-open on error.
     */
    private fun isOrderStillMatching(offerId: String): Boolean {
        if (offerId.isBlank()) return true
        return try {
            val task = FirebaseFirestore.getInstance()
                .collection("dispatch_offers")
                .document(offerId)
                .get()
            val snapshot = Tasks.await(task, 5, TimeUnit.SECONDS)
            val status = snapshot.getString("status")
            val isPending = status == "sent" || status == "pending"
            Log.d(TAG, "Offer check: offerId=$offerId, status=$status, isPending=$isPending")
            isPending
        } catch (e: Exception) {
            Log.w(TAG, "Offer check failed (fail-closed): offerId=$offerId, error=${e.message}")
            false
        }
    }

    /**
     * One-time Firestore read on dispatch_offers/{offerId} to verify the offer
     * is still in 'accepted' status. Used for trip_start_reminder. Fail-closed on error.
     */
    private fun isOrderStillAccepted(offerId: String): Boolean {
        if (offerId.isBlank()) return true
        return try {
            val task = FirebaseFirestore.getInstance()
                .collection("dispatch_offers")
                .document(offerId)
                .get()
            val snapshot = Tasks.await(task, 5, TimeUnit.SECONDS)
            val status = snapshot.getString("status")
            val isAccepted = status == "accepted"
            Log.d(TAG, "Trip reminder offer check: offerId=$offerId, status=$status, isAccepted=$isAccepted")
            isAccepted
        } catch (e: Exception) {
            Log.w(TAG, "Trip reminder offer check failed (fail-closed): offerId=$offerId, error=${e.message}")
            false
        }
    }

    // ── Active trip flag (SharedPreferences, set by Flutter) ──

    /**
     * Structured active-trip check with staleness detection.
     * Returns true ONLY if flag is active AND younger than STALE_THRESHOLD_MS.
     * Auto-clears stale state to prevent indefinite suppression after process death.
     */
    private fun isDriverOnActiveTrip(context: Context): Boolean {
        val prefs = context.getSharedPreferences(PREFS_TRIP_STATE, Context.MODE_PRIVATE)
        val active = prefs.getBoolean(KEY_HAS_ACTIVE_TRIP, false)
        if (!active) {
            Log.d(TAG, "suppression_reason=no_active_trip")
            return false
        }
        val setAt = prefs.getLong(KEY_TRIP_SET_AT, 0L)
        val ageMs = if (setAt > 0) System.currentTimeMillis() - setAt else Long.MAX_VALUE
        val orderId = prefs.getString(KEY_TRIP_ORDER_ID, null) ?: "unknown"
        val source = prefs.getString(KEY_TRIP_SOURCE, null) ?: "unknown"

        if (ageMs > STALE_THRESHOLD_MS) {
            Log.d(TAG, "suppression_reason=stale_state_auto_cleared age_ms=$ageMs orderId=$orderId source=$source")
            Log.i("WAWAPP_METRIC", "event=stale_suppression_cleared orderId=$orderId age_ms=$ageMs")
            prefs.edit()
                .putBoolean(KEY_HAS_ACTIVE_TRIP, false)
                .remove(KEY_TRIP_SET_AT)
                .remove(KEY_TRIP_ORDER_ID)
                .remove(KEY_TRIP_SOURCE)
                .apply()
            return false
        }

        Log.d(TAG, "suppression_reason=fresh_active_trip age_ms=$ageMs orderId=$orderId source=$source")
        return true
    }

    // ── Rejected orders (SharedPreferences, set by native reject paths) ──

    private fun isOrderRejected(context: Context, orderId: String): Boolean {
        val ids = context.getSharedPreferences(PREFS_REJECTED, Context.MODE_PRIVATE)
            .getStringSet(KEY_REJECTED_IDS, emptySet()) ?: emptySet()
        return orderId in ids
    }

    /**
     * Write certification marker to SharedPreferences for test instrumentation polling.
     * Only writes — never blocks or modifies notification flow.
     */
    private fun writeCertificationMarker(message: RemoteMessage) {
        try {
            val type = message.data["notificationType"] ?: message.data["type"] ?: "unknown"
            applicationContext.getSharedPreferences("fcm_certification", Context.MODE_PRIVATE)
                .edit()
                .putLong("last_push_received_at", System.currentTimeMillis())
                .putString("last_push_type", type)
                .putLong("push_sent_at", message.sentTime)
                .apply()
        } catch (_: Exception) {}
    }

    companion object {
        private const val TAG = "MyFCMService"
        private const val DEDUP_TTL_MS = 60L * 60 * 1000 // 60 minutes
        private const val STALE_THRESHOLD_MS = 20L * 60 * 1000 // 20 minutes (Refined per USER request)
        const val PREFS_TRIP_STATE = "driver_trip_state"
        const val KEY_HAS_ACTIVE_TRIP = "driver_has_active_trip"
        const val KEY_TRIP_SET_AT = "driver_trip_set_at"
        const val KEY_TRIP_ORDER_ID = "driver_trip_order_id"
        const val KEY_TRIP_SOURCE = "driver_trip_source"
        const val PREFS_REJECTED = "driver_rejected_orders_native"
        const val KEY_REJECTED_IDS = "rejected_order_ids"

        /** Mark an orderId as rejected. Called from native reject paths. */
        @Synchronized
        fun markOrderRejected(context: Context, orderId: String, offerId: String = "") {
            val prefs = context.getSharedPreferences(PREFS_REJECTED, Context.MODE_PRIVATE)
            val ids = prefs.getStringSet(KEY_REJECTED_IDS, mutableSetOf())?.toMutableSet()
                ?: mutableSetOf()
            ids.add(orderId)
            // Cap at 200 entries to prevent unbounded growth.
            // Oldest entries are lost but that's fine — orders expire in <1 hour.
            if (ids.size > 200) {
                val excess = ids.size - 200
                val iter = ids.iterator()
                repeat(excess) { if (iter.hasNext()) { iter.next(); iter.remove() } }
            }
            prefs.edit().putStringSet(KEY_REJECTED_IDS, ids).apply()

            // Call rejectOffer Cloud Function (handles Firestore writes on backend)
            if (offerId.isNotBlank()) {
                com.google.firebase.functions.FirebaseFunctions.getInstance()
                    .getHttpsCallable("rejectOffer")
                    .call(hashMapOf(
                        "offerId" to offerId,
                        "orderId" to orderId,
                        "reason" to "driver_rejected"
                    ))
                    .addOnFailureListener { e: Exception ->
                        Log.w(TAG, "rejectOffer call failed: ${e.message}")
                    }
            }
        }
    }
}
