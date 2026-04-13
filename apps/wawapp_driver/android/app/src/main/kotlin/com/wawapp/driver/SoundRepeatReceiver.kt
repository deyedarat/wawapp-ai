package com.wawapp.driver

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

        // Check if repeats were cancelled (user accepted/rejected)
        if (!NotificationHelper.hasPendingRepeats(context, orderId)) {
            Log.d(TAG, "Sound repeats cancelled for order $orderId, skipping")
            return
        }

        Log.d(TAG, "Playing repeat sound for order $orderId")
        playSoundOnce(context)
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
