/**
 * WawApp Dispatch Engine — Intake Boundary
 *
 * Ensures raw order documents are NEVER written to dispatch_queue
 * without normalization and validation.
 *
 * Flow: raw order → normalize → validate → serialize → write (or quarantine)
 *
 * ## Dispatch Intake Contract
 *
 * ### Required fields (fatal if missing/invalid):
 *   orderId        — non-empty string (from trigger context)
 *   pickup.lat     — finite number, -90..90, ≠ 0
 *   pickup.lng     — finite number, -180..180, ≠ 0
 *   price          — number ≥ 0
 *
 * ### Optional fields (warning if missing, fallback applied):
 *   clientName     — string; fallback: clients/{ownerId}.name → 'عميل'
 *   ownerId        — string; fallback: null
 *   pickup.label   — string; fallback: pickupAddress (string) → null
 *   dropoff.label  — string; fallback: dropoffAddress (string) → null
 *
 * ### Sanitization:
 *   - Strings are trimmed
 *   - Non-string clientName → fallback
 *   - Non-number price → 0
 *   - undefined values stripped recursively before Firestore write
 *   - Only explicitly mapped fields pass through (no raw leakage)
 *
 * ### Quarantine:
 *   - Fatal validation → dispatch_intake_failures/{orderId}
 *   - Unexpected exceptions → dispatch_intake_failures/{orderId}
 *   - Quarantine records include: field presence summary, normalized
 *     snapshot, validation errors, failure category, retryability flag
 *   - No raw PII stored (only field presence booleans)
 *
 * ### Idempotency:
 *   - dispatch_queue uses doc(orderId) → Firestore set() overwrites
 *   - Safe to call multiple times for same orderId
 *   - dispatch_intake_failures uses doc(orderId) → last failure wins
 *
 * ### Failure categories:
 *   - validation_failed     — non-retryable (data is permanently malformed)
 *   - intake_exception      — retryable (transient Firestore/network error)
 *   - quarantine_write_fail — retryable (quarantine itself failed)
 *
 * @version 2.2.0
 */

import * as admin from 'firebase-admin';
import { enqueueOrder } from './engine';
import { emitMetric } from './counters';

const db = admin.firestore();

// ============================================================================
// TYPES
// ============================================================================

/** Fields extracted and normalized from a raw order document */
export interface NormalizedDispatchPayload {
  orderId: string;
  pickupLat: number;
  pickupLng: number;
  dropoffLat: number;
  dropoffLng: number;
  price: number;
  clientName: string;
  // Snapshot fields for audit trail
  ownerId: string | null;
  pickupLabel: string | null;
  dropoffLabel: string | null;
}

export interface ValidationError {
  field: string;
  reason: string;
  severity: 'fatal' | 'warning';
}

export interface ValidationResult {
  valid: boolean;
  errors: ValidationError[];
}

export type FailureCategory =
  | 'validation_failed'
  | 'intake_exception'
  | 'quarantine_write_fail';

export interface IntakeFailureRecord {
  orderId: string;
  reason: string;
  failureCategory: FailureCategory;
  retryable: boolean;
  validationErrors: ValidationError[];
  normalizedSnapshot: Record<string, unknown> | null;
  rawFieldPresenceSummary: Record<string, boolean>;
  createdAt: admin.firestore.Timestamp;
}

// ============================================================================
// NORMALIZATION
// ============================================================================

/**
 * Build a canonical dispatch payload from a raw Firestore order document.
 *
 * - Explicitly maps known fields only
 * - Resolves clientName from clients collection when missing from order
 * - Trims strings
 * - Converts undefined → null or fallback where appropriate
 */
