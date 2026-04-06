# Q TASK 1: Hide Accepted Orders from Nearby Screen

**Priority:** HIGH ⚡
**Estimated Time:** 15 minutes
**Difficulty:** Easy

---

## Objective
Filter out accepted orders from the driver's nearby orders screen so that orders already assigned to a driver don't appear to other drivers.

---

## Current Problem
- Driver accepts an order
- Order still appears on the nearby screen (map) for other drivers or same driver
- Causes confusion and duplicate acceptance attempts

---

## Files to Modify

### 1. `apps/wawapp_driver/lib/features/nearby/providers/nearby_orders_provider.dart`

---

## Implementation Steps

### Step 1: Locate the Orders Processing Logic

Find where `rawOrders` from the service are being processed (approximately after line 50-80).

### Step 2: Add Filter Logic

Add this filter AFTER getting orders from the service:

```dart
// Filter out orders that are already assigned
final availableOrders = rawOrders.where((order) {
  // Only show orders that are:
  // 1. In 'matching' status (looking for driver)
  // 2. Not yet assigned to any driver
  return order.assignedDriverId == null && order.status == 'matching';
}).toList();
```

### Step 3: Use Filtered Orders

Replace `rawOrders` with `availableOrders` in the return statement.

---

## Expected Result

**Before:**
```dart
return orders; // Shows all orders including accepted ones
```

**After:**
```dart
final availableOrders = orders.where((order) {
  return order.assignedDriverId == null && order.status == 'matching';
}).toList();

return availableOrders; // Only unassigned orders
```

---

## Testing Checklist

- [ ] Open driver app
- [ ] See available orders on map
- [ ] Accept an order
- [ ] **Verify:** Order disappears from nearby screen immediately
- [ ] **Verify:** Other drivers don't see this order
- [ ] Cancel order (if supported) → order reappears if status returns to matching
- [ ] Run `flutter analyze` → 0 errors

---

## Safety Rules

✅ **DO:**
- Preserve existing error handling
- Keep all logging statements
- Keep existing null safety checks

❌ **DON'T:**
- Modify the `getNearbyOrders` Cloud Function
- Change other parts of the provider
- Remove any existing filters

---

## Verification

After implementation, check:

1. **Code Quality:**
   ```bash
   cd apps/wawapp_driver
   flutter analyze
   ```
   Should show: **0 errors**

2. **Runtime Test:**
   - Accept order → order vanishes from map ✓
   - No crashes or errors ✓

---

## Report Back to Claude

After completing this task, report:

1. ✅ File modified: `apps/wawapp_driver/lib/features/nearby/providers/nearby_orders_provider.dart`
2. ✅ Changes made: Added filter for `assignedDriverId == null && status == 'matching'`
3. ✅ `flutter analyze`: 0 errors
4. ✅ Manual test: Accepted orders disappear from nearby screen

---

**Ready to start? Copy this entire task and paste to Amazon Q!**
