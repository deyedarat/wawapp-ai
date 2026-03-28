# WawApp Firestore Schema - Admin View

This document describes the Firestore collections and their structure for admin panel integration.

## Collections

### `orders`

Order documents for the WawApp platform.

**Fields:**
- `id` (string) - Auto-generated document ID
- `ownerId` (string) - Client user ID who created the order
- `status` (string) - Order status: `assigning`, `accepted`, `on_route`, `completed`, `cancelled`, `cancelled_by_admin`, `cancelled_by_driver`, `cancelled_by_client`
- `driverId` (string, nullable) - Assigned driver user ID
- `assignedDriverId` (string, nullable) - Same as driverId (legacy field)
- `distanceKm` (number) - Distance in kilometers
- `price` (number) - Order price in MRU
- `pickupAddress` (string) - Pickup location address
- `dropoffAddress` (string) - Dropoff location address
- `pickup` (map) - Pickup location coordinates
  - `lat` (number)
  - `lng` (number)
  - `label` (string)
- `dropoff` (map) - Dropoff location coordinates
  - `lat` (number)
  - `lng` (number)
  - `label` (string)
- `createdAt` (timestamp) - Order creation time
- `updatedAt` (timestamp) - Last update time
- `completedAt` (timestamp, nullable) - Completion time
- `cancelledAt` (timestamp, nullable) - Cancellation time
- `cancelledBy` (string, nullable) - User ID who cancelled
- `cancellationReason` (string, nullable) - Reason for cancellation
- `driverRating` (number, nullable) - Driver rating (1-5)
- `ratedAt` (timestamp, nullable) - Rating timestamp

**Indexes Required:**
- `status ASC, assignedDriverId ASC, createdAt DESC` - For nearby orders query
- `driverId ASC, status ASC` - For driver's active orders
- `ownerId ASC, createdAt DESC` - For client's order history

---

### `drivers`

Driver profiles and status.

**Fields:**
- `id` (string) - Document ID (matches Firebase Auth UID)
- `name` (string) - Driver full name
- `phone` (string) - Phone number in E.164 format (+222XXXXXXXX)
- `photoUrl` (string, nullable) - Profile photo URL
- `vehicleType` (string, nullable) - Vehicle type/model
- `vehiclePlate` (string, nullable) - License plate number
- `vehicleColor` (string, nullable) - Vehicle color
- `city` (string, nullable) - Driver's city
- `region` (string, nullable) - Driver's region
- `isVerified` (boolean) - Admin verification status
- `isOnline` (boolean) - Currently online/offline
- `isBlocked` (boolean) - Blocked by admin
- `blockedAt` (timestamp, nullable) - When blocked
- `blockedBy` (string, nullable) - Admin UID who blocked
- `blockReason` (string, nullable) - Reason for blocking
- `rating` (number) - Average rating (0.0-5.0)
- `totalTrips` (number) - Total completed trips
- `createdAt` (timestamp) - Account creation time
- `updatedAt` (timestamp) - Last update time
- `lastOnlineAt` (timestamp, nullable) - Last time driver went online

**Indexes Required:**
- `isOnline ASC, createdAt DESC`
- `isBlocked ASC, createdAt DESC`

---

### `clients`

Client profiles and information.

**Fields:**
- `id` (string) - Document ID (matches Firebase Auth UID)
- `name` (string) - Client full name
- `phone` (string) - Phone number in E.164 format
- `photoUrl` (string, nullable) - Profile photo URL
- `preferredLanguage` (string) - Language preference ('ar', 'fr')
- `isVerified` (boolean) - Admin verification status
- `isBlocked` (boolean) - Blocked by admin (optional field)
- `blockedAt` (timestamp, nullable) - When blocked
- `blockedBy` (string, nullable) - Admin UID who blocked
- `blockReason` (string, nullable) - Reason for blocking
- `totalTrips` (number) - Total completed trips
- `averageRating` (number) - Average rating given to drivers
- `createdAt` (timestamp) - Account creation time
- `updatedAt` (timestamp) - Last update time
- `verifiedAt` (timestamp, nullable) - When verified
- `verifiedBy` (string, nullable) - Admin UID who verified

**Indexes Required:**
- `isVerified ASC, createdAt DESC`
- `createdAt DESC`

---

### `admin_actions`

Audit log for admin actions.

**Fields:**
- `action` (string) - Action type: `cancelOrder`, `blockDriver`, `unblockDriver`, `verifyClient`, `setAdminRole`, etc.
- `performedBy` (string) - Admin user ID who performed the action
- `performedAt` (timestamp) - When the action was performed
- `orderId` (string, nullable) - Related order ID
- `driverId` (string, nullable) - Related driver ID
- `clientId` (string, nullable) - Related client ID
- `reason` (string, nullable) - Reason for the action
- `previousStatus` (string, nullable) - Previous status before change
- Additional action-specific fields

**Indexes Required:**
- `performedAt DESC`
- `performedBy ASC, performedAt DESC`
- `action ASC, performedAt DESC`

---

## Status Enums

### Order Status Values

1. `assigning` - Order created, waiting for driver assignment
2. `accepted` - Driver accepted the order
3. `on_route` - Driver is on the way
4. `completed` - Order successfully completed
5. `cancelled` - General cancellation
6. `cancelled_by_admin` - Cancelled by admin
7. `cancelled_by_driver` - Cancelled by driver
8. `cancelled_by_client` - Cancelled by client

### Status Transitions

- `assigning` → `accepted` (driver accepts)
- `assigning` → `cancelled_*` (cancellation)
- `accepted` → `on_route` (driver starts trip)
- `accepted` → `cancelled_*` (cancellation)
- `on_route` → `completed` (delivery complete)
- `on_route` → `cancelled_*` (cancellation)

---

## Security Rules

Admin actions require custom claims:
```javascript
{
  isAdmin: true,
  role: "admin"
}
```

Firestore rules should check:
```javascript
request.auth.token.isAdmin == true
```

For admin-level read/write operations.

---

## Phone Number Format

All phone numbers are stored in E.164 format for Mauritania:
- Format: `+222XXXXXXXX`
- Local: 8 digits
- Prefixes:
  - `2` - Chinguitel
  - `3` - Mattel  
  - `4` - Mauritel

---

## Notes

- All timestamps use Firestore `FieldValue.serverTimestamp()`
- Deleted fields use `FieldValue.delete()`
- Queries use composite indexes for performance
- Admin actions are logged for audit trail
- Blocked users should be prevented from taking actions in the app
