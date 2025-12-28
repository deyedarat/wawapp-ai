# WawApp Security Model

## Overview

WawApp uses Firebase Firestore security rules to enforce access control at the database level. All client requests (Flutter apps) are validated against these rules. Cloud Functions bypass these rules and have full admin access.

## Custom Claims

| Claim | Type | Description | Set By |
|-------|------|-------------|--------|
| `isAdmin` | boolean | Grants full admin access to all collections | Cloud Function: `setAdminRole` |
| (none) | - | Regular users (clients/drivers) have no custom claims | N/A |

## Collection Access Matrix

### 🔐 `/users/{uid}` - User Profiles

| Operation | Unauthenticated | Own Document | Other Users | Admin |
|-----------|----------------|--------------|-------------|-------|
| **Read** | ❌ Denied | ✅ Allowed | ❌ Denied | ✅ Allowed (via admin claim) |
| **List** | ❌ **FIXED** (was allowed) | ❌ Denied | ❌ Denied | ✅ Allowed |
| **Create** | ❌ Denied | ✅ Allowed | ❌ Denied | ✅ Allowed |
| **Update** | ❌ Denied | ✅ Allowed* | ❌ Denied | ✅ Allowed |
| **Delete** | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied (use Cloud Functions) |

**Update restrictions:**
- ❌ Cannot modify `totalTrips` (admin-only)
- ❌ Cannot modify `averageRating` (admin-only)
- ❌ Cannot partially update PIN (must update both `pinHash` and `pinSalt` together)

**Security Notes:**
- Prevents phone enumeration attacks by denying list queries
- PIN integrity enforced (hash + salt must be updated atomically)

---

### 🚗 `/drivers/{driverId}` - Driver Profiles

| Operation | Unauthenticated | Own Document | Other Drivers | Admin |
|-----------|----------------|--------------|---------------|-------|
| **Read** | ❌ Denied | ✅ Allowed | ❌ **FIXED** (was allowed) | ✅ Allowed |
| **List** | ❌ **FIXED** (was allowed) | ❌ Denied | ❌ Denied | ✅ Allowed |
| **Create** | ❌ Denied | ✅ Allowed | ❌ Denied | ✅ Allowed |
| **Update** | ❌ Denied | ✅ Allowed* | ❌ Denied | ✅ Allowed |
| **Delete** | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied (use Cloud Functions) |

**Update restrictions:**
- ❌ Cannot modify `isVerified` (admin-only)
- ❌ Cannot modify `rating` (calculated by Cloud Functions)
- ❌ Cannot modify `totalTrips` (calculated by Cloud Functions)
- ❌ Cannot modify `ratedOrders` (calculated by Cloud Functions)

**Security Fixes:**
- **CRITICAL:** Removed `|| true` logic that allowed ANY authenticated user to read ANY driver
- Prevents phone enumeration by denying unauthenticated list queries

---

### 👤 `/clients/{clientId}` - Client Profiles

| Operation | Unauthenticated | Own Document | Other Clients | Admin |
|-----------|----------------|--------------|---------------|-------|
| **Read** | ❌ Denied | ✅ Allowed | ❌ Denied | ✅ Allowed |
| **List** | ❌ Denied | ❌ Denied | ❌ Denied | ✅ Allowed |
| **Create** | ❌ Denied | ✅ Allowed | ❌ Denied | ✅ Allowed |
| **Update** | ❌ Denied | ✅ Allowed* | ❌ Denied | ✅ Allowed |
| **Delete** | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied (use Cloud Functions) |

**Update restrictions:**
- ❌ Cannot modify `isVerified` (admin-only)
- ❌ Cannot modify `totalTrips` (admin-only)
- ❌ Cannot modify `averageRating` (admin-only)

---

### 📦 `/orders/{orderId}` - Order Documents

| Operation | Unauthenticated | Owner | Assigned Driver | Other Users | Admin |
|-----------|----------------|-------|-----------------|-------------|-------|
| **Read** | ❌ Denied | ✅ Allowed | ✅ Allowed | ✅ If status='matching' | ✅ Allowed |
| **List** | ❌ Denied | ✅ Own orders | ✅ Assigned orders | ✅ If status='matching' | ✅ Allowed |
| **Create** | ❌ Denied | ✅ Allowed* | ❌ Denied | ❌ Denied | ✅ Allowed |
| **Update** | ❌ Denied | ✅ Allowed** | ✅ Allowed** | ❌ Denied | ✅ Allowed |
| **Delete** | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied | ❌ Denied (soft delete via status) |

