package com.wawapp.driver

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.app.KeyguardManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.wawapp.driver/notifications"
    private val INTENT_CHANNEL = "com.wawapp.driver/intent_data"
    private val FCM_FOREGROUND_CHANNEL = "com.wawapp.driver/fcm_foreground"
    private val NEW_INTENT_CHANNEL = "com.wawapp.driver/new_intent"

    private val PREFS_PENDING_ACTION = "pending_native_action"

    private var newIntentEventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }

        // Request overlay permission for full-screen notifications over other apps (Android 12+)
        requestOverlayPermissionIfNeeded()

        // Cancel notification if opened from full-screen intent
        cancelNotificationIfNeeded()

        // Push onCreate intent to EventChannel + cache as fallback.
        dispatchActionIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // FCM Foreground Bridge — streams foreground FCM data to Flutter.
        // MyFirebaseMessagingService calls FcmForegroundBridge.sendMessage() when
        // the app is in the foreground instead of returning silently.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FCM_FOREGROUND_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    FcmForegroundBridge.eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    FcmForegroundBridge.eventSink = null
                }
            })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NEW_INTENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    newIntentEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    newIntentEventSink = null
                }
            })

        // Setup Intent Data Channel (for handling notification accept action)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getIntentData" -> {
                    val intentData = getIntentExtras()
                    result.success(intentData)
                }
                "clearIntentData" -> {
                    clearIntentExtras()
                    result.success(null)
                }
                "getPendingActionFromCache" -> {
                    val prefs = getSharedPreferences(PREFS_PENDING_ACTION, Context.MODE_PRIVATE)
                    val action = prefs.getString("action", null)
                    if (action != null) {
                        val ts = prefs.getLong("timestamp", 0L)
                        // Expire after 30 seconds — stale intents are not actionable
                        if (System.currentTimeMillis() - ts < 30_000) {
                            result.success(mapOf(
                                "action" to action,
                                "orderId" to prefs.getString("orderId", null),
                                "notificationType" to prefs.getString("notificationType", null),
                                "offerId" to prefs.getString("offerId", null)
                            ))
                        } else {
                            // Expired — clear and return null
                            prefs.edit().clear().apply()
                            result.success(null)
                        }
                    } else {
                        result.success(null)
                    }
                }
                "clearPendingActionCache" -> {
                    getSharedPreferences(PREFS_PENDING_ACTION, Context.MODE_PRIVATE)
                        .edit().clear().apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showFullScreenNotification" -> {
                    val orderId = call.argument<String>("orderId") ?: ""
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val pickupLabel = call.argument<String>("pickupLabel") ?: ""
                    val dropoffLabel = call.argument<String>("dropoffLabel") ?: ""
                    val price = call.argument<Double>("price") ?: 0.0
                    val distance = call.argument<Double>("distance") ?: 0.0
                    val createdAt = call.argument<Long>("createdAt") ?: 0L
                    val notificationType = call.argument<String>("notificationType") ?: "new_order"

                    NotificationHelper.showFullScreenNotification(
                        context = this,
                        orderId = orderId,
                        messageId = null,
                        title = title,
                        body = body,
                        pickupLabel = pickupLabel,
                        dropoffLabel = dropoffLabel,
                        price = price,
                        distance = distance,
                        createdAt = createdAt,
                        notificationType = notificationType
                    )
                    result.success(null)
                }
                "createNotificationChannels" -> {
                    NotificationHelper.createNotificationChannels(this)
                    result.success(null)
                }
                "cancelSoundRepeats" -> {
                    val orderId = call.argument<String>("orderId") ?: ""
                    NotificationHelper.cancelSoundRepeats(this, orderId)
                    result.success(null)
                }
                "cancelOrderNotification" -> {
                    val orderId = call.argument<String>("orderId") ?: ""
                    NotificationHelper.cancelOrderNotification(this, orderId)
                    result.success(null)
                }
                "scheduleSnooze" -> {
                    val orderId = call.argument<String>("orderId") ?: ""
                    val offerId = call.argument<String>("offerId") ?: ""
                    val delaySeconds = call.argument<Int>("delaySeconds") ?: 300
                    val pickupLabel = call.argument<String>("pickupLabel") ?: ""
                    val dropoffLabel = call.argument<String>("dropoffLabel") ?: ""
                    val price = call.argument<Double>("price") ?: 0.0
                    val distance = call.argument<Double>("distance") ?: 0.0
                    val createdAt = call.argument<Long>("createdAt") ?: 0L
                    SnoozeScheduler.schedule(
                        this, orderId, offerId, delaySeconds,
                        pickupLabel, dropoffLabel, price, distance, createdAt
                    )
                    result.success(null)
                }
                "cancelSnooze" -> {
                    val orderId = call.argument<String>("orderId") ?: ""
                    SnoozeScheduler.cancel(this, orderId)
                    result.success(null)
                }
                "requestBatteryOptimizationExemption" -> {
                    val granted = requestBatteryOptimizationExemption()
                    result.success(granted)
                }
                "isBatteryOptimizationDisabled" -> {
                    val disabled = isBatteryOptimizationDisabled()
                    result.success(disabled)
                }
                "canBypassDnd" -> {
                    val canBypass = canBypassDnd()
                    result.success(canBypass)
                }
                "requestDndBypassPermission" -> {
                    val granted = requestDndBypassPermission()
                    result.success(granted)
                }
                "canScheduleExactAlarms" -> {
                    val canSchedule = canScheduleExactAlarms()
                    result.success(canSchedule)
                }
                "requestExactAlarmPermission" -> {
                    val granted = requestExactAlarmPermission()
                    result.success(granted)
                }
                "canUseFullScreenIntent" -> {
                    val canUse = canUseFullScreenIntent()
                    result.success(canUse)
                }
                "requestFullScreenIntentPermission" -> {
                    val granted = requestFullScreenIntentPermission()
                    result.success(granted)
                }
                "canDrawOverlays" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermissionIfNeeded()
                    result.success(true)
                }
                "getAllPermissionStatuses" -> {
                    val statuses = mapOf(
                        "batteryOptimizationDisabled" to isBatteryOptimizationDisabled(),
                        "canBypassDnd" to canBypassDnd(),
                        "canScheduleExactAlarms" to canScheduleExactAlarms(),
                        "canUseFullScreenIntent" to canUseFullScreenIntent(),
                        "canDrawOverlays" to Settings.canDrawOverlays(this)
                    )
                    result.success(statuses)
                }
                "setActiveTripFlag" -> {
                    val active = call.argument<Boolean>("active") ?: false
                    val orderId = call.argument<String>("orderId") ?: ""
                    val source = call.argument<String>("source") ?: "flutter"
                    val editor = getSharedPreferences(
                        MyFirebaseMessagingService.PREFS_TRIP_STATE,
                        Context.MODE_PRIVATE
                    ).edit()
                        .putBoolean(MyFirebaseMessagingService.KEY_HAS_ACTIVE_TRIP, active)
                    if (active) {
                        editor.putLong(MyFirebaseMessagingService.KEY_TRIP_SET_AT, System.currentTimeMillis())
                            .putString(MyFirebaseMessagingService.KEY_TRIP_ORDER_ID, orderId)
                            .putString(MyFirebaseMessagingService.KEY_TRIP_SOURCE, source)
                    } else {
                        editor.remove(MyFirebaseMessagingService.KEY_TRIP_SET_AT)
                            .remove(MyFirebaseMessagingService.KEY_TRIP_ORDER_ID)
                            .remove(MyFirebaseMessagingService.KEY_TRIP_SOURCE)
                    }
                    editor.apply()
                    result.success(null)
                }
                "getRejectedOrderIds" -> {
                    val prefs = getSharedPreferences("driver_rejected_orders_native", Context.MODE_PRIVATE)
                    val ids = prefs.getStringSet("rejected_order_ids", emptySet()) ?: emptySet()
                    result.success(ids.toList())
                }
                "addRejectedOrderId" -> {
                    val orderId = call.argument<String>("orderId") ?: ""
                    if (orderId.isNotBlank()) {
                        val prefs = getSharedPreferences("driver_rejected_orders_native", Context.MODE_PRIVATE)
                        val ids = prefs.getStringSet("rejected_order_ids", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
                        ids.add(orderId)
                        prefs.edit().putStringSet("rejected_order_ids", ids).apply()
                    }
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun requestBatteryOptimizationExemption(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            try {
                startActivity(intent)
                true
            } catch (e: Exception) {
                false
            }
        } else {
            true // Not needed on older Android versions
        }
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true // Not applicable on older Android versions
        }
    }

    private fun canBypassDnd(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.isNotificationPolicyAccessGranted
        } else {
            true // Not applicable on older Android versions
        }
    }

    private fun requestDndBypassPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            try {
                startActivity(intent)
                true
            } catch (e: Exception) {
                false
            }
        } else {
            true // Not needed on older Android versions
        }
    }

    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true // Not needed on older Android versions
        }
    }

    private fun requestExactAlarmPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:$packageName")
            }
            try {
                startActivity(intent)
                true
            } catch (e: Exception) {
                false
            }
        } else {
            true // Not needed on older Android versions
        }
    }

    private fun canUseFullScreenIntent(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ (API 34+) requires explicit permission
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.canUseFullScreenIntent()
        } else {
            true // Not needed on older Android versions
        }
    }

    private fun requestFullScreenIntentPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                data = Uri.parse("package:$packageName")
            }
            try {
                startActivity(intent)
                true
            } catch (e: Exception) {
                false
            }
        } else {
            true // Not needed on older Android versions
        }
    }

    /**
     * Request SYSTEM_ALERT_WINDOW permission for launching FullScreenNotificationActivity
     * over other apps on Android 12+. Only prompts once per install.
     */
    private fun requestOverlayPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val prefs = getSharedPreferences("overlay_perm", Context.MODE_PRIVATE)
            if (prefs.getBoolean("asked", false)) return // Only ask once
            prefs.edit().putBoolean("asked", true).apply()

            // Show explanation via system dialog then open settings
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            try {
                startActivity(intent)
                android.widget.Toast.makeText(
                    this,
                    "يحتاج التطبيق صلاحية الظهور فوق التطبيقات الأخرى لعرض طلبات الشحن الجديدة",
                    android.widget.Toast.LENGTH_LONG
                ).show()
            } catch (_: Exception) {}
        }
    }

    /**
     * Get intent extras from notification actions (accept / reject / snooze).
     * Returns null if no data or if already consumed.
     */
    private fun getIntentExtras(): Map<String, String?>? {
        val action = intent?.getStringExtra("action")
        if (action in listOf("accept_order", "view_order", "reject_order", "snooze_order", "start_trip")) {
            return mapOf(
                "orderId" to intent?.getStringExtra("orderId"),
                "notificationType" to intent?.getStringExtra("notificationType"),
                "action" to action,
                "pickupLabel" to intent?.getStringExtra("pickupLabel"),
                "dropoffLabel" to intent?.getStringExtra("dropoffLabel"),
                "price" to intent?.extras?.getDouble("price", 0.0)?.toString(),
                "distance" to intent?.extras?.getDouble("distance", 0.0)?.toString(),
                "offerId" to intent?.getStringExtra("offerId")
            )
        }
        if (action == "trip_start_reminder") {
            return mapOf(
                "action" to action,
                "orderId" to intent?.getStringExtra("orderId"),
                "pickupLabel" to intent?.getStringExtra("pickupLabel"),
                "destinationLabel" to intent?.getStringExtra("destinationLabel"),
                "elapsedMinutes" to intent?.getStringExtra("elapsedMinutes")
            )
        }
        return null
    }

    /**
     * Clear intent extras to prevent duplicate handling.
     */
    private fun clearIntentExtras() {
        intent?.removeExtra("action")
        intent?.removeExtra("orderId")
        intent?.removeExtra("notificationType")
        intent?.removeExtra("pickupLabel")
        intent?.removeExtra("dropoffLabel")
        intent?.removeExtra("destinationLabel")
        intent?.removeExtra("elapsedMinutes")
        intent?.removeExtra("price")
        intent?.removeExtra("distance")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        // Cancel notification if opened from full-screen intent
        cancelNotificationIfNeeded()

        // Push to EventChannel + cache as fallback
        dispatchActionIntent(intent)
    }

    /**
     * Extract action data from intent and deliver to Flutter via two paths:
     *   1. EventChannel (immediate, if Flutter is listening)
     *   2. SharedPreferences (fallback, if EventSink is null during cold start)
     *
     * Flutter checks the fallback cache on startup via getPendingActionFromCache().
     */
    private fun dispatchActionIntent(intent: Intent?) {
        val action = intent?.getStringExtra("action") ?: return

        val data = mapOf<String, Any?>(
            "action" to action,
            "orderId" to intent.getStringExtra("orderId"),
            "notificationType" to intent.getStringExtra("notificationType"),
            "offerId" to intent.getStringExtra("offerId")
        )

        // Path 1: EventChannel (immediate delivery if Flutter is listening)
        if (newIntentEventSink != null) {
            newIntentEventSink?.success(data)
            // Clear cache — EventChannel delivery succeeded
            getSharedPreferences(PREFS_PENDING_ACTION, Context.MODE_PRIVATE)
                .edit().clear().apply()
        } else {
            // Path 2: Cache to SharedPreferences (Flutter will read on startup)
            val prefs = getSharedPreferences(PREFS_PENDING_ACTION, Context.MODE_PRIVATE)
            prefs.edit()
                .putString("action", action)
                .putString("orderId", intent.getStringExtra("orderId"))
                .putString("notificationType", intent.getStringExtra("notificationType"))
                .putString("offerId", intent.getStringExtra("offerId"))
                .putLong("timestamp", System.currentTimeMillis())
                .apply()
        }
    }

    /**
     * Cancel the notification when MainActivity is opened from a full-screen intent.
     * This prevents the notification from lingering in the notification tray.
     */
    private fun cancelNotificationIfNeeded() {
        val orderId = intent?.getStringExtra("orderId")
        if (orderId != null) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val notificationId = orderId.hashCode()
            notificationManager.cancel(notificationId)
        }
    }
}