export async function normalizeOrderForDispatch(
  orderId: string,
  raw: FirebaseFirestore.DocumentData
): Promise<NormalizedDispatchPayload> {
  // Pickup coordinates — support both formats
  const pickupLat: number = raw.pickup?.lat ?? NaN;
  const pickupLng: number = raw.pickup?.lng ?? NaN;

  const price: number = typeof raw.price === 'number' ? raw.price : 0;

  // clientName resolution chain:
  // 1. order.clientName (if present and non-empty)
  // 2. lookup from clients/{ownerId}.name
  // 3. fallback 'عميل'
  let clientName: string = typeof raw.clientName === 'string' ? raw.clientName.trim() : '';

  if (!clientName && raw.ownerId) {
    try {
      const clientDoc = await db.collection('clients').doc(raw.ownerId).get();
      if (clientDoc.exists) {
        const name = clientDoc.data()?.name;
        if (typeof name === 'string' && name.trim()) {
          clientName = name.trim();
        }
      }
    } catch {
      // Non-fatal — fall through to default
    }
  }

  if (!clientName) {
    clientName = 'عميل';
  }

  const pickupLabel: string | null =
    (typeof raw.pickup?.label === 'string' ? raw.pickup.label.trim() : null) ||
    (typeof raw.pickupAddress === 'string' ? raw.pickupAddress.trim() : null) ||
    null;

  const dropoffLabel: string | null =
    (typeof raw.dropoff?.label === 'string' ? raw.dropoff.label.trim() : null) ||
    (typeof raw.dropoffAddress === 'string' ? raw.dropoffAddress.trim() : null) ||
    null;

  return {
    orderId,
    pickupLat,
    pickupLng,
    dropoffLat: raw.dropoff?.lat ?? 0,
    dropoffLng: raw.dropoff?.lng ?? 0,
    price,
    clientName,
    ownerId: typeof raw.ownerId === 'string' ? raw.ownerId : null,
    pickupLabel,
    dropoffLabel,
  };
}

// ============================================================================
// VALIDATION
// ============================================================================

/**
 * Validate a normalized dispatch payload before queue insertion.
 *
 * Fatal = blocks dispatch. Warning = logged but allowed.
 */
export function validateDispatchPayload(
  payload: NormalizedDispatchPayload
): ValidationResult {
  const errors: ValidationError[] = [];

  // --- Fatal: required fields ---

  if (!payload.orderId) {
    errors.push({ field: 'orderId', reason: 'missing', severity: 'fatal' });
  }

  if (!Number.isFinite(payload.pickupLat) || payload.pickupLat === 0) {
    errors.push({ field: 'pickupLat', reason: `invalid: ${payload.pickupLat}`, severity: 'fatal' });
  }

  if (!Number.isFinite(payload.pickupLng) || payload.pickupLng === 0) {
    errors.push({ field: 'pickupLng', reason: `invalid: ${payload.pickupLng}`, severity: 'fatal' });
  }

  if (payload.price < 0) {
    errors.push({ field: 'price', reason: `negative: ${payload.price}`, severity: 'fatal' });
  }

  // Lat/lng range check
  if (Number.isFinite(payload.pickupLat) && (payload.pickupLat < -90 || payload.pickupLat > 90)) {
    errors.push({ field: 'pickupLat', reason: `out of range: ${payload.pickupLat}`, severity: 'fatal' });
  }

  if (Number.isFinite(payload.pickupLng) && (payload.pickupLng < -180 || payload.pickupLng > 180)) {
    errors.push({ field: 'pickupLng', reason: `out of range: ${payload.pickupLng}`, severity: 'fatal' });
  }

  // --- Warnings: optional but notable ---

  if (payload.price === 0) {
    errors.push({ field: 'price', reason: 'zero price', severity: 'warning' });
  }

  if (!payload.ownerId) {
    errors.push({ field: 'ownerId', reason: 'missing', severity: 'warning' });
  }

  if (!payload.pickupLabel) {
    errors.push({ field: 'pickupLabel', reason: 'missing', severity: 'warning' });
  }

  if (!payload.dropoffLabel) {
    errors.push({ field: 'dropoffLabel', reason: 'missing', severity: 'warning' });
  }

  const hasFatal = errors.some((e) => e.severity === 'fatal');

  return { valid: !hasFatal, errors };
}

