# تقرير جلسة العمل — 9 أبريل 2026

## ملخص تنفيذي
جلسة تشخيص وإصلاح نظام الإشعارات في تطبيق السائق (WawApp Driver). تم اكتشاف وإصلاح عدة مشاكل في Cloud Functions وتطبيق Flutter، لكن **مشكلة عدم ظهور الإشعار ملء الشاشة لا تزال قائمة**.

---

## 1. العمليات المنفذة

### 1.1 مزامنة الكود
- سحب كوميت جديد `7adfccc` من الريموت (fix: full-screen + sound + trip reminder fixes)
- الملفات المحدثة: `trip_start_reminder_screen.dart`, `main.dart`, `location_service.dart`, `notification_service.dart`, `monitorAcceptedOrders.ts`, `notifyUnassignedOrders.ts`

### 1.2 محاولة التثبيت
- فشل التثبيت الأول بسبب `INSTALL_FAILED_UPDATE_INCOMPATIBLE` (تعارض التوقيعات)
- تم حذف النسخة القديمة بـ `adb uninstall com.wawapp.driver`
- تم إعادة البناء والتثبيت بنجاح

---

## 2. المشاكل المكتشفة والإصلاحات

### 2.1 ✅ تم الإصلاح — عدم تطابق أسماء القنوات بين Cloud Functions والتطبيق

| الملف | القيمة القديمة | القيمة الجديدة |
|---|---|---|
| `notifyNewOrder.ts` (سطر 242) | `channelId: 'new_orders'` | `channelId: 'new_orders_v4'` |
| `notifyUnassignedOrders.ts` (سطر 340) | `channelId: 'unassigned_orders_v3'` | `channelId: 'unassigned_orders_v4'` |
| `AndroidManifest.xml` | `default_notification_channel_id: new_orders_v2` | `new_orders_v4` |
| `notification_service.dart` | قنوات v3 | قنوات v4 |

**التأثير:** الإشعارات كانت تُرسل على قنوات قديمة بدون إعدادات الصوت والأولوية الصحيحة.

### 2.2 ✅ تم الإصلاح — notifyNewOrder لا يتحقق من assignedDriverId

**المشكلة:** `notifyNewOrder.ts` كان يتحقق فقط من `driverId` عند فحص الطلبات النشطة للسائق، بينما الطلبات المقبولة تُسجل في `assignedDriverId`.

**النتيجة:** السائق الذي لديه طلب مقبول كان يستقبل إشعارات "طلب جديد" بالخطأ.

**الإصلاح:** إضافة فحص `assignedDriverId` بجانب `driverId`:
```typescript
// قبل
.where('driverId', '==', driverId)
.where('status', '==', 'accepted')

// بعد
.where('driverId', '==', driverId)
.where('status', 'in', ['accepted', 'onRoute'])
// + فحص إضافي:
.where('assignedDriverId', '==', driverId)
.where('status', 'in', ['accepted', 'onRoute'])
```

### 2.3 ✅ تم الإصلاح — monitorAcceptedOrders يرسل notification block

**المشكلة:** `monitorAcceptedOrders.ts` كان يرسل FCM مع `android.notification` block:
```typescript
android: {
  notification: {
    channelId: channelId,
    sound: 'trip_reminder',
    priority: 'max',
    visibility: 'public',
  },
},
```

**التأثير:** عندما يحتوي FCM على `android.notification`، أندرويد يعرضه كإشعار نظام عادي (بانر) **ولا يمرره للـ background handler** في Flutter. بالتالي كود `fullScreenIntent: true` في `main.dart` لم يكن يُنفذ.

**الإصلاح:** إزالة `android.notification` ليصبح data-only message:
```typescript
android: {
  priority: 'high',
  ttl: 120000,
},
```

### 2.4 ✅ تم الإصلاح — AndroidManifest ينقصه directBootAware

**الإصلاح:** إضافة `android:directBootAware="true"` للـ MainActivity.

### 2.5 ⚠️ ملاحظة — حقل region مفقود في بروفايل السائق

