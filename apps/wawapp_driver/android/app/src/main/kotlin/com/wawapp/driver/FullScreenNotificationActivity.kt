package com.wawapp.driver

import android.app.KeyguardManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
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
 */
class FullScreenNotificationActivity : FlutterActivity() {

    private val CHANNEL = "com.wawapp.driver/full_screen_notification"
    private var mediaPlayer: MediaPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Make notification appear on lock screen + turn screen on
        setupLockScreenBehavior()

        // Play notification sound
        playNotificationSound()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Create MethodChannel to send notification data to Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNotificationData" -> {
                    // Return notification data from Intent extras
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
                    // Allow Flutter to close this Activity
                    finish()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Configure Activity to show on lock screen and turn screen on.
     */
    private fun setupLockScreenBehavior() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            // Android 8.1 (API 27) and above
            setShowWhenLocked(true)
            setTurnScreenOn(true)

            // Dismiss keyguard to allow user interaction
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            // Android 8.0 (API 26) and below (deprecated but necessary for older devices)
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    /**
     * Play notification sound manually (repeat 3 times) using MediaPlayer.
     * This ensures sound plays even if notification channels are muted.
     */
    private fun playNotificationSound() {
        try {
            val soundUri = Uri.parse("android.resource://${packageName}/raw/trip_reminder")

            mediaPlayer = MediaPlayer().apply {
                setDataSource(applicationContext, soundUri)

                // Use ALARM stream to bypass Do Not Disturb
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .build()
                    )
                } else {
                    @Suppress("DEPRECATION")
                    setAudioStreamType(AudioManager.STREAM_ALARM)
                }

                // Loop 3 times
                isLooping = false
                var playCount = 0
                setOnCompletionListener {
                    playCount++
                    if (playCount < 3) {
                        seekTo(0)
                        start()
                    } else {
                        release()
                        mediaPlayer = null
                    }
                }

                prepare()
                start()
            }
        } catch (e: Exception) {
            android.util.Log.e("FullScreenNotification", "Error playing sound: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()

        // Stop and release MediaPlayer
        mediaPlayer?.apply {
            if (isPlaying) stop()
            release()
        }
        mediaPlayer = null
    }
}
