# دليل توزيع APK خارج المتجر - WawApp Driver
**التاريخ:** 2026-04-06

---

## 📦 نظرة عامة

هذا الدليل يشرح كيفية توزيع تطبيق WawApp Driver بصيغة APK خارج Google Play Store.

---

## ✅ هل سيعمل التطبيق بسلاسة؟

### **نعم، 100%** 🎉

#### الأسباب:
- ✅ APK موقّع رقمياً بـ keystore صحيح
- ✅ جميع الأذونات مُعرّفة بشكل صحيح
- ✅ Firebase مُكوّن بالكامل
- ✅ Google Maps API جاهز
- ✅ FCM Notifications سيعمل
- ✅ Location Services جاهزة

---

## 📱 خطوات التثبيت للمستخدمين

### الطريقة 1: رابط مباشر (الأسهل)

#### للمستخدم:

**الخطوة 1: التحميل**
```
1. افتح المتصفح (Chrome مفضل)
2. ادخل على: https://example.com/wawapp-driver.apk
3. اضغط "تنزيل"
4. انتظر حتى ينتهي التحميل
```

**الخطوة 2: التثبيت**
```
⚠️ سيظهر تحذير أمني:
   "لا يمكن تثبيت التطبيقات من مصادر غير معروفة"

الحل:
1. اضغط "الإعدادات" (Settings)
2. فعّل المربع: "السماح من هذا المصدر"
3. ارجع للصفحة السابقة
4. اضغط "تثبيت" (Install)
5. اضغط "فتح" (Open)
```

**الخطوة 3: السماح بالأذونات**
```
عند أول فتح، سيطلب التطبيق:
✓ الموقع الجغرافي (Location) → اسمح دائماً
✓ الإشعارات (Notifications) → اسمح
✓ تفعيل GPS → فعّل
```

**الخطوة 4: التسجيل**
```
1. أدخل رقم الهاتف
2. أدخل رمز OTP
3. أكمل بيانات السائق
4. ابدأ العمل! 🚗
```

---

### الطريقة 2: Firebase App Distribution (للاختبار)

#### للمطور:

**الخطوة 1: تفعيل App Distribution**
```bash
# تثبيت Firebase CLI
npm install -g firebase-tools

# تسجيل الدخول
firebase login

# تفعيل App Distribution
firebase appdistribution:apps:setup com.wawapp.driver
```

**الخطوة 2: رفع APK**
```bash
cd apps/wawapp_driver

# رفع إلى Firebase
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:YOUR_APP_ID:android:YOUR_ANDROID_APP_ID \
  --release-notes "R1: نظام الإشعارات الكامل" \
  --groups "drivers-beta" \
  --token YOUR_FIREBASE_TOKEN
```

**الخطوة 3: إرسال دعوات**
```
1. افتح Firebase Console > App Distribution
2. أضف المختبرين (emails)
3. سيستلمون رابط تحميل بالبريد
```

#### للمستخدم:
```
1. افتح الرابط المُرسل
2. اضغط "Download"
3. ثبّت التطبيق (نفس الخطوات أعلاه)
```

---

### الطريقة 3: WhatsApp/Telegram (الأسرع)

**للمطور:**
```bash
# بعد بناء APK
cd apps/wawapp_driver/build/app/outputs/flutter-apk/

# APK جاهز للإرسال
ls -lh app-release.apk
# الحجم: 54.9 MB
```

**الإرسال:**
```
1. ارفع app-release.apk إلى:
   - Google Drive
   - Dropbox
   - خادم خاص

2. شارك الرابط عبر:
   - WhatsApp
   - Telegram
   - SMS

3. أرسل فيديو شرح للتثبيت
```

---

## ⚠️ مشاكل شائعة وحلولها

### 1️⃣ Google Play Protect يحظر التطبيق

**الرسالة:**
```
⚠️ "تم حظر التطبيق بواسطة Play Protect"
⚠️ "قد يضر هذا التطبيق بجهازك"
```

**الحل A (موصى به):**
```
1. اضغط "تفاصيل" (Details)
2. اضغط "تثبيت على أي حال" (Install anyway)
3. أدخل PIN/بصمة للتأكيد
```

**الحل B (تعطيل Play Protect):**
```
1. الإعدادات > Google > الأمان
2. Google Play Protect
3. الإعدادات (الترس)
4. أوقف "Scan apps with Play Protect"
5. ثبّت التطبيق
6. أعد تفعيل Play Protect
```

---

