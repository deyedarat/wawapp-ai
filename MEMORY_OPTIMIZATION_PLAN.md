# خطة تحسين استهلاك الذاكرة - WawApp

**التاريخ:** 2025-12-31
**الحالة الحالية:**
- 📱 Driver App: **222MB** (الهدف: <150MB) → تخفيض 72MB
- 📱 Client App: **288MB** (الهدف: <150MB) → تخفيض 138MB

**الهدف:** الوصول لـ <150MB لكل تطبيق

---

## 📊 ملخص الفرص

| المصدر | Driver App | Client App | الأولوية |
|--------|-----------|-----------|----------|
| صور غير مضغوطة | - | 15-25MB | 🔴 عالية |
| خرائط Google | 20-30MB | 40-60MB | 🔴 عالية |
| Firebase غير مستخدم | 15-20MB | 15-20MB | 🟡 متوسطة |
| Location Tracking | 10-15MB | - | 🟡 متوسطة |
| Streams/Providers | 5-10MB | 5-10MB | 🟢 منخفضة |

**المجموع المتوقع:** 50-75MB (Driver) | 75-115MB (Client)

---

## 🎯 Phase 1: إصلاحات سريعة (وقت التنفيذ: ساعتان)

### 1.1 ضغط الصور (Client App فقط)
**التوفير المتوقع:** 15-25MB

#### الملفات المستهدفة:
```
apps/wawapp_client/assets/icons/
├── splash_client_bg.png (1.6MB) → WebP (200KB)
├── splash_client_logo.png (1.4MB) → SVG or WebP (150KB)
├── wawapp_client_1024.png (1.7MB) → WebP (220KB)
└── wawapp_client_adaptive_bg.png (465KB) → WebP (80KB)
```

#### الخطوات:
```bash
# 1. تحويل للـ WebP
cd apps/wawapp_client/assets/icons
cwebp -q 85 splash_client_bg.png -o splash_client_bg.webp
cwebp -q 85 splash_client_logo.png -o splash_client_logo.webp
cwebp -q 85 wawapp_client_1024.png -o wawapp_client_1024.webp
cwebp -q 85 wawapp_client_adaptive_bg.png -o wawapp_client_adaptive_bg.webp

# 2. حذف النسخ القديمة (PNG)
rm *.png

# 3. تحديث الكود للإشارة للملفات الجديدة
```

#### تعديلات الكود:
**ملف:** `apps/wawapp_client/lib/main.dart` (أو حيث يتم استخدام splash)
```dart
// قبل:
Image.asset('assets/icons/splash_client_bg.png')

// بعد:
Image.asset('assets/icons/splash_client_bg.webp')
```

---

### 1.2 حذف Firebase Dependencies غير المستخدمة
**التوفير المتوقع:** 15-20MB لكل تطبيق

#### Driver App:
**ملف:** `apps/wawapp_driver/pubspec.yaml`

```yaml
# احذف السطور التالية:
# Line 28:
# firebase_dynamic_links: ^6.1.10  # ← احذف هذا السطر

# بديل remote_config (اختياري):
# Line 29:
# firebase_remote_config: ^5.5.0  # ← استخدام محدود جداً
```

**الأثر:** يستخدم فقط في `tracking_service.dart:294` - يمكن استبداله بـ hardcoded config.

#### Client App:
**ملف:** `apps/wawapp_client/pubspec.yaml`

```yaml
# احذف:
# Line 30:
# firebase_dynamic_links: ^6.1.10  # ← غير مستخدم نهائياً
```

#### الخطوات:
```bash
# 1. عدل pubspec.yaml
# 2. نظف التبعيات
cd apps/wawapp_driver
flutter pub get
cd ../wawapp_client
flutter pub get
```

---

### 1.3 تحسين Location Tracking (Driver App)
**التوفير المتوقع:** 10-15MB

**ملف:** `apps/wawapp_driver/lib/services/location_service.dart`

#### التغيير 1: زيادة distanceFilter (Line ~150)
```dart
// قبل:
distanceFilter: 10,  // تحديث كل 10 متر (كثير جداً)

// بعد:
distanceFilter: 50,  // تحديث كل 50 متر (أفضل)
```

#### التغيير 2: حذف Timer الزائد
**ملف:** `apps/wawapp_driver/lib/services/tracking_service.dart`

```dart
// احذف Lines 197-216:
// _updateTimer = Timer.periodic(Duration(seconds: _updateIntervalSeconds * 3), (_) async {
//   ... كل هذا الكود الزائد
// });

// السبب: يوجد position stream نشط بالفعل - لا حاجة للـ Timer
```

---

## 🗺️ Phase 2: تحسينات الخرائط (وقت التنفيذ: 3-4 ساعات)

