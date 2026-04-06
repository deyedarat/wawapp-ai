# 🔔 دليل إصلاح الإشعارات بملء الشاشة - WawApp Driver

## 📋 ملخص المشكلة

**المشكلة الأصلية:**
- الإشعارات **أحياناً** تظهر بملء الشاشة، لكن أحياناً تظهر كإشعار عادي في notification tray
- بعد إعادة تشغيل التطبيق، الإشعارات تعود للنمط العادي

**السبب الجذري:**
عندما أضفنا `notification` block في رسائل FCM من Backend:
```typescript
// ❌ هذا النوع لا يعمل مع full-screen
{
  notification: { title, body },  // Android يعرضها تلقائياً كـ notification عادية
  data: { ... }
}
```

- Android يعرض الـ `notification` block **تلقائياً** من system tray
- الـ **background handler لا يُستدعى** للرسائل التي تحتوي `notification` block
- فقط **data-only messages** تستدعي background handler
- Background handler هو الوحيد الذي يمكنه عرض full-screen intent

---

## ✅ الحل النهائي

### **الاستراتيجية:**
أرسل **data-only messages** من Backend → Background handler يعرض full-screen notification

### **التغييرات المطبقة:**

#### **1. Backend: `functions/src/notifyNewOrder.ts`**

**قبل (❌ لا يعمل):**
```typescript
const message: admin.messaging.Message = {
  token: driver.fcmToken,
  notification: {  // ❌ يمنع background handler من العمل
    title: 'طلب جديد قريب منك',
    body: `${pickupLabel} → ${dropoffLabel}`,
  },
  data: { ... },
  android: {
    priority: 'high',
    notification: { channelId: 'new_orders', ... }
  }
};
```

**بعد (✅ يعمل):**
```typescript
const message: admin.messaging.Message = {
  token: driver.fcmToken,
  data: {  // ✅ data-only → background handler يُستدعى
    notificationType: 'new_order',
    type: 'new_order',
    title: 'طلب جديد قريب منك',
    body: `${pickupLabel} → ${dropoffLabel}`,
    orderId: orderId,
    pickupLat: String(pLat),
    pickupLng: String(pLng),
    // ... المزيد
  },
  android: {
    priority: 'high',
    ttl: 300000,
  }
};
```

#### **2. Backend: `functions/src/monitorAcceptedOrders.ts`**

**نفس المنطق - data-only:**
```typescript
await admin.messaging().send({
  token: fcmToken,
  data: {  // ✅ data-only
    ...data,
    title,
    body,
    notificationType: data.notificationType || data.type || '',
  },
  android: {
    priority: 'high',
    ttl: 120000,
  }
});
```

#### **3. App: Background Handler في `main.dart`**

**موجود بالفعل ويعمل (السطر 26-69):**
```dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final type = message.data['notificationType'] ?? message.data['type'];

  // عرض full-screen للطلبات الجديدة
  if (type == 'new_order' ||
      type == 'new_order_nearby' ||
      type == 'unassigned_order_reminder') {
    final plugin = FlutterLocalNotificationsPlugin();
    // ... initialize

    await plugin.show(
      orderId.hashCode,
      message.data['title'] ?? 'طلب جديد قريب منك',
      '$pickupLabel → $dropoffLabel',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,  // ✅ هذا هو المفتاح
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
        ),
      ),
    );
  }
}
```

---

## 🧪 طريقة الاختبار الصحيحة

### **الخطوات:**

1. **قفل الهاتف** (مهم جداً!)
   - اضغط زر القفل
   - انتظر حتى تنطفئ الشاشة تماماً

2. **إنشاء طلب جديد** من client app
   - افتح client app على هاتف آخر أو محاكي
   - أنشئ طلب جديد

3. **النتيجة المتوقعة:**
   - ✅ شاشة الهاتف المقفل **تضيء تلقائياً**
   - ✅ إشعار **بملء الشاشة** يظهر فوراً
   - ✅ زر "عرض الطلب" + زر "رفض"
   - ✅ صوت + اهتزاز

4. **اختبار إعادة التشغيل:**
   - رفض الإشعار أو اضغط "عرض الطلب"
   - أغلق التطبيق تماماً (Force Stop)
   - **قفل الهاتف مرة أخرى**
   - أنشئ طلب جديد
   - ✅ **يجب أن يظهر full-screen مرة أخرى**

