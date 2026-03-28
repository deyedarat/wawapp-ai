# تشخيص وحل مشاكل الإشعارات والطلبات

## 🔴 المشكلتان الرئيسيتان

### المشكلة 1: خطأ عند الضغط على "الطلبات القريبة"
### المشكلة 2: عدم وصول إشعارات للسائق عند إنشاء طلب جديد

---

## 📋 التشخيص الشامل

### 🔍 المشكلة 1: خطأ في صفحة الطلبات القريبة

#### الأسباب المحتملة:

1. **مشكلة في الموقع (Location)**
   - السائق لم يمنح صلاحية الموقع للتطبيق
   - خدمات الموقع معطلة على الجهاز
   - خطأ في الحصول على الموقع الحالي

2. **مشكلة في Firestore Query**
   - الـ Composite Index غير موجود
   - خطأ في الاتصال بـ Firestore
   - مشكلة في صلاحيات Firestore Rules

3. **مشكلة في البيانات**
   - حقول مفقودة في وثائق الطلبات
   - تنسيق بيانات خاطئ

#### خطوات التشخيص:

```bash
# 1. تشغيل التطبيق مع السجلات
cd apps/wawapp_driver
flutter run --release

# 2. مراقبة السجلات عند الضغط على "الطلبات القريبة"
# ابحث عن:
# - [Matching] getNearbyOrders called
# - [Matching] Driver is ONLINE
# - [Matching] Firestore snapshot received
# - أي رسائل خطأ (Error/Exception)
```

#### الحل المقترح:

**الخطوة 1: التحقق من صلاحيات الموقع**
```dart
// في NearbyScreen، تحقق من السجلات:
[Matching] NearbyScreen: Initializing location
[Matching] NearbyScreen: Location obtained: lat=X.XXXX, lng=Y.YYYY
```

إذا ظهر خطأ في الموقع:
- افتح إعدادات التطبيق على الجهاز
- امنح صلاحية الموقع (Location Permission)
- تأكد من تفعيل GPS

**الخطوة 2: التحقق من Firestore Index**

افتح Firebase Console → Firestore → Indexes

تأكد من وجود Index:
```
Collection: orders
Fields:
  - status (Ascending)
  - createdAt (Descending)
```

إذا لم يكن موجوداً، أنشئه:
```bash
cd functions
firebase deploy --only firestore:indexes
```

**الخطوة 3: التحقق من Firestore Rules**

افتح Firebase Console → Firestore → Rules

تأكد من وجود القاعدة:
```javascript
match /orders/{orderId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null;
}
```

---

### 🔍 المشكلة 2: عدم وصول إشعارات للسائق

#### الأسباب المحتملة:

1. **Cloud Function غير مفعلة**
   - `notifyNewOrder` غير deployed
   - Cloud Function بها أخطاء

2. **FCM Token مفقود**
   - السائق لم يسجل FCM Token في Firestore
   - Token منتهي الصلاحية

3. **السائق OFFLINE**
   - حالة السائق في Firestore: `isOnline = false`
   - Cloud Function تتجاهل السائقين الـ OFFLINE

4. **موقع السائق قديم أو مفقود**
   - لا توجد بيانات في `driver_locations`
   - آخر تحديث للموقع أقدم من 5 دقائق

5. **المسافة بعيدة**
   - السائق أبعد من 10 كم من موقع الاستلام

6. **تنسيق البيانات خاطئ**
   - حقول `pickup` أو `pickupAddress` مفقودة
   - الإحداثيات (lat/lng) غير صحيحة

#### خطوات التشخيص:

**الخطوة 1: التحقق من Cloud Functions**

```bash
# 1. تحقق من أن Functions مفعلة
firebase functions:log --only notifyNewOrder

# 2. إذا لم تكن مفعلة، deploy:
cd functions
npm run build
firebase deploy --only functions:notifyNewOrder
```

**الخطوة 2: التحقق من FCM Token**

افتح Firebase Console → Firestore → `drivers/{driverId}`

تحقق من:
```json
{
  "fcmToken": "xxxxx...", // يجب أن يكون موجود
  "isOnline": true,       // يجب أن يكون true
  "updatedAt": "timestamp" // حديث
}
```

