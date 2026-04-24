package com.wawapp.driver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver triggered by AlarmManager for snoozed order reminders.
 *
 * Fires even in Doze mode (setExactAndAllowWhileIdle) and after process death.
 *
 * Multi-layer dedup (FIX 4):
 * 1. Already handled — accepted/rejected (SharedPreferences, persistent)
 * 2. FCM dedup TTL — same offer already shown recently (SharedPreferences)
 * 3. Still matching — Firestore server check
 */
class SnoozeAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "SnoozeAlarmReceiver"
        const val ACTION = "com.wawapp.driver.SNOOZE_ALARM"
        const val EXTRA_ORDER_ID = "orderId"
        const val EXTRA_OFFER_ID = "offerId"
        const val EXTRA_PICKUP_LABEL = "pickupLabel"
        const val EXTRA_DROPOFF_LABEL = "dropoffLabel"
        const val EXTRA_PRICE = "price"
        const val EXTRA_DISTANCE = "distance"
        const val EXTRA_CREATED_AT = "createdAt"

        private const val PREFS_HANDLED = "snooze_prefs"
        private const val PREFS_DEDUP = "fcm_dedup"
        private const val DEDUP_TTL_MS = 10 * 60 * 1000L // 10 minutes

        fun markOrderHandled(context: Context, orderId: String) {
            context.getSharedPreferences(PREFS_HANDLED, Context.MODE_PRIVATE)
                .edit().putBoolean("handled_$orderId", true).apply()
        }

        fun isOrderHandled(context: Context, orderId: String): Boolean {
            return context.getSharedPreferences(PREFS_HANDLED, Context.MODE_PRIVATE)
                .getBoolean("handled_$orderId", false)
        }

        fun clearHandledFlag(context: Context, orderId: String) {
            context.getSharedPreferences(PREFS_HANDLED, Context.MODE_PRIVATE)
                .edit().remove("handled_$orderId").apply()
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val orderId = intent.getStringExtra(EXTRA_ORDER_ID) ?: return
        val offerId = intent.getStringExtra(EXTRA_OFFER_ID) ?: ""

        Log.d(TAG, "⏰ Snooze alarm fired: orderId=$orderId")

        // ── Layer 1: Already handled (accepted/rejected) ──
        if (isOrderHandled(context, orderId)) {
            Log.d(TAG, "⛔ Layer 1: order $orderId already handled")
            cleanup(context, orderId)
            return
        }

        // ── Layer 2: FCM dedup TTL (same offer shown recently) ──
        // Use same key format as MyFirebaseMessagingService for consistency.
        val dedupKey = offerId.ifBlank { orderId }
        if (isDuplicateByTtl(context, dedupKey)) {
            Log.d(TAG, "⛔ Layer 2: offer $dedupKey shown recently (TTL dedup)")
            cleanup(context, orderId)
            return
        }

        // Mark as seen in dedup before async Firestore check
        markSeenInDedup(context, dedupKey)

        // ── Layer 3: Firestore check (background thread, receiver has ~10s) ──
        Thread {
            val isStillMatching = checkOrderStillMatching(orderId)
            if (!isStillMatching) {
                Log.d(TAG, "⛔ Layer 3: order $orderId no longer matching")
                cleanup(context, orderId)
                return@Thread
            }

            // ── All checks passed — show notification ──
            val pickupLabel = intent.getStringExtra(EXTRA_PICKUP_LABEL) ?: "موقع الاستلام"
            val dropoffLabel = intent.getStringExtra(EXTRA_DROPOFF_LABEL) ?: "الوجهة"
            val price = intent.getDoubleExtra(EXTRA_PRICE, 0.0)
            val distance = intent.getDoubleExtra(EXTRA_DISTANCE, 0.0)
            val createdAt = intent.getLongExtra(EXTRA_CREATED_AT, System.currentTimeMillis())

            NotificationHelper.createNotificationChannels(context)

            // FIX 3: Use orderId.hashCode() consistently
            NotificationHelper.showFullScreenNotification(
                context = context,
                orderId = orderId,
                messageId = null, // notification ID derived from orderId inside helper
                title = "تذكير: طلب قريب منك",
                body = "$pickupLabel → $dropoffLabel",
                pickupLabel = pickupLabel,
                dropoffLabel = dropoffLabel,
                price = price,
                distance = distance,
                createdAt = createdAt,
                notificationType = "unassigned_order_reminder"
            )

            // Launch FullScreenNotificationActivity
            try {
                val fsIntent = Intent(context, FullScreenNotificationActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION
                    putExtra("orderId", orderId)
                    putExtra("pickupLabel", pickupLabel)
                    putExtra("dropoffLabel", dropoffLabel)
                    putExtra("price", price)
                    putExtra("distance", distance)
                    putExtra("createdAt", createdAt)
                    putExtra("notificationType", "unassigned_order_reminder")
                    putExtra("notificationId", orderId.hashCode())
                    putExtra("offerId", offerId)
                }
                context.startActivity(fsIntent)
                Log.d(TAG, "✅ Snooze notification shown: orderId=$orderId")
            } catch (e: Exception) {
                Log.w(TAG, "Activity launch failed (notification fallback active): ${e.message}")
            }

            cleanup(context, orderId)
        }.start()
    }

    // =========================================================================
    // Dedup helpers
    // =========================================================================

    private fun isDuplicateByTtl(context: Context, key: String): Boolean {
        val prefs = context.getSharedPreferences(PREFS_DEDUP, Context.MODE_PRIVATE)
        val ts = prefs.getLong(key, 0L)
        if (ts == 0L) return false
        return System.currentTimeMillis() - ts < DEDUP_TTL_MS
    }

    private fun markSeenInDedup(context: Context, key: String) {
        context.getSharedPreferences(PREFS_DEDUP, Context.MODE_PRIVATE)
            .edit().putLong(key, System.currentTimeMillis()).apply()
    }

    // =========================================================================
    // Firestore check
    // =========================================================================

    private fun checkOrderStillMatching(orderId: String): Boolean {
        return try {
            val task = com.google.firebase.firestore.FirebaseFirestore.getInstance()
                .collection("orders")
                .document(orderId)
                .get()
            val snapshot = com.google.android.gms.tasks.Tasks.await(
                task, 5, java.util.concurrent.TimeUnit.SECONDS
            )
            val status = snapshot.getString("status")
            val assigned = snapshot.getString("assignedDriverId")
            val isMatching = status == "matching" && assigned == null
            Log.d(TAG, "Firestore check: orderId=$orderId, status=$status, assigned=$assigned → $isMatching")
            isMatching
        } catch (e: Exception) {
            Log.w(TAG, "Firestore check failed (fail-open): ${e.message}")
            true
        }
    }

    // =========================================================================
    // Cleanup
    // =========================================================================

    private fun cleanup(context: Context, orderId: String) {
        clearHandledFlag(context, orderId)
        // Remove from persisted snoozes (FIX 2 integration)
        try {
            val prefs = context.getSharedPreferences("snooze_scheduler_prefs", Context.MODE_PRIVATE)
            val raw = prefs.getString("pending_snoozes", null)
            if (raw != null) {
                val map = org.json.JSONObject(raw)
                map.remove(orderId)
                prefs.edit().putString("pending_snoozes", map.toString()).apply()
            }
        } catch (_: Exception) {}
    }
}
