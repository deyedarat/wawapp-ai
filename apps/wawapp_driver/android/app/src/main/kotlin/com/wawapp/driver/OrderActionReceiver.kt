package com.wawapp.driver

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver for handling order accept/decline actions from CallStyle notification.
 */
class OrderActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val orderId = intent.getStringExtra("orderId") ?: return
        val notificationId = intent.getIntExtra("notificationId", 0)

        Log.d(TAG, "OrderActionReceiver: action=$action, orderId=$orderId")

        when (action) {
            ACTION_ACCEPT -> handleAccept(context, orderId, notificationId)
            ACTION_DECLINE -> handleDecline(context, orderId, notificationId)
            ACTION_START_TRIP -> handleStartTrip(context, orderId, notificationId)
            ACTION_SNOOZE -> handleSnooze(context, orderId, notificationId)
        }
    }

    private fun handleAccept(context: Context, orderId: String, notificationId: Int) {
        Log.d(TAG, "User accepted order: $orderId")

        // Cancel sound repeats
        NotificationHelper.cancelSoundRepeats(context, orderId)

        // Dismiss notification
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(notificationId)

        // Open MainActivity with orderId
        val mainIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("orderId", orderId)
            putExtra("action", "accept_order")
            putExtra("notificationType", "new_order_accepted")
        }
        context.startActivity(mainIntent)
    }

    private fun handleDecline(context: Context, orderId: String, notificationId: Int) {
        Log.d(TAG, "User declined order: $orderId")

        // Cancel sound repeats
        NotificationHelper.cancelSoundRepeats(context, orderId)

        // Dismiss notification
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(notificationId)

        // Open MainActivity so Flutter's AuthGate writes rejection to driver_rejected_orders.
        // This mirrors FullScreenNotificationActivity.onRejectClicked() exactly.
        val mainIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("orderId", orderId)
            putExtra("action", "reject_order")
        }
        context.startActivity(mainIntent)
    }

    private fun handleStartTrip(context: Context, orderId: String, notificationId: Int) {
        Log.d(TAG, "User starting trip: $orderId")

        // Cancel sound repeats
        NotificationHelper.cancelSoundRepeats(context, orderId)

        // Dismiss notification
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(notificationId)

        // Open MainActivity with start_trip action
        val mainIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("orderId", orderId)
            putExtra("action", "start_trip")
        }
        context.startActivity(mainIntent)
    }

    private fun handleSnooze(context: Context, orderId: String, notificationId: Int) {
        Log.d(TAG, "User snoozed trip reminder: $orderId")

        // Cancel sound repeats
        NotificationHelper.cancelSoundRepeats(context, orderId)

        // Dismiss notification
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(notificationId)

        // Just dismiss - Flutter will handle re-showing after snooze duration
    }

    companion object {
        private const val TAG = "OrderActionReceiver"
        const val ACTION_ACCEPT = "com.wawapp.driver.ORDER_ACCEPT"
        const val ACTION_DECLINE = "com.wawapp.driver.ORDER_DECLINE"
        const val ACTION_START_TRIP = "com.wawapp.driver.ORDER_START_TRIP"
        const val ACTION_SNOOZE = "com.wawapp.driver.ORDER_SNOOZE"
    }
}
