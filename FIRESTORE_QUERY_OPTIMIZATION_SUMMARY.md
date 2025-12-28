# Firestore Query Optimization Summary

## Changes Made

### 1. Orders Service (`apps/wawapp_driver/lib/services/orders_service.dart`)

**Updated `getNearbyOrders()` method:**
- ✅ Added `assignedDriverId` null filter to ensure only unassigned orders are returned
- ✅ Added `orderBy('createdAt', descending: true)` to show newest orders first
- ✅ Enhanced debug logging to show all query filters and results
- ✅ Added safety check to double-verify orders are unassigned
- ✅ Added comprehensive error handling for missing indexes/fields

**Query Changes:**
```dart
// BEFORE
.where('status', isEqualTo: OrderStatus.assigning.toFirestore())

// AFTER  
.where('status', isEqualTo: statusValue)
.where('assignedDriverId', isNull: true)
.orderBy('createdAt', descending: true)
```

### 2. Order Model (`apps/wawapp_driver/lib/models/order.dart`)

**Added `assignedDriverId` field:**
- ✅ Added `assignedDriverId` property to Order class
- ✅ Updated `fromFirestore()` factory to parse the field
- ✅ Maintains backward compatibility with existing `driverId` field

### 3. OrderStatus Enum (`packages/core_shared/lib/src/order_status.dart`)

**Updated transition logic:**
- ✅ Modified `createTransitionUpdate()` to set both `driverId` and `assignedDriverId` when accepting orders
- ✅ Ensures consistency between the two fields during transitions

### 4. History Repository (`apps/wawapp_driver/lib/features/history/data/driver_history_repository.dart`)

**Fixed hardcoded status:**
- ✅ Replaced hardcoded `'completed'` with `OrderStatus.completed.toFirestore()`
- ✅ Ensures consistency with canonical status values

## Status Field Analysis

### ✅ Canonical Status Field Usage
- **Field Name:** `status` (consistent across all queries)
- **Open for Matching Value:** `'matching'` (via `OrderStatus.assigning.toFirestore()`)
- **All Status Values:** Properly handled through `OrderStatus` enum

### ✅ Query Filters Applied

**Nearby/Matching Orders Query:**
1. `status == 'matching'` - Only orders open for driver assignment
2. `assignedDriverId == null` - Only unassigned orders  
3. `orderBy('createdAt', descending: true)` - Newest orders first
4. Distance filter: `<= 8.0km` (applied in-memory)

**Active Orders Query:**
1. `driverId == currentDriverId` - Driver's assigned orders
2. `status IN ['accepted', 'onRoute']` - Only active statuses

## Debug Logging Enhanced

### ✅ Pre-Query Logging
```dart
dev.log('[Matching] Query filters: status=$statusValue, assignedDriverId=null, maxDistance=8.0km');
```

### ✅ Per-Document Logging  
```dart
dev.log('[Matching] Order ${order.id}: status=${order.status}, assignedDriverId=$assignedDriverId, createdAt=$createdAt, pickup=($pickupLat,$pickupLng), distance=${distance.toStringAsFixed(2)}km, price=${order.price}');
```

### ✅ Result Summary Logging
```dart
dev.log('[Matching] Final result: ${orders.length} matching orders');
```

## Migration Notes

### ⚠️ Required Firestore Schema Updates

1. **Composite Index Required:**
   ```
   Collection: orders
   Fields: status (Ascending), assignedDriverId (Ascending), createdAt (Descending)
   ```

2. **Field Migration:**
   - Ensure all order documents have `assignedDriverId` field
   - For existing orders: `assignedDriverId` should be `null` for unassigned orders
   - For accepted orders: `assignedDriverId` should match `driverId`

3. **Backward Compatibility:**
   - Code maintains both `driverId` and `assignedDriverId` fields
   - Legacy status values are supported through `OrderStatus.fromFirestore()`

### 🔧 Error Handling Added

- **Missing Index:** Detects and logs Firestore index errors
- **Missing Field:** Handles cases where `assignedDriverId` doesn't exist
- **Query Failures:** Graceful fallback to empty results with detailed logging

## Files Modified

1. `apps/wawapp_driver/lib/services/orders_service.dart`
2. `apps/wawapp_driver/lib/models/order.dart` 
3. `packages/core_shared/lib/src/order_status.dart`
4. `apps/wawapp_driver/lib/features/history/data/driver_history_repository.dart`

## Testing Recommendations

1. **Verify Firestore Index:** Ensure composite index is created
2. **Test Query Performance:** Monitor query execution time with new filters
3. **Validate Field Migration:** Confirm all orders have proper `assignedDriverId` values
4. **Test Error Scenarios:** Verify graceful handling of missing fields/indexes