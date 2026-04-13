package com.wawapp.driver

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Bridge for forwarding foreground FCM messages from MyFirebaseMessagingService
 * to the Flutter layer via an EventChannel.
 *
 * Problem solved:
 *   MyFirebaseMessagingService (priority=10) intercepts ALL FCM messages before
 *   the firebase_messaging Flutter plugin can receive them. When the app is in
 *   the foreground, the service used to silently return — leaving Flutter with no
 *   knowledge of the incoming message. This bridge fills that gap.
 *
 * How it works:
 *   1. MainActivity registers an EventChannel ("com.wawapp.driver/fcm_foreground")
 *      and stores the EventSink here.
 *   2. MyFirebaseMessagingService calls sendMessage() instead of returning silently.
 *   3. Flutter's NotificationService listens to the stream and processes the message
 *      the same way it would handle FirebaseMessaging.onMessage.
 */
object FcmForegroundBridge {

    /** Set by MainActivity when Flutter starts listening to the EventChannel. */
    var eventSink: EventChannel.EventSink? = null

    /**
     * Forward FCM data payload to Flutter.
     * Thread-safe — always marshals to the main (UI) thread before posting.
     *
     * @param data  The RemoteMessage.data map (String→String? from FCM).
     */
    fun sendMessage(data: Map<String, String?>) {
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(data)
        }
    }
}
