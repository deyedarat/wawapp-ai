# بقالتي - Baqalati

**تطبيق البقالة المحلية في نواكشوط، موريتانيا**

> منصة متكاملة تربط الأسر بالبقالات المحلية في نواكشوط، مع نظام طلبات وتوصيل ذكي.

---

## نظرة عامة

بقالتي هو مشروع MVP يتكون من تطبيقين Flutter منفصلين يعملان مع Firebase كخلفية مشتركة:

| التطبيق | الوصف | المستخدم المستهدف |
|---------|-------|-------------------|
| **بقالتي** (Customer) | تصفح البقالات، طلب المنتجات، تتبع الطلبات | العملاء والأسر |
| **بقالتي للتجار** (Merchant) | إدارة الطلبات، المنتجات، والإحصائيات | أصحاب البقالات |

---

## هيكل المشروع

```
baqalati/
├── baqalati_customer/          # تطبيق العميل
│   ├── lib/
│   │   ├── main.dart           # نقطة الدخول
│   │   ├── models/             # نماذج البيانات
│   │   │   ├── store_model.dart
│   │   │   ├── product_model.dart
│   │   │   ├── order_model.dart
│   │   │   └── user_model.dart
│   │   ├── providers/          # إدارة الحالة (Provider)
│   │   │   ├── auth_provider.dart
│   │   │   ├── cart_provider.dart
│   │   │   ├── locale_provider.dart
│   │   │   └── orders_provider.dart
│   │   ├── screens/            # شاشات التطبيق
│   │   │   ├── auth/           # تسجيل الدخول والتسجيل
│   │   │   ├── home/           # الشاشة الرئيسية
│   │   │   ├── store/          # تفاصيل البقالة
│   │   │   ├── cart/           # سلة التسوق
│   │   │   ├── order/          # تأكيد الطلب
│   │   │   └── tracking/       # تتبع الطلب
│   │   ├── services/           # خدمات Firebase و Mock
│   │   ├── l10n/               # الترجمة (عربي/فرنسي)
│   │   ├── theme/              # ثيم التطبيق
│   │   └── widgets/            # عناصر واجهة مشتركة
│   └── pubspec.yaml
│
├── baqalati_merchant/          # تطبيق التاجر
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/             # نفس النماذج المشتركة
│   │   ├── providers/
│   │   │   ├── auth_provider.dart
│   │   │   ├── locale_provider.dart
│   │   │   ├── orders_provider.dart
│   │   │   └── products_provider.dart
│   │   ├── screens/
│   │   │   ├── auth/           # تسجيل دخول التاجر
│   │   │   ├── dashboard/      # لوحة التحكم
│   │   │   ├── orders/         # إدارة الطلبات
│   │   │   ├── products/       # إدارة المنتجات
│   │   │   └── stats/          # الإحصائيات
│   │   ├── services/
│   │   ├── l10n/
│   │   └── theme/
│   └── pubspec.yaml
│
├── firestore.rules             # قواعد أمان Firestore
├── storage.rules               # قواعد أمان Storage
└── README.md
```

---

## الميزات

### تطبيق العميل (بقالتي)

- **تسجيل الدخول / إنشاء حساب** - بريد إلكتروني أو دخول كزائر
- **الشاشة الرئيسية** - عرض البقالات القريبة مع البحث والتصنيفات
- **تفاصيل البقالة** - قائمة المنتجات مع الأسعار والتصنيف
- **سلة التسوق** - إضافة/حذف/تعديل الكميات
- **تأكيد الطلب** - اختيار توصيل أو استلام، عنوان، ملاحظات
- **تتبع الطلب** - متابعة حالة الطلب بشكل مرئي (جديد ← قيد التجهيز ← جاهز ← تم التسليم)
- **قائمة الطلبات** - عرض الطلبات النشطة والمكتملة

### تطبيق التاجر (بقالتي للتجار)

- **تسجيل دخول التاجر** - مخصص لأصحاب البقالات
- **لوحة التحكم** - ملخص يومي (طلبات، إيرادات، منتجات)
- **إدارة الطلبات** - عرض الطلبات الواردة مع تحديث الحالة
- **إدارة المنتجات** - إضافة، تعديل، حذف منتجات مع الصور والأسعار
- **الإحصائيات** - عدد الطلبات، الإيرادات، توزيع الحالات

---

## التقنيات المستخدمة

| التقنية | الاستخدام |
|---------|-----------|
| **Flutter 3.x** | إطار عمل التطبيق |
| **Provider** | إدارة الحالة |
| **Firebase Auth** | المصادقة |
| **Cloud Firestore** | قاعدة البيانات |
| **Firebase Storage** | تخزين الصور |
| **Firebase Cloud Messaging** | الإشعارات الفورية |

