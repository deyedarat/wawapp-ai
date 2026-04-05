# 🔧 Firebase Phone Auth — Error Code:39 Diagnostic Prompt

انسخ هذا البرومبت وألصقه في متصفح AI (ChatGPT/Gemini) لتشخيص وإصلاح المشكلة:

---

## البرومبت:

```
أنا مطور تطبيق Flutter يستخدم Firebase Phone Authentication.
التطبيق يفشل في إرسال OTP مع الأخطاء التالية من logcat:

ERROR 1: [SmsRetrieverHelper] SMS verification code request failed: unknown status code: 17028 null
ERROR 2: Firebase re-triggers with non-reCAPTCHA Enterprise flow
ERROR 3: [SmsRetrieverHelper] SMS verification code request failed: unknown status code: 17499 Error code:39
FINAL: "An internal error has occurred. [ Error code:39 ]"

معلومات المشروع:
- Firebase Project ID: wawapp-952d6
- Project Number: 363341993641
- Android Package: com.wawapp.client (+ com.wawapp.driver)
- رقم الهاتف المستهدف: بادئة +222 (موريتانيا)
- reCAPTCHA Enterprise: يعمل بنجاح (Successfully obtained site key)
- الشريحة: شبكة LTE موريتانية (MCC=609, MNC=10)

التسلسل الكامل:
1. ✅ OtpStage.sending يبدأ
2. ✅ reCAPTCHA Enterprise ينجح ويحصل على site key
3. ❌ أول محاولة SMS تفشل (status code: 17028)
4. 🔄 Firebase يعيد المحاولة بدون reCAPTCHA Enterprise
5. ❌ ثاني محاولة تفشل (status code: 17499, Error code:39)
6. ❌ verificationFailed callback يُستدعى

أريد منك إعطائي خطوات تفصيلية للتحقق والإصلاح في 3 لوحات تحكم:

## 1. Firebase Console (https://console.firebase.google.com)
- تحقق من: Authentication → Phone → SMS quota/usage
- تحقق من: Authentication → Settings → Authorized domains
- تحقق من: Authentication → Phone → Test phone numbers
- تحقق من: Project Settings → General → SHA-1/SHA-256 fingerprints
- تحقق من: Billing plan (Spark vs Blaze) وحدود SMS
- تحقق من: Authentication → Settings → SMS Region Policy (هل موريتانيا +222 محظورة؟)

## 2. Google Cloud Console (https://console.cloud.google.com)
- تحقق من: APIs & Services → Enabled APIs:
  * Identity Toolkit API (مطلوب لـ Phone Auth)
  * Token Service API
  * Android Device Verification API
  * reCAPTCHA Enterprise API
- تحقق من: APIs & Services → Credentials → API Keys:
  * هل المفتاح AIzaSyBO67aaNMqotGFF73jlCB8uVGUQ5bILfVM موجود وغير مقيد بشكل خاطئ؟
  * هل Android restrictions تتضمن com.wawapp.client و com.wawapp.driver؟
  * هل SHA-1 fingerprints مضافة بشكل صحيح؟
- تحقق من: APIs & Services → Dashboard → Error rates
- تحقق من: IAM → Service accounts → firebase-adminsdk permissions
- تحقق من: Quotas → Identity Toolkit API quotas

## 3. Google Cloud reCAPTCHA Enterprise
- تحقق من: Security → reCAPTCHA Enterprise → Site keys
- تحقق من: هل site key مرتبط بـ com.wawapp.client؟
- تحقق من: Assessment logs → هل التقييمات تمر بنجاح؟

## 4. تحقق إضافي مهم
- Error code 17028 = BILLING_NOT_ENABLED أو SMS_QUOTA_EXCEEDED
- Error code 17499 = INTERNAL_ERROR (عادة مشكلة في إعدادات المشروع)
- Error code 39 = غالباً مرتبط بـ reCAPTCHA أو Phone Auth configuration

أعطني:
1. قائمة مرقمة بالخطوات الدقيقة للتحقق في كل لوحة تحكم
2. لكل خطوة: ما المتوقع أن أراه إذا كان الإعداد صحيحاً
3. لكل خطوة: ما الإصلاح إذا كان الإعداد خاطئاً
4. ترتيب الأولوية (ما الأكثر احتمالاً أن يكون السبب)
5. كيف أضيف رقم اختبار مؤقت لتجاوز المشكلة أثناء التطوير

ملاحظة: التطبيق يعمل على جهاز Samsung حقيقي متصل عبر USB debugging، وليس emulator.
```

---

## روابط مباشرة للتحقق:

| الخدمة | الرابط |
|--------|--------|
| Firebase Console | https://console.firebase.google.com/project/wawapp-952d6/authentication/providers |
| Firebase Phone Settings | https://console.firebase.google.com/project/wawapp-952d6/authentication/settings |
| Firebase Usage | https://console.firebase.google.com/project/wawapp-952d6/usage |
| GCP APIs | https://console.cloud.google.com/apis/dashboard?project=wawapp-952d6 |
| GCP Credentials | https://console.cloud.google.com/apis/credentials?project=wawapp-952d6 |
| GCP Quotas | https://console.cloud.google.com/iam-admin/quotas?project=wawapp-952d6 |
| reCAPTCHA Enterprise | https://console.cloud.google.com/security/recaptcha?project=wawapp-952d6 |
| GCP Billing | https://console.cloud.google.com/billing?project=wawapp-952d6 |

## أول شيء جربه (الأسرع):
افتح Firebase Console → Authentication → Phone → أضف رقم اختبار:
- Phone: `+22200000000`
- Code: `123456`
ثم جرب بهذا الرقم في التطبيق.
