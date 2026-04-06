# Q TASK 3: Driver Cancellation Flow with Reasons

**Priority:** MEDIUM
**Estimated Time:** 2 hours
**Difficulty:** Moderate

---

## Overview

This task has **5 sub-tasks** (A → E). Each builds on the previous one.

**Complete them in order:**

1. **Part A:** Add CancelReason enum (15 min)
2. **Part B:** Create cancellation dialog UI (30 min)
3. **Part C:** Integrate dialog into ActiveOrderScreen (20 min)
4. **Part D:** Update OrdersService (15 min)
5. **Part E:** Backend - Return cancelled order to matching (40 min)

---

## Files to Create/Modify

**New Files:**
- `packages/core_shared/lib/src/cancel_reason.dart`
- `apps/wawapp_driver/lib/features/active/widgets/cancel_order_dialog.dart`
- `functions/src/handleDriverCancellation.ts`

**Modified Files:**
- `packages/core_shared/lib/core_shared.dart`
- `apps/wawapp_driver/lib/features/active/active_order_screen.dart`
- `apps/wawapp_driver/lib/services/orders_service.dart`
- `functions/src/index.ts`

---

## Sub-Tasks

### ✅ Part A: Data Model (15 min)
→ See: [Q_TASK_3A_Cancel_Reason_Enum.md](Q_TASK_3A_Cancel_Reason_Enum.md)

### ✅ Part B: UI Dialog (30 min)
→ See: [Q_TASK_3B_Cancel_Dialog_UI.md](Q_TASK_3B_Cancel_Dialog_UI.md)

### ✅ Part C: Integration (20 min)
→ See: [Q_TASK_3C_Integrate_Dialog.md](Q_TASK_3C_Integrate_Dialog.md)

### ✅ Part D: Service Update (15 min)
→ See: [Q_TASK_3D_Update_Service.md](Q_TASK_3D_Update_Service.md)

### ✅ Part E: Backend Logic (40 min)
→ See: [Q_TASK_3E_Backend_Return_To_Matching.md](Q_TASK_3E_Backend_Return_To_Matching.md)

---

## Complete Flow

**User Journey:**
1. Driver accepts order
2. Driver needs to cancel (vehicle breakdown, customer unreachable, etc.)
3. Driver presses "إلغاء الطلب" button
4. **NEW:** Dialog appears with 4 cancellation reasons
5. Driver selects reason
6. Driver confirms cancellation
7. **Backend:** Order returns to `matching` status
8. **Backend:** Customer receives notification with reason
9. Other drivers can now see and accept the order

---

## Testing Checklist

After completing ALL parts (A→E):

- [ ] Driver accepts order
- [ ] Presses cancel button
- [ ] Dialog shows 4 reasons in Arabic
- [ ] Select "تعطل السيارة" → confirm
- [ ] Order status changes to `cancelledByDriver`
- [ ] Backend detects cancellation
- [ ] Order status changes to `matching`
- [ ] Customer receives notification
- [ ] New drivers can see the order on nearby screen
- [ ] Firestore document has `cancelReason: 'vehicle_breakdown'`
- [ ] `flutter analyze` → 0 errors
- [ ] `npm run build` → success

---

## Safety Rules

✅ **MUST:**
- Complete parts in order (A → B → C → D → E)
- Test after each part
- Report to Claude after each part

❌ **DON'T:**
- Skip any part
- Change unrelated code
- Remove existing functionality

---

## Report Back to Claude

After completing **each part**, report:

**Part A:**
- ✅ Created: `cancel_reason.dart`
- ✅ Export added to `core_shared.dart`
- ✅ `flutter analyze`: 0 errors

**Part B:**
- ✅ Created: `cancel_order_dialog.dart`
- ✅ Dialog displays 4 reasons
- ✅ `flutter analyze`: 0 errors

**Part C:**
- ✅ Modified: `active_order_screen.dart`
- ✅ Dialog integrated with cancel button
- ✅ Test: Dialog appears on cancel press

**Part D:**
- ✅ Modified: `orders_service.dart`
- ✅ Added `reason` parameter
- ✅ `flutter analyze`: 0 errors

**Part E:**
- ✅ Created: `handleDriverCancellation.ts`
- ✅ Export added to `index.ts`
- ✅ Build successful
- ✅ Deployed to Firebase
- ✅ Test: Order returns to matching

---

**Ready to start? Begin with Part A!**