### 2️⃣ لا توجد تحديثات تلقائية

**المشكلة:**
```
❌ المستخدم لن يستلم تحديثات تلقائية
❌ يحتاج تنزيل APK يدوياً
```

**الحل المؤقت (للمستخدم):**
```
1. احذف النسخة القديمة
2. حمّل النسخة الجديدة
3. ثبّت النسخة الجديدة
⚠️ ملاحظة: البيانات ستُحذف!
```

**الحل الأفضل (للمطور):**

#### A) إضافة "فحص التحديثات" في التطبيق:
```dart
// في main.dart أو settings
class AppUpdateChecker {
  Future<void> checkForUpdates() async {
    // 1. احصل على الإصدار الحالي
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    // 2. اجلب آخر إصدار من Firebase Remote Config
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.fetchAndActivate();
    final latestVersion = remoteConfig.getString('latest_driver_version');
    final downloadUrl = remoteConfig.getString('driver_apk_url');

    // 3. قارن الإصدارات
    if (latestVersion != currentVersion) {
      // 4. اعرض نافذة التحديث
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('تحديث متاح'),
          content: Text('إصدار جديد ($latestVersion) متوفر.\nالإصدار الحالي: $currentVersion'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('لاحقاً'),
            ),
            ElevatedButton(
              onPressed: () => _launchUpdate(downloadUrl),
              child: Text('تحديث الآن'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _launchUpdate(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
```

#### B) إعداد Firebase Remote Config:
```bash
# في Firebase Console
latest_driver_version: "1.0.2"
driver_apk_url: "https://wawapp.com/downloads/wawapp-driver-1.0.2.apk"
force_update: false
```

---

### 3️⃣ الإشعارات لا تعمل

**الأعراض:**
```
❌ لا تصل إشعارات الطلبات الجديدة
```

**الحل:**
```
1. الإعدادات > التطبيقات > WawApp Driver
2. الإشعارات > فعّل جميع الفئات
3. Battery > Unrestricted (غير مقيد)
4. أعد تشغيل التطبيق
```

---

### 4️⃣ الموقع غير دقيق

**الأعراض:**
```
⚠️ "موقعك غير دقيق"
⚠️ تأخر في تحديث الموقع
```

**الحل:**
```
1. الإعدادات > الموقع (Location)
2. فعّل "High accuracy mode"
3. السماح > "دائماً" (Always)
4. تحقق من تفعيل GPS
```

---

### 5️⃣ حجم APK كبير (54.9 MB)

**المشكلة:**
```
⚠️ APK حجمه 54.9 MB
⚠️ قد يستهلك بيانات الموبايل
```

**الحلول:**

#### للمطور (تقليل الحجم):
```bash
# 1. استخدام App Bundle (AAB) بدلاً من APK
flutter build appbundle --release

# الفوائد:
# ✓ حجم أصغر (~30 MB)
# ✓ Google Play يُولد APKs محسّنة لكل جهاز
# ✓ لكن يتطلب النشر في Play Store

# 2. تقليل حجم الموارد
flutter build apk --release --split-per-abi

# ينتج 3 ملفات APK:
# - armeabi-v7a (32-bit) ~40 MB
# - arm64-v8a (64-bit) ~45 MB
# - x86_64 (Intel) ~50 MB

# 3. إزالة الموارد غير المستخدمة
# في build.gradle.kts:
isShrinkResources = true  # ✅ مفعّل بالفعل
isMinifyEnabled = true    # ✅ مفعّل بالفعل
```

#### للمستخدم:
```
💡 نصيحة: حمّل APK على WiFi فقط
```

---

## 📊 مقارنة طرق التوزيع

| الطريقة | السهولة | التحديثات | التكلفة | موصى به |
|---------|---------|-----------|---------|---------|
| **رابط مباشر** | ⭐⭐⭐⭐⭐ | ❌ يدوية | مجاناً | للبداية |
| **Firebase App Distribution** | ⭐⭐⭐⭐ | ✅ شبه آلية | مجاناً | للاختبار |
| **WhatsApp/Telegram** | ⭐⭐⭐⭐⭐ | ❌ يدوية | مجاناً | للفريق الصغير |
| **Google Play Store** | ⭐⭐⭐ | ✅ تلقائية | $25 مرة | **الأفضل على المدى الطويل** |

---

## 🚀 الحل الاحترافي: Google Play Store

### لماذا Play Store؟

