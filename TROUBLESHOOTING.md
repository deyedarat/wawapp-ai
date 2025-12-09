# لماذا لا تظهر الطلبات للسائق؟

## التحقق السريع:

### 1. تحقق من حالة السائق
```
Firebase Console > Firestore > drivers > {driverId}
✅ isOnline = true
✅ location.lat و location.lng موجودة
✅ isVerified = true
```

### 2. تحقق من وجود طلبات
```
Firebase Console > Firestore > orders
ابحث عن طلب بهذه الشروط:
✅ status = "matching"
✅ assignedDriverId = null أو غير موجود
✅ pickup.lat و pickup.lng موجودة
```

### 3. تحقق من المسافة
احسب المسافة بين السائق والطلب:
- يجب أن تكون ≤ 8 كم

### 4. تحقق من الفهرس المركب
```
Firebase Console > Firestore > Indexes
يجب أن يكون هناك فهرس:
Collection: orders
Fields: 
  - status (Ascending)
  - assignedDriverId (Ascending)
  - createdAt (Descending)
```

### 5. تحقق من Logs
```
flutter run --debug
ابحث عن:
[Matching] ✅ Driver is ONLINE
[Matching] 📦 Firestore snapshot received: X documents
[Matching] 📊 FINAL RESULT: X matching orders
```

## الأخطاء الشائعة:

❌ السائق OFFLINE → اضغط زر "متصل" في التطبيق
❌ لا توجد طلبات → أنشئ طلب من تطبيق العميل
❌ status = "requested" → يجب أن يكون "matching"
❌ assignedDriverId موجود → الطلب مأخوذ بالفعل
❌ المسافة > 8km → قرّب السائق من الطلب
❌ الفهرس مفقود → انتظر إنشاء الفهرس تلقائياً أو أنشئه يدوياً