إذا كان `fcmToken` مفقود:
1. افتح تطبيق السائق
2. سجل الدخول
3. انتظر بضع ثوان
4. تحقق مرة أخرى من Firestore

**الخطوة 3: التحقق من موقع السائق**

افتح Firebase Console → Firestore → `driver_locations/{driverId}`

تحقق من:
```json
{
  "lat": 18.xxxx,
  "lng": -15.xxxx,
  "updatedAt": "timestamp", // يجب أن يكون خلال آخر 5 دقائق
  "accuracy": 20 // يجب أن يكون < 100
}
```

إذا كان الموقع قديم أو مفقود:
1. افتح تطبيق السائق
2. تأكد من أن السائق ONLINE
3. انتظر 10 ثوان
4. تحقق مرة أخرى

**الخطوة 4: التحقق من حالة الطلب**

عند إنشاء طلب جديد، افتح Firestore → `orders/{orderId}`

تحقق من:
```json
{
  "status": "matching", // يجب أن يكون "matching"
  "pickup": {
    "lat": 18.xxxx,
    "lng": -15.xxxx,
    "label": "اسم المكان"
  },
  "createdAt": "timestamp"
}
```

**الخطوة 5: مراقبة Cloud Function Logs**

```bash
# في terminal منفصل
firebase functions:log --only notifyNewOrder --follow
```

ثم أنشئ طلب جديد من تطبيق العميل.

ابحث عن:
```
[NotifyNewOrder] New order created
[NotifyNewOrder] Found eligible drivers
[NotifyNewOrder] Notification sent to driver
```

إذا ظهر:
```
[NotifyNewOrder] No eligible drivers found
```

تحقق من:
- السائق ONLINE؟
- موقع السائق محدث؟
- المسافة < 10 كم؟

---

## ✅ الحلول الشاملة

### الحل 1: إصلاح خطأ الطلبات القريبة

#### السيناريو A: خطأ في الموقع

```bash
# على الجهاز:
1. إعدادات → التطبيقات → WawApp Driver → الأذونات
2. امنح صلاحية "الموقع" → "السماح دائماً"
3. إعدادات → الموقع → تفعيل GPS
4. أعد فتح التطبيق
```

#### السيناريو B: Firestore Index مفقود

```bash
cd functions
firebase deploy --only firestore:indexes
# انتظر 2-5 دقائق حتى يتم إنشاء الـ index
```

#### السيناريو C: خطأ في Firestore Rules

```bash
# افتح Firebase Console → Firestore → Rules
# تأكد من السماح بالقراءة للمستخدمين المسجلين
firebase deploy --only firestore:rules
```

### الحل 2: إصلاح عدم وصول الإشعارات

#### الخطوة 1: Deploy Cloud Function

```bash
cd functions
npm install
npm run build
firebase deploy --only functions:notifyNewOrder
```

#### الخطوة 2: التأكد من FCM Token

في تطبيق السائق، أضف هذا الكود للتحقق:

```dart
// في DriverHomeScreen أو auth_gate.dart
Future<void> _checkFCMToken() async {
  final token = await FirebaseMessaging.instance.getToken();
  print('🔔 FCM Token: $token');
  
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && token != null) {
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(user.uid)
        .update({'fcmToken': token});
    print('✅ FCM Token saved to Firestore');
  }
}
```

#### الخطوة 3: التأكد من تحديث الموقع

```dart
// في DriverHomeScreen
// تأكد من أن LocationService يعمل بشكل صحيح
LocationService.instance.startTracking();
```

#### الخطوة 4: اختبار شامل

```bash
# Terminal 1: مراقبة Cloud Functions
firebase functions:log --only notifyNewOrder --follow

# Terminal 2: تشغيل تطبيق السائق
cd apps/wawapp_driver
flutter run --release

# Terminal 3: تشغيل Admin Panel أو تطبيق العميل
# أنشئ طلب جديد
```

---

## 🧪 سيناريو اختبار كامل

### الإعداد:

1. **تطبيق السائق:**
   - مسجل دخول
   - حالة: ONLINE (🟢)
   - الموقع: مفعل ويتم تحديثه

2. **Firebase Console:**
   - `drivers/{driverId}`:
     - `isOnline: true`
     - `fcmToken: "xxx..."`
   - `driver_locations/{driverId}`:
     - `lat: 18.xxxx`
     - `lng: -15.xxxx`
     - `updatedAt: [recent]`

