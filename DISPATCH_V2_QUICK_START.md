# ⚡ Dispatch Engine v2.0 — Quick Start

## 🎯 5-Minute Overview

**Before** (v1.0):
```
Order created → Send to ALL drivers → First to accept wins
Problems: Duplicates, spam, unfair
```

**After** (v2.0):
```
Order created → Wave 1 (closest driver, 15s)
              → Wave 2 (3 nearby drivers, 30s)
              → Wave 3 (5 farther drivers, 45s)
Benefits: Zero duplicates, faster acceptance, fair distribution
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     ORDER LIFECYCLE                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Client creates order (status: matching)                    │
│            ↓                                                │
│  notifyNewOrderV2 (Firestore trigger)                       │
│            ↓                                                │
│  enqueueOrder() → dispatch_queue                            │
│            ↓                                                │
│  processNextWave() → wave 1                                 │
│            ↓                                                │
│  ┌──────────────────────────────────────┐                   │
│  │ WAVE 1 (Closest Driver, 15s TTL)     │                   │
│  │  - Send FCM                           │                   │
│  │  - Create dispatch_offer              │                   │
│  │  - Update driver_dispatch_state       │                   │
│  └──────────────────────────────────────┘                   │
│            ↓                                                │
│  Driver accepts?                                            │
│   YES → handleOfferAcceptance()                             │
│         → Update order status                               │
│         → Expire all other offers                           │
│         → Remove from queue                                 │
│   NO  → Wait for expiration                                 │
│            ↓                                                │
│  processExpiredWaves (scheduled, every 30s)                 │
│            ↓                                                │
│  Expire wave 1 offers                                       │
│            ↓                                                │
│  processNextWave() → wave 2                                 │
│            ↓                                                │
│  ┌──────────────────────────────────────┐                   │
│  │ WAVE 2 (3 Nearby Drivers, 30s TTL)   │                   │
│  └──────────────────────────────────────┘                   │
│            ↓                                                │
│  ... repeat until accepted or waves exhausted ...           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📂 File Structure

```
functions/src/dispatch/
├── types.ts           # Type definitions + wave configuration
├── engine.ts          # Core dispatch logic
├── selectors.ts       # Driver eligibility checks
├── notifications.ts   # FCM sending
└── index.ts           # Exports

functions/src/
├── acceptOrder.v2.ts        # Offer-based acceptance
├── notifyNewOrder.v2.ts     # Queue enrollment
├── rejectOffer.ts           # Explicit rejection
└── processExpiredWaves.ts   # Scheduled expiration handler
```

---

## 🔑 Key Concepts

### 1. Dispatch Queue

**Collection**: `dispatch_queue/{orderId}`

**Purpose**: Tracks wave state per order

**Fields**:
```typescript
{
  orderId: string
  currentWave: number          // 0 → 1 → 2 → 3
  totalOffersSent: number
  waveStartedAt: Timestamp
  waveExpiresAt: Timestamp     // Indexed for scheduled processing
  pickupLat, pickupLng, price  // Snapshot for quick access
}
```

---

### 2. Dispatch Offers

**Collection**: `dispatch_offers/{offerId}`

**ID Format**: `{orderId}_{driverId}`

**Purpose**: Individual offer to specific driver

**Lifecycle**:
```
sent → accepted  ✅
    → rejected  ❌
    → expired   ⏱️
    → cancelled 🚫
```

**Fields**:
```typescript
{
  offerId, orderId, driverId
  status: OfferStatus
  round: number               // Wave number (1, 2, 3)
  priority: number            // Within-wave priority (distance-based)
  sentAt, expiresAt, respondedAt
  distance: number            // km from pickup
}
```

---

### 3. Driver Dispatch State

**Collection**: `driver_dispatch_state/{driverId}`

**Purpose**: Single source of truth per driver

**Fields**:
```typescript
{
  driverId: string
  status: 'available' | 'busy' | 'offline'
  activeOfferId: string | null
  activeOrderId: string | null
  acceptanceLock: boolean      // Prevents double-acceptance
  lockExpiresAt: Timestamp
  lastOfferAt: Timestamp
}
```

---

## 🎛️ Configuration

### Wave Setup

Edit `functions/src/dispatch/types.ts`:

```typescript
export const DEFAULT_WAVES: DispatchWave[] = [
  {
    round: 1,
    maxDrivers: 1,      // Send to 1 driver
    ttl: 15,            // 15-second timeout
    maxDistance: 3      // Within 3km
  },
  {
    round: 2,
    maxDrivers: 3,      // Send to 3 drivers
    ttl: 30,            // 30-second timeout
    maxDistance: 8      // Within 8km
  },
  {
    round: 3,
    maxDrivers: 5,      // Send to 5 drivers
    ttl: 45,            // 45-second timeout
    maxDistance: 15     // Within 15km
  },
];
```

### Scheduled Function

Edit `functions/src/processExpiredWaves.ts`:

```typescript
.pubsub.schedule('every 30 seconds')  // Adjust frequency
.runWith({
  timeoutSeconds: 120,                // Max execution time
  memory: '256MB',                    // Memory allocation
})
```

---

## 🔧 Common Tasks

### Task 1: Add a New Wave

```typescript
// In types.ts
export const DEFAULT_WAVES: DispatchWave[] = [
  { round: 1, maxDrivers: 1, ttl: 15, maxDistance: 3 },
  { round: 2, maxDrivers: 3, ttl: 30, maxDistance: 8 },
  { round: 3, maxDrivers: 5, ttl: 45, maxDistance: 15 },
  { round: 4, maxDrivers: 10, ttl: 60, maxDistance: 25 },  // New wave!
];
```

**Deploy**:
```bash
cd functions
npm run build
firebase deploy --only functions
```

---

### Task 2: Change Wave Timing

```typescript
// Faster waves for high-density markets
{ round: 1, maxDrivers: 1, ttl: 10, maxDistance: 2 },   // Was 15s, 3km
{ round: 2, maxDrivers: 3, ttl: 20, maxDistance: 5 },   // Was 30s, 8km

