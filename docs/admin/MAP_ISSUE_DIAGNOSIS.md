# تشخيص مشكلة الخريطة في لوحة الإدارة

**التاريخ:** 20 يونيو 2026  
**الموقع:** https://wawapp-952d6.web.app  
**الشاشة:** "اختر موقع الاستلام" (MapLocationPicker)  
**العرض:** مساحة بيضاء فارغة بدل خريطة Google Maps

---

## ما تم التحقق منه

### 1. الفوترة (Billing) ✅ سليم
- حسابان Billing نشطان (Status: Active)
- مشروع `wawapp-952d6` مربوط بحساب "Firebase Payment" (ID: 010D85-ECF8E4-83E5EF)
- الإنفاق $0 في آخر 30 يوم (طبيعي - ضمن الحصة المجانية $200/شهر)

### 2. تفعيل APIs ✅ سليم
- Maps JavaScript API: مفعّل (API Enabled ✅)
- Places API: مفعّل (54 طلب)
- Geocoding API: مفعّل (54 طلب)
- Directions API: مفعّل (54 طلب)
- Maps SDK for Android: مفعّل (18 طلب)

### 3. تقييدات المفتاح (API Key Restrictions) ✅ سليم
- المفتاح: `AIzaSyDF_TYfDGqpoZtYLSYBFvjAPva6Qp3S6Bs`
- Application restrictions: **Websites**
- Website restrictions:
  - `wawapp-952d6.firebaseapp.com/*`
  - `wawapp-952d6.web.app/*`
- API restrictions: **2 APIs** (Maps JavaScript API + Places API New)

### 4. الكود (index.html) ✅ سليم
- Google Maps JS API يُحمّل مع `loading=async` و `callback=_onMapsApiReady`
- Flutter يبدأ فقط بعد تهيئة Maps API (حل مشكلة race condition)
- المكتبات: `libraries=places&language=ar`

### 5. الكود (MapLocationPicker) ✅ سليم
- يستخدم `google_maps_flutter: ^2.10.0`
- `google_maps_flutter_web: 0.5.14+3` (في pubspec.lock)
- GoogleMap widget داخل Stack في body الـ Scaffold (بدون مشاكل sizing)
- `webGestureHandling: WebGestureHandling.greedy`

### 6. إضافات المتصفح ✅ لا يوجد ad blocker مثبّت
- Claude (Beta)
- Genspark
- Google Docs Offline
- Manus AI Browser Operator
- لا يوجد AdBlock/uBlock/AdGuard

---

## السبب الجذري المُكتشف

### خطأ Console:
```
Failed to load resource: net::ERR_BLOCKED_BY_CLIENT
URL: maps.googleapis.com/maps/api/mapsjs/gen_204?csp_test=true
```

### التشخيص:
**متصفح Comet (من Perplexity)** يحتوي على **مانع إعلانات مدمج** يحجب طلبات Google Maps API.

### ما تم تجربته:
- إضافة `wawapp-952d6.web.app` لقائمة "Allow ads on these sites" في Comet → **لم ينفع**
- السبب: قائمة الاستثناءات تستثني الإعلانات المعروضة على الموقع، لكنها لا تستثني الطلبات الصادرة إلى نطاقات محظورة مثل `googleapis.com`

---

## الخلاصة

| العنصر | الحالة |
|--------|--------|
| Google Cloud Billing | ✅ مفعّل ومربوط |
| Maps JavaScript API | ✅ مفعّل |
| API Key + Restrictions | ✅ صحيح |
| الكود (Frontend) | ✅ سليم |
| المتصفح (Comet Ad Blocker) | ❌ يحجب googleapis.com |

**المشكلة ليست في الكود ولا في إعدادات Google Cloud. المشكلة في مانع الإعلانات المدمج في متصفح Comet.**

---

## الحلول

1. **استخدام Chrome/Edge/Firefox** لفتح لوحة الإدارة (الأبسط والأضمن)
2. **تعطيل Ad Blocker بالكامل** في Comet (Settings → Privacy → Blocking → إيقاف التبديل)
3. **حل برمجي:** إضافة كشف تلقائي لفشل تحميل الخريطة مع رسالة تنبيه للمستخدم
