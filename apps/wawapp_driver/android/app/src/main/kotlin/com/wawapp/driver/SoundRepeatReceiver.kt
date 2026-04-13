package com.wawapp.driver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver triggered by AlarmManager as a BACKUP for sound repeats.
 *
 * PRIMARY path: Handler.postDelayed in NotificationHelper fires at +2s/+4s
 * while the process is alive (FullScreenNotificationActivity is showing).
 *
 * BACKUP path (this receiver): fires via AlarmManager even if the process
 * was killed before the Handler could run. Uses consumePendingRepeat() to
 * prevent double-play if the Handler already fired.
 */
class SoundRepeatReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "SoundRepeatReceiver"
        const val ACTION = "com.wawapp.driver.SOUND_REPEAT"
        const val EXTRA_NOTIFICATION_ID = "notificationId"
        const val EXTRA_ORDER_ID = "orderId"
        const val EXTRA_REPEAT_NUM = "repeatNum"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val orderId = intent.getStringExtra(EXTRA_ORDER_ID) ?: ""
        val repeatNum = intent.getIntExtra(EXTRA_REPEAT_NUM, 0)

        if (repeatNum == 0 || orderId.isEmpty()) {
            Log.w(TAG, "Missing orderId or repeatNum, skipping")
            return
        }

        // consumePendingRepeat returns false if:
        //   (a) Handler already played this repeat slot, OR
        //   (b) cancelSoundRepeats was called (order accepted/rejected)
        if (!NotificationHelper.consumePendingRepeat(context, orderId, repeatNum)) {
            Log.d(TAG, "Repeat $repeatNum already consumed or cancelled for order $orderId")
            return
        }

        Log.d(TAG, "AlarmManager backup: playing repeat $repeatNum for order $orderId")
        NotificationHelper.playSoundOnce(context)
    }
}