// OR

// Slower waves for low-density markets
{ round: 1, maxDrivers: 1, ttl: 30, maxDistance: 5 },   // Was 15s, 3km
{ round: 2, maxDrivers: 3, ttl: 60, maxDistance: 12 },  // Was 30s, 8km
```

---

### Task 3: Debug Stuck Order

**Symptoms**: Order stuck in `matching` status, no offers sent

**Check**:

1. **Is order in queue?**
   ```
   Firestore → dispatch_queue → {orderId}
   If missing: notifyNewOrderV2 didn't fire
   ```

2. **Are waves expiring?**
   ```
   Check waveExpiresAt timestamp
   If in past: processExpiredWaves should have triggered
   ```

3. **Are drivers eligible?**
   ```
   Functions logs → Search "No eligible drivers"
   Possible causes:
   - No drivers within wave maxDistance
   - All drivers have active orders
   - All drivers offline
   ```

4. **Manual recovery**:
   ```bash
   # Trigger wave manually (via Firebase Console Functions tab)
   firebase functions:shell
   > processExpiredWaves()
   ```

---

### Task 4: Monitor Dispatch Performance

**Query dispatch metrics**:

```javascript
// Firestore query
db.collection('dispatch_metrics')
  .where('acceptedAt', '>=', yesterday)
  .get()
  .then(snapshot => {
    const metrics = snapshot.docs.map(doc => doc.data());

    // Average time to accept
    const avgTime = metrics.reduce((sum, m) => sum + m.timeToAcceptSeconds, 0) / metrics.length;

    // Acceptance rate by wave
    const wave1 = metrics.filter(m => m.acceptedAtWave === 1).length;
    const wave2 = metrics.filter(m => m.acceptedAtWave === 2).length;
    const wave3 = metrics.filter(m => m.acceptedAtWave === 3).length;

    console.log({ avgTime, wave1, wave2, wave3 });
  });
```

---

## 🧪 Testing Checklist

### Local Testing (Emulator)

```bash
# Start emulator
firebase emulators:start

# Create test order
# (Use client app or Postman to Firestore REST API)

# Check logs
# Terminal will show:
# [NotifyNewOrderV2] Order enqueued
# [DispatchEngine] Starting wave 1
# [DispatchNotifications] Notification sent
```

### Production Testing

1. **Acceptance Flow**:
   - [ ] Create order from client app
   - [ ] Driver receives notification within 5 seconds
   - [ ] Driver taps "Accept"
   - [ ] Order status becomes `accepted`
   - [ ] Other drivers' offers expire automatically

2. **Rejection Flow**:
   - [ ] Create order
   - [ ] Driver taps "Reject"
   - [ ] Offer status becomes `rejected`
   - [ ] Wave 2 starts after 15 seconds

3. **Expiration Flow**:
   - [ ] Create order
   - [ ] Don't respond
   - [ ] Wait 15 seconds
   - [ ] Offer status becomes `expired`
   - [ ] Wave 2 starts automatically

---

## 🎓 Learning Resources

### Read the Code

1. Start with: `functions/src/dispatch/types.ts`
   - Understand data structures

2. Then: `functions/src/dispatch/engine.ts`
   - Follow `enqueueOrder()` → `processNextWave()` → `handleOfferAcceptance()`

3. Finally: `functions/src/dispatch/selectors.ts`
   - See how eligible drivers are selected

### Watch the Logs

```bash
# Real-time logs
firebase functions:log --only processExpiredWaves

# Search for specific order
firebase functions:log | grep "ORDER_ID_HERE"
```

### Inspect Firestore

Firebase Console → Firestore:

```
dispatch_queue/{orderId}        → Current wave state
dispatch_offers/{offerId}       → Individual offers
driver_dispatch_state/{driverId} → Driver availability
dispatch_metrics/{orderId}      → Performance data
```

---

## 🚀 Next Steps

1. ✅ Read this guide
2. ✅ Deploy to staging environment
3. ✅ Test with synthetic orders
4. ✅ Monitor metrics for 24 hours
5. ✅ Deploy to production
6. ✅ Update driver app
7. ✅ Monitor for 1 week
8. ✅ Remove v1 functions

---

**Questions?** Check `DISPATCH_V2_DEPLOYMENT_GUIDE.md` for detailed instructions.

**Issues?** Check Cloud Functions logs and Firestore console first.

---

**Version**: 2.0.0
**Last Updated**: 2026-04-16
**Author**: WawApp Development Team 🔥