### 2.1 تحديد حجم Marker Cache (Client App)
**التوفير المتوقع:** 20-30MB

**ملف:** `apps/wawapp_client/lib/features/map/providers/district_layer_provider.dart`

#### التغيير 1: إضافة حد أقصى للـ cache (Line 9)
```dart
// قبل:
final Map<String, Set<Marker>> _markerCache = {};

// بعد:
final Map<String, Set<Marker>> _markerCache = {};
static const int _maxCacheSize = 5; // احتفظ بـ 5 zoom levels فقط
```

#### التغيير 2: تطبيق LRU eviction (بعد Line 64)
```dart
// أضف بعد Line 64:
void _evictOldCacheIfNeeded() {
  if (_markerCache.length > _maxCacheSize) {
    // احذف الأقدم (first key)
    _markerCache.remove(_markerCache.keys.first);
  }
}

// ثم استدعِ في getMarkersForZoom():
_evictOldCacheIfNeeded();
```

---

### 2.2 تعطيل ميزات الخريطة غير الضرورية
**التوفير المتوقع:** 10-15MB

**ملف:** `apps/wawapp_client/lib/features/map/map_picker_screen.dart`

#### Lines 224-226:
```dart
// قبل:
myLocationEnabled: true,  // يستهلك موارد
myLocationButtonEnabled: false,
// compassEnabled: غير موجود (enabled افتراضياً)

// بعد:
myLocationEnabled: false,  // عطّل - نستخدم custom marker
myLocationButtonEnabled: false,
compassEnabled: false,  // أضف هذا السطر
```

---

### 2.3 تبسيط Polyline Rendering
**التوفير المتوقع:** 5-10MB

**ملف:** `apps/wawapp_client/lib/features/track/widgets/order_tracking_view.dart`

#### Line 62 (في الـ Polyline):
```dart
// قبل:
patterns: [PatternItem.dash(20), PatternItem.gap(10)],  // يستهلك ذاكرة إضافية

// بعد:
// احذف السطر بالكامل - استخدم خط متصل solid
```

**السبب:** الخطوط المتقطعة (dashed) تستهلك ذاكرة أكثر من الخطوط المتصلة.

---

### 2.4 تأخير رسم Polygons حتى Zoom مناسب
**التوفير المتوقع:** 10-15MB

**ملف:** `apps/wawapp_client/lib/features/map/providers/district_layer_provider.dart`

#### أضف شرط Zoom Level (Lines 18-30):
```dart
Future<Set<Marker>> getMarkersForZoom(double zoom, String languageCode) async {
  // أضف هذا الشرط:
  if (zoom < 10) {
    // لا ترسم districts في zoom بعيد
    return {};
  }

  final cacheKey = '${zoom}_$languageCode';
  // ... باقي الكود
}
```

---

## 🧹 Phase 3: تنظيف Streams & Providers (وقت التنفيذ: ساعة واحدة)

### 3.1 تحسين PostFrameCallback (Client App)
**التوفير المتوقع:** 3-5MB

**ملف:** `apps/wawapp_client/lib/features/track/widgets/order_tracking_view.dart`

#### Line 295:
```dart
// قبل:
WidgetsBinding.instance.addPostFrameCallback((_) {
  // يتم استدعاؤه على كل build - هدر موارد
});

// بعد:
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // يتم استدعاؤه مرة واحدة فقط
  });
}
```

---

### 3.2 زيادة عتبة Distance Calculations
**التوفير المتوقع:** 2-3MB

**ملف:** `apps/wawapp_client/lib/features/track/widgets/order_tracking_view.dart`

#### Lines 159-167:
```dart
// قبل:
if (distance < 50) return;  // تحقق كل 50 متر

// بعد:
if (distance < 100) return;  // تحقق كل 100 متر (نصف التحديثات)
```

---

## 📋 خطة التنفيذ المقترحة

### اليوم 1 (ساعتان):
```bash
# Phase 1: Quick Wins
1. ضغط الصور (Client) → flutter pub get → test
2. حذف firebase_dynamic_links (both apps) → flutter pub get
3. تحسين location tracking (Driver) → test
```

**التوفير المتوقع:** 40-60MB إجمالاً

---

### اليوم 2 (4 ساعات):
```bash
# Phase 2: Map Optimizations
1. تحديد Marker cache (Client)
2. تعطيل map features (Client)
3. تبسيط polylines (Client)
4. تأخير polygons (Client)
```

**التوفير المتوقع:** 45-70MB (Client فقط)

---

### اليوم 3 (ساعة):
```bash
# Phase 3: Stream Cleanup
1. تحسين PostFrameCallback (Client)
2. زيادة distance threshold (Client)
3. Build & Test final APKs
```

**التوفير المتوقع:** 5-8MB

---

## 🧪 الاختبار بعد كل Phase