// ============================================================================
// FIRESTORE SERIALIZATION
// ============================================================================

/**
 * Recursively remove undefined values from an object before Firestore write.
 *
 * - undefined → omitted
 * - null → preserved (Firestore supports null)
 * - false / 0 / '' → preserved
 */
export function removeUndefinedDeep<T>(obj: T): T {
  if (obj === null || obj === undefined || typeof obj !== 'object') {
    return obj;
  }

  if (obj instanceof admin.firestore.Timestamp) {
    return obj;
  }

  if (Array.isArray(obj)) {
    return obj.map((item) => removeUndefinedDeep(item)) as unknown as T;
  }

  const cleaned: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj as Record<string, unknown>)) {
    if (value === undefined) continue;
    cleaned[key] = removeUndefinedDeep(value);
  }
  return cleaned as T;
}

// ============================================================================
// QUARANTINE (Dead-Letter)
// ============================================================================

/**
 * Classify failure as retryable or non-retryable.
 *
 * Non-retryable: permanently malformed data (validation failures).
 * Retryable: transient errors (Firestore timeout, network, etc.).
 */
function classifyFailure(reason: string): { category: FailureCategory; retryable: boolean } {
  if (reason === 'validation_failed') {
    return { category: 'validation_failed', retryable: false };
  }
  if (reason.startsWith('intake_exception')) {
    return { category: 'intake_exception', retryable: true };
  }
  return { category: 'quarantine_write_fail', retryable: true };
}

/**
 * Write a failed intake to dispatch_intake_failures for investigation.
 *
 * Dead-letter record is queryable by:
 *   - orderId (document ID)
 *   - failureCategory (indexed field)
 *   - retryable (boolean — filter actionable failures)
 *   - createdAt (timestamp — TTL / cleanup)
 *
 * Sensitive data policy: raw order data is NOT stored.
 * Only field-presence booleans are recorded for debugging.
 */
async function quarantineOrder(
  orderId: string,
  reason: string,
  validationErrors: ValidationError[],
  normalizedSnapshot: NormalizedDispatchPayload | null,
  rawData: FirebaseFirestore.DocumentData
): Promise<void> {
  const rawFieldPresenceSummary: Record<string, boolean> = {
    pickup: rawData.pickup != null,
    'pickup.lat': rawData.pickup?.lat != null,
    'pickup.lng': rawData.pickup?.lng != null,
    dropoff: rawData.dropoff != null,
    price: rawData.price != null,
    ownerId: rawData.ownerId != null,
    clientName: rawData.clientName != null,
    status: rawData.status != null,
    createdAt: rawData.createdAt != null,
    pickupAddress: rawData.pickupAddress != null,
    dropoffAddress: rawData.dropoffAddress != null,
  };

  const { category, retryable } = classifyFailure(reason);

  const record: IntakeFailureRecord = {
    orderId,
    reason,
    failureCategory: category,
    retryable,
    validationErrors,
    normalizedSnapshot: normalizedSnapshot
      ? removeUndefinedDeep({ ...normalizedSnapshot })
      : null,
    rawFieldPresenceSummary,
    createdAt: admin.firestore.Timestamp.now(),
  };

  try {
    await db
      .collection('dispatch_intake_failures')
      .doc(orderId)
      .set(removeUndefinedDeep(record));

    console.error(JSON.stringify({
      tag: 'DispatchIntake',
      stage: 'quarantine',
      orderId,
      result: 'quarantined',
      failureCategory: category,
      retryable,
      reason,
      fatalErrors: validationErrors.filter((e) => e.severity === 'fatal'),
      rawFieldPresence: rawFieldPresenceSummary,
    }));
  } catch (writeErr: any) {
    emitMetric('dispatch_intake_failed_firestore', { orderId });
    console.error(JSON.stringify({
      tag: 'DispatchIntake',
      stage: 'quarantine_write',
      orderId,
      result: 'CRITICAL_QUARANTINE_WRITE_FAILED',
      error: writeErr.message,
    }));
  }
}

