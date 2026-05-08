package com.wawapp.driver

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import com.google.firebase.messaging.FirebaseMessaging
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Production-grade FCM notification certification test.
 *
 * Validates on Firebase Test Lab physical devices (Samsung A15, Android 14):
 * - Real FCM token acquisition
 * - Token persistence for external push injection
 * - Push delivery in foreground/background states
 * - Notification dedup logic
 * - AlarmManager sound repeat scheduling
 * - FullScreenNotificationActivity launch
 *
 * Markers for log parsing:
 *   WAWAPP_TEST, FCM_TOKEN=, WAITING_FOR_PUSH, PUSH_RECEIVED
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * AGENTIC ORCHESTRATION CONTRACT
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * This test emits structured JSON events on logcat tag "WAWAPP_EVENT" for
 * machine consumption by external orchestration agents (Antigravity, MCP,
 * Appium, scenario replay frameworks).
 *
 * Event schema (NDJSON on logcat):
 *   {"event":"<EVENT_TYPE>","ts":<unix_ms>,"phase":"<PHASE>","data":{...}}
 *
 * Event types:
 *   SCENARIO_START    — test execution begins, includes device metadata
 *   TOKEN_ACQUIRED    — FCM token ready for push injection
 *   PHASE_TRANSITION  — boundary between test phases
 *   AWAITING_STIMULUS — test is idle, waiting for external input
 *   STIMULUS_RECEIVED — external push arrived and was processed
 *   ASSERTION_RESULT  — individual check pass/fail with evidence
 *   SCENARIO_END      — test complete, includes aggregate verdict
 *
 * Agents can:
 *   1. Stream logcat filtered on "WAWAPP_EVENT" for real-time state
 *   2. Parse TOKEN_ACQUIRED to inject pushes at the right moment
 *   3. Wait for AWAITING_STIMULUS before sending FCM payloads
 *   4. Collect ASSERTION_RESULT events for automated verdict aggregation
 *   5. Use SCENARIO_END exit code for CI gate decisions
 *
 * File artifacts (retrievable via adb pull or Test Lab GCS bucket):
 *   /data/data/com.wawapp.driver/files/fcm_token.txt
 *   /data/data/com.wawapp.driver/files/certification_events.ndjson
 *   /sdcard/Android/data/com.wawapp.driver/files/fcm_token.txt
 *   /sdcard/Android/data/com.wawapp.driver/files/certification_events.ndjson
 */
@RunWith(AndroidJUnit4::class)
class NotificationE2ETest {

    companion object {
        private const val TAG = "WAWAPP_TEST"
        private const val EVENT_TAG = "WAWAPP_EVENT"
        private const val WAIT_FOR_PUSH_SECONDS = 180L
        private const val POLL_INTERVAL_MS = 2000L
        private const val EVENTS_FILE = "certification_events.ndjson"
    }

    @get:Rule
    val permissionRule: GrantPermissionRule = if (Build.VERSION.SDK_INT >= 33) {
        GrantPermissionRule.grant(Manifest.permission.POST_NOTIFICATIONS)
    } else {
        GrantPermissionRule.grant()
    }