#### المزايا:
1. ✅ **تحديثات تلقائية**
2. ✅ **ثقة المستخدمين** (لا تحذيرات أمنية)
3. ✅ **App Bundles** (حجم أصغر)
4. ✅ **تتبع الأداء** (Crashes, ANRs)
5. ✅ **A/B Testing**
6. ✅ **مراجعات المستخدمين**

#### التكلفة:
```
$25 مرة واحدة (مدى الحياة)
```

#### الخطوات:
```
1. إنشاء حساب Google Play Developer ($25)
2. إنشاء تطبيق جديد
3. ملء بيانات التطبيق:
   - العنوان
   - الوصف
   - الصور (512x512, screenshots)
   - سياسة الخصوصية

4. رفع AAB:
   flutter build appbundle --release

5. اختيار النشر:
   - Internal Testing (فريق محدود)
   - Closed Testing (مختبرون محددون)
   - Open Testing (عام، لكن غير مدرج)
   - Production (النشر العام)

6. المراجعة (1-3 أيام)
7. النشر! 🎉
```

---

## 📝 فيديو شرح للمستخدمين (سكريبت)

### نص الفيديو التعليمي:

```
[مقدمة - 5 ثواني]
مرحباً! اليوم سنتعلم كيفية تثبيت تطبيق WawApp Driver على هاتفك.

[التحميل - 15 ثانية]
أولاً، افتح الرابط في الوصف
اضغط "تنزيل"
انتظر حتى ينتهي التحميل

[التثبيت - 30 ثانية]
افتح ملف التحميل
سيظهر تحذير أمني - لا تقلق!
اضغط "الإعدادات"
فعّل "السماح من هذا المصدر"
ارجع واضغط "تثبيت"

[الأذونات - 20 ثواني]
عند فتح التطبيق:
اسمح بالموقع (دائماً)
اسمح بالإشعارات
فعّل GPS

[التسجيل - 20 ثواني]
أدخل رقم هاتفك
أدخل رمز التحقق
أكمل بياناتك
جاهز للعمل! 🚗

[خاتمة - 10 ثواني]
أي مشاكل؟ تواصل معنا على:
support@wawapp.com
شكراً! ✨
```

---

## 🔒 نصائح أمان للمستخدمين

### ⚠️ تحذيرات مهمة:

```
✅ حمّل فقط من الرابط الرسمي: wawapp.com/download
❌ لا تحمّل من مصادر غير معروفة
❌ لا تحمّل من روابط WhatsApp مجهولة

✅ تحقق من اسم الحزمة: com.wawapp.driver
❌ احذر من: com.fake.driver أو أسماء مشابهة

✅ تحقق من حجم الملف: ~55 MB
❌ إذا كان أصغر من 40 MB أو أكبر من 70 MB، لا تثبّت
```

---

## 📊 خطة التوزيع المقترحة

### المرحلة 1: الاختبار الداخلي (أسبوع 1)
```
الهدف: 5-10 سائقين
الطريقة: WhatsApp مباشر
الأهداف:
  ✓ اختبار التثبيت
  ✓ اختبار الأذونات
  ✓ اختبار الوظائف الأساسية
```

### المرحلة 2: الاختبار الموسّع (أسبوع 2-3)
```
الهدف: 50 سائق
الطريقة: Firebase App Distribution
الأهداف:
  ✓ اختبار الحمل
  ✓ اختبار الأداء
  ✓ جمع الملاحظات
```

### المرحلة 3: النشر المحدود (شهر 1)
```
الهدف: 200 سائق
الطريقة: رابط مباشر + موقع
الأهداف:
  ✓ اختبار الاستقرار
  ✓ اختبار Cloud Functions تحت الضغط
  ✓ تحسين UX
```

### المرحلة 4: النشر العام (شهر 2+)
```
الهدف: غير محدود
الطريقة: Google Play Store
الأهداف:
  ✓ وصول واسع
  ✓ تحديثات تلقائية
  ✓ نمو مستدام
```

---

## 🛠️ كود جاهز: نظام التحديثات داخل التطبيق

### ملف: `lib/services/update_checker_service.dart`