### قياس استهلاك الذاكرة:

#### على Android:
```bash
# 1. بناء APK
flutter build apk --release

# 2. تثبيت على جهاز
adb install build/app/outputs/flutter-apk/app-release.apk

# 3. قياس الذاكرة
adb shell dumpsys meminfo com.wawapp.driver | grep TOTAL
adb shell dumpsys meminfo com.wawapp.client | grep TOTAL
```

#### النتيجة المستهدفة:
```
Driver: TOTAL PSS: ~135000 KB (135MB)
Client: TOTAL PSS: ~145000 KB (145MB)
```

---

## 📊 جدول التوفير المتوقع

| Phase | Driver App | Client App | الوقت |
|-------|-----------|-----------|-------|
| **Phase 1** | -25 to -35MB | -30 to -45MB | 2h |
| **Phase 2** | -20 to -30MB | -45 to -70MB | 4h |
| **Phase 3** | -5 to -10MB | -5 to -8MB | 1h |
| **المجموع** | **-50 to -75MB** | **-80 to -123MB** | **7h** |

### النتيجة النهائية:
- **Driver:** 222MB → **147-172MB** ✅ (الهدف: <150MB)
- **Client:** 288MB → **165-208MB** ⚠️ (قد نحتاج تحسينات إضافية)

---

## ⚠️ مخاطر محتملة

### 1. ضغط الصور (Low Risk)
- **المشكلة:** قد تفقد الصور بعض الجودة
- **الحل:** استخدم quality 85-90 في cwebp
- **الاختبار:** راجع الصور بصرياً قبل الحذف

### 2. حذف firebase_dynamic_links (Low Risk)
- **المشكلة:** قد تكون مخطط لاستخدامه مستقبلاً
- **الحل:** يمكن إضافته لاحقاً إذا احتجت
- **الاختبار:** ابحث في الكود عن استخدامات (grep)

### 3. زيادة distanceFilter (Medium Risk)
- **المشكلة:** قد تقلل دقة tracking
- **الحل:** ابدأ بـ 30m بدلاً من 50m
- **الاختبار:** جرّب في رحلة حقيقية

### 4. تحديد Marker Cache (Low Risk)
- **المشكلة:** قد تحتاج إعادة رسم markers أحياناً
- **الحل:** استخدم LRU للاحتفاظ بالأكثر استخداماً
- **الاختبار:** zoom in/out بسرعة وراقب الأداء

---

## 🔍 تحليل إضافي (إذا لم تكفِ التحسينات)

### خيارات متقدمة:

1. **استخدام Flutter DevTools Profiler:**
   ```bash
   flutter run --profile
   # افتح DevTools → Memory tab
   # خذ snapshot وراجع أكبر الكائنات
   ```

2. **Lazy Loading للـ Firebase Services:**
   - تحميل Analytics/Crashlytics فقط عند الحاجة
   - استخدام Deferred Components

3. **تقليل Map Instances:**
   - استخدام single map controller مشترك
   - إعادة استخدام بدلاً من إنشاء instances جديدة

4. **Image Caching Limits:**
   - تحديد حجم `imageCache.maximumSize`
   - استخدام `CachedNetworkImage` مع size limits

---

## ✅ Checklist التنفيذ

### Phase 1:
- [ ] ضغط splash_client_bg.png → WebP
- [ ] ضغط splash_client_logo.png → WebP
- [ ] ضغط wawapp_client_1024.png → WebP
- [ ] حذف firebase_dynamic_links (Driver)
- [ ] حذف firebase_dynamic_links (Client)
- [ ] زيادة distanceFilter إلى 50m (Driver)
- [ ] حذف redundant Timer (Driver tracking_service.dart)

### Phase 2:
- [ ] إضافة _maxCacheSize للـ marker cache
- [ ] تطبيق LRU eviction
- [ ] تعطيل myLocationEnabled
- [ ] تعطيل compassEnabled
- [ ] حذف dashed polyline patterns
- [ ] إضافة zoom level check للـ polygons

### Phase 3:
- [ ] نقل PostFrameCallback إلى initState
- [ ] زيادة distance threshold إلى 100m
- [ ] Build & Test

### Testing:
- [ ] قياس Driver memory: target <150MB
- [ ] قياس Client memory: target <150MB
- [ ] اختبار visual للصور المضغوطة
- [ ] اختبار tracking accuracy
- [ ] اختبار map rendering performance

---

**الخلاصة:**
- Phase 1 وحده قد يحل المشكلة للـ Driver App
- Client App يحتاج Phase 1 + 2 للوصول للهدف
- Phase 3 اختياري لتحسين إضافي

**الوقت الإجمالي:** 6-8 ساعات عمل
**الأولوية:** متوسطة (بعد P0-AUTH-1 الذي تم حله)
