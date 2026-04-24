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
            ACTION_SNOOZE -> handleSnooze(context, orderId, notificationId, intent)
        }
    }

    private fun handleAccept(context: Context, orderId: String, notificationId: Int) {
        Log.d(TAG, "User accepted order: $orderId")

        // Cancel sound repeats
        NotificationHelper.cancelSoundRepeats(context, orderId)

        // Cancel any pending snooze alarm for this order (prevents ghost notification)
        SnoozeScheduler.cancel(context, orderId)

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

        // Cancel any pending snooze alarm for this order (prevents ghost notification)
        SnoozeScheduler.cancel(context, orderId)

        // Mark as rejected so native FCM handler won't re-show this order
        MyFirebaseMessagingService.markOrderRejected(context, orderId)

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

    private fun handleSnooze(context: Context, orderId: String, notificationId: Int, intent: Intent) {
        Log.d(TAG, "User snoozed order: $orderId")

        // Cancel sound repeats
        NotificationHelper.cancelSoundRepeats(context, orderId)

        // Dismiss notification
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(notificationId)

        // Schedule snooze alarm via AlarmManager (survives Doze + process death).
        // Mirrors FullScreenNotificationActivity.onLaterClicked() exactly.
        val offerId = intent.getStringExtra("offerId") ?: ""
        val pickupLabel = intent.getStringExtra("pickupLabel") ?: ""
        val dropoffLabel = intent.getStringExtra("dropoffLabel") ?: ""
        val price = intent.getDoubleExtra("price", 0.0)
        val distance = intent.getDoubleExtra("distance", 0.0)
        val createdAt = intent.getLongExtra("createdAt", 0L)

        SnoozeScheduler.schedule(
            context = context,
            orderId = orderId,
            offerId = offerId,
            delaySeconds = 300,
            pickupLabel = pickupLabel,
            dropoffLabel = dropoffLabel,
            price = price,
            distance = distance,
            createdAt = createdAt
        )

        Log.d(TAG, "Snooze scheduled for order: $orderId (300s)")
    }

    companion object {
        private const val TAG = "OrderActionReceiver"
        const val ACTION_ACCEPT = "com.wawapp.driver.ORDER_ACCEPT"
        const val ACTION_DECLINE = "com.wawapp.driver.ORDER_DECLINE"
        const val ACTION_START_TRIP = "com.wawapp.driver.ORDER_START_TRIP"
        const val ACTION_SNOOZE = "com.wawapp.driver.ORDER_SNOOZE"
    }
}