// ============================================================================
// SAFE ENQUEUE (Public Entry Point)
// ============================================================================

/**
 * Safe dispatch intake: normalize → validate → serialize → enqueue (or quarantine).
 *
 * This is the ONLY function that should be called from order triggers.
 * It guarantees no undefined fields reach dispatch_queue or Firestore.
 *
 * Returns true if order was successfully enqueued, false if quarantined.
 */
export async function safeEnqueueOrder(
  orderId: string,
  rawOrderData: FirebaseFirestore.DocumentData
): Promise<boolean> {
  let normalized: NormalizedDispatchPayload | null = null;
  let queueInsertAttempted = false;
  let queueInsertSucceeded = false;

  emitMetric('dispatch_intake_started', { orderId });

  // Build field presence map for structured log (always logged, success or fail)
  const requiredFieldPresence = {
    pickup: rawOrderData.pickup != null,
    'pickup.lat': rawOrderData.pickup?.lat != null,
    'pickup.lng': rawOrderData.pickup?.lng != null,
    price: rawOrderData.price != null,
    ownerId: rawOrderData.ownerId != null,
    clientName: rawOrderData.clientName != null,
  };

  try {
    // Step 1: Normalize
    normalized = await normalizeOrderForDispatch(orderId, rawOrderData);

    // Step 2: Validate
    const validation = validateDispatchPayload(normalized);

    // Log warnings even on success
    const warnings = validation.errors.filter((e) => e.severity === 'warning');
    if (warnings.length > 0) {
      console.warn(JSON.stringify({
        tag: 'DispatchIntake',
        stage: 'validate',
        orderId,
        result: 'warnings',
        warnings,
      }));
    }

    // Step 3: Fatal → quarantine (non-retryable)
    if (!validation.valid) {
      emitMetric('dispatch_intake_failed_validation', { orderId });

      console.error(JSON.stringify({
        tag: 'DispatchIntake',
        stage: 'validate',
        orderId,
        result: 'failed',
        failureCategory: 'validation_failed',
        requiredFieldPresence,
        queueInsertAttempted: false,
        queueInsertSucceeded: false,
        fatalErrors: validation.errors.filter((e) => e.severity === 'fatal'),
      }));

      await quarantineOrder(
        orderId,
        'validation_failed',
        validation.errors,
        normalized,
        rawOrderData
      );
      return false;
    }

    // Step 4: Enqueue with validated, normalized data
    queueInsertAttempted = true;
    await enqueueOrder(normalized);
    queueInsertSucceeded = true;

    emitMetric('dispatch_intake_succeeded', { orderId });

    console.log(JSON.stringify({
      tag: 'DispatchIntake',
      stage: 'enqueue',
      orderId,
      result: 'success',
      failureCategory: null,
      requiredFieldPresence,
      queueInsertAttempted,
      queueInsertSucceeded,
      clientName: normalized.clientName,
    }));

    return true;
  } catch (error: any) {
    // Catch-all: quarantine instead of crashing the trigger (retryable)
    const failureCategory = queueInsertAttempted
      ? 'dispatch_intake_failed_firestore'
      : 'dispatch_intake_failed_unknown';

    emitMetric(failureCategory as any, { orderId });

    console.error(JSON.stringify({
      tag: 'DispatchIntake',
      stage: queueInsertAttempted ? 'enqueue' : 'normalize',
      orderId,
      result: 'exception',
      failureCategory,
      requiredFieldPresence,
      queueInsertAttempted,
      queueInsertSucceeded,
      error: error.message,
    }));

    await quarantineOrder(
      orderId,
      `intake_exception: ${error.message}`,
      [],
      normalized,
      rawOrderData
    );

    return false;
  }
}
