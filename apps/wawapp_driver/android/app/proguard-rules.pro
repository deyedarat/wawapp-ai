# ============================================================
# WawApp Driver — ProGuard / R8 Rules
# ============================================================
# Protects classes registered in AndroidManifest.xml from being
# renamed or removed by R8 during Release builds.
# Without these rules, FCM, AlarmManager, and BroadcastReceivers
# silently stop working in Production.
# ============================================================

# --- Native FCM handler ---
-keep class com.wawapp.driver.MyFirebaseMessagingService { *; }

# --- Full-screen notification activity (lock screen) ---
-keep class com.wawapp.driver.FullScreenNotificationActivity { *; }

# --- BroadcastReceivers registered in AndroidManifest ---
-keep class com.wawapp.driver.OrderActionReceiver { *; }
-keep class com.wawapp.driver.SoundRepeatReceiver { *; }
-keep class com.wawapp.driver.NotificationDismissReceiver { *; }

# --- NotificationHelper (called reflectively by the receivers above) ---
-keep class com.wawapp.driver.NotificationHelper { *; }

# --- MainActivity (target of all notification PendingIntents) ---
-keep class com.wawapp.driver.MainActivity { *; }

# --- Firebase Messaging (transitive — FCM SDK uses reflection internally) ---
-keep class com.google.firebase.messaging.** { *; }

# --- Kotlin Metadata (required for Kotlin reflection used by Firebase SDK) ---
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# --- Keep raw resources (notification sounds) ---
-keep class **.R$raw
-keepclassmembers class **.R$raw { *; }
-keep class **.R
-keepclassmembers class **.R { *; }
