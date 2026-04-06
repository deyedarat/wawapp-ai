# Q TASK 7: Improve Insufficient Balance UI Feedback

**Priority:** HIGH ⚡
**Estimated Time:** 30 minutes
**Difficulty:** Easy

---

## Objective
Fix the "data loss" issue when driver presses "بدء الرحلة" (Start Trip) with insufficient wallet balance.

---

## Current Problem

**Scenario:**
1. Driver accepts order
2. Driver presses "بدء الرحلة" button
3. Backend checks wallet balance (needs 10% of order price)
4. **If insufficient:** Backend reverts order status to `accepted`
5. **Bug:** Driver sees generic error, UI doesn't handle revert gracefully
6. User reports "data loss" (order info disappears or UI breaks)

**Root Cause:**
- `processTripStartFee.ts` reverts status on insufficient balance
- Driver app doesn't show clear error message
- No loading state on button
- Poor UX when transaction fails

---

## Files to Modify

### 1. `apps/wawapp_driver/lib/features/active/active_order_screen.dart`

---

## Implementation Steps

### Step 1: Add Loading State

Add a new state variable at the top of `_ActiveOrderScreenState` class (after `_isCancelling`):

```dart
bool _isStartingTrip = false;
```

---

### Step 2: Improve `_transition()` Method

Find the `_transition()` method (around line 41) and replace it with this enhanced version:

```dart
Future<void> _transition(String orderId, OrderStatus to) async {
  // Set loading state for trip start
  if (to == OrderStatus.onRoute) {
    setState(() => _isStartingTrip = true);
  }

  try {
    final ordersService = ref.read(ordersServiceProvider);
    await ordersService.transition(orderId, to);

    if (!mounted) return;

    // Success feedback with specific message
    String message = 'تم تحديث حالة الطلب';
    Color backgroundColor = Colors.green;

    if (to == OrderStatus.onRoute) {
      message = 'تم بدء الرحلة بنجاح ✓';
      setState(() => _isStartingTrip = false);
    } else if (to == OrderStatus.completed) {
      message = 'تم إكمال الطلب بنجاح ✓';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  } on Object catch (e) {
    if (!mounted) return;

    // Reset loading state
    if (to == OrderStatus.onRoute) {
      setState(() => _isStartingTrip = false);
    }

    // Enhanced error messages with specific handling
    String errorMessage = 'حدث خطأ غير متوقع';
    Color backgroundColor = Colors.red;
    Duration duration = const Duration(seconds: 4);

    final errorString = e.toString().toLowerCase();

    if (errorString.contains('insufficient') ||
        errorString.contains('balance') ||
        errorString.contains('رصيد')) {
      errorMessage = '⚠️ رصيد محفظتك غير كافٍ لبدء الرحلة\n\nيرجى شحن المحفظة أولاً';
      duration = const Duration(seconds: 6);
    } else if (errorString.contains('current status') ||
               errorString.contains('status')) {
      errorMessage = 'لا يمكن تحديث الطلب الآن، ربما تغيّرت حالته.';
    } else if (errorString.contains('network') ||
               errorString.contains('connection')) {
      errorMessage = 'خطأ في الاتصال، تحقق من الإنترنت وحاول مرة أخرى';
    } else {
      errorMessage = 'تعذّر تحديث الطلب: ${e.toString()}';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: backgroundColor,
        duration: duration,
        action: SnackBarAction(
          label: 'حسناً',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}
```

---

### Step 3: Update "بدء الرحلة" Button with Loading State

Find the "بدء الرحلة" button (around line 359-364) and update it:

```dart
ElevatedButton(
  onPressed: order.orderStatus.canDriverStartTrip &&
             order.id != null &&
             !_isStartingTrip  // ADD THIS CONDITION
      ? () => _transition(order.id!, OrderStatus.onRoute)
      : null,
  style: ElevatedButton.styleFrom(
    minimumSize: const Size(double.infinity, 48),
  ),
  child: _isStartingTrip  // ADD THIS TERNARY
      ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('جارِ بدء الرحلة...'),
          ],
        )
      : const Text('بدء الرحلة'),
),
```

---

### Step 4: Optional - Add Wallet Balance Warning

Add this helper widget before the "بدء الرحلة" button to show wallet warning:

```dart
// Check wallet balance (optional - requires wallet provider)
// If you have wallet balance available, add this before the button:
if (order.orderStatus.canDriverStartTrip)
  Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      border: Border.all(color: Colors.orange),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: Colors.orange.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'سيتم اقتطاع ${(order.price * 0.1).toStringAsFixed(0)} أوقية عند بدء الرحلة',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange.shade900,
            ),
          ),
        ),
      ],
    ),
  ),
```

---

## Testing Checklist

### Scenario 1: Sufficient Balance
- [ ] Accept order
- [ ] Press "بدء الرحلة"
- [ ] Button shows loading spinner
- [ ] Success message appears: "تم بدء الرحلة بنجاح ✓"
- [ ] Order transitions to `onRoute` status
- [ ] 10% deducted from wallet

### Scenario 2: Insufficient Balance
- [ ] Accept order
- [ ] Ensure wallet balance < 10% of order price
- [ ] Press "بدء الرحلة"
- [ ] Button shows loading spinner
- [ ] Clear error message appears: "⚠️ رصيد محفظتك غير كافٍ..."
- [ ] Order **remains** in `accepted` status
- [ ] **No data loss** - order info still visible
- [ ] Driver can navigate to wallet or cancel order

### Scenario 3: Network Error
- [ ] Disable internet
- [ ] Press "بدء الرحلة"
- [ ] Network error message appears
- [ ] Order info preserved

---

## Before vs After

**Before (Current):**
```
[Press بدء الرحلة]
→ Generic error: "خطأ: ..."
→ UI might break
→ User confused
```

**After (Fixed):**
```
[Press بدء الرحلة]
→ Loading spinner appears
→ Clear error: "⚠️ رصيد محفظتك غير كافٍ لبدء الرحلة"
→ Order info preserved
→ User knows exactly what to do (recharge wallet)
```

---

## Safety Rules

✅ **DO:**
- Add specific error messages
- Show loading state
- Preserve order data on error
- Give actionable feedback

❌ **DON'T:**
- Change backend logic
- Modify wallet deduction logic
- Remove existing error handling

---

## Backend Context

The backend (`processTripStartFee.ts`) does this:

1. Checks wallet balance
2. **If insufficient:**
   - Reverts order status: `onRoute` → `accepted`
   - Sends FCM notification
   - Increments `feeRevertCount`
3. **After 3 failed attempts:** Cancels order

Your job is to make the UI handle step 2 gracefully.

---

## Verification

```bash
cd apps/wawapp_driver
flutter analyze
```

Expected: **0 errors**

---

## Report Back to Claude

After completing this task, report:

1. ✅ File modified: `apps/wawapp_driver/lib/features/active/active_order_screen.dart`
2. ✅ Added: Loading state (`_isStartingTrip`)
3. ✅ Enhanced: `_transition()` method with specific error messages
4. ✅ Updated: "بدء الرحلة" button with loading UI
5. ✅ Test: Insufficient balance scenario → clear error, no data loss
6. ✅ `flutter analyze`: 0 errors

---

**Ready to start? Copy this entire task and paste to Amazon Q!**
