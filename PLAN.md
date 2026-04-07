# خطة تحسين نظام الإشعارات للسائقين

## 🎯 الهدف
تحسين منطق الإشعارات في تطبيق السائق بتطبيق التحسينات التالية:
1. إنشاء Full-Screen UI لـ `trip_start_reminder`
2. إضافة أصوات مختلفة للإشعارات المختلفة
3. تحسين معالجة pending navigation مع fallback آمن
4. تحديث Notification Channels لاستخدام الأصوات الجديدة

---

## 📋 التحسينات المطلوبة

### 1️⃣ إنشاء Full-Screen UI لـ Trip Start Reminder

**المشكلة الحالية:**
- `trip_start_reminder` مُصنّف كـ full-screen type لكنه لا يفتح full-screen UI
- يعرض فقط notification عادي + navigation للـ `/active-order`
- قد لا يكون واضحاً كفاية للسائق على شاشة القفل

**الحل:**
- إنشاء ملف جديد: `trip_start_reminder_screen.dart`
- Data class جديد: `TripStartReminderData`
- Route جديد في app_router.dart: `/trip-start-reminder`
- UI يشبه full-screen notification لكن مُخصص للتذكير ببدء الرحلة

**الملفات المتأثرة:**
- ✅ إنشاء: `apps/wawapp_driver/lib/features/notifications/trip_start_reminder_screen.dart`
- ✅ تعديل: `apps/wawapp_driver/lib/core/router/app_router.dart`
- ✅ تعديل: `apps/wawapp_driver/lib/services/notification_service.dart`

---

### 2️⃣ إضافة أصوات مختلفة للإشعارات

**المشكلة الحالية:**
- جميع الإشعارات تستخدم نفس الصوت: `trip_reminder.wav`
- لا يمكن للسائق التمييز بين نوع الإشعار من الصوت

**الحل:**
- ملاحظة: نحتاج 3 ملفات صوت جديدة:
  - `new_order_alert.wav` - للطلبات الجديدة (urgent)
  - `trip_start_warning.wav` - لتذكير بدء الرحلة (urgent)
  - `order_update_soft.wav` - للتحديثات العامة (soft)

**القرار:**
- سنستخدم نفس الملف الحالي `trip_reminder.wav` لجميع الأصوات حالياً
- سنترك تعليقات في الكود توضح أنه يمكن استبدالها لاحقاً
- المستخدم سيحتاج لإضافة ملفات الصوت الجديدة يدوياً إذا أراد

**الملفات المتأثرة:**
- ✅ تعديل: `apps/wawapp_driver/lib/services/notification_service.dart`
- 📝 ملاحظة: سنضيف تعليقات توضح أسماء الملفات المطلوبة

---

### 3️⃣ تحسين Pending Navigation مع Fallback

**المشكلة الحالية:**
```dart
void _navigateToFullScreen(FullScreenNotificationData data) {
  final ctx = _navigatorKey?.currentContext;
  if (ctx == null) {
    _pendingRoute = '/full-screen-notification';
    _pendingNotificationData = {...};
    return;  // ⚠️ لا يوجد ضمان للتنفيذ لاحقاً
  }
}
```

**الحل:**
- استخدام `WidgetsBinding.instance.addPostFrameCallback`
- إضافة retry mechanism مع timeout
- تسجيل الأخطاء بشكل أفضل

**الملفات المتأثرة:**
- ✅ تعديل: `apps/wawapp_driver/lib/services/notification_service.dart`

---

### 4️⃣ تحديث Notification Channels

**التغييرات:**
- تحديث أسماء الأصوات في Channels (مع استخدام نفس الصوت حالياً)
- إضافة تعليقات توضيحية لكل channel

**الملفات المتأثرة:**
- ✅ تعديل: `apps/wawapp_driver/lib/services/notification_service.dart`

---

## 🗂️ الملفات التي سيتم إنشاؤها/تعديلها

### ملفات جديدة (1):
1. `apps/wawapp_driver/lib/features/notifications/trip_start_reminder_screen.dart`

### ملفات معدلة (2):
1. `apps/wawapp_driver/lib/services/notification_service.dart`
2. `apps/wawapp_driver/lib/core/router/app_router.dart`

---

## 📐 التصميم التفصيلي

### 1. Trip Start Reminder Screen

**Data Class:**
```dart
class TripStartReminderData {
  final String orderId;
  final String pickupLabel;
  final int remainingMinutes;
  final int? createdAtMs;
}
```

