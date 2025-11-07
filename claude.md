🧠 CLAUDE.MD — Unified Coding & Agent Discipline Guide

(WawApp 2025 Edition)

الهدف: جعل Claude Code يتصرّف كمساعد برمجي منضبط وآمن، يحافظ على بنية المشروع ويعمل بانسجام مع Amazon Q Developer و Specify (Speckit).

🔒 SECTION 1 — SECURITY & QUALITY RULES

Authorized Changes Only

عدّل فقط ما طُلِب صراحة.

لا تغيّر أوامر Flutter أو Gradle أو PowerShell إلا بعد تأكيد.

أي تعديل غير مذكور = Prohibited Change.

Dependency Management

أضف dependencies في pubspec.yaml, package.json, أو build.gradle عند الاستيراد.

لا تُدرج import بدون تحديث ملف التبعيات.

No Placeholders or Dummy Data

لا تستخدم YOUR_API_KEY أو TODO.

استخدم متغيرات البيئة (.env, api_keys.xml).

Security by Design

احفظ المفاتيح في السيرفر فقط.

فعّل Row-Level Security في Firestore أو SQL.

نظّف أي أسرار قبل commit أو push.

Evidence-Based Answers

أظهر الملف + الأسطر + المقتطف عند تأكيد أو نفي تنفيذ ميزة.

لا تجزم دون دليل.

No Assumptions

عند الغموض، اطلب clarification ولا تخمّن.

Preserve Functional Requirements

أصلح الخطأ دون تغيير المنطق أو requirements.

اطلب إذنًا قبل أي refactor تغييري.

Intelligent Logging

أضف INFO/WARN/ERROR حيث يلزم فقط.

لا تفرط أو تُهمل التسجيل.

⚙️ SECTION 2 — COMMAND SCOPE LIMITS
الفئة	المسموح	المحظور
Git	commit, branch, merge --no-ff, diff, push origin feature/*	أي force-push, reset --hard, تغييرات main مباشرة
Flutter	flutter analyze, format ., build apk	تعديل SDK path أو flutter upgrade بدون إذن
Gradle	gradlew assembleDebug, clean, dependencies	حذف .gradle/ أو تعديل wrapper بيدويًا
PowerShell / Speckit	.\spec.ps1 env:verify, doctor, build, test	تعديل السكربتات الأساسية أو المتغيرات النظامية
🏗️ SECTION 3 — ARCHITECTURE COMPLIANCE

اتبع سياسة preserve_existing architecture.

لا تُنشئ مجلدات bloc أو cubit جديدة — النظام Riverpod فقط.

حافظ على هيكل المجلدات:

features/
  auth/
  orders/
  core/


كلّ تعديل Firebase يجب أن يمر عبر updateStats, verifyRules, و indexes.

لا تغيّر مخطط Firestore بدون إضافة migration في /migrations.

🧩 SECTION 4 — EXECUTION PROTOCOLS
قبل أي أمر تنفيذي:

✅ تحقق من الطلب صراحة.

✅ قدّم ملخّص خطواتك قبل التنفيذ.

✅ اطلب تأكيد المستخدم إن كان الأمر يؤثر في البيئة.

بعد التنفيذ:

سجّل الملفات المعدّلة في ملف CHANGES.md.

حلّل أي تحذير في flutter analyze.

نظّف أي كود اختبار مؤقت.

🧠 SECTION 5 — INTEGRATION NOTES
Amazon Q Developer

استخدمه فقط لأوامر التحليل والتصفية النهائية (flutter analyze, dart format).

لا يُسمح له بتعديل الكود إلا ضمن فرع مؤقت chore/q-fix-*.

عند تشغيل أمر خارجي، نفّذ Dry-Run أولاً.

Specify / Speckit

لا تتجاوز preserve_existing.

سجّل التحقق في logs/specify-run-YYYYMMDD.txt.

قبل env:verify, افحص doctor وانتظر حالة OK لكل مكوّن.

عند فشل أي فحص (Flutter, Gradle, Firebase) أوقف العمل ولا تحاول الإصلاح تلقائيًا.

✅ SECTION 6 — MANDATORY CHECKLIST BEFORE REPLY

 هل عدّلت فقط ما طُلِب؟

 هل أضفت التبعيات في ملف ها؟

 هل تجنّبت placeholders والقيم الصلبة؟

 هل تحقّقت من الأمان (Secrets, RLS, HTTPS)؟

 هل تحقّقت من التحليل (flutter analyze نظيف)؟

 هل وثّقت التغييرات؟

🛑 SECTION 7 — EMERGENCY STOP POLICY

إذا كان أي شيء غير واضح:

توقّف فورًا.

اسأل عن التفاصيل الناقصة.

انتظر تأكيد المستخدم.

استأنف فقط عند وضوح كامل 100 %.