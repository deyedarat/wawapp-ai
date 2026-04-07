# خطوات التحقق النهائية - Full-Screen Notifications

## ✅ ما تم إنجازه:

### 1. إضافة Permissions في AndroidManifest ✅
```xml
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
```

### 2. إضافة طلب الإذن برمجياً ✅
في `notification_service.dart:55-77`

### 3. Build كامل مع resources الصوتية ✅
```
✓ flutter clean
✓ flutter pub get
✓ flutter build apk --release (55.8MB)
✓ flutter install --release
```

---

## 🧪 خطوات التحقق اليدوي (مطلوب من المستخدم):

### الخطوة 1: فتح إعدادات التطبيق
1. اذهب إلى: **Settings → Apps → wawapp_driver**
2. اضغط على **"Autorisations"** (الأذونات)
3. **ابحث عن "Alarmes et rappels"** في القائمة

**النتيجة المتوقعة:**
- ✅ يجب أن ترى "Alarmes et rappels" في القائمة
- ✅ إذا ظهر → فعّله (ON)

---

### الخطوة 2: اختبار الإشعار

#### أ) اختبار من Firebase Console:
1. افتح [Firebase Console](https://console.firebase.google.com/project/wawapp-952d6/messaging)
2. اضغط **Send test message**
3. أدخل FCM token الخاص بالجهاز
4. في **Additional options** → اضغط **Android**
5. املأ:
   ```
   Channel ID: new_orders
   Sound: trip_reminder
   ```
6. أرسل الإشعار

**النتيجة المتوقعة:**
- ✅ يفتح الإشعار **تلقائياً بملء الشاشة** (مثل رقم متصل)
- ✅ يشتغل الصوت `trip_reminder.wav`
- ✅ لا حاجة للضغط على الإشعار من الأعلى

#### ب) اختبار عن طريق طلب حقيقي:
1. افتح تطبيق العميل (wawapp_client)
2. أنشئ طلب جديد قريب من السائق
3. راقب تطبيق السائق

**النتيجة المتوقعة:**
- ✅ إشعار full-screen تلقائي
- ✅ صوت trip_reminder.wav
- ✅ شاشة قبول الطلب تظهر فوراً

---

## 🔍 Logs للتحقق من الأخطاء:

```bash
# على الكمبيوتر
adb logcat | grep -iE "NotificationService|flutter|error"
```

**علامات النجاح:**
```
[NotificationService] Can use full-screen intent: true
[NotificationService] 🚀 Full-screen notification for order: ORDER_ID
```

**علامات الفشل:**
```
PlatformException(invalid_sound, The resource trip_reminder could not be found...
[NotificationService] Can use full-screen intent: false
```

---

## ⚠️ إذا لم يعمل:

### المشكلة 1: إذن "Alarmes et rappels" غير ظاهر
**الحل:**
```bash
# تأكد من أن الـ permissions في Manifest
adb shell dumpsys package com.wawapp.driver | grep -i "permission"
```

يجب أن ترى:
```
android.permission.SCHEDULE_EXACT_ALARM: granted=true
android.permission.USE_EXACT_ALARM: granted=true
```

### المشكلة 2: الإشعار يظهر من الأعلى فقط (heads-up)
**السبب:** الإذن غير مفعّل

**الحل:**
1. Settings → Apps → wawapp_driver → Autorisations
2. فعّل "Alarmes et rappels"
3. أعد اختبار الإشعار

### المشكلة 3: خطأ "invalid_sound"
**السبب:** ملفات الصوت غير محملة

**الحل:**
```bash
# تحقق من وجود الملفات
adb shell "ls -lh /data/app/*/com.wawapp.driver*/base.apk"
adb shell "aapt dump resources /data/app/.../base.apk | grep trip_reminder"
```

إذا لم تظهر → أعد build:
```bash
flutter clean && flutter build apk --release && flutter install
```

---

## 📱 ملاحظة Samsung:

إذا كان الجهاز Samsung:
- افتح Settings → Apps → wawapp_driver
- ابحث عن **"Suppr. autoris. si appli. inutilisée"**
- **أوقفه (OFF)** ⚠️

**السبب:** Samsung تحذف الأذونات تلقائياً إذا لم يُستخدم التطبيق لفترة.

---

## 📊 الملفات المعدلة:

| الملف | التغيير |
|------|----------|
| `AndroidManifest.xml` | إضافة `SCHEDULE_EXACT_ALARM` و `USE_EXACT_ALARM` |
| `notification_service.dart` | إضافة `_requestFullScreenIntentPermission()` |
| الأصوات | تأكيد وجود `trip_reminder.wav` في `res/raw/` |

---

**التاريخ:** 2026-04-07
**الحالة:** ✅ Build مكتمل - **في انتظار اختبار يدوي من المستخدم**
