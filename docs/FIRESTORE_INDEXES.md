# Firestore Composite Indexes - WawApp

## Overview

This document lists all required Firestore composite indexes for the WawApp client and driver applications. These indexes must be deployed to Firebase before running queries in production to avoid "missing index" runtime errors.

---

## Quick Deployment

### Method 1: Firebase CLI (Recommended)

```bash
# From repository root
firebase deploy --only firestore:indexes
```

This command reads `firestore.indexes.json` and creates all defined indexes automatically.

### Method 2: Manual Creation via Console

Visit [Firebase Console - Firestore Indexes](https://console.firebase.google.com/project/_/firestore/indexes) and create each index manually following the specifications below.

---

## Required Composite Indexes

### Index #1: Status + CreatedAt (Legacy)

**Collection**: `orders`
**Fields**:
- `status` (Ascending)
- `createdAt` (Descending)

**Used By**: Legacy/Unused (may be removed in future)
**Status**: ✅ EXISTS

---

### Index #2: Driver Completed Orders

**Collection**: `orders`
**Fields**:
- `driverId` (Ascending)
- `status` (Ascending)
- `completedAt` (Descending)

**Used By**:
- `apps/wawapp_driver/lib/features/history/data/driver_history_repository.dart:watchCompletedOrders()`
- `apps/wawapp_driver/lib/features/earnings/data/driver_earnings_repository.dart:watchCompletedOrdersForDriver()`

**Query Example**:
```dart
_firestore
  .collection('orders')
  .where('driverId', isEqualTo: driverId)
  .where('status', isEqualTo: 'completed')
  .orderBy('completedAt', descending: true)
```

**Status**: ✅ EXISTS

---

### Index #3: Nearby Orders Matching

**Collection**: `orders`
**Fields**:
- `status` (Ascending)
- `assignedDriverId` (Ascending)
- `createdAt` (Descending)

**Used By**:
- `apps/wawapp_driver/lib/services/orders_service.dart:getNearbyOrders()`

**Query Example**:
```dart
_firestore
  .collection('orders')
  .where('status', isEqualTo: 'matching')
  .where('assignedDriverId', isNull: true)
  .orderBy('createdAt', descending: true)
```

**Status**: ⚠️ **NEWLY ADDED** - Deploy required

**Critical**: This index is essential for the driver matching system. Without it, drivers will not be able to fetch nearby available orders.

---

### Index #4: Client Order History

**Collection**: `orders`
**Fields**:
- `ownerId` (Ascending)
- `createdAt` (Descending)

**Used By**:
- `apps/wawapp_client/lib/features/track/data/orders_repository.dart:getUserOrders()`

**Query Example**:
```dart
_firestore
  .collection('orders')
  .where('ownerId', isEqualTo: userId)
  .orderBy('createdAt', descending: true)
```

**Status**: ⚠️ **NEWLY ADDED** - Deploy required

**Note**: Required for client-side order history feature (currently partially implemented).

---

### Index #5: Client Order History by Status

**Collection**: `orders`
**Fields**:
- `ownerId` (Ascending)
- `status` (Ascending)
- `createdAt` (Descending)

**Used By**:
- `apps/wawapp_client/lib/features/track/data/orders_repository.dart:getUserOrdersByStatus()`

**Query Example**:
```dart
_firestore
  .collection('orders')
  .where('ownerId', isEqualTo: userId)
  .where('status', isEqualTo: 'completed')
  .orderBy('createdAt', descending: true)
```

**Status**: ⚠️ **NEWLY ADDED** - Deploy required

---

### Index #6: Driver Active Orders

**Collection**: `orders`
**Fields**:
- `driverId` (Ascending)
- `status` (Ascending)

**Used By**:
- `apps/wawapp_driver/lib/services/orders_service.dart:getDriverActiveOrders()`

**Query Example**:
```dart
_firestore
  .collection('orders')
  .where('driverId', isEqualTo: driverId)
  .where('status', whereIn: ['accepted', 'onRoute'])
```

**Status**: ⚠️ **NEWLY ADDED** - Deploy required

**Note**: `whereIn` queries typically auto-create simple indexes, but explicit definition ensures consistency.

---

## Deployment Instructions

### Step 1: Verify firestore.indexes.json

Ensure `firestore.indexes.json` at repository root contains all 6 indexes listed above.

**Current file location**: `C:\Users\hp\Music\WawApp\firestore.indexes.json`

### Step 2: Deploy via Firebase CLI

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Deploy indexes from repository root
cd C:\Users\hp\Music\WawApp
firebase deploy --only firestore:indexes
```

### Step 3: Wait for Index Build

After deployment, Firebase will build the indexes. This process can take:
- **Empty collection**: ~1-2 minutes
- **Small dataset (<1000 docs)**: ~5-10 minutes
- **Large dataset (>10k docs)**: 30+ minutes

Monitor build status in [Firebase Console - Indexes tab](https://console.firebase.google.com/project/_/firestore/indexes).

### Step 4: Verify Index Status

All indexes should show status: **Enabled (green checkmark)**

---

## Troubleshooting

### Error: "The query requires an index"

**Symptoms**: Runtime exception when executing a Firestore query:
```
[cloud_firestore/failed-precondition] The query requires an index. You can create it here: https://console.firebase.google.com/...
```

**Solution**:
1. Click the provided link to create the index manually
2. OR: Update `firestore.indexes.json` and redeploy
3. Wait for index to finish building

### Error: "Index already exists"

**Symptoms**: Deployment fails with "index already exists" error

**Solution**: This is safe to ignore. Firebase CLI detects existing indexes and skips them.

### Slow Query Performance

**Symptoms**: Queries take >2 seconds to return results

**Possible Causes**:
1. Missing index (check logs for index warnings)
2. Index still building (check Firebase Console)
3. Large result set without pagination
4. Network latency

**Solutions**:
- Verify all indexes are **Enabled** in Firebase Console
- Implement pagination with `limit()` and `startAfter()`
- Use Firestore emulator for local development

---

## Index Maintenance

### When to Update Indexes

Add or modify indexes when:
1. Adding new Firestore queries with multiple filters
2. Combining `.where()` with `.orderBy()`
3. Using multiple `.where()` clauses on different fields
4. Receiving "missing index" errors in production logs

### Testing Index Requirements

Before deploying new queries:

```dart
// Test locally with Firestore emulator
// Run: firebase emulators:start --only firestore

// The emulator will auto-suggest required indexes in console output
```

### Index Cleanup

Periodically review and remove unused indexes to reduce storage costs:

```bash
# List all indexes
firebase firestore:indexes

# Delete unused index (use Firebase Console for safety)
```

---

## Security Considerations

### Index vs Security Rules

**Important**: Indexes do NOT enforce security. Always configure Firestore Security Rules (`firestore.rules`) to protect data.

Example:
```javascript
// Even with index on ownerId, this rule prevents unauthorized access
match /orders/{orderId} {
  allow read: if request.auth.uid == resource.data.ownerId;
}
```

### Sensitive Field Indexing

Avoid indexing sensitive fields unless absolutely necessary:
- ❌ PINs, passwords, tokens
- ❌ Full phone numbers (use hashed values)
- ✅ Status, timestamps, IDs

---

## Query Performance Tips

### Use Pagination

```dart
// Bad: Fetches ALL orders
_firestore.collection('orders').where('ownerId', isEqualTo: uid).get();

// Good: Limit results + use cursor pagination
_firestore
  .collection('orders')
  .where('ownerId', isEqualTo: uid)
  .orderBy('createdAt', descending: true)
  .limit(20)
  .startAfter(lastDocument)
  .get();
```

### Limit Real-Time Listeners

```dart
// Expensive: Live updates on all orders
_firestore.collection('orders').snapshots();

// Better: Filter + limit
_firestore
  .collection('orders')
  .where('status', isEqualTo: 'matching')
  .limit(50)
  .snapshots();
```

### Cache Strategy

Enable persistence for offline support:

```dart
// In main.dart after Firebase initialization
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

---

## Summary Checklist

Before production deployment, verify:

- [ ] All 6 indexes defined in `firestore.indexes.json`
- [ ] Indexes deployed via `firebase deploy --only firestore:indexes`
- [ ] All indexes show **Enabled** status in Firebase Console
- [ ] No "missing index" errors in test environment
- [ ] Security rules prevent unauthorized access
- [ ] Queries use pagination where appropriate

---

## References

- [Firestore Index Documentation](https://firebase.google.com/docs/firestore/query-data/indexing)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [Query Best Practices](https://firebase.google.com/docs/firestore/best-practices)
- [WawApp Firestore Rules](../firestore.rules)

---

**Last Updated**: 2025-11-21
**Project**: WawApp v1.0
**Maintained By**: Development Team
