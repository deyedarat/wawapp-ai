package com.wawapp.driver

import android.app.Activity
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.util.Log
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration

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

    private var orderListener: ListenerRegistration? = null
    private var offerListener: ListenerRegistration? = null
    private var wakeLock: PowerManager.WakeLock? = null

    private val terminalStatuses = setOf(
        "cancelled", "cancelledByClient", "cancelledByDriver",
        "expired", "accepted", "completed"
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        // CRITICAL: Lock-screen flags MUST be set BEFORE super.onCreate() and setContentView()
        // to ensure the window is configured before the decor view is created.
        // This fixes locked-screen failures on Android 12-14 and Xiaomi/MIUI.
        setupLockScreenFlags()

        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_full_screen_notification)

        // Acquire WakeLock as fallback for devices where setTurnScreenOn is unreliable
        acquireScreenWakeLock()

        // Dismiss keyguard AFTER layout is inflated (some OEMs require visible window)
        dismissKeyguard()

        logLockScreenState("onCreate")

        loadNotificationData()
        setupButtons()
        startOrderListener()

        Log.d(TAG, "Full-screen notification opened: orderId=$orderId, type=$notificationType, notifId=$notificationId")
        Log.d("WAWAPP_TEST", "FULLSCREEN_LAUNCHED orderId=$orderId, type=$notificationType, locked=${(getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked}")
        Log.i("WAWAPP_EVENT", "{\"event\":\"FULLSCREEN_LAUNCHED\",\"ts\":${System.currentTimeMillis()},\"phase\":\"runtime\",\"data\":{\"orderId\":\"$orderId\",\"type\":\"$notificationType\",\"locked\":${(getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked}}}")
    }

    /**
     * Set window flags BEFORE super.onCreate(). This is the correct lifecycle ordering
     * for lock-screen activities. Android's WindowManager reads these flags during
     * decor view creation — setting them after is too late on some OEMs.
     */
    private fun setupLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }

        // Window flags — applied to ALL API levels for maximum compatibility.
        // On API 27+ these are redundant with setShowWhenLocked/setTurnScreenOn
        // but some OEMs (Xiaomi MIUI, Oppo ColorOS) still require the flags.
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )
    }

    /**
     * Acquire a partial WakeLock with ACQUIRE_CAUSES_WAKEUP to force screen on.
     * This is the nuclear fallback for devices where setTurnScreenOn(true) fails
     * (common on Xiaomi MIUI 13+, some Samsung One UI 5+ builds).
     * Released in onDestroy() — max 60s timeout as safety net.
     */
    private fun acquireScreenWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            wakeLock = pm.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "wawapp:fullscreen_notification"
            ).apply {
                acquire(60_000L) // 60s max — auto-release safety
            }
            Log.d(TAG, "WakeLock acquired (ACQUIRE_CAUSES_WAKEUP)")
        } catch (e: Exception) {
            Log.w(TAG, "WakeLock acquisition failed: ${e.message}")
        }
    }

    /**
     * Dismiss keyguard with callback logging. Called AFTER setContentView()
     * because some OEMs require a visible window before keyguard dismissal.
     */
    private fun dismissKeyguard() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                override fun onDismissSucceeded() {
                    Log.d(TAG, "Keyguard dismissed successfully")
                }
                override fun onDismissCancelled() {
                    Log.w(TAG, "Keyguard dismissal cancelled (user has secure lock?)")
                }
                override fun onDismissError() {
                    Log.w(TAG, "Keyguard dismissal error")
                }
            })
        }
    }

    /**
     * Log lock-screen and permission state for QA diagnostics.
     */
    private fun logLockScreenState(phase: String) {
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val isLocked = km.isKeyguardLocked
        val isSecure = km.isDeviceSecure
        val isScreenOn = pm.isInteractive

        Log.d(TAG, "[$phase] lockState: locked=$isLocked, secure=$isSecure, screenOn=$isScreenOn, sdk=${Build.VERSION.SDK_INT}")

        // Android 14+ full-screen intent permission check
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val canFSI = nm.canUseFullScreenIntent()
            Log.d(TAG, "[$phase] USE_FULL_SCREEN_INTENT granted=$canFSI")
            if (!canFSI) {
                Log.w(TAG, "⚠️ Full-screen intent permission REVOKED on Android 14+ — activity may not show over lock screen via notification fallback")
            }
        }
    }

    private fun loadNotificationData() {
        // Extract data from Intent extras
        orderId = intent.getStringExtra("orderId") ?: "unknown"

        // Validate orderId — finish immediately if invalid
        if (orderId.isBlank() || orderId == "unknown") {
            Log.w(TAG, "Invalid orderId ('$orderId') — finishing activity")
            finish()
            return
        }

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

        // Mark this order in native dedup so subsequent FCM waves are dropped
        val dedupPrefs = getSharedPreferences("fcm_dedup", Context.MODE_PRIVATE)
        dedupPrefs.edit()
            .putLong(offerId.ifBlank { orderId }, System.currentTimeMillis())
            .putLong(orderId, System.currentTimeMillis())
            .apply()

        // Set active trip flag so FCM handler suppresses new_order notifications
        val tripPrefs = getSharedPreferences(MyFirebaseMessagingService.PREFS_TRIP_STATE, Context.MODE_PRIVATE)
        tripPrefs.edit()
            .putBoolean(MyFirebaseMessagingService.KEY_HAS_ACTIVE_TRIP, true)
            .putLong(MyFirebaseMessagingService.KEY_TRIP_SET_AT, System.currentTimeMillis())
            .putString(MyFirebaseMessagingService.KEY_TRIP_ORDER_ID, orderId)
            .putString(MyFirebaseMessagingService.KEY_TRIP_SOURCE, "native_accept")
            .apply()

        Log.d(TAG, "onAcceptClicked: launching MainActivity with action=accept_order, orderId=$orderId, offerId=$offerId")

        // Open MainActivity with orderId
        // FLAG_ACTIVITY_SINGLE_TOP ensures onNewIntent() is called on existing instance
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
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
        MyFirebaseMessagingService.markOrderRejected(this, orderId, offerId)

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

    private fun startOrderListener() {
        if (!::orderId.isInitialized || orderId.isBlank() || orderId == "unknown") return
        orderListener?.remove()
        orderListener = FirebaseFirestore.getInstance()
            .collection("orders")
            .document(orderId)
            .addSnapshotListener { snap, error ->
                if (error != null) {
                    Log.w(TAG, "Order listener error: ${error.message}")
                    return@addSnapshotListener
                }
                if (snap == null || !snap.exists()) {
                    Log.d(TAG, "Order $orderId deleted — finishing")
                    cancelNotification()
                    finish()
                    return@addSnapshotListener
                }
                val status = snap.getString("status")
                if (status != null && status in terminalStatuses) {
                    Log.d(TAG, "Order $orderId reached terminal status '$status' — finishing")
                    cancelNotification()
                    finish()
                }
            }

        // Also monitor the specific dispatch_offer for this driver.
        // When the offer expires/is cancelled (even if order stays 'matching'
        // because another wave is being tried), dismiss the fullscreen.
        startOfferListener()
    }

    private fun startOfferListener() {
        if (offerId.isBlank()) return
        offerListener?.remove()
        offerListener = FirebaseFirestore.getInstance()
            .collection("dispatch_offers")
            .document(offerId)
            .addSnapshotListener { snap, error ->
                if (error != null) {
                    Log.w(TAG, "Offer listener error: ${error.message}")
                    return@addSnapshotListener
                }
                if (snap == null || !snap.exists()) {
                    Log.d(TAG, "Offer $offerId deleted — finishing")
                    cancelNotification()
                    finish()
                    return@addSnapshotListener
                }
                val status = snap.getString("status")
                val offerTerminalStatuses = setOf("expired", "cancelled", "accepted", "rejected")
                if (status != null && status in offerTerminalStatuses) {
                    Log.d(TAG, "Offer $offerId reached terminal status '$status' — finishing")
                    cancelNotification()
                    finish()
                }
            }
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        loadNotificationData()
        startOrderListener()
        // Restart sound for the new order
        NotificationHelper.playSoundOnce(this)
        Log.d(TAG, "onNewIntent: UI updated for new order $orderId")
    }

    override fun onDestroy() {
        orderListener?.remove()
        orderListener = null
        offerListener?.remove()
        offerListener = null
        releaseWakeLock()
        super.onDestroy()
        Log.d(TAG, "Full-screen notification destroyed: orderId=$orderId")
    }

    @Deprecated("Use onBackPressedDispatcher")
    override fun onBackPressed() {
        // Cancel notification + sound on back press (prevents orphaned notification)
        cancelNotification()
        super.onBackPressed()
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "WakeLock released")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "WakeLock release error: ${e.message}")
        }
        wakeLock = null
    }

    companion object {
        private const val TAG = "FullScreenNotifActivity"
    }
}