**UI Elements:**
- خلفية برتقالية/صفراء (تحذير)
- أيقونة ساعة كبيرة مع countdown
- عنوان: "هل وصلت للعميل؟"
- تفاصيل: موقع الاستلام + الوقت المتبقي
- زر كبير: "بدأت الرحلة" (يشغل الرحلة)
- زر صغير: "لم أصل بعد" (يغلق فقط)

**الألوان:**
- Background: `Color(0xFFF59E0B)` (Orange/Amber)
- Primary Button: `Color(0xFF1B5E20)` (Dark Green)
- Secondary Button: `Color(0xFF757575)` (Grey)

---

### 2. Notification Service Updates

**التحسينات:**
```dart
// 1. تحديث _showTripReminderNotification لفتح full-screen
void _showTripReminderNotification(Map<String, dynamic> data) {
  // عرض system notification
  _localNotifications.show(...);

  // فتح full-screen UI
  _navigateToTripStartReminder(TripStartReminderData.parse(data));
}

// 2. إضافة _navigateToTripStartReminder
void _navigateToTripStartReminder(TripStartReminderData data) {
  // مع fallback mechanism
}

// 3. تحسين _navigateToFullScreen مع retry
void _navigateToFullScreen(FullScreenNotificationData data) {
  if (ctx == null) {
    _schedulePendingNavigation(() {
      _navigateToFullScreen(data);
    });
  }
}

// 4. إضافة _schedulePendingNavigation
void _schedulePendingNavigation(VoidCallback callback) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_navigatorKey?.currentContext != null) {
      callback();
    } else {
      // Retry after delay
    }
  });
}
```

---

### 3. Router Updates

**إضافة Route جديد:**
```dart
GoRoute(
  path: '/trip-start-reminder',
  name: 'tripStartReminder',
  builder: (context, state) {
    final extra = state.extra;
    if (extra is TripStartReminderData) {
      return TripStartReminderScreen(data: extra);
    }
    // Fallback
    return const ActiveOrderScreen();
  },
),
```

---

## ✅ Checklist للتنفيذ

### Phase 1: إنشاء Trip Start Reminder Screen
- [ ] إنشاء `trip_start_reminder_screen.dart`
- [ ] إضافة `TripStartReminderData` class
- [ ] تصميم UI (countdown timer + buttons)
- [ ] دمج مع `OrdersService` لبدء الرحلة

### Phase 2: تحديث Notification Service
- [ ] تحديث `_showTripReminderNotification`
- [ ] إضافة `_navigateToTripStartReminder`
- [ ] تحسين `_navigateToFullScreen` مع retry
- [ ] إضافة `_schedulePendingNavigation` helper
- [ ] تحديث notification channels (مع ملاحظات الأصوات)

### Phase 3: تحديث Router
- [ ] إضافة route `/trip-start-reminder`
- [ ] import الـ screen الجديد

### Phase 4: Testing
- [ ] اختبار full-screen notification للطلبات الجديدة
- [ ] اختبار full-screen reminder لبدء الرحلة
- [ ] اختبار pending navigation عند بدء التطبيق
- [ ] اختبار الأصوات (نفس الصوت حالياً)

---

## 🎨 Design Guidelines

### Colors:
- **New Order**: Green `Color(0xFF1B5E20)`
- **Trip Reminder**: Amber `Color(0xFFF59E0B)`
- **Error/Cancel**: Red `Color(0xFFE53935)`

### Typography:
- **Title**: 26px Bold
- **Subtitle**: 18px Regular
- **Body**: 16px Regular
- **Caption**: 14px Regular

### Spacing:
- **Screen Padding**: 32px horizontal, 48px bottom
- **Card Margin**: 24px horizontal
- **Element Spacing**: 12-16px between elements

---

## 📝 ملاحظات هامة

1. **الأصوات:**
   - حالياً سنستخدم `trip_reminder.wav` لجميع الإشعارات
   - سنضيف تعليقات توضح أسماء الملفات المقترحة للمستقبل
   - المستخدم يمكنه إضافة الملفات يدوياً في `android/app/src/main/res/raw/`

2. **التوافقية:**
   - التحسينات متوافقة مع الكود الحالي
   - لا تتطلب تغييرات في Firebase Functions
   - لا تتطلب تغييرات في Firestore

3. **الأمان:**
   - جميع التحسينات تحترم قواعد CLAUDE.md
   - لا تعديل على البنية الأساسية
   - فقط إضافة features جديدة

---

## 🚀 جاهز للتنفيذ

هذه الخطة شاملة ومفصلة. عند الموافقة، سأبدأ بالتنفيذ خطوة بخطوة.
