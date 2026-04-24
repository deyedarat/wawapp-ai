package com.wawapp.driver

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import org.json.JSONObject

/**
 * Schedules and cancels snooze alarms via AlarmManager.
 *
 * Production hardening:
 * - Runtime check for SCHEDULE_EXACT_ALARM (Android 12+)
 * - Persists pending snoozes to SharedPreferences (survives process death)
 * - Provides restoreAll() for re-scheduling after device reboot
 */
object SnoozeScheduler {

    private const val TAG = "SnoozeScheduler"
    private const val REQUEST_CODE_BASE = 50000
    private const val PREFS_NAME = "snooze_scheduler_prefs"
    private const val KEY_PENDING = "pending_snoozes" // JSON map: orderId → serialized data

    // =========================================================================
    // Schedule
    // =========================================================================

    fun schedule(
        context: Context,
        orderId: String,
        offerId: String,
        delaySeconds: Int,
        pickupLabel: String,
        dropoffLabel: String,
        price: Double,
        distance: Double,
        createdAt: Long
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // ── FIX 1: Exact alarm permission check (Android 12+) ──
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!am.canScheduleExactAlarms()) {
                Log.w(TAG, "⚠️ SCHEDULE_EXACT_ALARM not granted — prompting user")
                try {
                    val settingsIntent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                        data = Uri.parse("package:${context.packageName}")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(settingsIntent)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to open exact alarm settings: ${e.message}")
                }
                // Fall through to inexact alarm as fallback (don't return silently)
            }
        }

        // Absolute trigger time (RTC) for persistence across reboots
        val triggerAtRtc = System.currentTimeMillis() + (delaySeconds * 1000L)
        // Elapsed trigger for AlarmManager (more accurate for current boot)
        val triggerAtElapsed = SystemClock.elapsedRealtime() + (delaySeconds * 1000L)

        val pi = buildPendingIntent(
            context, orderId, offerId,
            pickupLabel, dropoffLabel, price, distance, createdAt
        )

        // ── Schedule alarm ──
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && am.canScheduleExactAlarms()) {
                am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtElapsed, pi)
                Log.d(TAG, "✅ Exact snooze alarm scheduled: orderId=$orderId, delay=${delaySeconds}s")
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Try exact, fall back to inexact on SecurityException
                try {
                    am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtElapsed, pi)
                    Log.d(TAG, "✅ Exact snooze alarm scheduled (pre-S): orderId=$orderId")
                } catch (e: SecurityException) {
                    am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtElapsed, pi)
                    Log.w(TAG, "⚠️ Inexact fallback used: ${e.message}")
                }
            } else {
                am.setExact(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtElapsed, pi)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule alarm: ${e.message}")
            return
        }

        // ── FIX R1: Clear native dedup so SnoozeAlarmReceiver won't be blocked ──
        // MyFirebaseMessagingService wrote this key when the original FCM arrived.
        // Without clearing it, the 10-min TTL outlasts the 5-min snooze delay.
        val dedupKey = offerId.ifBlank { orderId }
        val dedupPrefs = context.getSharedPreferences("fcm_dedup", Context.MODE_PRIVATE)
        val editor = dedupPrefs.edit()
        editor.remove(dedupKey)
        // Also clear orderId-based variants (legacy fallback keys)
        if (dedupKey == offerId) {
            editor.remove("${orderId}_1")
            editor.remove("${orderId}_snooze")
        }
        editor.apply()
        Log.d(TAG, "🔕 Cleared native dedup for snoozed offer: key=$dedupKey")

        // ── FIX 2: Persist for reboot recovery ──
        persistSnooze(context, orderId, offerId, triggerAtRtc,
            pickupLabel, dropoffLabel, price, distance, createdAt)
    }

    // =========================================================================
    // Cancel
    // =========================================================================

    fun cancel(context: Context, orderId: String) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = buildPendingIntent(context, orderId, "", "", "", 0.0, 0.0, 0L)
        am.cancel(pi)
        pi.cancel()
        SnoozeAlarmReceiver.markOrderHandled(context, orderId)
        removePersisted(context, orderId)
        Log.d(TAG, "🔕 Snooze cancelled: orderId=$orderId")
    }

    // =========================================================================
    // FIX 2: Reboot recovery — called by SnoozeBootReceiver
    // =========================================================================

    fun restoreAll(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_PENDING, null) ?: return
        val map = try { JSONObject(raw) } catch (_: Exception) { return }

        val now = System.currentTimeMillis()
        val keysToRemove = mutableListOf<String>()

        for (key in map.keys()) {
            try {
                val entry = map.getJSONObject(key)
                val triggerAtRtc = entry.getLong("triggerAtRtc")

                // Skip expired snoozes
                if (triggerAtRtc <= now) {
                    keysToRemove.add(key)
                    continue
                }

                val remainingMs = triggerAtRtc - now
                val remainingSeconds = (remainingMs / 1000).toInt().coerceAtLeast(5)

                schedule(
                    context = context,
                    orderId = key,
                    offerId = entry.optString("offerId", ""),
                    delaySeconds = remainingSeconds,
                    pickupLabel = entry.optString("pickupLabel", ""),
                    dropoffLabel = entry.optString("dropoffLabel", ""),
                    price = entry.optDouble("price", 0.0),
                    distance = entry.optDouble("distance", 0.0),
                    createdAt = entry.optLong("createdAt", 0L)
                )
                Log.d(TAG, "🔄 Restored snooze after reboot: orderId=$key, remaining=${remainingSeconds}s")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to restore snooze for $key: ${e.message}")
                keysToRemove.add(key)
            }
        }

        // Clean up expired entries
        if (keysToRemove.isNotEmpty()) {
            for (k in keysToRemove) map.remove(k)
            prefs.edit().putString(KEY_PENDING, map.toString()).apply()
        }
    }

    // =========================================================================
    // Persistence helpers
    // =========================================================================

    private fun persistSnooze(
        context: Context, orderId: String, offerId: String,
        triggerAtRtc: Long, pickupLabel: String, dropoffLabel: String,
        price: Double, distance: Double, createdAt: Long
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val map = try {
            JSONObject(prefs.getString(KEY_PENDING, "{}") ?: "{}")
        } catch (_: Exception) { JSONObject() }

        val entry = JSONObject().apply {
            put("offerId", offerId)
            put("triggerAtRtc", triggerAtRtc)
            put("pickupLabel", pickupLabel)
            put("dropoffLabel", dropoffLabel)
            put("price", price)
            put("distance", distance)
            put("createdAt", createdAt)
        }
        map.put(orderId, entry)
        prefs.edit().putString(KEY_PENDING, map.toString()).apply()
    }

    private fun removePersisted(context: Context, orderId: String) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val map = try {
            JSONObject(prefs.getString(KEY_PENDING, "{}") ?: "{}")
        } catch (_: Exception) { return }
        map.remove(orderId)
        prefs.edit().putString(KEY_PENDING, map.toString()).apply()
    }

    // =========================================================================
    // PendingIntent builder
    // =========================================================================

    private fun buildPendingIntent(
        context: Context,
        orderId: String,
        offerId: String,
        pickupLabel: String,
        dropoffLabel: String,
        price: Double,
        distance: Double,
        createdAt: Long
    ): PendingIntent {
        val intent = Intent(context, SnoozeAlarmReceiver::class.java).apply {
            action = SnoozeAlarmReceiver.ACTION
            putExtra(SnoozeAlarmReceiver.EXTRA_ORDER_ID, orderId)
            putExtra(SnoozeAlarmReceiver.EXTRA_OFFER_ID, offerId)
            putExtra(SnoozeAlarmReceiver.EXTRA_PICKUP_LABEL, pickupLabel)
            putExtra(SnoozeAlarmReceiver.EXTRA_DROPOFF_LABEL, dropoffLabel)
            putExtra(SnoozeAlarmReceiver.EXTRA_PRICE, price)
            putExtra(SnoozeAlarmReceiver.EXTRA_DISTANCE, distance)
            putExtra(SnoozeAlarmReceiver.EXTRA_CREATED_AT, createdAt)
        }
        val requestCode = REQUEST_CODE_BASE + orderId.hashCode()
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
