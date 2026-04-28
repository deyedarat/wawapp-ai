package com.wawapp.driver

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import com.google.android.gms.tasks.Tasks
import com.google.firebase.firestore.FirebaseFirestore
import java.util.concurrent.TimeUnit

/**
 * Native full-screen Activity for trip start reminders (amber/orange theme).
 *
 * Shows over lock screen like FullScreenNotificationActivity but with:
 * - Amber background (warning color)
 * - Live elapsed timer since order acceptance
 * - "Start Trip" and "Not Yet" buttons
 *
 * On "Start Trip": opens MainActivity with action=start_trip
 * On "Not Yet": dismisses and returns to previous screen
 */
class TripReminderActivity : Activity() {

    private lateinit var orderId: String
    private var elapsedMinutes: Int = 0
    private var elapsedSeconds: Int = 0
    private var notificationId: Int = 0
    private val handler = Handler(Looper.getMainLooper())
    private var timerRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_trip_reminder)

        setupLockScreenBehavior()
        loadData()
        setupButtons()
        startTimer()

        // Verify order is still accepted — close if cancelled/completed
        verifyOrderStatus()

        Log.d(TAG, "TripReminderActivity opened: orderId=$orderId, elapsed=${elapsedMinutes}min")
    }

    private fun setupLockScreenBehavior() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            km.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    private fun loadData() {
        orderId = intent.getStringExtra("orderId") ?: "unknown"
        elapsedMinutes = intent.getIntExtra("elapsedMinutes", 0)
        elapsedSeconds = elapsedMinutes * 60
        notificationId = intent.getIntExtra("notificationId", orderId.hashCode())

        val pickupLabel = intent.getStringExtra("pickupLabel") ?: "موقع الاستلام"
        val dropoffLabel = intent.getStringExtra("dropoffLabel")
            ?: intent.getStringExtra("destinationLabel")
            ?: "الوجهة"

        findViewById<TextView>(R.id.pickup_label).text = pickupLabel
        findViewById<TextView>(R.id.dropoff_label).text = dropoffLabel
        updateTimerDisplay()
    }

    private fun setupButtons() {
        findViewById<Button>(R.id.start_trip_button).setOnClickListener {
            Log.d(TAG, "Start trip clicked: orderId=$orderId")
            cancelNotification()
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("orderId", orderId)
                putExtra("action", "start_trip")
                putExtra("notificationType", "trip_start_reminder")
            }
            startActivity(intent)
            finish()
        }

        findViewById<Button>(R.id.not_yet_button).setOnClickListener {
            Log.d(TAG, "Not yet clicked: orderId=$orderId")
            cancelNotification()
            finish()
        }
    }

    private fun startTimer() {
        timerRunnable = object : Runnable {
            override fun run() {
                elapsedSeconds++
                updateTimerDisplay()
                handler.postDelayed(this, 1000)
            }
        }
        handler.postDelayed(timerRunnable!!, 1000)
    }

    private fun updateTimerDisplay() {
        val m = elapsedSeconds / 60
        val s = elapsedSeconds % 60
        val text = String.format("%02d:%02d", m, s)
        findViewById<TextView>(R.id.elapsed_timer).text = text
    }

    private fun cancelNotification() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        nm.cancel(notificationId)
        nm.cancel(2002) // NOTIF_ID_TRIP_REMINDER (fixed ID)
        nm.cancel(orderId.hashCode()) // legacy fallback
        NotificationHelper.cancelSoundRepeats(this, orderId)
    }

    private fun verifyOrderStatus() {
        Thread {
            try {
                val task = FirebaseFirestore.getInstance()
                    .collection("orders")
                    .document(orderId)
                    .get()
                val snapshot = Tasks.await(task, 5, TimeUnit.SECONDS)
                val status = snapshot.getString("status")
                if (status != "accepted") {
                    Log.d(TAG, "Order $orderId is '$status' (not accepted) — closing reminder")
                    handler.post {
                        cancelNotification()
                        finish()
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Order status check failed (keeping open): ${e.message}")
            }
        }.start()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Reset timer and reload data for the new reminder
        timerRunnable?.let { handler.removeCallbacks(it) }
        loadData()
        startTimer()
        NotificationHelper.playSoundOnce(this)
        verifyOrderStatus()
        Log.d(TAG, "onNewIntent: UI updated for order $orderId")
    }

    override fun onDestroy() {
        timerRunnable?.let { handler.removeCallbacks(it) }
        super.onDestroy()
    }

    companion object {
        private const val TAG = "TripReminderActivity"
    }
}
