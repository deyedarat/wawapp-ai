package com.wawapp.driver

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.app.KeyguardManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.wawapp.driver/notifications"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showFullScreenNotification" -> {
                    val orderId = call.argument<String>("orderId") ?: ""
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val pickupLabel = call.argument<String>("pickupLabel") ?: ""
                    val dropoffLabel = call.argument<String>("dropoffLabel") ?: ""
                    val price = call.argument<Double>("price") ?: 0.0
                    val distance = call.argument<Double>("distance") ?: 0.0
                    val createdAt = call.argument<Long>("createdAt") ?: 0L
                    val notificationType = call.argument<String>("notificationType") ?: "new_order"

                    NotificationHelper.showFullScreenNotification(
                        this,
                        orderId,
                        title,
                        body,
                        pickupLabel,
                        dropoffLabel,
                        price,
                        distance,
                        createdAt,
                        notificationType
                    )
                    result.success(null)
                }
                "createNotificationChannels" -> {
                    NotificationHelper.createNotificationChannels(this)
                    result.success(null)
                }
                "cancelSoundRepeats" -> {
                    val orderId = call.argument<String>("orderId") ?: ""
                    NotificationHelper.cancelSoundRepeats(this, orderId)
                    result.success(null)
                }
                "requestBatteryOptimizationExemption" -> {
                    val granted = requestBatteryOptimizationExemption()
                    result.success(granted)
                }
                "isBatteryOptimizationDisabled" -> {
                    val disabled = isBatteryOptimizationDisabled()
                    result.success(disabled)
                }
                "canBypassDnd" -> {
                    val canBypass = canBypassDnd()
                    result.success(canBypass)
                }
                "requestDndBypassPermission" -> {
                    val granted = requestDndBypassPermission()
                    result.success(granted)
                }
                "canScheduleExactAlarms" -> {
                    val canSchedule = canScheduleExactAlarms()
                    result.success(canSchedule)
                }
                "requestExactAlarmPermission" -> {
                    val granted = requestExactAlarmPermission()
                    result.success(granted)
                }
                "getAllPermissionStatuses" -> {
                    val statuses = mapOf(
                        "batteryOptimizationDisabled" to isBatteryOptimizationDisabled(),
                        "canBypassDnd" to canBypassDnd(),
                        "canScheduleExactAlarms" to canScheduleExactAlarms()
                    )
                    result.success(statuses)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun requestBatteryOptimizationExemption(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            try {
                startActivity(intent)
                true
            } catch (e: Exception) {
                false
            }
        } else {
            true // Not needed on older Android versions
        }
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true // Not applicable on older Android versions
        }
    }

    private fun canBypassDnd(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.isNotificationPolicyAccessGranted
        } else {
            true // Not applicable on older Android versions
        }
    }

    private fun requestDndBypassPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            try {
                startActivity(intent)
                true
            } catch (e: Exception) {
                false
            }
        } else {
            true // Not needed on older Android versions
        }
    }

    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true // Not needed on older Android versions
        }
    }

    private fun requestExactAlarmPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:$packageName")
            }
            try {
                startActivity(intent)
                true
            } catch (e: Exception) {
                false
            }
        } else {
            true // Not needed on older Android versions
        }
    }
}
