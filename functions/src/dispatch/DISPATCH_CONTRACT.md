# Dispatch V2 — Production Contract

## 1. Intake Contract

### Required Fields (fatal → quarantine)
| Field | Type | Constraint |
|-------|------|-----------|
| `orderId` | string | non-empty |
| `pickup.lat` | number | finite, -90..90, ≠ 0 |
| `pickup.lng` | number | finite, -180..180, ≠ 0 |
| `price` | number | ≥ 0 |

### Optional Fields (warning, fallback applied)
| Field | Fallback |
|-------|----------|
| `clientName` | `clients/{ownerId}.name` → `'عميل'` |
| `ownerId` | `null` |
| `pickup.label` | `pickupAddress` (string) → `null` |
| `dropoff.label` | `dropoffAddress` (string) → `null` |

### Sanitization
- Strings trimmed
- Non-string `clientName` → fallback
- Non-number `price` → `0`
- `undefined` stripped recursively (`removeUndefinedDeep`) before every Firestore write
- Only explicitly mapped fields pass through (no raw field leakage)

### Quarantine (Dead-Letter)
- Collection: `dispatch_intake_failures/{orderId}`
- Contains: `failureCategory`, `retryable`, `validationErrors`, `rawFieldPresenceSummary`, `normalizedSnapshot`
- Does NOT store raw PII — only field-presence booleans
- Queryable by: `failureCategory`, `retryable`, `createdAt`

### Idempotency
- `dispatch_queue` uses `doc(orderId)` → Firestore `set()` overwrites
- `dispatch_intake_failures` uses `doc(orderId)` → last failure wins
- Engine checks `currentWave > 0` before re-enqueue to prevent duplicate wave triggers

---

## 2. Failure Classification

| Category | Retryable | Example |
|----------|-----------|---------|
| `validation_failed` | ❌ No | Missing coordinates, negative price |
| `intake_exception` | ✅ Yes | Firestore timeout, network error |
| `quarantine_write_fail` | ✅ Yes | Quarantine record itself failed to write |

**Retry policy:** Cloud Functions v1 Firestore triggers retry automatically on thrown errors. `safeEnqueueOrder` catches all exceptions and returns `false` instead of throwing — the trigger function (`notifyNewOrderV2`) returns `null` on failure, preventing infinite retry loops for permanently malformed orders.

---

## 3. Structured Logging

Every intake attempt emits a JSON log with:
```json
{
  "tag": "DispatchIntake",
  "stage": "validate|enqueue|quarantine",
  "orderId": "...",
  "result": "success|failed|exception|quarantined|duplicate_skipped",
  "failureCategory": "validation_failed|intake_exception|null",
  "requiredFieldPresence": { "pickup": true, "pickup.lat": false, ... },
  "queueInsertAttempted": true,
  "queueInsertSucceeded": false,
  "error": "..."
}
```

**Root cause within 1 minute:** Filter Cloud Logging by `jsonPayload.tag = "DispatchIntake"` + `jsonPayload.orderId`.

---

## 4. Metrics (Log-Based Counters)

Emitted via `emitMetric()` → structured JSON → Cloud Logging → Log-based Metrics.

| Metric | When |
|--------|------|
| `dispatch_intake_started` | Every intake attempt |
| `dispatch_intake_succeeded` | Order enqueued |
| `dispatch_intake_failed_validation` | Fatal validation |
| `dispatch_intake_failed_firestore` | Firestore write error |
| `dispatch_queue_duplicate_skipped` | Re-enqueue of active order |
| `wave_creation_started` | Wave N begins |
| `wave_creation_succeeded` | Wave offers sent |
| `wave_creation_failed` | Wave processing error |
| `wave_no_eligible_drivers` | No drivers in radius |
| `wave_all_exhausted` | All 3 waves failed |
| `notification_sent` | FCM delivered |
| `notification_failed` | FCM error |

**Dashboard setup:** GCP Console → Monitoring → Log-based Metrics → Create metric on `jsonPayload.metric`.

---

## 5. Firestore Write Safety

All Firestore writes in the dispatch pipeline pass through `removeUndefinedDeep()`:
- `dispatch_queue` — `enqueueOrder()`
- `dispatch_metrics` — `enqueueOrder()`
- `dispatch_offers` — `sendWaveOffers()` batch
- `driver_dispatch_state` — `sendWaveOffers()` batch
- `dispatch_intake_failures` — `quarantineOrder()`

FCM data payloads defensively coerce all values to strings with fallbacks (no `undefined` can reach `admin.messaging().send()`).

---

## 6. Rollout Checklist

### Pre-Deploy
- [ ] `npm run test:intake` passes (all 7 test groups)
- [ ] `npm run build` succeeds with no TS errors
- [ ] Verify `dispatch_intake_failures` Firestore collection exists (auto-created on first write)
- [ ] Confirm `notifyNewOrder` (v1) is commented out in `index.ts`
- [ ] Confirm `notifyUnassignedOrders` (v1) is commented out in `index.ts`

### Deploy
- [ ] Deploy with `firebase deploy --only functions:notifyNewOrderV2,functions:processExpiredWaves,functions:acceptOrderV2,functions:rejectOffer`
- [ ] Verify Cloud Scheduler job for `processExpiredWaves` is active (every 1 minute)

### Post-Deploy Validation
- [ ] Create test order → verify `dispatch_queue/{orderId}` created
- [ ] Verify structured log appears in Cloud Logging (`jsonPayload.tag = "DispatchIntake"`)
- [ ] Verify `dispatch_metrics/{orderId}` created
- [ ] Create malformed test order (no pickup) → verify `dispatch_intake_failures/{orderId}` created
- [ ] Verify `failureCategory` and `retryable` fields present in quarantine record
- [ ] Accept offer → verify order status transitions to `accepted`
- [ ] Verify wave expiration triggers next wave (wait 15s for wave 1)

### Monitoring (First 24h)
- [ ] Set up Cloud Logging alert on `jsonPayload.metric = "dispatch_intake_failed_firestore"` (> 0 in 5min)
- [ ] Set up alert on `jsonPayload.metric = "wave_all_exhausted"` (> 5 in 1h)
- [ ] Monitor `dispatch_intake_failures` collection size (should be near-zero)
- [ ] Verify no `CRITICAL_QUARANTINE_WRITE_FAILED` logs

### Rollback Plan
- Re-enable `notifyNewOrder` (v1) in `index.ts` and redeploy
- `notifyUnassignedOrders` can be re-enabled as fallback
- Dispatch queue entries are safe to delete (orders remain in `orders` collection)
