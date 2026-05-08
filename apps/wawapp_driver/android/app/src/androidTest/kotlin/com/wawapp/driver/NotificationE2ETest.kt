package com.wawapp.driver

import android.util.Log
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.google.firebase.messaging.FirebaseMessaging
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class NotificationE2ETest {

    companion object {
        private const val TAG = "NotificationE2ETest"
    }

    @Test
    fun extractFcmTokenAndWait() {
        // Launch MainActivity via ActivityScenario (modern API)
        val scenario = ActivityScenario.launch(MainActivity::class.java)

        val context = InstrumentationRegistry
            .getInstrumentation()
            .targetContext

        val latch = CountDownLatch(1)

        FirebaseMessaging.getInstance().token
            .addOnCompleteListener { task ->

                if (!task.isSuccessful) {
                    Log.e(TAG, "FCM token fetch failed: ${task.exception?.message}")
                    latch.countDown()
                    return@addOnCompleteListener
                }

                val token = task.result ?: ""

                Log.d(TAG, "FCM TOKEN = $token")

                try {
                    val file = File(context.filesDir, "fcm_token.txt")
                    file.writeText(token)
                    Log.d(TAG, "Token written to ${file.absolutePath}")
                } catch (e: Exception) {
                    Log.e(TAG, "File write failed: ${e.message}")
                }

                latch.countDown()
            }

        latch.await(60, TimeUnit.SECONDS)

        // Keep app alive for external FCM injection (2 minutes)
        Log.d(TAG, "Waiting 120s for external FCM push...")
        Thread.sleep(120_000)

        scenario.close()
    }
}
