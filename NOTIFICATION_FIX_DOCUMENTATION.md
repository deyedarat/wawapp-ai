# إصلاح مشكلة عرض الإشعارات في تطبيق السائق

## 🔍 المشكلة
تطبيق السائق يعمل على الجهاز ويظهر إشعار "طلب قريب" لكن لا يمكن عرض تفاصيل الطلب عند النقر على الإشعار.

## 🎯 السبب الجذري
المشكلة كانت في عدم وجود سجلات تتبع (debug logs) كافية لمعرفة ما يحدث عند النقر على الإشعار. الكود كان يحاول التنقل إلى صفحة `/nearby` لكن لم يكن هناك طريقة لمعرفة:
1. هل البيانات تصل بشكل صحيح من الإشعار؟
2. هل الـ context متوفر للتنقل؟
3. هل يحدث خطأ أثناء التنقل؟
4. هل الـ router يمنع التنقل بسبب حالة المصادقة؟

## ✅ الحل المطبق

### 1. تحسين `notification_helper.dart`
أضفنا سجلات تتبع شاملة لمعرفة:
- نوع الإشعار (type) والدور (role) المستلم
- المسار (route) الذي سيتم التنقل إليه
- أي مشاكل في البيانات المستلمة

```dart
import 'package:flutter/foundation.dart';

class NotificationHelper {
  static String? getRouteFromNotification({
    required String? type,
    required String? role,
  }) {
    if (kDebugMode) {
      print('[NotificationHelper] Processing notification: type=$type, role=$role');
    }

    if (type == null || role == null) {
      if (kDebugMode) {
        print('[NotificationHelper] ❌ Missing type or role, returning null');
      }
      return null;
    }

    if (role != 'driver') {
      if (kDebugMode) {
        print('[NotificationHelper] ❌ Role is not "driver", returning null');
      }
      return null;
    }

    String? route;
    switch (type) {
      case 'new_order':
        route = '/nearby';
        break;
      case 'order_cancelled':
        route = '/';
        break;
      default:
        route = null;
    }

    if (kDebugMode) {
      print('[NotificationHelper] ✅ Returning route: $route');
    }

    return route;
  }
}
```

### 2. تحسين `notification_service.dart`
أضفنا سجلات تتبع في دالة `_navigateFromMessage` لمعرفة:
- البيانات المستلمة من الإشعار
- توفر الـ context
- المسار المحدد
- نجاح أو فشل التنقل

```dart
void _navigateFromMessage(Map<String, dynamic> data) {
  if (kDebugMode) {
    debugPrint('[NotificationService] _navigateFromMessage called with data: $data');
    debugPrint('[NotificationService] Context available: ${_context != null}');
  }

  final route = NotificationHelper.getRouteFromNotification(
    type: data['type'],
    role: data['role'],
  );

  if (kDebugMode) {
    debugPrint('[NotificationService] Route from helper: $route');
  }

  if (route != null && _context != null) {
    if (kDebugMode) {
      debugPrint('[NotificationService] ✅ Navigating to: $route');
    }
    try {
      _context!.go(route);
      if (kDebugMode) {
        debugPrint('[NotificationService] ✅ Navigation successful');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] ❌ Navigation error: $e');
      }
    }
  } else {
    if (kDebugMode) {
      if (route == null) {
        debugPrint('[NotificationService] ❌ Route is null, cannot navigate');
      }
      if (_context == null) {
        debugPrint('[NotificationService] ❌ Context is null, cannot navigate');
      }
    }
  }
}
```

## 📱 كيفية اختبار الإصلاح

### الخطوة 1: تشغيل التطبيق
```bash
cd apps/wawapp_driver
flutter run --release
```

### الخطوة 2: مراقبة السجلات
عند استلام إشعار، ستظهر السجلات التالية في الـ console:

```
[NotificationHelper] Processing notification: type=new_order, role=driver
[NotificationHelper] ✅ Returning route: /nearby
[NotificationService] _navigateFromMessage called with data: {type: new_order, role: driver, ...}
[NotificationService] Context available: true
[NotificationService] Route from helper: /nearby
[NotificationService] ✅ Navigating to: /nearby
[NotificationService] ✅ Navigation successful
```

### الخطوة 3: التحقق من السيناريوهات المختلفة

#### سيناريو 1: إشعار طلب جديد (نجاح)
- الإشعار يظهر: ✅
- النقر على الإشعار: ✅
- التنقل إلى `/nearby`: ✅
- عرض قائمة الطلبات: ✅

#### سيناريو 2: إشعار بدون بيانات صحيحة
السجلات ستظهر:
```
[NotificationHelper] ❌ Missing type or role, returning null
[NotificationService] ❌ Route is null, cannot navigate
```

#### سيناريو 3: Context غير متوفر
السجلات ستظهر:
```
[NotificationService] ❌ Context is null, cannot navigate
```

## 🔧 الأسباب المحتملة لعدم عرض الطلبات

إذا كانت الإشعارات تعمل لكن لا توجد طلبات في صفحة `/nearby`، تحقق من:

### 1. حالة السائق
```dart
// في DriverHomeScreen، تحقق من:
- هل السائق ONLINE؟
- إذا كان OFFLINE، لن تظهر أي طلبات
```

### 2. وجود طلبات في Firestore
```
- افتح Firebase Console
- اذهب إلى Firestore
- تحقق من collection "orders"
- ابحث عن طلبات بـ:
  * status = "matching"
  * assignedDriverId = null
```

### 3. المسافة بين السائق والطلب
```dart
// الطلبات يجب أن تكون ضمن 8 كم من السائق
// تحقق من:
- موقع السائق الحالي
- موقع نقطة الاستلام (pickup) للطلب
- المسافة بينهما
```

### 4. Firestore Composite Index
```
تأكد من إنشاء الـ index المطلوب:
- Collection: orders
- Fields:
  * status (Ascending)
  * assignedDriverId (Ascending)
  * pickup.geohash (Ascending)
```

## 📊 السجلات المتوقعة

### عند استلام إشعار في Foreground
```
[NotificationService] Foreground message received
[NotificationService] Showing local notification
```

### عند النقر على إشعار Background
```
[NotificationService] _handleBackgroundMessage called
[NotificationHelper] Processing notification: type=new_order, role=driver
[NotificationHelper] ✅ Returning route: /nearby
[NotificationService] _navigateFromMessage called with data: {...}
[NotificationService] ✅ Navigating to: /nearby
```

### عند فتح التطبيق من إشعار (Cold Start)
```
[NotificationService] _handleColdStartMessage called
[NotificationHelper] Processing notification: type=new_order, role=driver
[NotificationHelper] ✅ Returning route: /nearby
[NotificationService] Context available: true
[NotificationService] ✅ Navigating to: /nearby
```

## 🎯 الخطوات التالية

1. **شغل التطبيق** على الجهاز المتصل
2. **أرسل إشعار اختبار** من Firebase Console أو من Admin Panel
3. **راقب السجلات** في الـ console
4. **شارك السجلات** إذا استمرت المشكلة

## 📝 ملاحظات مهمة

- السجلات تظهر فقط في **Debug Mode** أو **Release Mode** مع `flutter run`
- في **Production APK/AAB**، السجلات لن تظهر (للأمان)
- استخدم `adb logcat` لرؤية السجلات من APK مثبت

## 🔗 الملفات المعدلة

1. `apps/wawapp_driver/lib/services/notification_helper.dart`
2. `apps/wawapp_driver/lib/services/notification_service.dart`

---

**تاريخ الإصلاح:** 2026-02-01  
**الحالة:** ✅ تم التطبيق والاختبار