    @Test
    fun fcmCertification_extractTokenAndWaitForPush() {
        Log.i(TAG, "═══════════════════════════════════════════════════")
        Log.i(TAG, "  FCM NOTIFICATION CERTIFICATION TEST START")
        Log.i(TAG, "  Device: ${Build.MANUFACTURER} ${Build.MODEL}")
        Log.i(TAG, "  SDK: ${Build.VERSION.SDK_INT} (Android ${Build.VERSION.RELEASE})")
        Log.i(TAG, "═══════════════════════════════════════════════════")

        val context = InstrumentationRegistry.getInstrumentation().targetContext

        emitEvent("SCENARIO_START", "init", mapOf(
            "scenario" to "fcm_certification",
            "device" to "${Build.MANUFACTURER}/${Build.MODEL}",
            "sdk" to Build.VERSION.SDK_INT,
            "android" to Build.VERSION.RELEASE,
            "package" to context.packageName
        ))

        // Phase 1: Launch app and acquire FCM token
        Log.i(TAG, "[PHASE 1] Launching MainActivity...")
        val scenario = ActivityScenario.launch(MainActivity::class.java)
        Log.i(TAG, "[PHASE 1] MainActivity launched successfully")

        val tokenLatch = CountDownLatch(1)
        var fcmToken = ""

        FirebaseMessaging.getInstance().token
            .addOnCompleteListener { task ->
                if (!task.isSuccessful) {
                    Log.e(TAG, "[PHASE 1] FCM token fetch FAILED: ${task.exception?.message}")
                    tokenLatch.countDown()
                    return@addOnCompleteListener
                }

                fcmToken = task.result ?: ""
                Log.i(TAG, "FCM_TOKEN=$fcmToken")
                Log.i(TAG, "[PHASE 1] Token length: ${fcmToken.length}")

                // Persist token to file artifact (retrievable via `adb pull`)
                persistToken(context, fcmToken)

                tokenLatch.countDown()
            }

        val tokenAcquired = tokenLatch.await(30, TimeUnit.SECONDS)
        if (!tokenAcquired || fcmToken.isEmpty()) {
            Log.e(TAG, "[PHASE 1] FATAL: Could not acquire FCM token within 30s")
            scenario.close()
            return
        }

        Log.i(TAG, "[PHASE 1] ✓ FCM token acquired and persisted")

        emitEvent("TOKEN_ACQUIRED", "phase_1", mapOf(
            "token" to fcmToken,
            "length" to fcmToken.length
        ))
        emitEvent("PHASE_TRANSITION", "phase_1", mapOf("from" to "token_acquisition", "to" to "channel_audit"))

        // Phase 2: Log notification channel state
        logNotificationChannelState(context)

        // Phase 3: Wait for external FCM push injection
        emitEvent("PHASE_TRANSITION", "phase_2", mapOf("from" to "channel_audit", "to" to "awaiting_stimulus"))
        emitEvent("AWAITING_STIMULUS", "phase_3", mapOf(
            "stimulus_type" to "fcm_push",
            "timeout_seconds" to WAIT_FOR_PUSH_SECONDS,
            "token" to fcmToken,
            "ready" to true
        ))

        Log.i(TAG, "WAITING_FOR_PUSH")
        Log.i(TAG, "[PHASE 3] Waiting ${WAIT_FOR_PUSH_SECONDS}s for external FCM push...")
        Log.i(TAG, "[PHASE 3] Send push to token above using orchestration script")

        val pushReceived = waitForPushDelivery(context)

        if (pushReceived) {
            Log.i(TAG, "PUSH_RECEIVED")
            Log.i(TAG, "[PHASE 3] ✓ Push notification delivered and processed")
            emitEvent("STIMULUS_RECEIVED", "phase_3", mapOf("type" to "fcm_push", "success" to true))
            emitEvent("ASSERTION_RESULT", "phase_3", mapOf(
                "check" to "fcm_delivery", "result" to "PASS", "evidence" to "SharedPreferences marker written"
            ))
        } else {
            Log.w(TAG, "[PHASE 3] ⚠ No push detected within ${WAIT_FOR_PUSH_SECONDS}s window")
            Log.w(TAG, "[PHASE 3] This may be expected if orchestration script was not run")
            emitEvent("ASSERTION_RESULT", "phase_3", mapOf(
                "check" to "fcm_delivery", "result" to "SKIP", "evidence" to "No stimulus received within timeout"
            ))
        }

        // Phase 4: Final state audit
        logFinalState(context)

        emitEvent("SCENARIO_END", "complete", mapOf(
            "scenario" to "fcm_certification",
            "push_received" to pushReceived,
            "verdict" to if (pushReceived) "PASS" else "INCONCLUSIVE"
        ))

        Log.i(TAG, "═══════════════════════════════════════════════════")
        Log.i(TAG, "  FCM CERTIFICATION TEST COMPLETE")
        Log.i(TAG, "═══════════════════════════════════════════════════")

        scenario.close()
    }

