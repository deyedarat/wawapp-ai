# إصلاح الصوت والإشعار على الشاشة المقفلة

## 📋 المشاكل المكتشفة:

### 1. ❌ لا يوجد صوت عند وصول الإشعار
**السبب:**
- الـ background handler في `main.dart` لم يُنشئ الـ notification channels قبل إرسال الإشعار
- بدون channel، Android يتجاهل إعدادات الصوت

### 2. ❌ الإشعار لا يظهر بملء الشاشة عندما تكون الشاشة مقفلة
**السبب:**
- نقص في إعدادات الإشعار: `ongoing`, `autoCancel`, `showWhen`, `timeoutAfter`
- MainActivity تحتوي بالفعل على `showWhenLocked="true"` و `turnScreenOn="true"` ✅

---

## ✅ الحل المطبق:

### التعديل في `main.dart` - Background Message Handler

**الملف:** `apps/wawapp_driver/lib/main.dart:30-110`

#### الإضافات:

1. **Import `dart:typed_data`** للـ vibration pattern:
```dart
import 'dart:typed_data';
```

2. **إنشاء Notification Channels قبل إرسال الإشعار:**
```dart
// Create notification channels with sound BEFORE showing notification
final android = plugin.resolvePlatformSpecificImplementation<
    AndroidFlutterLocalNotificationsPlugin>();

if (android != null) {
  // Channel for new orders
  const newOrdersChannel = AndroidNotificationChannel(
    'new_orders',
    'طلبات جديدة',
    description: 'إشعارات الطلبات الجديدة القريبة منك - أولوية قصوى',
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('trip_reminder'),
  );

  // Channel for unassigned orders reminder
  const unassignedOrdersChannel = AndroidNotificationChannel(
    'unassigned_orders',
    'تذكير بطلبات متاحة',
    description: 'تذكيرات بالطلبات المتاحة القريبة منك - أولوية قصوى',
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('trip_reminder'),
  );

  // Create channels
  await android.createNotificationChannel(newOrdersChannel);
  await android.createNotificationChannel(unassignedOrdersChannel);
}
```

3. **تحسين إعدادات الإشعار للشاشة المقفلة:**
```dart
NotificationDetails(
  android: AndroidNotificationDetails(
    channelId,
    channelName,
    importance: Importance.max,
    priority: Priority.max,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
    playSound: true,
    sound: const RawResourceAndroidNotificationSound('trip_reminder'),
    fullScreenIntent: true,
    category: AndroidNotificationCategory.call,
    visibility: NotificationVisibility.public,
    showWhen: true,          // ⭐ جديد
    ongoing: true,            // ⭐ جديد - يبقى حتى يتم التفاعل معه
    autoCancel: false,        // ⭐ جديد - لا يُلغى تلقائياً
    timeoutAfter: 60000,      // ⭐ جديد - ينتهي بعد دقيقة
  ),
)
```

4. **إصلاح channel IDs:**
```dart
// من:
final channelId = type == 'unassigned_order_reminder'
    ? 'unassigned_orders_v2'  // ❌ خطأ
    : 'new_orders_v2';         // ❌ خطأ

// إلى:
final channelId = type == 'unassigned_order_reminder'
    ? 'unassigned_orders'      // ✅ صحيح
    : 'new_orders';            // ✅ صحيح
```

---

## 🎯 النتيجة المتوقعة الآن:

### ✅ الصوت:
- يشتغل `trip_reminder.wav` عند وصول الإشعار
- حتى لو كان التطبيق مغلقاً (background)
- حتى لو كانت الشاشة مقفلة

### ✅ Full-Screen على الشاشة المقفلة:
- الإشعار يفتح **تلقائياً بملء الشاشة**
- الشاشة **تُشعل** تلقائياً (turnScreenOn=true)
- يظهر فوق شاشة القفل (showWhenLocked=true)
- يبقى ظاهراً حتى يتفاعل معه السائق (ongoing=true)

---

## 🧪 اختبار الآن:

### الخطوة 1: أقفل الشاشة
اضغط على زر Power لقفل الهاتف

### الخطوة 2: أرسل طلب جديد
من تطبيق العميل أو Firebase Console

### الخطوة 3: راقب السلوك

**يجب أن يحدث التالي:**
1. ✅ الشاشة **تُشعل** تلقائياً
2. ✅ يظهر الإشعار **بملء الشاشة** فوراً
3. ✅ يشتغل صوت `trip_reminder.wav`
4. ✅ رجّة (vibration) قوية
5. ✅ شاشة قبول الطلب ظاهرة مباشرة

---

## 🔍 Logs للتحقق:

```bash
adb logcat | grep -iE "flutter|NotificationService|sound|channel"
```

**علامات النجاح:**
```
D/FlutterLocalNotificationsPlugin: Creating notification channel: new_orders
D/NotificationManager: Notification sound: trip_reminder
I/flutter: [NotificationService] 🚀 Full-screen notification
```

**علامات الفشل:**
```
E/flutter: PlatformException(invalid_sound, The resource trip_reminder could not be found
W/NotificationService: Channel not found
```

---

## 📊 الفرق قبل وبعد:

| العنصر | قبل ❌ | بعد ✅ |
|--------|--------|--------|
| إنشاء Channels في background | لا | **نعم** |
| الصوت على background | لا يعمل | **يعمل** |
| Full-screen على شاشة مقفلة | لا | **نعم** |
| الشاشة تُشعل تلقائياً | لا | **نعم** |
| الإشعار يبقى حتى التفاعل | لا | **نعم (ongoing)** |
| Vibration pattern | بسيط | **قوي** |
| Channel ID | `new_orders_v2` (خطأ) | **`new_orders`** (صحيح) |

---

## ⚠️ ملاحظات مهمة:

### 1. Battery Optimization
بعض أجهزة Samsung تمنع الإشعارات إذا كان التطبيق في "Deep Sleep".

**الحل:**
- Settings → Battery → Battery optimization
- ابحث عن wawapp_driver
- اختر **"Don't optimize"**

### 2. Do Not Disturb Mode
إذا كان الهاتف في وضع "عدم الإزعاج":
- Settings → Sound → Do not disturb
- أضف wawapp_driver إلى **Exceptions**

### 3. Notification Importance
تأكد أن notification channels لها أعلى أولوية:
- Settings → Apps → wawapp_driver → Notifications
- تحقق أن "طلبات جديدة" → **"Alerting"** أو **"Urgent"**

---

**التاريخ:** 2026-04-07
**Build:** app-release.apk (55.9MB)
**الحالة:** ✅ مثبّت وجاهز للاختبار