**Create restrictions:**
- Must set `status: "matching"`
- Must set `ownerId: request.auth.uid` (own order)
- Must provide valid `price >= 0`
- Must provide `0 <= distanceKm < 100`
- Must provide valid coordinates (`-90 <= lat <= 90`, `-180 <= lng <= 180`)
- Must provide non-empty `pickupAddress` and `dropoffAddress`

**Update restrictions:**
- ❌ Cannot modify `price` after creation
- ❌ Cannot modify `ownerId`
- ✅ Can update `status` only via valid transitions:
  - `matching` → `accepted`, `cancelled`, `cancelledByClient`, `cancelledByDriver`
  - `accepted` → `onRoute`, `cancelled`, `cancelledByClient`, `cancelledByDriver`
  - `onRoute` → `completed`, `cancelled`, `cancelledByDriver`
- ✅ Owner can add rating (1-5 stars) when `status == 'completed'`
- ✅ Driver can accept order (`status: matching → accepted`, set `driverId`)
- ✅ Driver can update status for assigned orders
- ✅ Owner can cancel (`cancelledByClient`)

**Discovery:**
- Orders with `status == "matching"` are visible to all authenticated users (for driver discovery)
- Once accepted, only owner and assigned driver can read

---

### 📍 `/driver_locations/{driverId}` - Real-Time Driver Locations

| Operation | Unauthenticated | Any Authenticated User | Driver (own) | Admin |
|-----------|----------------|------------------------|--------------|-------|
| **Read** | ❌ Denied | ✅ Allowed | ✅ Allowed | ✅ Allowed |
| **Write** | ❌ Denied | ❌ Denied | ✅ Allowed (own doc) | ✅ Allowed |

**Purpose:** Real-time location tracking for order matching. Any authenticated user can read to find nearby drivers.

---

### 💰 `/wallets/{walletId}` - Driver Wallets (Phase 5)

| Operation | Unauthenticated | Wallet Owner (Driver) | Other Users | Admin |
|-----------|----------------|----------------------|-------------|-------|
| **Read** | ❌ Denied | ✅ Allowed | ❌ Denied | ✅ Allowed |
| **Write** | ❌ Denied | ❌ **Denied** (Cloud Functions only) | ❌ Denied | ❌ **Denied** (Cloud Functions only) |

**Security:** All wallet modifications (balance updates, withdrawals) must go through Cloud Functions to ensure transaction integrity.

---

### 🧾 `/transactions/{transactionId}` - Transaction History (Phase 5)

| Operation | Unauthenticated | Wallet Owner | Other Users | Admin |
|-----------|----------------|--------------|-------------|-------|
| **Read** | ❌ Denied | ✅ Allowed (if `walletId == uid`) | ❌ Denied | ✅ Allowed |
| **Write** | ❌ Denied | ❌ **Denied** (Cloud Functions only) | ❌ Denied | ❌ **Denied** (Cloud Functions only) |

**Security:** Transactions are append-only via Cloud Functions. No client can create/modify/delete transactions.

---

### 💸 `/payouts/{payoutId}` - Payout Requests (Phase 5)

| Operation | Unauthenticated | Driver (own payouts) | Other Users | Admin |
|-----------|----------------|----------------------|-------------|-------|
| **Read** | ❌ Denied | ✅ Allowed (if `driverId == uid`) | ❌ Denied | ✅ Allowed |
| **Write** | ❌ Denied | ❌ **Denied** (Cloud Functions only) | ❌ Denied | ✅ Allowed |

**Workflow:** Drivers request payouts via Cloud Functions. Admins approve/reject via admin panel (Cloud Functions).

---

### 👑 `/admins/{adminId}` - Admin Users

| Operation | Unauthenticated | Regular Users | Admin |
|-----------|----------------|---------------|-------|
| **Read** | ❌ Denied | ❌ Denied | ✅ Allowed |
| **Write** | ❌ Denied | ❌ **Denied** (Cloud Functions only) | ❌ **Denied** (Cloud Functions only) |

