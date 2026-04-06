# Q TASK 4: Display Customer Phone Number

**Priority:** HIGH ⚡
**Estimated Time:** 1 hour
**Difficulty:** Moderate

---

## Overview

This task has **3 sub-tasks** (A → C). Complete them in order.

**What it does:**
When driver accepts an order, fetch customer's phone number and display it prominently so driver can call customer easily.

---

## Sub-Tasks

### ✅ Part A: Backend - Add Phone to Order (20 min)
→ See: [Q_TASK_4A_Backend_Customer_Phone.md](Q_TASK_4A_Backend_Customer_Phone.md)

### ✅ Part B: Data Model - Add Phone Field (15 min)
→ See: [Q_TASK_4B_Order_Model_Phone.md](Q_TASK_4B_Order_Model_Phone.md)

### ✅ Part C: UI - Display Phone Prominently (25 min)
→ See: [Q_TASK_4C_Display_Phone_UI.md](Q_TASK_4C_Display_Phone_UI.md)

---

## Complete Flow

**User Journey:**
1. Driver sees new order notification
2. Driver accepts order
3. **Backend:** Fetches customer phone from `users/{ownerId}`
4. **Backend:** Adds `customerPhone` to order document
5. **App:** Order model parses `customerPhone` field
6. **App:** UI displays phone number prominently with call button
7. Driver taps call button → phone dialer opens
8. Driver can easily contact customer

---

## Files to Create/Modify

**Modified Files:**
- `functions/src/acceptOrder.ts` (Part A)
- `packages/core_shared/lib/src/order.dart` (Part B)
- `apps/wawapp_driver/lib/features/active/active_order_screen.dart` (Part C)

---

## Testing Checklist

After completing ALL parts (A→C):

- [ ] Accept an order
- [ ] Check Firestore: `orders/{orderId}` has `customerPhone` field
- [ ] Phone number displays in active order screen
- [ ] Phone number is large and readable
- [ ] "اتصل" (Call) button is green and prominent
- [ ] Tap call button → phone dialer opens with customer number
- [ ] If no phone in users collection → UI handles gracefully (no crash)
- [ ] `flutter analyze` → 0 errors
- [ ] `npm run build` → success

---

## Security Considerations

✅ **Privacy Protection:**
- Phone number only added to order **after acceptance** (not before)
- Only assigned driver can see phone number
- Phone number removed when order completed/cancelled (optional)

✅ **Firestore Rules:**
```javascript
// In firestore.rules
match /orders/{orderId} {
  allow read: if request.auth != null && (
    request.auth.uid == resource.data.ownerId ||  // Customer
    request.auth.uid == resource.data.assignedDriverId  // Assigned driver
  );
}
```

---

## Visual Design

**Before:**
```
[ Order Details Card ]
- Order #ABC123
- Pickup → Dropoff
- Distance: 5 km
- Price: 100 MRU
- [TODO: Phone icon]  ← Generic placeholder
```

**After:**
```
[ Customer Phone Card - Prominent ]
📞 رقم العميل
   +222 12 34 56 78
   [ 📞 اتصل ] ← Green button

[ Order Details Card ]
- Order #ABC123
- Pickup → Dropoff
...
```

---

## Safety Rules

✅ **MUST:**
- Complete parts in order (A → B → C)
- Test after each part
- Report to Claude after each part

❌ **DON'T:**
- Skip any part
- Expose phone before order acceptance
- Hard-code phone numbers

---

## Report Back to Claude

After completing **each part**, report:

**Part A:**
- ✅ Modified: `acceptOrder.ts`
- ✅ Fetches customer phone from `users` collection
- ✅ Adds `customerPhone` to order on acceptance
- ✅ Build successful

**Part B:**
- ✅ Modified: `order.dart`
- ✅ Added `customerPhone?` field
- ✅ Updated all constructors and methods
- ✅ `flutter analyze`: 0 errors

**Part C:**
- ✅ Modified: `active_order_screen.dart`
- ✅ Phone card displays prominently
- ✅ Call button works
- ✅ Test: Phone dialer opens with correct number

---

**Ready to start? Begin with Part A!**
