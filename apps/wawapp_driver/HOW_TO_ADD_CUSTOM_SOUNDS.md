# 🔊 كيفية إضافة أصوات مخصصة للإشعارات

## الخطوات

### 1. تحضير ملفات الصوت

احصل على ملفات `.wav` بالمواصفات التالية:
- **Format:** WAV
- **Sample Rate:** 44100 Hz أو 48000 Hz
- **Bit Depth:** 16-bit
- **Channels:** Mono أو Stereo
- **Duration:** 1-3 ثواني

### 2. تسمية الملفات

أنشئ 3 ملفات صوت بالأسماء التالية:
```
new_order_alert.wav       - صوت حاد ومزعج للطلبات الجديدة
trip_start_warning.wav    - صوت تحذيري قوي لتذكير بدء الرحلة
order_update_soft.wav     - صوت هادئ للتحديثات العامة
```

### 3. وضع الملفات في المجلد الصحيح

ضع الملفات في:
```
apps/wawapp_driver/android/app/src/main/res/raw/
```

المجلد يحتوي حالياً على:
```
apps/wawapp_driver/android/app/src/main/res/raw/
├── trip_reminder.wav          (موجود)
├── new_order_alert.wav        (أضفه)
├── trip_start_warning.wav     (أضفه)
└── order_update_soft.wav      (أضفه)
```

### 4. تحديث الكود

افتح الملف:
```
apps/wawapp_driver/lib/services/notification_service.dart
```

#### ابحث عن السطر 67:
```dart
sound: RawResourceAndroidNotificationSound('trip_reminder'), // TODO: new_order_alert
```

**غيّره إلى:**
```dart
sound: RawResourceAndroidNotificationSound('new_order_alert'),
```

#### ابحث عن السطر 79:
```dart
sound: RawResourceAndroidNotificationSound('trip_reminder'), // TODO: new_order_alert
```

**غيّره إلى:**
```dart
sound: RawResourceAndroidNotificationSound('new_order_alert'),
```

#### ابحث عن السطر 91:
```dart
sound: RawResourceAndroidNotificationSound('trip_reminder'), // TODO: order_update_soft
```

**غيّره إلى:**
```dart
sound: RawResourceAndroidNotificationSound('order_update_soft'),
```

#### ابحث عن السطر 114:
```dart
sound: RawResourceAndroidNotificationSound('trip_reminder'), // TODO: trip_start_warning
```

**غيّره إلى:**
```dart
sound: RawResourceAndroidNotificationSound('trip_start_warning'),
```

#### ابحث عن السطر 276:
```dart
sound: const RawResourceAndroidNotificationSound('trip_reminder'), // TODO: trip_start_warning
```

**غيّره إلى:**
```dart
sound: const RawResourceAndroidNotificationSound('trip_start_warning'),
```

### 5. إعادة البناء

بعد إضافة الملفات وتحديث الكود، قم بما يلي:

```bash
cd apps/wawapp_driver
flutter clean
flutter pub get
flutter build apk
```

### 6. الاختبار

جرّب الإشعارات المختلفة وتأكد من الأصوات:
- طلب جديد → `new_order_alert.wav`
- تذكير بدء الرحلة → `trip_start_warning.wav`
- تحديث طلب → `order_update_soft.wav`

---

## 🎵 مصادر أصوات مجانية

### مواقع موصى بها:
1. **Freesound.org** - https://freesound.org
   - ابحث: "notification alert", "warning beep", "soft chime"

2. **Zapsplat** - https://www.zapsplat.com
   - قسم: Notification & Alert Sounds

3. **Mixkit** - https://mixkit.co/free-sound-effects/
   - أصوات notification جاهزة

### أدوات تحويل الصيغ:
إذا حصلت على ملفات MP3 أو OGG:
- **FFmpeg** (command line):
  ```bash
  ffmpeg -i input.mp3 -acodec pcm_s16le -ar 44100 output.wav
  ```
- **Audacity** (برنامج مجاني): https://www.audacityteam.org/
- **Online Audio Converter**: https://online-audio-converter.com/

---

## ⚠️ ملاحظات مهمة

1. **أسماء الملفات:**
   - يجب أن تكون lowercase فقط
   - لا تستخدم spaces أو أحرف خاصة
   - استخدم underscores `_` فقط

2. **حجم الملفات:**
   - حاول ألا تتجاوز 100KB لكل ملف
   - الأصوات القصيرة (1-2 ثانية) كافية

3. **الاختبار:**
   - اختبر على جهاز حقيقي (ليس emulator)
   - تأكد من مستوى الصوت في الجهاز

4. **إعادة التثبيت:**
   - قد تحتاج لحذف التطبيق وإعادة تثبيته لضمان تطبيق التغييرات
   - أو استخدم: `flutter clean && flutter run`

---

## ✅ Checklist

- [ ] تحميل/إنشاء 3 ملفات WAV
- [ ] تسمية الملفات بالأسماء الصحيحة
- [ ] وضع الملفات في `res/raw/`
- [ ] تحديث الكود في `notification_service.dart` (5 أماكن)
- [ ] تشغيل `flutter clean`
- [ ] تشغيل `flutter pub get`
- [ ] إعادة البناء والتثبيت
- [ ] اختبار كل نوع إشعار

---

## 🆘 في حالة المشاكل

### المشكلة: الصوت لا يعمل
- ✅ تأكد من أن اسم الملف صحيح تماماً (lowercase)
- ✅ تأكد من أن الملف في المجلد الصحيح
- ✅ حذف التطبيق وإعادة تثبيته
- ✅ تأكد من أن صوت الجهاز غير muted

### المشكلة: build error
- ✅ تأكد من صيغة الملف WAV صحيحة
- ✅ جرّب تحويل الملف بـ Audacity
- ✅ تأكد من عدم وجود spaces في الاسم

### المشكلة: الصوت مشوش
- ✅ حوّل الملف إلى 44100 Hz, 16-bit, Mono
- ✅ استخدم ملف أقصر (1-2 ثانية)
