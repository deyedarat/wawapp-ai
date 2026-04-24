# Patch Plan: R-014 — Add `cancelledByAdmin` to Flutter State Machine

## Objective

Prevent Flutter crash when reading orders cancelled by admin (`status: 'cancelled_by_admin'`).

## Change (1 file, 6 edits)

### File: `packages/core_shared/lib/src/order_status.dart`

| Edit | Location | Change | Regression risk |
|------|----------|--------|-----------------|
| 1 | After `cancelledBySystem` enum value (L40) | Add `cancelledByAdmin,` | Any exhaustive `switch` without `default` will fail to compile — intentional, forces handling |
| 2 | `fromFirestore()` — after `cancelledBySystem` case (L71) | Add `case 'cancelled_by_admin': return OrderStatus.cancelledByAdmin;` | None — additive parser case |
| 3 | `toFirestore()` — after `cancelledBySystem` case (L97) | Add `case OrderStatus.cancelledByAdmin: return 'cancelled_by_admin';` | None — matches backend string exactly |
| 4 | `toArabicLabel()` — after `cancelledBySystem` case (L120) | Add `case OrderStatus.cancelledByAdmin: return 'ألغي من الإدارة';` | None — display only |
| 5 | `canTransitionTo()` — after `cancelledBySystem` entry (L166) | Add `OrderStatus.cancelledByAdmin: <OrderStatus>[],` | None — terminal status, no outgoing transitions |
| 6 | `createTransitionUpdate()` — cancelledAt guard (L193-195) | Add `this == OrderStatus.cancelledByAdmin` to the condition | None — ensures cancelledAt timestamp is set |

## Revert

```
git checkout HEAD -- packages/core_shared/lib/src/order_status.dart
```

## Verification

| Check | Method | Result |
|-------|--------|--------|
| Dart analysis (order_status.dart) | `dart analyze` | ✅ "No issues found!" |
| Dart analysis (active_order_screen.dart) | `dart analyze` | ✅ Zero errors (3 pre-existing infos) — `default:` case handles new enum |
| Enum value present | `findstr Admin` → L43 | ✅ `cancelledByAdmin,` |
| Parser present | L75-76 | ✅ `case 'cancelled_by_admin': return OrderStatus.cancelledByAdmin;` |
| Serializer present | L103-104 | ✅ `case OrderStatus.cancelledByAdmin: return 'cancelled_by_admin';` |
| Arabic label present | L129 | ✅ `'ألغي من الإدارة'` |
| Transition map present | L176 | ✅ `OrderStatus.cancelledByAdmin: <OrderStatus>[]` (terminal) |
| cancelledAt guard present | L206 | ✅ Added to the `||` chain |

### Before vs After

**Before**: `OrderStatus.fromFirestore('cancelled_by_admin')` → `throw ArgumentError('Unknown order status: cancelled_by_admin')` → **app crash**

**After**: `OrderStatus.fromFirestore('cancelled_by_admin')` → `OrderStatus.cancelledByAdmin` → renders as "ألغي من الإدارة" in UI → **no crash**