---

## ⚠️ ملاحظات مهمة

### **1. لماذا لا يعمل إذا كان التطبيق مفتوح؟**
- Full-screen intent **لا يعمل** إذا كان التطبيق في foreground (مفتوح)
- في هذه الحالة، foreground handler (`_handleForegroundMessage`) يعرض الإشعار
- Full-screen **فقط** يعمل عندما:
  - الهاتف مقفل 🔒
  - التطبيق في background (مغلق)
  - التطبيق مغلق تماماً (terminated)

### **2. Android 12+ Battery Optimization:**
إذا لم يعمل full-screen حتى بعد التطبيق، قد تكون المشكلة في إعدادات البطارية:

**الحل:**
1. Settings → Apps → WawApp Driver
2. Battery → Unrestricted
3. Notifications → Allow all
4. Display over other apps → Allow

### **3. Permission في AndroidManifest:**
موجود بالفعل ✅:
```xml
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### **4. Notification Channel:**
Channel `new_orders` موجود مع `Importance.max` ✅:
```dart
const newOrdersChannel = AndroidNotificationChannel(
  'new_orders',
  'طلبات جديدة',
  description: 'إشعارات الطلبات الجديدة القريبة منك',
  importance: Importance.max,  // ✅ مهم جداً
  enableVibration: true,
  playSound: true,
);
```

---

## 🔍 Debugging

إذا لم يعمل full-screen، افحص:

### **1. Backend Logs:**
```bash
firebase functions:log --only notifyNewOrder
```

**ابحث عن:**
```
[NotifyNewOrder] Notification sent to driver
driver_id: xxx
order_id: xxx
message_id: projects/.../messages/xxx
```

### **2. Android Logcat:**
```bash
adb logcat | grep -E "(FCM|Notification|WawApp)"
```

**ابحث عن:**
```
[NotificationService] 🔔 onBackgroundMessage received
type=new_order
orderId=xxx
```

### **3. تحقق من FCM Token:**
```dart
// في driver app
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');
```

تأكد أن الـ token في Firestore `drivers/{driverId}.fcmToken` يطابق الـ token الحالي.

---

## 📊 جدول الفروقات

| السيناريو | notification block | data-only | النتيجة |
|-----------|-------------------|-----------|---------|
| App مفتوح (foreground) | ❌ system tray | ✅ foreground handler | ✅ عادي |
| App في background | ❌ system tray | ✅ background handler | ✅ full-screen |
| App مغلق (terminated) | ❌ system tray | ✅ background handler | ✅ full-screen |
| Hاتف مقفل | ❌ system tray | ✅ background handler | ✅ **full-screen** |

---

## ✅ التحقق من النشر

```bash
firebase functions:list | grep -E "(notifyNewOrder|monitorAcceptedOrders)"
```

**النتيجة المتوقعة:**
```
notifyNewOrder               | v1 | firestore-orders-onCreate  | us-central1 | 256 | nodejs20
monitorAcceptedOrders        | v1 | schedule-every-1-minutes   | us-central1 | 256 | nodejs20
```

---

## 🎯 الخلاصة

**الإصلاح النهائي:**
1. ✅ Backend يرسل **data-only messages** (بدون `notification` block)
2. ✅ Background handler يعرض full-screen notification
3. ✅ Foreground handler يعرض إشعار عادي (App مفتوح)
4. ✅ Full-screen يعمل **دائماً** عند قفل الهاتف

**الاختبار:**
- قفل الهاتف 🔒
- إنشاء طلب جديد
- ✅ full-screen يظهر فوراً

**إذا لم يعمل:**
- تحقق من إعدادات البطارية (Unrestricted)
- تحقق من permissions (Display over other apps)
- تحقق من backend logs
- تحقق من FCM token

---

**آخر نشر:** 2026-04-06
**الحالة:** ✅ منشور ويعمل

**الملفات المنشورة:**
- `functions/src/notifyNewOrder.ts` ✅
- `functions/src/monitorAcceptedOrders.ts` ✅

**ملاحظة:** لا حاجة لإعادة build التطبيق - التغييرات في Backend فقط.
