# Q TASK 4B: Order Model - Add Customer Phone Field

**Part:** B of 3
**Time:** 15 minutes

---

## Objective
Add `customerPhone` field to the Order model so Flutter app can parse and use it.

---

## File to Modify

### `packages/core_shared/lib/src/order.dart`

---

## Implementation Steps

### Step 1: Add Field to Class

Find the Order class definition (around line 6-56) and add the new field:

```dart
class Order {
  final String? id;
  final String? ownerId;
  final double distanceKm;
  final double price;

  // Address fields (from Client app)
  final String pickupAddress;
  final String dropoffAddress;

  // Location coordinates
  final LocationPoint pickup;
  final LocationPoint dropoff;

  final String? status;
  final String? driverId;

  // Driver-specific field: separate assigned driver tracking
  final String? assignedDriverId;

  // ADD THIS FIELD:
  /// Customer's phone number (only available after driver acceptance)
  final String? customerPhone;

  // Timestamps
  final DateTime? createdAt;
  // ... rest of fields
```

---

### Step 2: Update Constructor

Add `customerPhone` to the constructor parameters:

```dart
const Order({
  this.id,
  this.ownerId,
  required this.distanceKm,
  required this.price,
  required this.pickupAddress,
  required this.dropoffAddress,
  required this.pickup,
  required this.dropoff,
  this.status,
  this.driverId,
  this.assignedDriverId,
  this.customerPhone,  // ADD THIS LINE
  this.createdAt,
  this.updatedAt,
  this.completedAt,
  this.driverRating,
  this.ratedAt,
  this.weightTons = 0.5,
});
```

---

### Step 3: Update `fromFirestore` Factory

In the `fromFirestore` method (around line 63-90), add parsing:

```dart
factory Order.fromFirestore(Map<String, dynamic> data) {
  final pickupData = data['pickup'] as Map<String, dynamic>;
  final dropoffData = data['dropoff'] as Map<String, dynamic>;

  return Order(
    id: data['id'] as String?,
    ownerId: data['ownerId'] as String?,
    distanceKm: (data['distanceKm'] as num).toDouble(),
    price: (data['price'] as num).toDouble(),
    pickupAddress: data['pickupAddress'] as String? ??
        pickupData['label'] as String? ??
        '',
    dropoffAddress: data['dropoffAddress'] as String? ??
        dropoffData['label'] as String? ??
        '',
    pickup: LocationPoint.fromMap(pickupData),
    dropoff: LocationPoint.fromMap(dropoffData),
    status: data['status'] as String?,
    driverId: data['driverId'] as String?,
    assignedDriverId: data['assignedDriverId'] as String?,
    customerPhone: data['customerPhone'] as String?,  // ADD THIS LINE
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    driverRating: data['driverRating'] as int?,
    ratedAt: (data['ratedAt'] as Timestamp?)?.toDate(),
    weightTons: (data['weightTons'] as num?)?.toDouble() ?? 0.5,
  );
}
```

---

### Step 4: Update `fromFirestoreWithId` Factory

In the `fromFirestoreWithId` method (around line 94-121), add the same line:

```dart
factory Order.fromFirestoreWithId(String id, Map<String, dynamic> data) {
  final pickupData = data['pickup'] as Map<String, dynamic>;
  final dropoffData = data['dropoff'] as Map<String, dynamic>;

  return Order(
    id: id,
    ownerId: data['ownerId'] as String?,
    distanceKm: (data['distanceKm'] as num).toDouble(),
    price: (data['price'] as num).toDouble(),
    pickupAddress: data['pickupAddress'] as String? ??
        pickupData['label'] as String? ??
        '',
    dropoffAddress: data['dropoffAddress'] as String? ??
        dropoffData['label'] as String? ??
        '',
    pickup: LocationPoint.fromMap(pickupData),
    dropoff: LocationPoint.fromMap(dropoffData),
    status: data['status'] as String?,
    driverId: data['driverId'] as String?,
    assignedDriverId: data['assignedDriverId'] as String?,
    customerPhone: data['customerPhone'] as String?,  // ADD THIS LINE
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    driverRating: data['driverRating'] as int?,
    ratedAt: (data['ratedAt'] as Timestamp?)?.toDate(),
    weightTons: (data['weightTons'] as num?)?.toDouble() ?? 0.5,
  );
}
```

---

### Step 5: Update `toMap` Method

In the `toMap()` method (around line 123-142), add the field:

```dart
Map<String, dynamic> toMap() => {
      'id': id,
      'ownerId': ownerId,
      'distanceKm': distanceKm,
      'price': price,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'pickup': pickup.toMap(),
      'dropoff': dropoff.toMap(),
      'status': status,
      'driverId': driverId,
      'assignedDriverId': assignedDriverId,
      'customerPhone': customerPhone,  // ADD THIS LINE
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'driverRating': driverRating,
      'ratedAt': ratedAt != null ? Timestamp.fromDate(ratedAt!) : null,
      'weightTons': weightTons,
    };
```

---

### Step 6: Update `copyWith` Method

In the `copyWith()` method (around line 144-182), add the parameter and logic:

```dart
Order copyWith({
  String? id,
  String? ownerId,
  double? distanceKm,
  double? price,
  String? pickupAddress,
  String? dropoffAddress,
  LocationPoint? pickup,
  LocationPoint? dropoff,
  String? status,
  String? driverId,
  String? assignedDriverId,
  String? customerPhone,  // ADD THIS PARAMETER
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? completedAt,
  int? driverRating,
  DateTime? ratedAt,
  double? weightTons,
}) {
  return Order(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    distanceKm: distanceKm ?? this.distanceKm,
    price: price ?? this.price,
    pickupAddress: pickupAddress ?? this.pickupAddress,
    dropoffAddress: dropoffAddress ?? this.dropoffAddress,
    pickup: pickup ?? this.pickup,
    dropoff: dropoff ?? this.dropoff,
    status: status ?? this.status,
    driverId: driverId ?? this.driverId,
    assignedDriverId: assignedDriverId ?? this.assignedDriverId,
    customerPhone: customerPhone ?? this.customerPhone,  // ADD THIS LINE
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt ?? this.completedAt,
    driverRating: driverRating ?? this.driverRating,
    ratedAt: ratedAt ?? this.ratedAt,
    weightTons: weightTons ?? this.weightTons,
  );
}
```

---

## Summary

**Changes made:**
1. ✅ Added `final String? customerPhone;` field
2. ✅ Added to constructor parameters
3. ✅ Added to `fromFirestore` parsing
4. ✅ Added to `fromFirestoreWithId` parsing
5. ✅ Added to `toMap()` serialization
6. ✅ Added to `copyWith()` method

---

## Testing

```bash
cd packages/core_shared
flutter analyze
```

Expected: **0 errors**

Also test in driver app:
```bash
cd apps/wawapp_driver
flutter analyze
```

Expected: **0 errors**

---

## Verification

After this change:
- Order objects can now hold `customerPhone`
- Backward compatible (nullable field)
- No breaking changes to existing code

---

## Report Back to Claude

✅ Modified: `packages/core_shared/lib/src/order.dart`
✅ Added: `customerPhone` field to Order class
✅ Updated: All 5 required locations (field, constructor, fromFirestore, toMap, copyWith)
✅ `flutter analyze`: 0 errors in core_shared
✅ `flutter analyze`: 0 errors in wawapp_driver

---

**Next:** Proceed to Part C - Display Phone in UI
