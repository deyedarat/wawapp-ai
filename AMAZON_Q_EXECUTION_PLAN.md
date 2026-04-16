# 📋 Amazon Q Execution Plan - Dispatch v2.0 Integration

## 🎯 هدف هذا الملف
توجيه تنفيذ Amazon Q خطوة بخطوة لإكمال تكامل Dispatch v2.0 مع Flutter.

---

## 📊 ترتيب التنفيذ

### **المرحلة 1: إصلاح Backend (حرج 🔴)**
**الأولوية:** عاجل - يجب تنفيذه أولاً لمنع الإشعارات المكررة

**الملف:** [Q_PROMPT_FIX_NOTIFY_UNASSIGNED.md](./Q_PROMPT_FIX_NOTIFY_UNASSIGNED.md)

**الـ Prompt:**
```
افتح الملف Q_PROMPT_FIX_NOTIFY_UNASSIGNED.md واتبع "Approach A: Disable the Function"
```

**التحقق:**
```bash
firebase functions:list | grep notifyUnassignedOrders
# يجب ألا يظهر شيء
```

**الوقت المتوقع:** 2 دقيقة

---

### **المرحلة 2: Flutter Models (متوسط 🟡)**

**الملف:** [Q_PROMPTS_DISPATCH_V2_FLUTTER.md](./Q_PROMPTS_DISPATCH_V2_FLUTTER.md)

#### **Prompt 1/4: Create DispatchOffer Model**
```
افتح Q_PROMPTS_DISPATCH_V2_FLUTTER.md وقم بتنفيذ "Prompt 1: Create DispatchOffer Model"
```

**التحقق:**
```bash
flutter analyze apps/wawapp_driver
```

**الوقت المتوقع:** 3 دقائق

---

### **المرحلة 3: Flutter Services (متوسط 🟡)**

#### **Prompt 2/4: Update Orders Service**
```
افتح Q_PROMPTS_DISPATCH_V2_FLUTTER.md وقم بتنفيذ "Prompt 2: Update Orders Service for v2.0"
```

**التحقق:**
```bash
flutter analyze apps/wawapp_driver
grep -n "acceptOfferV2" apps/wawapp_driver/lib/features/orders/services/orders_service.dart
```

**الوقت المتوقع:** 5 دقائق

---

### **المرحلة 4: Flutter Widgets (متوسط 🟡)**

#### **Prompt 3/4: Create Dispatch Offer Card**
```
افتح Q_PROMPTS_DISPATCH_V2_FLUTTER.md وقم بتنفيذ "Prompt 3: Create Dispatch Offer Card Widget"
```

**التحقق:**
```bash
flutter analyze apps/wawapp_driver
ls apps/wawapp_driver/lib/features/orders/widgets/dispatch_offer_card.dart
```

**الوقت المتوقع:** 5 دقائق

---

### **المرحلة 5: Flutter Providers (متوسط 🟡)**

#### **Prompt 4/4: Update Orders Provider**
```
افتح Q_PROMPTS_DISPATCH_V2_FLUTTER.md وقم بتنفيذ "Prompt 4: Update Orders Provider"
```

**التحقق:**
```bash
flutter analyze apps/wawapp_driver
grep -n "watchMyOffers" apps/wawapp_driver/lib/features/orders/providers/orders_provider.dart
```

**الوقت المتوقع:** 5 دقائق

---

## ✅ Checklist التنفيذ الكامل

بعد إنهاء جميع المراحل، تحقق من:

- [ ] **Backend:**
  - [ ] `notifyUnassignedOrders` تم حذفها أو تعطيلها
  - [ ] `firebase functions:list` لا يظهر notifyUnassignedOrders

- [ ] **Flutter Models:**
  - [ ] `dispatch_offer.dart` موجود في المسار الصحيح
  - [ ] Model يحتوي على جميع الحقول المطلوبة

- [ ] **Flutter Services:**
  - [ ] `acceptOfferV2()` موجودة في orders_service.dart
  - [ ] `rejectOffer()` موجودة
  - [ ] `watchMyOffers()` موجودة

- [ ] **Flutter Widgets:**
  - [ ] `dispatch_offer_card.dart` موجود
  - [ ] Widget يحتوي على countdown timer
  - [ ] أزرار Accept و Reject موجودة

- [ ] **Flutter Providers:**
  - [ ] Provider يحتوي على v2 methods
  - [ ] Methods تستدعي الـ service layer بشكل صحيح

- [ ] **Final Verification:**
  - [ ] `flutter analyze apps/wawapp_driver` → لا توجد أخطاء
  - [ ] جميع الـ imports صحيحة
  - [ ] لا توجد أخطاء type checking

---

## 🚀 ما بعد الإنهاء

بعد إتمام جميع المراحل بنجاح:

1. **تحديث UI:**
   - تعديل `nearby_orders_screen.dart` لاستخدام `DispatchOfferCard`
   - إضافة `StreamBuilder` للاستماع لـ `watchMyOffers`

2. **اختبار:**
   - إنشاء طلب اختبار
   - التحقق من استلام العرض في التطبيق
   - اختبار Accept و Reject
   - التحقق من countdown timer

3. **Deployment:**
   - Build APK
   - اختبار على جهاز حقيقي
   - رفع على Play Store (internal testing)

---

## 📊 الوقت الإجمالي المتوقع

| المرحلة | الوقت |
|---------|-------|
| Backend Fix | 2 دقيقة |
| Model | 3 دقائق |
| Service | 5 دقائق |
| Widget | 5 دقائق |
| Provider | 5 دقائق |
| **المجموع** | **20 دقيقة** |

---

## ⚠️ ملاحظات مهمة

1. **لا تُخطِ أي مرحلة** - الترتيب مهم
2. **تحقق بعد كل مرحلة** - لا تنتقل للتالية قبل التحقق
3. **إذا فشل `flutter analyze`** - أصلح الأخطاء قبل المتابعة
4. **احفظ نسخة احتياطية** قبل البدء:
   ```bash
   git stash
   git checkout -b feature/dispatch-v2-flutter-integration
   ```

---

## 🆘 في حالة الأخطاء

### خطأ: Missing imports
```bash
# افتح الملف وأضف imports يدوياً
import 'package:cloud_firestore/cloud_firestore.dart';
```

### خطأ: Type mismatch
```bash
# تحقق من أن Firestore field types تطابق Flutter types
# Timestamp → DateTime
# num → double
```

### خطأ: File not found
```bash
# تأكد من المسار الصحيح
ls apps/wawapp_driver/lib/features/orders/models/
```

---

## 📞 للدعم

إذا واجهت مشاكل:
1. شغّل `flutter analyze apps/wawapp_driver` وأرسل الـ output
2. ارجع إلى الـ prompt الأصلي وتحقق من الخطوات
3. اطلب من Amazon Q إصلاح الخطأ المحدد

---

**الإصدار:** 2.0.0
**تاريخ الإنشاء:** 2026-04-16
**الحالة:** ✅ جاهز للتنفيذ
**المنفذ:** Amazon Q Developer
**المراقب:** Claude Code
