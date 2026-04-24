package com.wawapp.driver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Re-schedules all pending snooze alarms after device reboot.
 * AlarmManager alarms are lost on reboot — this receiver restores them
 * from SharedPreferences where SnoozeScheduler persists them.
 */
class SnoozeBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        Log.d(TAG, "📱 Device rebooted — restoring pending snooze alarms")
        SnoozeScheduler.restoreAll(context)
    }

    companion object {
        private const val TAG = "SnoozeBootReceiver"
    }
}