**Security:** Admin roles are managed exclusively through Cloud Functions (`setAdminRole`, `removeAdminRole`). No client SDK access.

---

### 📝 `/users/{uid}/savedLocations/{locationId}` - Saved Locations Subcollection

| Operation | Owner | Other Users | Admin |
|-----------|-------|-------------|-------|
| **Read** | ✅ Allowed | ❌ Denied | ✅ Allowed |
| **Create** | ✅ Allowed* | ❌ Denied | ✅ Allowed |
| **Update** | ✅ Allowed* | ❌ Denied | ✅ Allowed |
| **Delete** | ✅ Allowed | ❌ Denied | ✅ Allowed |

**Validation:**
- `lat` must be number, `-90 <= lat <= 90`
- `lng` must be number, `-180 <= lng <= 180`
- `label` must be non-empty string

---

## Security Principles

### 1. Defense in Depth
- ✅ Client SDK requests validated by Firestore rules
- ✅ Cloud Functions bypass rules but implement business logic validation
- ✅ Admin actions require custom claims (`isAdmin: true`)

### 2. Least Privilege
- Users can only access their own documents
- Admin-only fields cannot be modified by clients
- Financial operations (wallets, transactions) are Cloud Functions-only

### 3. Data Integrity
- Status transitions validated (can't skip from `matching` to `completed`)
- Immutable fields enforced (price, ownerId cannot change)
- Atomic updates required (PIN hash + salt together)

### 4. Privacy Protection
- ❌ Phone enumeration prevented (no unauthenticated list queries)
- ❌ Cross-user data access denied
- ✅ Sensitive fields (PIN hash, wallet balance) protected

### 5. Audit Trail
- Cloud Functions log all admin actions
- Transactions are append-only (no updates/deletes)
- Order status changes tracked with timestamps

---

## Common Attack Vectors (Mitigated)

### ❌ Phone Number Enumeration
**Attack:** Query `/users` or `/drivers` collection to discover which phone numbers are registered.

**Mitigation:**
- Removed `allow list: if request.auth == null;` from `/users` and `/drivers`
- Phone number lookups must use Cloud Functions with rate limiting

### ❌ Privilege Escalation
**Attack:** Modify `isVerified`, `isAdmin`, or `totalTrips` fields to gain elevated privileges.

**Mitigation:**
- Admin-only fields cannot be modified by clients (enforced in rules)
- Custom claims (`isAdmin`) are set via Cloud Functions only

### ❌ Financial Fraud
**Attack:** Directly modify wallet balance or create fake transactions.

**Mitigation:**
- All writes to `/wallets` and `/transactions` denied for client SDK
- Only Cloud Functions can modify financial data

### ❌ Order Hijacking
**Attack:** Accept someone else's order or modify price after acceptance.

**Mitigation:**
- `price` and `ownerId` are immutable after creation
- Only assigned driver can update order status after acceptance

### ❌ Cross-User Data Access
**Attack:** Read other users' profiles, orders, or wallets.

**Mitigation:**
- Strict ownership checks: `request.auth.uid == documentId`
- Orders only visible to owner, assigned driver, or if status == "matching"

---

## Testing

All security rules are tested using Firebase Emulator. See `firestore-rules-tests/` directory.

**Run tests:**
```bash
cd firestore-rules-tests
npm install
npm test
```

**Test coverage:** 57 tests covering all collections and access patterns.

---

## Emergency Security Response

If a security vulnerability is discovered:

1. **Immediate:** Deploy restrictive rules via Firebase Console
2. **Within 1 hour:** Investigate scope of breach (check Firestore audit logs)
3. **Within 4 hours:** Deploy fix and verify with tests
4. **Within 24 hours:** Notify affected users if data was compromised
5. **Post-mortem:** Document incident and update security model

**Emergency contact:** `security@wawapp.mr`

---

## Changelog

### 2025-12-22 - BLOCKER-5 Security Fixes
- **CRITICAL:** Removed unauthenticated list access to `/users` and `/drivers` (phone enumeration fix)
- **CRITICAL:** Fixed over-permissive driver read rule (removed `|| true` logic)
- Added comprehensive automated security tests (57 test cases)
- Documented complete security model

### Previous
- Initial security rules implementation
- Admin custom claims support
- Wallet & transaction read-only enforcement
