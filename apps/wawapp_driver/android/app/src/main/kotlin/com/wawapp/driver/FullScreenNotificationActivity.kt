package com.wawapp.driver

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

/**
 * Native Kotlin Activity for full-screen notifications (no Flutter Engine).
 *
 * This Activity:
 * - Shows when locked (setShowWhenLocked)
 * - Turns screen on automatically (setTurnScreenOn)
 * - Dismisses keyguard (requestDismissKeyguard)
 * - Displays order details in native XML UI
 * - Opens MainActivity with orderId on "Accept"
 * - Closes on "Reject"
 *
 * Benefits over FlutterActivity:
 * - Opens instantly (< 200ms instead of 3-5 seconds)
 * - No Firebase/Auth overhead
 * - Industry standard (Uber/Careem pattern)
 * - No black screen issues
 */
class FullScreenNotificationActivity : Activity() {

    private lateinit var orderId: String
    private lateinit var notificationType: String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_full_screen_notification)

        setupLockScreenBehavior()
        loadNotificationData()
        setupButtons()

        // Cancel the notification immediately when the full-screen activity opens
        cancelNotification()

        Log.d(TAG, "Full-screen notification opened: orderId=$orderId, type=$notificationType")
    }

    private fun setupLockScreenBehavior() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            // Modern API (Android 8.1+)
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            // Legacy API (Android < 8.1)
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    private fun loadNotificationData() {
        // Extract data from Intent extras
        orderId = intent.getStringExtra("orderId") ?: "unknown"
        val pickupLabel = intent.getStringExtra("pickupLabel") ?: "موقع الاستلام"
        val dropoffLabel = intent.getStringExtra("dropoffLabel") ?: "الوجهة"
        val price = intent.getDoubleExtra("price", 0.0)
        val distance = intent.getDoubleExtra("distance", 0.0)
        notificationType = intent.getStringExtra("notificationType") ?: "new_order"

        // Update UI elements
        findViewById<TextView>(R.id.pickup_label).text = pickupLabel
        findViewById<TextView>(R.id.dropoff_label).text = dropoffLabel
        findViewById<TextView>(R.id.price_text).text = String.format("%.0f أوقية", price)
        findViewById<TextView>(R.id.distance_text).text = String.format("%.1f كم", distance)
        findViewById<TextView>(R.id.order_id_text).text = "Order: $orderId"

        // Update title based on notification type
        val titleText = when (notificationType) {
            "trip_start_reminder" -> "هل وصلت للعميل؟"
            "unassigned_order_reminder" -> "تذكير: طلب قريب منك"
            else -> "طلب جديد قريب منك"
        }
        findViewById<TextView>(R.id.notification_title).text = titleText
    }

    private fun setupButtons() {
        val acceptButton = findViewById<Button>(R.id.accept_button)
        val rejectButton = findViewById<Button>(R.id.reject_button)
        val laterButton = findViewById<Button>(R.id.later_button)

        acceptButton.setOnClickListener {
            Log.d(TAG, "Accept button clicked for order: $orderId")
            onAcceptClicked()
        }

        rejectButton.setOnClickListener {
            Log.d(TAG, "Reject button clicked for order: $orderId")
            onRejectClicked()
        }

        laterButton.setOnClickListener {
            Log.d(TAG, "Later button clicked for order: $orderId")
            onLaterClicked()
        }
    }

    private fun onAcceptClicked() {
        // Cancel sound repeats
        NotificationHelper.cancelSoundRepeats(this, orderId)

        // Open MainActivity with orderId
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("orderId", orderId)
            putExtra("notificationType", notificationType)
            putExtra("action", "open_order")
        }
        startActivity(intent)

        // Close this activity
        finish()
    }

    private fun onRejectClicked() {
        NotificationHelper.cancelSoundRepeats(this, orderId)

        // Open MainActivity so Flutter can write to driver_rejected_orders
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("orderId", orderId)
            putExtra("action", "reject_order")
        }
        startActivity(intent)
        finish()
    }

    private fun onLaterClicked() {
        NotificationHelper.cancelSoundRepeats(this, orderId)

        // Open MainActivity so Flutter can schedule a snooze reminder
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("orderId", orderId)
            putExtra("action", "snooze_order")
        }
        startActivity(intent)
        finish()

        Log.d(TAG, "User chose 'Later' for order: $orderId")
    }

    private fun cancelNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val notificationId = orderId.hashCode()
        notificationManager.cancel(notificationId)
        Log.d(TAG, "Notification cancelled: id=$notificationId, orderId=$orderId")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Full-screen notification destroyed: orderId=$orderId")
    }

    companion object {
        private const val TAG = "FullScreenNotifActivity"
    }
}
