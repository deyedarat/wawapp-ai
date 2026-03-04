# Google Maps Setup - تطبيق السائق

## نظرة عامة
تم إضافة خرائط Google Maps إلى شاشة الطلب النشط لعرض موقع الالتقاط والتوصيل مع مسار التوجيه.

## متطلبات الإعداد

### 1. الحصول على مفتاح API من Google Cloud Console

1. اذهب إلى [Google Cloud Console](https://console.cloud.google.com/)
2. اختر المشروع أو أنشئ مشروع جديد
3. من القائمة الجانبية، اختر **APIs & Services** > **Credentials**
4. انقر على **Create Credentials** > **API Key**
5. سيتم إنشاء مفتاح API جديد

### 2. تفعيل الـ APIs المطلوبة

من صفحة **APIs & Services** > **Library**، قم بتفعيل:

- **Maps SDK for Android**
- **Maps SDK for iOS**
- **Directions API** (للتوجيه)
- **Geocoding API** (لتحويل العناوين)

### 3. تقييد المفتاح (Restrict API Key)

من أجل الأمان، قم بتقييد كل مفتاح:

#### لـ Android:
1. اختر **Android apps** من Application restrictions
2. أضف package name: `com.wawappmr.driver`
3. أضف SHA-1 certificate fingerprints (للتطوير والإنتاج)
4. احصر API restrictions على: Maps SDK for Android, Directions API, Geocoding API

#### لـ iOS:
1. اختر **iOS apps** من Application restrictions
2. أضف Bundle ID: `com.wawappmr.driver`
3. احصر API restrictions على: Maps SDK for iOS, Directions API, Geocoding API

### 4. إضافة المفتاح للتطبيق

#### Android:
الملف موجود بالفعل: `android/app/src/main/res/values/api_keys.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="google_maps_api_key">YOUR_ANDROID_GOOGLE_MAPS_API_KEY</string>
</resources>
```

#### iOS:
تم إضافة المفتاح إلى `ios/Runner/Info.plist`:

```xml
<key>GMSApiKey</key>
<string>YOUR_IOS_GOOGLE_MAPS_API_KEY</string>
```

استبدل `YOUR_IOS_GOOGLE_MAPS_API_KEY` بمفتاحك الفعلي.

## الميزات المضافة

### شاشة الطلب النشط (ActiveOrderScreen)

1. **خريطة تفاعلية**:
   - تعرض نقطة الالتقاط (ماركر أخضر)
   - تعرض نقطة التوصيل (ماركر أحمر)
   - خط مسار بين النقطتين
   - عرض الموقع الحالي للسائق
   - تكبير تلقائي لإظهار كلا النقطتين

2. **أزرار الاتصال والتوجيه**:
   - زر الاتصال بالعميل (يحتاج ربط برقم العميل)
   - أزرار لفتح الخرائط الخارجية (Google Maps) لكل نقطة

3. **تفاصيل الطلب**:
   - معلومات الطلب
   - العناوين
   - المسافة والسعر
   - الحالة الحالية

## الأذونات المطلوبة

### Android (موجودة بالفعل في AndroidManifest.xml):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
```

### iOS (تمت إضافتها إلى Info.plist):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>نحتاج إلى موقعك لإظهار الطلبات القريبة وتوجيهك للعملاء</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>نحتاج إلى موقعك في الخلفية لتتبع الرحلات واستقبال الطلبات</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>نحتاج إلى موقعك في الخلفية لتتبع الرحلات واستقبال الطلبات</string>
```

## اختبار التكامل

1. تأكد من إضافة مفاتيح API الصحيحة
2. قم بتشغيل التطبيق
3. سجل دخول كسائق وانتقل إلى الصفحة الرئيسية
4. اذهب إلى "الطلبات القريبة" واقبل طلباً
5. في شاشة الطلب النشط، يجب أن ترى:
   - خريطة تعرض موقع الالتقاط والتوصيل
   - أزرار للتوجيه والاتصال

## المهام المستقبلية

- [ ] ربط زر الاتصال بالعميل برقم هاتف العميل من Firestore
- [ ] إضافة تقييم العميل بعد إتمام الرحلة
- [ ] إضافة مسار توجيه حقيقي باستخدام Directions API
- [ ] تحديث موقع السائق الحالي على الخريطة في الوقت الفعلي