---

## هيكل Firestore

```
├── users/
│   └── {userId}
│       ├── name: string
│       ├── email: string
│       ├── phone: string
│       ├── address: string
│       ├── role: "customer" | "merchant"
│       ├── storeId: string? (for merchants)
│       └── createdAt: timestamp
│
├── stores/
│   └── {storeId}
│       ├── name, nameAr, nameFr: string
│       ├── address, addressAr, addressFr: string
│       ├── phone: string
│       ├── imageUrl: string
│       ├── latitude, longitude: number
│       ├── rating: number
│       ├── isOpen: boolean
│       ├── ownerId: string
│       ├── categories: string[]
│       └── products/ (sub-collection)
│           └── {productId}
│               ├── name, nameAr, nameFr: string
│               ├── price: number
│               ├── unit, unitAr, unitFr: string
│               ├── imageUrl: string
│               ├── category, categoryAr, categoryFr: string
│               ├── isAvailable: boolean
│               └── createdAt: timestamp
│
└── orders/
    └── {orderId}
        ├── userId: string
        ├── userName: string
        ├── userPhone: string
        ├── storeId: string
        ├── storeName: string
        ├── items: CartItem[]
        ├── totalAmount: number
        ├── status: "pending" | "preparing" | "ready" | "delivered" | "cancelled"
        ├── deliveryType: "delivery" | "pickup"
        ├── deliveryAddress: string
        ├── notes: string
        ├── createdAt: timestamp
        └── updatedAt: timestamp
```

---

## التثبيت والتشغيل

### المتطلبات

- Flutter SDK 3.1+
- Dart SDK 3.1+
- Android Studio أو VS Code
- (اختياري) حساب Firebase

### تشغيل تطبيق العميل

```bash
cd baqalati_customer
flutter pub get
flutter run
```

### تشغيل تطبيق التاجر

```bash
cd baqalati_merchant
flutter pub get
flutter run
```

### ربط Firebase (عند الجاهزية)

1. أنشئ مشروع Firebase جديد
2. أضف تطبيقات Android/iOS
3. نزّل ملفات التكوين (`google-services.json` / `GoogleService-Info.plist`)
4. فعّل Authentication (Email/Password)
5. أنشئ قاعدة بيانات Firestore
6. فعّل Firebase Storage
7. فعّل Cloud Messaging
8. أزل التعليقات عن حزم Firebase في `pubspec.yaml`
9. أزل التعليقات عن كود Firebase في `firebase_service.dart`

---

## التصميم

### الألوان

| اللون | الكود | الاستخدام |
|-------|-------|-----------|
| أخضر داكن | `#1B5E20` | شريط التاجر |
| أخضر رئيسي | `#2E7D32` | اللون الأساسي |
| أخضر فاتح | `#4CAF50` | عناصر ثانوية |
| أبيض | `#FFFFFF` | الخلفيات |
| رمادي فاتح | `#F5F5F5` | خلفية التطبيق |

### دعم اللغات

- **العربية** (RTL) - اللغة الافتراضية
- **الفرنسية** (LTR) - اللغة الثانية

يمكن التبديل بين اللغتين من أي شاشة.

---

## العملة

التطبيق يستخدم **الأوقية الموريتانية (MRU)** كعملة أساسية.

---

## Mock Data

التطبيق يأتي مع بيانات تجريبية تشمل:

- **5 بقالات** في أحياء مختلفة من نواكشوط (تفرغ زينة، لكصر، عرفات، السبخة، دار النعيم)
- **منتجات متنوعة** لكل بقالة (خضروات، ألبان، لحوم، مشروبات، إلخ)
- **3 طلبات تجريبية** بحالات مختلفة
- **حسابات تجريبية** للعميل والتاجر

### بيانات الدخول التجريبية

| التطبيق | البريد | كلمة المرور |
|---------|--------|-------------|
| العميل | demo@baqalati.mr | password |
| التاجر | merchant@baqalati.mr | password |

---

## الخطوات القادمة (Roadmap)

- [ ] ربط Firebase حقيقي
- [ ] إضافة خرائط Google لتحديد موقع البقالة
- [ ] نظام تقييم البقالات
- [ ] إشعارات فورية عبر FCM
- [ ] دعم الدفع الإلكتروني (Bankily, Sedad)
- [ ] تطبيق ويب للإدارة
- [ ] دعم اللغة الحسانية

---

## الترخيص

هذا المشروع مرخص تحت رخصة MIT.

---

**بقالتي** - بقالتك المفضلة في نواكشوط 🇲🇷
