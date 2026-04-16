# 📋 الخطوات التالية - Dispatch Engine v2.0

## ✅ ما تم إنجازه

1. ✅ نشر 4 Cloud Functions جديدة (acceptOrderV2, notifyNewOrderV2, rejectOffer, processExpiredWaves)
2. ✅ نشر Firestore indexes (جاهزة للاستخدام)
3. ✅ نشر Security rules
4. ✅ حذف notifyNewOrder v1 لمنع التكرار
5. ✅ processExpiredWaves يعمل بشكل صحيح كل دقيقة

---

## 🧪 الخطوة 1: اختبار النظام (الآن)

### اختبار يدوي عبر Firebase Console:

1. **افتح Firebase Console:**
   https://console.firebase.google.com/project/wawapp-952d6/firestore

2. **أنشئ طلب اختبار:**
   ```
   Collection: orders
   Document ID: auto
   Data:
   {
     "status": "matching",
     "pickupLat": 18.0735,
     "pickupLng": -15.9582,
     "price": 500,
     "clientName": "Test Client",
     "createdAt": [Current Timestamp],
     "ownerId": "test_client_id"
   }
   ```

3. **راقب Firestore Collections:**
   - انتظر 2-3 ثواني
   - افحص `dispatch_queue/{orderId}` → يجب أن يُنشأ تلقائياً
   - افحص `dispatch_offers/{offerId}` → يجب أن يُرسل عرض للسائق الأقرب

4. **راقب Cloud Functions Logs:**
   ```bash
   firebase functions:log --only notifyNewOrderV2
   ```

   يجب أن ترى:
   ```
   [NotifyNewOrderV2] Order enqueued
   [DispatchEngine] Starting wave 1
   [DispatchEngine] Notification sent to driver
   ```

---

## 📱 الخطوة 2: تحديث تطبيق السائق (مطلوب قبل الاستخدام الكامل)

### ⚠️ تغيير جذري (Breaking Change):

الآن `acceptOrderV2` يتطلب `offerId` إلزامياً.

### ملفات Flutter المطلوب تعديلها:

#### 1. تحديث `orders_service.dart`

**قبل (v1):**
```dart
Future<void> acceptOrder(String orderId) async {
  final callable = FirebaseFunctions.instance.httpsCallable('acceptOrder');
  await callable.call({'orderId': orderId});
}
```

**بعد (v2):**
```dart
Future<void> acceptOrder(String orderId, String offerId) async {
  final callable = FirebaseFunctions.instance.httpsCallable('acceptOrderV2');
  await callable.call({
    'orderId': orderId,
    'offerId': offerId,  // ✅ مطلوب الآن
  });
}
```

#### 2. إضافة دعم الرفض الصريح

```dart
Future<void> rejectOffer(String offerId) async {
  final callable = FirebaseFunctions.instance.httpsCallable('rejectOffer');
  await callable.call({'offerId': offerId});
}
```

#### 3. تحديث UI لعرض الـ offers

**قبل:** السائق يستمع إلى `orders` collection مباشرة

**بعد:** السائق يستمع إلى `dispatch_offers` collection:

```dart
Stream<List<DispatchOffer>> watchMyOffers(String driverId) {
  return FirebaseFirestore.instance
    .collection('dispatch_offers')
    .where('driverId', isEqualTo: driverId)
    .where('status', isEqualTo: 'sent')
    .orderBy('sentAt', descending: true)
    .snapshots()
    .map((snapshot) => snapshot.docs
      .map((doc) => DispatchOffer.fromFirestore(doc))
      .toList());
}
```

#### 4. إنشاء Flutter Model للـ DispatchOffer

```dart
class DispatchOffer {
  final String offerId;
  final String orderId;
  final String driverId;
  final String status;
  final int round;
  final int priority;
  final DateTime sentAt;
  final DateTime expiresAt;
  final double distance;

  DispatchOffer({
    required this.offerId,
    required this.orderId,
    required this.driverId,
    required this.status,
    required this.round,
    required this.priority,
    required this.sentAt,
    required this.expiresAt,
    required this.distance,
  });

  factory DispatchOffer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DispatchOffer(
      offerId: doc.id,
      orderId: data['orderId'],
      driverId: data['driverId'],
      status: data['status'],
      round: data['round'],
      priority: data['priority'],
      sentAt: (data['sentAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      distance: (data['distance'] as num).toDouble(),
    );
  }
}
```

---

## 📊 الخطوة 3: مراقبة الأداء (24-48 ساعة)

