# دليل استكشاف أخطاء الإشعارات

## الخطوات التشخيصية

### 1. التحقق من موقع السائق في Firestore

```
Firebase Console → Firestore → driver_locations → {driverId}
```

**يجب أن ترى:**
- ✅ `lat`: رقم (مثل: 33.5731)
- ✅ `lng`: رقم (مثل: -7.5898)
- ✅ `accuracy`: رقم (أقل من 100)
- ✅ `updatedAt`: timestamp حديث (آخر 5 دقائق)

**إذا لم يكن موجوداً:**
- افتح تطبيق السائق وشاهد Logcat
- ابحث عن: `[TRACKING_SERVICE]`
- يجب أن ترى: `Firestore write successful`

---

### 2. التحقق من حالة السائق

```
Firebase Console → Firestore → drivers → {driverId}
```

**يجب أن ترى:**
- ✅ `isOnline`: true
- ✅ `fcmToken`: string طويل (مثل: "fK3xH...")
- ✅ `lastOnlineAt`: timestamp حديث

**إذا كان `isOnline` = false:**
- اضغط على زر GO ONLINE في التطبيق
- انتظر حتى يتحول الزر للأخضر

**إذا كان `fcmToken` غير موجود:**
- أعد تشغيل التطبيق
- قد تحتاج لحذف بيانات التطبيق وإعادة تسجيل الدخول

---

### 3. التحقق من Cloud Function Logs

```bash
firebase functions:log --only notifyNewOrder
```

**ابحث عن:**

#### ❌ خطأ: `No recent driver locations found`
**السبب:** لا يوجد مواقع في `driver_locations` محدثة خلال آخر 5 دقائق
**الحل:** تأكد من أن السائق متصل وأن GPS مفعّل

#### ❌ خطأ: `Order missing pickup coordinates`
**السبب:** الطلب لا يحتوي على موقع الانطلاق
**الحل:** تأكد من اختيار موقع على الخريطة في تطبيق العميل

#### ✅ نجاح: `Notification sent to driver`
**معناه:** الإشعار تم إرساله بنجاح
**إذا لم يصل للهاتف:** المشكلة في FCM Token أو الأذونات

#### ⚠️ تحذير: `Invalid FCM token`
**السبب:** FCM Token منتهي أو غير صحيح
**الحل:**
1. احذف التطبيق من الهاتف
2. أعد التثبيت
3. سجل دخول مرة أخرى

---

### 4. التحقق من أذونات الإشعارات

**على Android:**
```
Settings → Apps → WawApp Driver → Notifications
```

**يجب أن تكون:**
- ✅ All notifications: ON
- ✅ New Orders: ON (مهم جداً!)

**على الكود:**
```dart
// في driver_home_screen.dart
// يجب أن ترى في Logcat:
[FCM] Permission granted: true
```

---

### 5. الفحص الشامل (Checklist)

قبل إنشاء طلب جديد، تأكد من:

- [ ] السائق ضغط على GO ONLINE وأصبح الزر أخضر
- [ ] GPS مفعّل على هاتف السائق
- [ ] أذونات الموقع ممنوحة للتطبيق
- [ ] أذونات الإشعارات ممنوحة للتطبيق
- [ ] الهاتف متصل بالإنترنت (WiFi أو Data)
- [ ] Firebase Console يظهر `isOnline: true` للسائق
- [ ] Firebase Console يظهر موقع حديث في `driver_locations`
- [ ] تطبيق العميل يختار موقع انطلاق صحيح على الخريطة

---

### 6. أوامر مفيدة للتشخيص

#### فحص آخر 20 سطر من Cloud Functions:
```bash
firebase functions:log --only notifyNewOrder | Select-Object -Last 20
```

#### مراقبة logs مباشرة:
```bash
# في terminal منفصل
firebase functions:log --only notifyNewOrder
```

#### فحص build الـ Cloud Function:
```bash
cd functions
npm run build
```

---

### 7. المسافة القصوى

Cloud Function يرسل الإشعار **فقط** للسائقين الذين يبعدون **أقل من 10 كم** من موقع الانطلاق.

**للتحقق:**
- احسب المسافة بين السائق وموقع الطلب على Google Maps
- إذا كانت أكثر من 10 كم → لن يصل الإشعار

**لتغيير المسافة القصوى:**
```typescript
// في functions/src/notifyNewOrder.ts
const MAX_NOTIFICATION_RADIUS_KM = 10; // غيّر هذا الرقم
```

---

### 8. إذا ظلت المشكلة موجودة

اتصل بالمطور وأرفق:

1. Screenshot من Firestore Console (drivers و driver_locations)
2. Logcat من تطبيق السائق (آخر 100 سطر)
3. Cloud Function logs (آخر 20 سطر)
4. معلومات الطلب (orderId من Firebase Console)

---

## الملفات المتأثرة

- **Cloud Function:** `functions/src/notifyNewOrder.ts`
- **Driver App:** `apps/wawapp_driver/lib/services/tracking_service.dart`
- **Driver Status:** `apps/wawapp_driver/lib/services/driver_status_service.dart`
- **FCM Service:** `packages/core_shared/lib/src/fcm/base_fcm_service.dart`
