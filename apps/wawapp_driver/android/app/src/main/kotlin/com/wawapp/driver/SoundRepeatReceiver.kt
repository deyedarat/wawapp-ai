package com.wawapp.driver

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.util.Log

/**
 * BroadcastReceiver triggered by AlarmManager to repeat notification sound.
 *
 * Uses MediaPlayer with USAGE_ALARM to bypass DND and play the sound
 * without creating additional visible notifications.
 *
 * Checks that the main notification still exists before playing
 * (user may have dismissed or tapped it).
 */
class SoundRepeatReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "SoundRepeatReceiver"
        const val ACTION = "com.wawapp.driver.SOUND_REPEAT"
        const val EXTRA_NOTIFICATION_ID = "notificationId"
        const val EXTRA_ORDER_ID = "orderId"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
        val orderId = intent.getStringExtra(EXTRA_ORDER_ID) ?: ""

        // Check if main notification still exists (user didn't dismiss/tap)
        if (!isNotificationActive(context, notificationId)) {
            Log.d(TAG, "Main notification $notificationId dismissed, skipping sound repeat")
            return
        }

        // Check if repeats were cancelled
        if (!NotificationHelper.hasPendingRepeats(context, orderId)) {
            Log.d(TAG, "Sound repeats cancelled for order $orderId, skipping")
            return
        }

        Log.d(TAG, "Playing repeat sound for order $orderId")
        playSoundOnce(context)
    }

    private fun isNotificationActive(context: Context, notificationId: Int): Boolean {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            nm.activeNotifications.any { it.id == notificationId }
        } else {
            true // Can't check on older APIs, assume active
        }
    }

    private fun playSoundOnce(context: Context) {
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
            Log.e(TAG, "Error playing repeat sound: ${e.message}")
        }
    }
}
