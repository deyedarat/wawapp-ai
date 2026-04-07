# 🚨 إصلاحات حرجة - 2026-04-07

## المشاكل المُصلّحة

### ❌ المشكلة #1: الأصوات المخصصة لا تعمل
**الوصف:** رغم نسخ ملفات الأصوات الجديدة، التطبيق كان يستخدم `trip_reminder.wav` للطلبات الجديدة.

**السبب الجذري:**
1. السطر 68: `sound: RawResourceAndroidNotificationSound('trip_reminder')` ❌
2. السطر 79: `sound: RawResourceAndroidNotificationSound('trip_reminder')` ❌
3. السطر 381: `sound: const RawResourceAndroidNotificationSound('trip_reminder')` ❌

**الإصلاح:**
```diff
- sound: RawResourceAndroidNotificationSound('trip_reminder'),
+ sound: RawResourceAndroidNotificationSound('new_order_alert'),
```

**الملفات المعدلة:**
- ✅ `lib/services/notification_service.dart` (السطور 68, 79, 381)

---

### ❌ المشكلة #2: السائق يستقبل إشعارات طلبات جديدة رغم قبوله لطلب
**الوصف:** السائق الذي قَبِل طلباً (status = 'accepted') لكن لم يبدأ الرحلة بعد، مازال يستقبل إشعارات طلبات جديدة.

**السبب الجذري:**
السطر 588 كان يستخدم:
```dart
.where('status', whereIn: ['accepted', 'onRoute'])  // ❌ خطأ!
```

**Firestore يخزن الحالة كـ:**
- `'accepted'` ✅
- `'on_route'` ✅ (مع underscore)

**لكن الكود كان يبحث عن:**
- `'accepted'` ✅
- `'onRoute'` ❌ (بدون underscore - لن يجد شيء!)

**الإصلاح:**
```diff
- .where('status', whereIn: ['accepted', 'onRoute'])
+ .where('status', whereIn: ['accepted', 'on_route'])  // ✅ صحيح
```

**الملفات المعدلة:**
- ✅ `lib/services/notification_service.dart` (السطر 588)

**إضافة logging للتأكد:**
```dart
if (kDebugMode && hasActiveTrip) {
  final doc = snapshot.docs.first;
  debugPrint('[NotificationService] Driver has active trip: ${doc.id}, status: ${doc.data()['status']}, skipping new order notification');
}
```

---

## 📊 ملخص التعديلات

### notification_service.dart

| السطر | قبل | بعد |
|-------|-----|-----|
| 68 | `'trip_reminder'` | `'new_order_alert'` ✅ |
| 79 | `'trip_reminder'` | `'new_order_alert'` ✅ |
| 90 | `'trip_reminder'` | `'order_update_soft'` ✅ |
| 112 | `'trip_reminder'` | `'trip_start_warning'` ✅ |
| 295 | `'trip_reminder'` | `'trip_start_warning'` ✅ |
| 381 | `'trip_reminder'` | `'new_order_alert'` ✅ |
| 588 | `'onRoute'` | `'on_route'` ✅ |

---

## 🧪 كيفية الاختبار

### اختبار #1: الأصوات المخصصة

```bash
# 1. احذف التطبيق تماماً
adb uninstall com.wawapp.driver

# 2. أعد البناء والتثبيت
cd apps/wawapp_driver
flutter clean
flutter pub get
flutter build apk --release
flutter install
```

**التحقق:**
- أرسل إشعار `new_order` → يجب سماع `new_order_alert.wav` (صوت حاد)
- أرسل إشعار `trip_start_reminder` → يجب سماع `trip_start_warning.wav` (صوت مع voice)
- أرسل إشعار `order_update` → يجب سماع `order_update_soft.wav` (صوت هادئ)

---

### اختبار #2: منع الإشعارات للسائق المشغول

**السيناريو:**
1. السائق يفتح التطبيق
2. يقبل طلباً (status = 'accepted')
3. **لا يبدأ الرحلة بعد**
4. يصل طلب جديد

**النتيجة المتوقعة:**
- ❌ **لا** يجب أن يظهر إشعار الطلب الجديد
- ✅ في logs يجب أن يظهر:
  ```
  [NotificationService] Driver has active trip: ORDER_ID, status: accepted, skipping new order notification
  ```

**للتحقق من Logs:**
```bash
adb logcat | grep NotificationService
```

---

## 🔍 التحقق من Firestore

لفهم الحالات في Firestore، استخدم:

```javascript
// Firestore Console
db.collection('orders')
  .where('status', 'in', ['accepted', 'on_route'])
  .get()
  .then(docs => {
    docs.forEach(doc => {
      console.log(doc.id, '→', doc.data().status);
    });
  });
```

