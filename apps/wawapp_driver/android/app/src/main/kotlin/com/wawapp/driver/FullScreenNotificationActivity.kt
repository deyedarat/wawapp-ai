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
    private var notificationId: Int = 0
    private var offerId: String = ""
    private var pickupLabel: String = ""
    private var dropoffLabel: String = ""
    private var price: Double = 0.0
    private var distance: Double = 0.0
    private var createdAt: Long = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_full_screen_notification)

        setupLockScreenBehavior()
        loadNotificationData()
        setupButtons()

        // Do NOT cancel notification here — keep it visible as fallback.
        // Sound from FLAG_INSISTENT continues until user interacts (accept/reject/later).
        // This ensures full-screen experience is preserved.

        Log.d(TAG, "Full-screen notification opened: orderId=$orderId, type=$notificationType, notifId=$notificationId")
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
        pickupLabel = intent.getStringExtra("pickupLabel") ?: "موقع الاستلام"
        dropoffLabel = intent.getStringExtra("dropoffLabel") ?: "الوجهة"
        price = intent.getDoubleExtra("price", 0.0)
        distance = intent.getDoubleExtra("distance", 0.0)
        createdAt = intent.getLongExtra("createdAt", 0L)
        notificationType = intent.getStringExtra("notificationType") ?: "new_order"
        notificationId = intent.getIntExtra("notificationId", orderId.hashCode())
        offerId = intent.getStringExtra("offerId") ?: ""

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
        // Cancel notification + sound completely
        cancelNotification()

        // Cancel any pending snooze alarm for this order (prevents ghost notification)
        SnoozeScheduler.cancel(this, orderId)

        // Open MainActivity with orderId
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("orderId", orderId)
            putExtra("notificationType", notificationType)
            putExtra("action", "accept_order")
            putExtra("offerId", offerId)
        }
        startActivity(intent)

        // Close this activity
        finish()
    }

    private fun onRejectClicked() {
        cancelNotification()

        // Cancel any pending snooze alarm for this order (prevents ghost notification)
        SnoozeScheduler.cancel(this, orderId)

        // Mark as rejected so native FCM handler won't re-show this order
        MyFirebaseMessagingService.markOrderRejected(this, orderId)

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
        cancelNotification()

        // Schedule snooze alarm via AlarmManager (survives Doze + process death).
        // This matches Flutter's FullScreenNotificationScreen._snooze() exactly:
        // 1. SnoozeScheduler.schedule() clears native fcm_dedup so the alarm
        //    won't be blocked by the 10-min TTL dedup.
        // 2. SnoozeAlarmReceiver fires after 300s, re-validates via Firestore,
        //    and re-shows the full-screen notification.
        SnoozeScheduler.schedule(
            context = this,
            orderId = orderId,
            offerId = offerId,
            delaySeconds = 300,
            pickupLabel = pickupLabel,
            dropoffLabel = dropoffLabel,
            price = price,
            distance = distance,
            createdAt = createdAt
        )

        finish()

        Log.d(TAG, "User chose 'Later' for order: $orderId — snooze scheduled (300s)")
    }

    private fun cancelNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        // Cancel by the exact notificationId used when creating
        notificationManager.cancel(notificationId)
        // Cancel fixed-ID notifications (covers the new stacking fix)
        notificationManager.cancel(2000) // NOTIF_ID_NEW_ORDER
        notificationManager.cancel(2001) // NOTIF_ID_UNASSIGNED
        // Also cancel by orderId.hashCode() as legacy fallback
        notificationManager.cancel(orderId.hashCode())
        // Stop FLAG_INSISTENT sound + scheduled repeats
        NotificationHelper.cancelSoundRepeats(this, orderId)
        Log.d(TAG, "Notification cancelled: notifId=$notificationId, orderId=$orderId")
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        loadNotificationData()
        // Restart sound for the new order
        NotificationHelper.playSoundOnce(this)
        Log.d(TAG, "onNewIntent: UI updated for new order $orderId")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Full-screen notification destroyed: orderId=$orderId")
    }

    companion object {
        private const val TAG = "FullScreenNotifActivity"
    }
}
