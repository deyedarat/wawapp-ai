package com.wawapp.driver

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Dedicated Activity for full-screen notifications that behave like incoming phone calls.
 *
 * This Activity:
 * - Shows when locked (setShowWhenLocked)
 * - Turns screen on automatically (setTurnScreenOn)
 * - Dismisses keyguard (requestDismissKeyguard)
 * - Receives notification data via Intent extras
 * - Communicates with Flutter UI via MethodChannel
 *
 * Sound is handled entirely by NotificationHelper (channel sound + AlarmManager repeats).
 * No MediaPlayer here to avoid double-sound conflicts.
 */
class FullScreenNotificationActivity : FlutterActivity() {

    private val CHANNEL = "com.wawapp.driver/full_screen_notification"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupLockScreenBehavior()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNotificationData" -> {
                    val data = mapOf(
                        "orderId" to intent.getStringExtra("orderId"),
                        "pickupLabel" to intent.getStringExtra("pickupLabel"),
                        "dropoffLabel" to intent.getStringExtra("dropoffLabel"),
                        "price" to intent.getDoubleExtra("price", 0.0),
                        "distance" to intent.getDoubleExtra("distance", 0.0),
                        "createdAt" to intent.getLongExtra("createdAt", 0L),
                        "notificationType" to intent.getStringExtra("notificationType")
                    )
                    result.success(data)
                }
                "dismissActivity" -> {
                    // Cancel sound repeats when Flutter dismisses this activity
                    val orderId = intent.getStringExtra("orderId")
                    if (orderId != null) {
                        NotificationHelper.cancelSoundRepeats(this, orderId)
                    }
                    finish()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setupLockScreenBehavior() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Cancel sound repeats if activity is destroyed (user navigated away)
        val orderId = intent.getStringExtra("orderId")
        if (orderId != null) {
            NotificationHelper.cancelSoundRepeats(this, orderId)
        }
    }
}
