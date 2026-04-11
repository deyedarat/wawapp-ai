package com.wawapp.driver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receiver triggered when user swipes away (dismisses) a notification.
 * Cancels any pending sound repeats for that order.
 */
class NotificationDismissReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val orderId = intent.getStringExtra("orderId") ?: return
        Log.d("NotificationDismiss", "Notification dismissed for order $orderId, cancelling repeats")
        NotificationHelper.cancelSoundRepeats(context, orderId)
    }
}
