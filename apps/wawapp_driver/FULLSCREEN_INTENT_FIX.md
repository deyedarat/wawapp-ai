# إصلاح Full-Screen Intent - الإشعارات ملء الشاشة تلقائياً

## 📋 المشكلة
الإشعارات تظهر من الأعلى كـ heads-up notification عادية، ويجب الضغط عليها لرؤيتها بملء الشاشة.
المطلوب: أن تفتح **تلقائياً** بملء الشاشة مثل رقم متصل.

**السبب الجذري:**
- الإذن "Alarmes et rappels" (SCHEDULE_EXACT_ALARM) **غير مدرج** في Manifest
- بدونه، Android لا يسمح بـ full-screen intent تلقائي

---

## ✅ الحل

### 1. إضافة Permissions الناقصة في AndroidManifest.xml ✅

**الملف:** `apps/wawapp_driver/android/app/src/main/AndroidManifest.xml`

```xml
<!-- Permissions الموجودة مسبقاً -->
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />

<!-- الإضافات الجديدة ⭐ -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
```

**الشرح:**
- `SCHEDULE_EXACT_ALARM`: مطلوب لـ Android 12+ (API 31+)
- `USE_EXACT_ALARM`: بديل لـ Android 13+ (API 33+)

### 2. إضافة طلب الإذن برمجياً (Android 12+)
**الملف:** `apps/wawapp_driver/lib/services/notification_service.dart`

**الإضافة الجديدة:**
```dart
/// Request permission to show full-screen intent notifications (Android 12+)
Future<void> _requestFullScreenIntentPermission() async {
  final android = _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (android != null) {
    // Check if we can use full-screen intent
    final canUse = await android.canScheduleExactNotifications() ?? false;

    if (kDebugMode) {
      debugPrint('[NotificationService] Can use full-screen intent: $canUse');
    }

    // Request permission if not granted
    if (!canUse) {
      final granted = await android.requestExactAlarmsPermission();
      if (kDebugMode) {
        debugPrint('[NotificationService] Full-screen intent permission granted: $granted');
      }
    }
  }
}
```

**استدعاء الدالة في _initializeLocalNotifications():**
```dart
await _createNotificationChannels();

// Request USE_FULL_SCREEN_INTENT permission for Android 12+ (API 31+)
await _requestFullScreenIntentPermission();
```

### 3. إصلاح صوت الإشعار في full-screen notification
**تم تغيير السطر 380 من:**
```dart
sound: const RawResourceAndroidNotificationSound('new_order_alert'),
```

**إلى:**
```dart
sound: const RawResourceAndroidNotificationSound('trip_reminder'),
```

---

## 🧪 الاختبار

### المطلوب:
```bash
# 1. حذف التطبيق لضمان إعادة تهيئة الـ permissions
adb uninstall com.wawapp.driver

# 2. Clean build
cd apps/wawapp_driver
flutter clean
flutter pub get

# 3. بناء وتثبيت
flutter build apk --release
flutter install
```

### السلوك المتوقع:

#### عند أول فتح للتطبيق:
- ✅ سيطلب إذن "Alarmes et rappels" (Exact Alarms)
- ✅ يجب الموافقة على الإذن في الإعدادات

**كيف تتحقق:**
1. افتح Settings → Apps → wawapp_driver → Autorisations
2. يجب أن ترى "Alarmes et rappels" في القائمة ✅
3. تأكد أنه مفعّل (ON)

#### عند وصول إشعار جديد:
- ✅ **يفتح تلقائياً بملء الشاشة** مثل رقم متصل
- ✅ لا حاجة للضغط على الإشعار من الأعلى
- ✅ يعمل حتى مع الشاشة مقفلة

---

## ⚠️ ملاحظة Samsung: "Suppr. autoris. si appli. inutilisée"

إذا كان جهازك Samsung:
- افتح Settings → Apps → wawapp_driver
- ابحث عن "Suppr. autoris. si appli. inutilisée"
- **أوقفه** (OFF) ⚠️

**السبب:** Samsung تحذف الأذونات تلقائياً إذا لم يُستخدم التطبيق لفترة.
للـ driver app، هذا غير مرغوب فيه!

---

## 🔍 Logs للتحقق:
```bash
adb logcat | grep -iE "NotificationService|full.screen"
```

**ما يجب أن تراه:**
```
[NotificationService] Can use full-screen intent: true
[NotificationService] 🚀 Full-screen notification for order: ORDER_ID
```

---

## ⚠️ ملاحظات مهمة:

### Android 12+ (API 31+):
- **يتطلب** إذن `USE_FULL_SCREEN_INTENT` برمجياً
- بدون الإذن → الإشعار يظهر عادي من الأعلى فقط ❌

### Android 10-11:
- الإذن في Manifest كافٍ
- يعمل بدون طلب برمجي

### إذا لم يعمل:
1. **تحقق من الإعدادات اليدوية:**
   - Settings → Apps → wawapp_driver → Notifications
   - تأكد أن "Display over other apps" مفعّل

2. **أعد تثبيت التطبيق:**
   ```bash
   adb uninstall com.wawapp.driver
   flutter install
   ```

---

## 📊 التغييرات التقنية:

| العنصر | قبل | بعد |
|--------|-----|-----|
| طلب Permission برمجياً | ❌ لا يوجد | ✅ `requestExactAlarmsPermission()` |
| صوت full-screen notification | `new_order_alert` | `trip_reminder` |
| السلوك | heads-up عادي | **full-screen تلقائي** ✅ |

---

**التاريخ:** 2026-04-07
**الملفات المعدلة:**
- `apps/wawapp_driver/lib/services/notification_service.dart`