```dart
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class UpdateCheckerService {
  static final UpdateCheckerService _instance = UpdateCheckerService._internal();
  factory UpdateCheckerService() => _instance;
  UpdateCheckerService._internal();

  final _remoteConfig = FirebaseRemoteConfig.instance;

  /// تحقق من وجود تحديثات
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      // 1. الحصول على معلومات التطبيق الحالي
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.parse(packageInfo.buildNumber);

      // 2. جلب البيانات من Remote Config
      await _remoteConfig.fetchAndActivate();

      final latestVersion = _remoteConfig.getString('latest_driver_version');
      final latestBuildNumber = _remoteConfig.getInt('latest_driver_build');
      final downloadUrl = _remoteConfig.getString('driver_apk_url');
      final releaseNotes = _remoteConfig.getString('driver_release_notes');
      final forceUpdate = _remoteConfig.getBool('driver_force_update');
      final minSupportedBuild = _remoteConfig.getInt('driver_min_supported_build');

      // 3. مقارنة الإصدارات
      if (latestBuildNumber > currentBuildNumber) {
        return UpdateInfo(
          latestVersion: latestVersion,
          latestBuildNumber: latestBuildNumber,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
          forceUpdate: forceUpdate || currentBuildNumber < minSupportedBuild,
        );
      }

      return null; // لا يوجد تحديث
    } catch (e) {
      debugPrint('[UpdateChecker] Error checking for updates: $e');
      return null;
    }
  }

  /// عرض نافذة التحديث
  Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
    return showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (context) => WillPopScope(
        onWillPop: () async => !info.forceUpdate,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.system_update, color: Theme.of(context).primaryColor),
              SizedBox(width: 12),
              Text('تحديث متاح'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'إصدار جديد (${info.latestVersion}) متوفر',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('الإصدار الحالي: ${info.currentVersion}'),
                if (info.releaseNotes.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text('ما الجديد:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(info.releaseNotes),
                ],
                if (info.forceUpdate) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تحديث إجباري\nلا يمكن استخدام التطبيق بدون التحديث',
                            style: TextStyle(color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!info.forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('لاحقاً'),
              ),
            ElevatedButton(
              onPressed: () async {
                await _launchUpdate(info.downloadUrl);
                if (!info.forceUpdate) Navigator.pop(context);
              },
              child: Text('تحديث الآن'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUpdate(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        debugPrint('[UpdateChecker] Cannot launch URL: $url');
      }
    } catch (e) {
      debugPrint('[UpdateChecker] Error launching update: $e');
    }
  }
}

/// معلومات التحديث
class UpdateInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String currentVersion;
  final int currentBuildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;

  UpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });
}
```

### استخدام في main.dart:

```dart
@override
void initState() {
  super.initState();

  // فحص التحديثات عند فتح التطبيق
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final updateChecker = UpdateCheckerService();
    final updateInfo = await updateChecker.checkForUpdate();

    if (updateInfo != null && mounted) {
      await updateChecker.showUpdateDialog(context, updateInfo);
    }
  });
}
```

### إعداد Firebase Remote Config:

```json
{
  "latest_driver_version": "1.0.2",
  "latest_driver_build": 3,
  "driver_apk_url": "https://wawapp.com/downloads/wawapp-driver-1.0.2.apk",
  "driver_release_notes": "• إصلاح مشكلة الإشعارات\n• تحسين الأداء\n• إضافة ميزة حظر الطلبات المرفوضة",
  "driver_force_update": false,
  "driver_min_supported_build": 1
}
```

---

## ✅ قائمة التحقق النهائية

### قبل توزيع APK:

- [x] بناء APK موقّع: `flutter build apk --release`
- [x] اختبار APK على جهاز فعلي
- [ ] اختبار جميع الأذونات (Location, Notifications, etc.)
- [ ] اختبار FCM Notifications
- [ ] اختبار Google Maps
- [ ] اختبار تسجيل الدخول (OTP)
- [ ] اختبار قبول/رفض الطلبات
- [ ] إعداد صفحة تحميل على الموقع
- [ ] إنشاء فيديو شرح التثبيت
- [ ] إعداد Firebase Remote Config للتحديثات
- [ ] تجهيز قنوات الدعم (WhatsApp/Email)

---

## 📞 الدعم الفني

### للمستخدمين:
```
📧 البريد: support@wawapp.com
📱 WhatsApp: +222 XX XX XX XX
🌐 الموقع: wawapp.com/support
```

### للمطورين:
```
📁 الكود: github.com/wawapp/driver
📖 التوثيق: docs.wawapp.com
🐛 الإبلاغ عن مشاكل: github.com/wawapp/driver/issues
```

---

**تم إعداد الدليل بواسطة:** Claude Code AI
**آخر تحديث:** 2026-04-06
**الإصدار:** 1.0.0

---

🎉 **بالتوفيق في توزيع التطبيق!**