أداة التشخيص تعتبر `region` مطلوباً، لكن بعد الفحص:
- الكوميت `1d9e64f` حذف حقل `region` من التطبيق عمداً
- Cloud Functions (`notifyUnassignedOrders`, `notifyNewOrder`) **لا تتحقق من `region`** — تتحقق فقط من: `name`, `vehicleType`, `vehiclePlate`, `city`
- **ليست مشكلة حقيقية** — فقط تحذير من أداة التشخيص

---

## 3. المشكلة المتبقية — الإشعار لا يظهر ملء الشاشة

### الحالة الحالية
- Cloud Functions ترسل التذكيرات بنجاح (6+ تذكيرات مرسلة)
- FCM token صالح ومحدث
- الإشعار يصل كبانر عادي وليس ملء الشاشة
- الصوت قد لا يعمل

### الأسباب المحتملة المتبقية

#### A. صلاحية USE_FULL_SCREEN_INTENT (أندرويد 14+)
في أندرويد 14، هذه الصلاحية **لا تُمنح تلقائياً** لتطبيقات debug. يجب التفعيل يدوياً:
- إعدادات → التطبيقات → WawApp Driver → الوصول الخاص → التنبيهات بملء الشاشة

#### B. وضع عدم الإزعاج (DND)
قد يحجب شاشات الاتصال حتى لو كانت بأولوية قصوى.

#### C. سلوك أندرويد الطبيعي
إذا الشاشة **مفتوحة والمستخدم نشط**، أندرويد يعرض heads-up banner بدلاً من full-screen intent. الشاشة الكاملة تظهر فقط عندما:
- الشاشة مغلقة (screen off)
- الهاتف على شاشة القفل (lock screen)

#### D. قناة الإشعارات "عالقة"
رغم الترقية لـ v4، قد يحتاج الأمر:
- حذف بيانات التطبيق بالكامل (Clear Data)
- أو الترقية لـ v5 مع حذف v4

#### E. تأخر تطبيق التغييرات
الـ background handler في `main.dart` تم تحديثه لكن **قد لا يكون التطبيق المثبت على الهاتف هو النسخة الأخيرة** — يجب التأكد من إعادة البناء بعد كل التعديلات.

---

## 4. Cloud Functions المنشورة

| Function | الحالة | التاريخ |
|---|---|---|
| `notifyNewOrder` | ✅ منشورة | 2026-04-09 |
| `notifyUnassignedOrders` | ✅ منشورة | 2026-04-09 |
| `monitorAcceptedOrders` | ✅ منشورة | 2026-04-09 |

---

## 5. الملفات المعدلة (غير مُرسلة لـ Git بعد)

### Flutter (تطبيق السائق)
- `apps/wawapp_driver/android/app/src/main/AndroidManifest.xml` — directBootAware + default channel v4
- `apps/wawapp_driver/lib/services/notification_service.dart` — قنوات v4

### Cloud Functions
- `functions/src/notifyNewOrder.ts` — channel v4 + فحص assignedDriverId
- `functions/src/notifyUnassignedOrders.ts` — channel v4
- `functions/src/monitorAcceptedOrders.ts` — إزالة android.notification block

---

## 6. خطوات التحقق المطلوبة

### فوري
1. [ ] التأكد من بناء وتثبيت النسخة الأخيرة على الهاتف
2. [ ] التحقق من صلاحية "التنبيهات بملء الشاشة" في إعدادات الهاتف
3. [ ] التحقق من عدم تفعيل وضع "عدم الإزعاج"
4. [ ] اختبار مع الشاشة مغلقة (screen off) — هل يظهر ملء الشاشة؟

### لاحق
5. [ ] إضافة logging في background handler لتأكيد أنه يُستدعى
6. [ ] اختبار على جهاز آخر بإصدار أندرويد مختلف
7. [ ] النظر في استخدام `flutter_incoming_call` أو مكتبة متخصصة لشاشات الاتصال

---

## 7. معلومات النظام

- **السائق:** sidi (ID: `49ZGFxTVAMaAMkVd4GQZ9Juyjgf1`)
- **الطلب المقبول:** `8fnS1p5duvJGc9sBOosu` (290 MRU, دوار مدريد → نهج غاري)
- **عدد التذكيرات المرسلة:** 6+
- **حالة FCM Token:** صالح (محدث قبل دقيقتين)
- **فرع Git:** `feature/r1-notifications`
- **آخر كوميت محلي:** `7adfccc`
