# 🔧 حل مشكلة تسجيل الخروج التلقائي من لوحة التحكم

## المشكلة
المستخدم يدخل إلى لوحة التحكم ثم يخرج تلقائيًا. السبب: المستخدم ليس لديه **custom claim** اسمه `isAdmin`.

## الحلول المتاحة

### ✅ الحل 1: استخدام Firebase Console (الأسرع والأسهل)

لأن نظام Firebase لا يدعم إضافة custom claims مباشرة من Console، نحتاج لاستخدام أحد الحلول التالية:

---

### ✅ الحل 2: استخدام Cloud Function عبر Firebase CLI

1. **تسجيل الدخول كـ admin مؤقت (Dev Mode)**:

   قم بتعديل ملف البناء مؤقتًا لاستخدام Dev Mode:

   ```bash
   cd apps/wawapp_admin
   flutter build web --release --dart-define=ENVIRONMENT=dev
   firebase deploy --only hosting:admin
   ```

2. **بعد الدخول للوحة التحكم**، استخدم Dev Tools (Console) وقم بتشغيل:

   ```javascript
   // Get Firebase Functions
   const functions = firebase.functions();
   const setAdminRole = functions.httpsCallable('setAdminRole');

   // Get current user UID
   const uid = firebase.auth().currentUser.uid;

   // Set admin role
   setAdminRole({ uid: uid })
     .then(result => console.log('✅ Success:', result.data))
     .catch(error => console.error('❌ Error:', error));
   ```

---

### ✅ الحل 3: استخدام Bootstrap Cloud Function (الموصى به)

تم إنشاء Cloud Function خاصة لإنشاء أول admin:

#### الخطوة 1: تعيين المفتاح السري

```bash
firebase functions:config:set admin.bootstrap_secret="YOUR_STRONG_SECRET_KEY_12345"
```

#### الخطوة 2: إعادة نشر الـ Functions

```bash
cd functions
npm run build
firebase deploy --only functions:bootstrapFirstAdmin
```

#### الخطوة 3: استخدام صفحة Bootstrap

افتح ملف: `scripts/bootstrap_admin.html` في المتصفح، واملأ:

- البريد الإلكتروني: `myadmin@wawapp.co`
- كلمة المرور: `Madmin1234`
- المفتاح السري: نفس المفتاح الذي أضفته في الخطوة 1

---

### ✅ الحل 4: باستخدام Firebase Extensions (الأسهل)

يمكن تثبيت Extension خاص بإدارة Custom Claims من Firebase Marketplace، لكن يتطلب إعداد إضافي.

---

## 🚀 الحل الأسرع (مؤقت للتجربة)

إذا كنت تريد الدخول **الآن** بسرعة للتجربة:

1. **أعد بناء Admin Panel في Dev Mode**:

   ```bash
   cd apps/wawapp_admin
   flutter build web --release --dart-define=ENVIRONMENT=dev
   firebase deploy --only hosting:admin
   ```

   في Dev Mode، لا يتطلب النظام custom claim `isAdmin`.

2. **بعد الانتهاء من التجربة**، أعد البناء في Production Mode:

   ```bash
   flutter build web --release --dart-define=ENVIRONMENT=prod
   firebase deploy --only hosting:admin
   ```

   ثم استخدم أحد الحلول أعلاه لإضافة custom claim.

---

## ⚠️ ملاحظات أمنية

- **Dev Mode** يسمح لأي مستخدم مسجل بالدخول إلى لوحة التحكم (غير آمن!)
- **Production Mode** يتطلب custom claim `isAdmin` (آمن)
- لا تترك Admin Panel في Dev Mode في بيئة Production!

---

## 📝 الحل الموصى به نهائيًا

استخدم **الحل 3** (Bootstrap Cloud Function) لأنه:
- آمن (محمي بمفتاح سري)
- يعمل لمرة واحدة فقط
- يسجل جميع الإجراءات في Firestore
- يمنع إنشاء admins إضافيين بدون تفويض

بعد إنشاء أول admin، استخدم لوحة التحكم الداخلية لإضافة admins آخرين عبر `setAdminRole` Cloud Function.