3. **Cloud Functions:**
   - `notifyNewOrder`: deployed ✅

### الاختبار:

```bash
# 1. ابدأ مراقبة السجلات
firebase functions:log --only notifyNewOrder --follow

# 2. في تطبيق العميل أو Admin Panel:
# أنشئ طلب جديد بموقع استلام قريب من السائق (< 10 كم)

# 3. راقب السجلات:
```

**السجلات المتوقعة:**

```
[NotifyNewOrder] New order created { order_id: 'xxx', status: 'matching' }
[NotifyNewOrder] Found eligible drivers { driver_count: 1, closest_distance_km: '2.50' }
[NotifyNewOrder] Notification sent to driver { driver_id: 'yyy', order_id: 'xxx', distance_km: '2.50' }
[NotifyNewOrder] Notification summary { sent_count: 1, failed_count: 0 }
```

**على تطبيق السائق:**

1. يظهر إشعار: "طلب جديد قريب منك"
2. عند النقر على الإشعار:
   - السجلات:
     ```
     [NotificationHelper] Processing notification: type=new_order, role=driver
     [NotificationHelper] ✅ Returning route: /nearby
     [NotificationService] ✅ Navigating to: /nearby
     ```
   - يفتح صفحة "الطلبات القريبة"
   - يظهر الطلب الجديد

---

## 🔧 أوامر التشخيص السريع

### فحص Cloud Functions:
```bash
firebase functions:list
firebase functions:log --only notifyNewOrder --limit 50
```

### فحص Firestore:
```bash
# في Firebase Console
# 1. Firestore → orders → ابحث عن status="matching"
# 2. Firestore → drivers → تحقق من isOnline=true و fcmToken
# 3. Firestore → driver_locations → تحقق من updatedAt حديث
```

### فحص تطبيق السائق:
```bash
cd apps/wawapp_driver
flutter run --release
# راقب السجلات في console
```

### اختبار FCM مباشرة:
```bash
# استخدم Firebase Console → Cloud Messaging
# أرسل إشعار اختبار إلى FCM Token السائق
```

---

## 📊 جدول استكشاف الأخطاء

| المشكلة | السبب المحتمل | الحل |
|---------|---------------|------|
| "حدث خطأ" في الطلبات القريبة | خطأ في الموقع | امنح صلاحية الموقع |
| | Firestore Index مفقود | `firebase deploy --only firestore:indexes` |
| | خطأ في Firestore Rules | تحقق من القواعد |
| لا يصل إشعار للسائق | Cloud Function غير مفعلة | `firebase deploy --only functions:notifyNewOrder` |
| | FCM Token مفقود | أعد تسجيل الدخول |
| | السائق OFFLINE | اضغط على زر "متصل" |
| | موقع السائق قديم | انتظر 10 ثوان |
| | المسافة بعيدة | اقترب من موقع الطلب |
| الإشعار يظهر لكن لا يفتح الصفحة | Context غير متوفر | أعد فتح التطبيق |
| | خطأ في التنقل | تحقق من السجلات |

---

## 🎯 الخطوات التالية الموصى بها

### 1. تشخيص فوري:
```bash
# شغل هذه الأوامر الآن:
cd apps/wawapp_driver
flutter run --release

# في terminal آخر:
firebase functions:log --only notifyNewOrder --follow

# ثم:
# 1. افتح تطبيق السائق
# 2. تأكد من أنه ONLINE
# 3. اضغط على "الطلبات القريبة"
# 4. شارك السجلات (logs) التي تظهر
```

### 2. اختبار الإشعارات:
```bash
# 1. تأكد من deploy Cloud Function:
cd functions
firebase deploy --only functions:notifyNewOrder

# 2. أنشئ طلب اختبار من Admin Panel
# 3. راقب السجلات في كلا الـ terminals
```

### 3. إذا استمرت المشكلة:
- شارك السجلات الكاملة (logs)
- شارك screenshot من Firestore للطلب
- شارك screenshot من Firestore لبيانات السائق

---

**تاريخ التوثيق:** 2026-02-01  
**الحالة:** جاهز للتشخيص والاختبار