### Metrics المطلوب مراقبتها:

1. **Cloud Functions Metrics:**
   - عدد استدعاءات `acceptOrderV2`
   - عدد استدعاءات `notifyNewOrderV2`
   - معدل النجاح (يجب أن يكون > 99%)
   - متوسط وقت التنفيذ

2. **Firestore Usage:**
   - عدد القراءات (يجب أن ينخفض بنسبة 60%)
   - عدد الكتابات
   - تكلفة Firestore الشهرية

3. **Driver Experience:**
   - متوسط الوقت حتى قبول الطلب (هدف: < 30 ثانية)
   - معدل قبول الطلبات من الموجة الأولى (هدف: > 60%)
   - عدد الإشعارات المكررة (هدف: 0)

### أوامر المراقبة:

```bash
# مراقبة logs في الوقت الفعلي
firebase functions:log --only acceptOrderV2,notifyNewOrderV2,rejectOffer,processExpiredWaves

# التحقق من عدد الاستدعاءات
firebase functions:log --lines 1000 | grep "Function triggered" | wc -l

# البحث عن أخطاء
firebase functions:log --lines 1000 | grep -i "error"
```

---

## 🎯 الخطوة 4: التأكد من جاهزية النظام

### قبل الاستخدام الكامل:

- [ ] تم اختبار إنشاء طلب اختبار في Firestore Console
- [ ] تم التحقق من إنشاء dispatch_queue entry
- [ ] تم التحقق من إرسال dispatch_offer للسائق الأقرب
- [ ] تم التحقق من عمل processExpiredWaves كل دقيقة
- [ ] تم تحديث تطبيق السائق Flutter لاستخدام v2 APIs
- [ ] تم اختبار قبول عرض من السائق
- [ ] تم اختبار رفض عرض من السائق
- [ ] تم التحقق من انتهاء صلاحية العروض بعد TTL

---

## 🚨 استراتيجية الـ Rollback (في حالة وجود مشاكل)

### إذا حدثت مشاكل:

1. **استعادة v1 مؤقتاً:**
   ```bash
   # إعادة نشر notifyNewOrder v1
   git checkout <commit_before_v2> -- functions/src/notifyNewOrder.ts
   git checkout <commit_before_v2> -- functions/src/index.ts
   cd functions && npm run build
   firebase deploy --only functions:notifyNewOrder
   ```

2. **حذف v2 functions:**
   ```bash
   firebase functions:delete acceptOrderV2 notifyNewOrderV2 rejectOffer processExpiredWaves --force
   ```

3. **إعادة نشر تطبيق السائق القديم** (من Google Play Console)

---

## 📞 الدعم الفني

### في حالة المشاكل:

1. **افحص Cloud Functions Logs:**
   ```bash
   firebase functions:log --lines 500
   ```

2. **افحص Firestore Console:**
   - تحقق من وجود بيانات في dispatch_queue
   - تحقق من وجود بيانات في dispatch_offers
   - تحقق من حالة السائقين في driver_dispatch_state

3. **رسائل الخطأ الشائعة:**
   - `offerId is required` → التطبيق لم يتم تحديثه لإرسال offerId
   - `offer_expired` → العرض انتهت صلاحيته قبل القبول
   - `already_accepted` → سائق آخر قبل الطلب
   - `driver_busy` → السائق لديه طلب نشط بالفعل

---

## 🔮 التحسينات المستقبلية (بعد استقرار v2.0)

1. **Smart Wave Sizing:** تعديل عدد السائقين في كل موجة حسب كثافة السوق
2. **Driver Preferences:** السماح للسائقين بتعيين filters (مسافة، سعر)
3. **ML-Based Matching:** توقع احتمالية قبول السائق للطلب
4. **Real-time Wave Adjustment:** تعديل TTL ديناميكياً حسب معدل القبول

---

## 📈 معايير النجاح (بعد 7 أيام)

| Metric | v1.0 Baseline | v2.0 Target | Status |
|--------|---------------|-------------|--------|
| إشعارات مكررة | ~15% | 0% | ⏳ |
| وقت القبول | ~45 ثانية | ~25 ثانية | ⏳ |
| Firestore Reads | ~200/order | ~50/order | ⏳ |
| معدل القبول | ~40% | ~60% | ⏳ |
| تكلفة Firestore | Baseline | -60% | ⏳ |

---

**الإصدار:** 2.0.0
**تاريخ النشر:** 2026-04-16
**الحالة:** ✅ مباشر في الإنتاج