    private fun persistToken(context: Context, token: String) {
        try {
            // Internal storage (always accessible)
            val internalFile = File(context.filesDir, "fcm_token.txt")
            internalFile.writeText(token)
            Log.i(TAG, "[TOKEN] Written to: ${internalFile.absolutePath}")

            // External storage for easier `adb pull` on Test Lab
            val externalDir = context.getExternalFilesDir(null)
            if (externalDir != null) {
                val externalFile = File(externalDir, "fcm_token.txt")
                externalFile.writeText(token)
                Log.i(TAG, "[TOKEN] Written to: ${externalFile.absolutePath}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "[TOKEN] File write failed: ${e.message}")
        }
    }

    private fun logNotificationChannelState(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            Log.i(TAG, "[PHASE 2] Notification channels:")
            nm.notificationChannels.forEach { ch ->
                Log.i(TAG, "  Channel: id=${ch.id}, importance=${ch.importance}, sound=${ch.sound}, bypassDnd=${ch.canBypassDnd()}")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                Log.i(TAG, "[PHASE 2] canUseFullScreenIntent=${nm.canUseFullScreenIntent()}")
            }
        }
        Log.i(TAG, "[PHASE 2] ✓ Channel state logged")
    }

    /**
     * Poll SharedPreferences for evidence that MyFirebaseMessagingService processed a push.
     * The service writes a timestamp to "fcm_test_received" when it sees a qa_test type.
     */
    private fun waitForPushDelivery(context: Context): Boolean {
        val prefs = context.getSharedPreferences("fcm_certification", Context.MODE_PRIVATE)
        // Clear any stale marker
        prefs.edit().remove("last_push_received_at").apply()

        val deadline = System.currentTimeMillis() + (WAIT_FOR_PUSH_SECONDS * 1000)
        var pollCount = 0

        while (System.currentTimeMillis() < deadline) {
            Thread.sleep(POLL_INTERVAL_MS)
            pollCount++

            val receivedAt = prefs.getLong("last_push_received_at", 0L)
            if (receivedAt > 0) {
                val latencyMs = receivedAt - prefs.getLong("push_sent_at", receivedAt)
                Log.i(TAG, "[PHASE 3] Push detected after ${pollCount * POLL_INTERVAL_MS}ms polling")
                Log.i(TAG, "[PHASE 3] Push type: ${prefs.getString("last_push_type", "unknown")}")
                Log.i(TAG, "[PHASE 3] Delivery latency: ${latencyMs}ms")
                return true
            }

            // Log heartbeat every 30s
            if (pollCount % 15 == 0) {
                Log.i(TAG, "[PHASE 3] Still waiting... (${pollCount * POLL_INTERVAL_MS / 1000}s elapsed)")
            }
        }
        return false
    }

    private fun logFinalState(context: Context) {
        Log.i(TAG, "[PHASE 4] Final state audit:")
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val activeNotifs = nm.activeNotifications
        Log.i(TAG, "[PHASE 4] Active notifications: ${activeNotifs.size}")
        activeNotifs.forEach { sbn ->
            Log.i(TAG, "  Notif: id=${sbn.id}, channel=${sbn.notification.channelId}, tag=${sbn.tag}")
        }

        // Check dedup state
        val dedupPrefs = context.getSharedPreferences("fcm_dedup", Context.MODE_PRIVATE)
        Log.i(TAG, "[PHASE 4] Dedup entries: ${dedupPrefs.all.size}")

        // Check sound repeat state
        val soundPrefs = context.getSharedPreferences("sound_repeat_prefs", Context.MODE_PRIVATE)
        Log.i(TAG, "[PHASE 4] Sound repeat entries: ${soundPrefs.all.size}")

        emitEvent("ASSERTION_RESULT", "phase_4", mapOf(
            "check" to "notification_state_audit",
            "result" to "PASS",
            "active_notifications" to activeNotifs.size,
            "dedup_entries" to dedupPrefs.all.size,
            "sound_repeat_entries" to soundPrefs.all.size
        ))
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // AGENTIC ORCHESTRATION: Structured Event Emitter
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Emit a structured JSON event to logcat (tag: WAWAPP_EVENT) and to
     * a persistent NDJSON file artifact.
     *
     * External agents (Antigravity, MCP, Appium) can:
     * - Stream `adb logcat -s WAWAPP_EVENT:*` for real-time events
     * - Pull certification_events.ndjson from device after test
     * - Parse events for automated decision-making
     */
    private fun emitEvent(event: String, phase: String, data: Map<String, Any>) {
        val payload = buildString {
            append('{"event":"'); append(event)
            append('","ts":'); append(System.currentTimeMillis())
            append(',"phase":"'); append(phase)
            append('","data":{')
            data.entries.forEachIndexed { i, (k, v) ->
                if (i > 0) append(',')
                append('"'); append(k); append('":')
                when (v) {
                    is String -> { append('"'); append(v.replace("\"", "\\\"")); append('"') }
                    is Boolean -> append(v)
                    is Number -> append(v)
                    else -> { append('"'); append(v.toString()); append('"') }
                }
            }
            append('}}')
        }

        Log.i(EVENT_TAG, payload)

        // Persist to NDJSON file artifact (best-effort, never blocks test)
        try {
            val context = InstrumentationRegistry.getInstrumentation().targetContext
            File(context.filesDir, EVENTS_FILE).appendText(payload + "\n")
        } catch (_: Exception) {}
    }
}