**يجب أن يظهر:**
```
order_123 → accepted
order_456 → on_route
```

**وليس:**
```
order_123 → onRoute  ❌ (هذا خطأ!)
```

---

## ⚠️ ملاحظات مهمة

### 1. Android Notification Channels
رغم إضافة `deleteNotificationChannel` في السطور 119-120، **Android قد لا يحدّث الصوت** إذا:
- التطبيق مُثبّت بالفعل
- المستخدم غيّر إعدادات الإشعارات يدوياً في Settings

**الحل الوحيد المضمون:**
```bash
adb uninstall com.wawapp.driver
# ثم أعد التثبيت
```

### 2. حالات Order Status في WawApp

| الحالة في Firestore | الوصف |
|---------------------|--------|
| `pending` | الطلب جديد، لم يُقبل بعد |
| `accepted` | السائق قَبِل لكن لم يبدأ الرحلة |
| `on_route` | السائق بدأ الرحلة (في الطريق) |
| `delivered` | تم التوصيل |
| `completed` | اكتملت الرحلة |
| `cancelled_by_client` | العميل ألغى |
| `cancelled_by_driver` | السائق ألغى |

### 3. متى يجب منع الإشعارات؟

**يُمنع الإشعار إذا:**
- السائق عنده طلب في حالة `accepted` ✅
- السائق عنده طلب في حالة `on_route` ✅

**يُسمح الإشعار إذا:**
- السائق ليس لديه طلبات نشطة ✅
- السائق أكمل آخر رحلة (`completed`) ✅

---

## 📝 Checklist ما بعد الإصلاح

- [x] تحديث جميع `RawResourceAndroidNotificationSound` للأصوات الجديدة
- [x] إصلاح `'onRoute'` إلى `'on_route'` في whereIn
- [x] إضافة logging محسّن في `_isDriverOnActiveTrip`
- [x] التأكد من وجود الأصوات في `res/raw/`
- [ ] اختبار على جهاز حقيقي (uninstall → reinstall)
- [ ] مراقبة logs للتأكد من عدم وصول إشعارات للسائق المشغول
- [ ] التأكد من الأصوات المختلفة

---

## 🚀 الخطوات التالية

```bash
# 1. احذف التطبيق
adb uninstall com.wawapp.driver

# 2. Clean build
cd apps/wawapp_driver
flutter clean

# 3. Get dependencies
flutter pub get

# 4. Build release APK
flutter build apk --release

# 5. Install
flutter install

# 6. Monitor logs
adb logcat | grep -E "(NotificationService|FCM)"

# 7. Test scenarios
# - أرسل طلب جديد للسائق الفارغ → يجب أن يظهر
# - السائق يقبل الطلب
# - أرسل طلب جديد آخر → يجب ألا يظهر
# - السائق يبدأ الرحلة
# - أرسل طلب جديد آخر → يجب ألا يظهر
# - السائق ينهي الرحلة
# - أرسل طلب جديد → يجب أن يظهر
```

---

## 📅 التاريخ والإصدار

- **تاريخ الإصلاح:** 2026-04-07
- **المطور:** Claude Code
- **الأولوية:** 🚨 حرجة (Critical)
- **الحالة:** ✅ جاهز للاختبار

---

## 🆘 في حالة استمرار المشاكل

### المشكلة: الصوت مازال trip_reminder
**الحل:**
1. تأكد من حذف التطبيق: `adb uninstall com.wawapp.driver`
2. امسح cache Android: Settings → Apps → Clear all data
3. أعد تشغيل الجهاز
4. أعد التثبيت

### المشكلة: مازالت تصل إشعارات للسائق المشغول
**التحقق:**
```bash
# راقب logs
adb logcat | grep "Driver has active trip"

# إذا لم يظهر شيء، معناه الفحص لا يعمل
# تحقق من Firestore أن الحالة فعلاً 'accepted' أو 'on_route'
```

**Firestore Query للتحقق:**
```javascript
db.collection('orders')
  .where('driverId', '==', 'DRIVER_UID')
  .where('status', 'in', ['accepted', 'on_route'])
  .get()
```

---

## ✅ النتيجة المتوقعة

بعد التطبيق الصحيح لهذه الإصلاحات:

1. ✅ الطلبات الجديدة تشغل صوت `new_order_alert.wav` (حاد ومزعج)
2. ✅ تذكير بدء الرحلة يشغل `trip_start_warning.wav` (مع صوت بشري)
3. ✅ التحديثات العامة تشغل `order_update_soft.wav` (هادئ)
4. ✅ السائق المشغول (accepted/on_route) **لا** يستقبل إشعارات طلبات جديدة
5. ✅ Logs واضحة تبيّن السبب عند منع الإشعار

**كل شيء جاهز الآن! 🎉**
