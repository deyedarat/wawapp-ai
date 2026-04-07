# Deploy Firebase Functions - إصلاح الصوت النهائي

## المشكلة الجذرية المكتشفة:

Firebase Functions كانت ترسل **data-only** messages بدون `notification` block!

**النتيجة:**
- ❌ Android لا يُشغّل الصوت تلقائياً
- ❌ لا يظهر heads-up notification
- ❌ الإشعار "صامت" تماماً

---

## ✅ التعديلات المطبقة:

### 1. `notifyNewOrder.ts` - السطر 215-248

**قبل:**
```typescript
const message: admin.messaging.Message = {
  token: driver.fcmToken,
  data: { ... },  // data only
  android: {
    priority: 'high',
  },
};
```

**بعد:**
```typescript
const message: admin.messaging.Message = {
  token: driver.fcmToken,
  notification: {  // ⭐ إضافة notification block
    title: 'طلب جديد قريب منك',
    body: `${pickupLabel} → ${dropoffLabel}`,
  },
  data: { ... },
  android: {
    priority: 'high',
    notification: {  // ⭐ إعدادات Android الخاصة
      channelId: 'new_orders',
      sound: 'trip_reminder',
      priority: 'max',
      visibility: 'public',
    },
  },
};
```

### 2. `notifyUnassignedOrders.ts` - السطر 286-317

نفس التعديل ✅

---

## 📤 خطوات النشر:

```bash
cd functions
npm run build
firebase deploy --only functions
```

---

## 🔍 التحقق بعد النشر:

```bash
firebase functions:log --only notifyNewOrder
```

يجب أن ترى:
```
[NotifyNewOrder] Notification sent to driver
message_id: projects/.../messages/...
```

---

**استخدم Amazon Q لتنفيذ النشر!**
