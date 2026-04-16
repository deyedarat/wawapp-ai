/**
 * Dispatch V2 Intake — Regression Test Suite
 *
 * Prevents the class of bugs where raw/malformed order data
 * reaches dispatch_queue or crashes the intake boundary.
 *
 * @version 1.0.0
 */

// ── Mock firebase-admin BEFORE any import that touches it ────────────────────

const mockSet = jest.fn().mockResolvedValue(undefined);
const mockDoc = jest.fn((id: string) => ({ set: mockSet, id }));
const mockCollection = jest.fn((name: string) => ({ doc: mockDoc }));
const mockGet = jest.fn().mockResolvedValue({ exists: false, data: () => undefined });

// Timestamp must be a real class so `instanceof` works in removeUndefinedDeep
class MockTimestamp {
  _ms: number;
  constructor(ms: number) { this._ms = ms; }
  toMillis() { return this._ms; }
  static now() { return new MockTimestamp(Date.now()); }
  static fromMillis(ms: number) { return new MockTimestamp(ms); }
}

jest.mock('firebase-admin', () => ({
  firestore: Object.assign(
    () => ({ collection: mockCollection, doc: mockDoc }),
    {
      Timestamp: MockTimestamp,
      FieldValue: {
        delete: () => '__DELETE__',
        increment: (n: number) => n,
        arrayUnion: (...a: any[]) => a,
      },
    }
  ),
  initializeApp: jest.fn(),
  messaging: jest.fn(() => ({ send: jest.fn() })),
}));

// ── Mock engine.enqueueOrder so safeEnqueueOrder never hits real Firestore ───

const mockEnqueueOrder = jest.fn().mockResolvedValue(undefined);
jest.mock('../dispatch/engine', () => ({
  enqueueOrder: (...args: any[]) => mockEnqueueOrder(...args),
}));

// ── Imports (after mocks) ────────────────────────────────────────────────────

import {
  normalizeOrderForDispatch,
  validateDispatchPayload,
  removeUndefinedDeep,
  safeEnqueueOrder,
  NormalizedDispatchPayload,
} from '../dispatch/intake';

// ── Helpers ──────────────────────────────────────────────────────────────────

/** Minimal valid raw order document */
function validRawOrder(overrides: Record<string, any> = {}): Record<string, any> {
  return {
    pickup: { lat: 18.0735, lng: -15.9582, label: 'Tevragh Zeina' },
    dropoff: { lat: 18.0866, lng: -15.9784, label: 'Ksar' },
    price: 200,
    ownerId: 'client_abc',
    clientName: 'Ahmed',
    status: 'matching',
    createdAt: MockTimestamp.now(),
    ...overrides,
  };
}

// ── Setup / Teardown ─────────────────────────────────────────────────────────

beforeEach(() => {
  jest.clearAllMocks();
  mockGet.mockResolvedValue({ exists: false, data: () => undefined });
  mockDoc.mockImplementation((id: string) => ({
    set: mockSet,
    get: mockGet,
    id,
  }));
});

// ═══════════════════════════════════════════════════════════════════════════════
// 1. HAPPY PATH
// ═══════════════════════════════════════════════════════════════════════════════

describe('1 — Happy path', () => {
  test('valid order normalizes correctly', async () => {
    const raw = validRawOrder();
    const p = await normalizeOrderForDispatch('order_1', raw);

    expect(p.orderId).toBe('order_1');
    expect(p.pickupLat).toBe(18.0735);
    expect(p.pickupLng).toBe(-15.9582);
    expect(p.price).toBe(200);
    expect(p.clientName).toBe('Ahmed');
    expect(p.ownerId).toBe('client_abc');
    expect(p.pickupLabel).toBe('Tevragh Zeina');
    expect(p.dropoffLabel).toBe('Ksar');
  });

  test('valid payload passes validation', () => {
    const payload: NormalizedDispatchPayload = {
      orderId: 'order_1',
      pickupLat: 18.0735,
      pickupLng: -15.9582,
      dropoffLat: 18.0866,
      dropoffLng: -15.9784,
      price: 200,
      clientName: 'Ahmed',
      ownerId: 'client_abc',
      pickupLabel: 'Tevragh Zeina',
      dropoffLabel: 'Ksar',
    };
    const result = validateDispatchPayload(payload);
    expect(result.valid).toBe(true);
    expect(result.errors.filter((e) => e.severity === 'fatal')).toHaveLength(0);
  });

  test('safeEnqueueOrder returns true and calls enqueueOrder', async () => {
    const raw = validRawOrder();
    const ok = await safeEnqueueOrder('order_1', raw);

    expect(ok).toBe(true);
    expect(mockEnqueueOrder).toHaveBeenCalledTimes(1);
    const arg = mockEnqueueOrder.mock.calls[0][0] as NormalizedDispatchPayload;
    expect(arg.orderId).toBe('order_1');
    expect(arg.pickupLat).toBe(18.0735);
  });

  test('dispatch_queue write uses sanitized payload (no raw passthrough)', async () => {
    await safeEnqueueOrder('order_1', validRawOrder());
    const arg = mockEnqueueOrder.mock.calls[0][0];
    // Only known fields exist — no raw leakage
    expect(Object.keys(arg).sort()).toEqual(
      ['clientName', 'dropoffLabel', 'dropoffLat', 'dropoffLng', 'orderId', 'ownerId', 'pickupLabel', 'pickupLat', 'pickupLng', 'price']
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// 2. MISSING OPTIONAL FIELDS
// ═══════════════════════════════════════════════════════════════════════════════

describe('2 — Missing optional fields', () => {
  test('missing clientName resolves to fallback عميل', async () => {
    const raw = validRawOrder({ clientName: undefined });
    const p = await normalizeOrderForDispatch('o2', raw);
    expect(p.clientName).toBe('عميل');
  });

  test('empty-string clientName resolves to fallback', async () => {
    const raw = validRawOrder({ clientName: '' });
    const p = await normalizeOrderForDispatch('o2b', raw);
    expect(p.clientName).toBe('عميل');
  });

  test('missing pickup/dropoff labels normalize to null', async () => {
    const raw = validRawOrder();
    delete raw.pickup.label;
    delete raw.dropoff;
    const p = await normalizeOrderForDispatch('o3', raw);
    expect(p.pickupLabel).toBeNull();
    expect(p.dropoffLabel).toBeNull();
  });

  test('missing ownerId normalizes to null and produces warning, not fatal', async () => {
    const raw = validRawOrder({ ownerId: undefined });
    const p = await normalizeOrderForDispatch('o4', raw);
    expect(p.ownerId).toBeNull();

    const v = validateDispatchPayload(p);
    expect(v.valid).toBe(true);
    expect(v.errors.some((e) => e.field === 'ownerId' && e.severity === 'warning')).toBe(true);
  });

  test('order with missing optionals still enqueues successfully', async () => {
    const raw = validRawOrder({
      clientName: undefined,
      dropoff: undefined,
      pickupAddress: undefined,
      dropoffAddress: undefined,
    });
    const ok = await safeEnqueueOrder('o5', raw);
    expect(ok).toBe(true);
    expect(mockEnqueueOrder).toHaveBeenCalledTimes(1);
  });

  test('no undefined values in normalized payload', async () => {
    const raw = validRawOrder({
      clientName: undefined,
      dropoff: undefined,
      notes: undefined,
    });
    const p = await normalizeOrderForDispatch('o6', raw);
    for (const val of Object.values(p)) {
      expect(val).not.toBeUndefined();
    }
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// 3. MISSING REQUIRED FIELDS
// ═══════════════════════════════════════════════════════════════════════════════

describe('3 — Missing required fields', () => {
  test('missing pickup coordinates → fatal validation', async () => {
    const raw = validRawOrder({ pickup: {} });
    const p = await normalizeOrderForDispatch('r1', raw);
    const v = validateDispatchPayload(p);

    expect(v.valid).toBe(false);
    expect(v.errors.some((e) => e.field === 'pickupLat' && e.severity === 'fatal')).toBe(true);
    expect(v.errors.some((e) => e.field === 'pickupLng' && e.severity === 'fatal')).toBe(true);
  });

  test('pickup with lat=0, lng=0 → fatal (null-island guard)', async () => {
    const raw = validRawOrder({ pickup: { lat: 0, lng: 0 } });
    const p = await normalizeOrderForDispatch('r2', raw);
    const v = validateDispatchPayload(p);

    expect(v.valid).toBe(false);
  });

  test('missing pickup entirely → fatal, no crash', async () => {
    const raw = validRawOrder({ pickup: undefined });
    const p = await normalizeOrderForDispatch('r3', raw);
    const v = validateDispatchPayload(p);

    expect(v.valid).toBe(false);
  });

  test('safeEnqueueOrder quarantines invalid order (returns false, no enqueue)', async () => {
    const raw = validRawOrder({ pickup: undefined });
    const ok = await safeEnqueueOrder('r4', raw);

    expect(ok).toBe(false);
    expect(mockEnqueueOrder).not.toHaveBeenCalled();
    // quarantine write attempted via collection('dispatch_intake_failures')
    expect(mockSet).toHaveBeenCalled();
  });

  test('negative price → fatal', () => {
    const payload: NormalizedDispatchPayload = {
      orderId: 'r5',
      pickupLat: 18.07,
      pickupLng: -15.95,
      dropoffLat: 0,
      dropoffLng: 0,
      price: -50,
      clientName: 'X',
      ownerId: null,
      pickupLabel: null,
      dropoffLabel: null,
    };
    const v = validateDispatchPayload(payload);
    expect(v.valid).toBe(false);
    expect(v.errors.some((e) => e.field === 'price' && e.severity === 'fatal')).toBe(true);
  });

  test('lat out of range → fatal', () => {
    const payload: NormalizedDispatchPayload = {
      orderId: 'r6',
      pickupLat: 999,
      pickupLng: -15.95,
      dropoffLat: 0,
      dropoffLng: 0,
      price: 100,
      clientName: 'X',
      ownerId: null,
      pickupLabel: null,
      dropoffLabel: null,
    };
    const v = validateDispatchPayload(payload);
    expect(v.valid).toBe(false);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// 4. MALFORMED FIELDS
// ═══════════════════════════════════════════════════════════════════════════════

describe('4 — Malformed fields', () => {
  test('price as string → normalizes to 0', async () => {
    const raw = validRawOrder({ price: 'two hundred' });
    const p = await normalizeOrderForDispatch('m1', raw);
    expect(p.price).toBe(0);
  });

  test('pickup.lat as string → passthrough via ?? → validation catches non-finite', async () => {
    // The normalizer uses `raw.pickup?.lat ?? NaN` — a string is truthy so it passes through.
    // validateDispatchPayload checks Number.isFinite which rejects strings.
    const raw = validRawOrder({ pickup: { lat: 'north', lng: -15.95 } });
    const p = await normalizeOrderForDispatch('m2', raw);
    // pickupLat is the string 'north' (not a number)
    expect(Number.isFinite(p.pickupLat)).toBe(false);

    const v = validateDispatchPayload(p);
    expect(v.valid).toBe(false);
  });

  test('clientName as number → fallback', async () => {
    const raw = validRawOrder({ clientName: 12345 });
    const p = await normalizeOrderForDispatch('m3', raw);
    expect(p.clientName).toBe('عميل');
  });

  test('clientName as array → fallback', async () => {
    const raw = validRawOrder({ clientName: ['a', 'b'] });
    const p = await normalizeOrderForDispatch('m4', raw);
    expect(p.clientName).toBe('عميل');
  });

  test('pickup as flat string → NaN coords → fatal', async () => {
    const raw = validRawOrder({ pickup: 'some address' });
    const p = await normalizeOrderForDispatch('m5', raw);
    const v = validateDispatchPayload(p);
    expect(v.valid).toBe(false);
  });

  test('ownerId as number → null', async () => {
    const raw = validRawOrder({ ownerId: 999 });
    const p = await normalizeOrderForDispatch('m6', raw);
    expect(p.ownerId).toBeNull();
  });

  test('empty orderId → fatal', () => {
    const payload: NormalizedDispatchPayload = {
      orderId: '',
      pickupLat: 18.07,
      pickupLng: -15.95,
      dropoffLat: 0,
      dropoffLng: 0,
      price: 100,
      clientName: 'X',
      ownerId: null,
      pickupLabel: null,
      dropoffLabel: null,
    };
    const v = validateDispatchPayload(payload);
    expect(v.valid).toBe(false);
    expect(v.errors.some((e) => e.field === 'orderId')).toBe(true);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// 5. IDEMPOTENCY
// ═══════════════════════════════════════════════════════════════════════════════

describe('5 — Idempotency', () => {
  test('same order processed twice → enqueueOrder called twice (engine.set uses doc(orderId) so Firestore overwrites)', async () => {
    const raw = validRawOrder();
    await safeEnqueueOrder('idem_1', raw);
    await safeEnqueueOrder('idem_1', raw);

    expect(mockEnqueueOrder).toHaveBeenCalledTimes(2);
    expect(mockEnqueueOrder.mock.calls[0][0].orderId).toBe('idem_1');
    expect(mockEnqueueOrder.mock.calls[1][0].orderId).toBe('idem_1');
  });

  test('same orderId produces identical normalized payloads', async () => {
    const raw = validRawOrder();
    const p1 = await normalizeOrderForDispatch('idem_2', raw);
    const p2 = await normalizeOrderForDispatch('idem_2', raw);
    expect(p1).toEqual(p2);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// 6. FIRESTORE SERIALIZATION SAFETY
// ═══════════════════════════════════════════════════════════════════════════════

describe('6 — Firestore serialization safety (removeUndefinedDeep)', () => {
  test('strips top-level undefined', () => {
    const input = { a: 1, b: undefined, c: 'ok' };
    const out = removeUndefinedDeep(input);
    expect(out).toEqual({ a: 1, c: 'ok' });
    expect('b' in out).toBe(false);
  });

  test('strips nested undefined', () => {
    const input = { a: { x: 1, y: undefined }, b: 2 };
    const out = removeUndefinedDeep(input);
    expect(out).toEqual({ a: { x: 1 }, b: 2 });
  });

  test('strips deeply nested undefined', () => {
    const input = { a: { b: { c: { d: undefined, e: 'keep' } } } };
    const out = removeUndefinedDeep(input);
    expect(out).toEqual({ a: { b: { c: { e: 'keep' } } } });
  });

  test('preserves null (Firestore supports null)', () => {
    const input = { a: null, b: 1 };
    const out = removeUndefinedDeep(input);
    expect(out).toEqual({ a: null, b: 1 });
  });

  test('preserves false, 0, empty string', () => {
    const input = { a: false, b: 0, c: '' };
    const out = removeUndefinedDeep(input);
    expect(out).toEqual({ a: false, b: 0, c: '' });
  });

  test('handles arrays with undefined inside objects', () => {
    const input = { arr: [{ a: 1, b: undefined }, { c: undefined }] };
    const out = removeUndefinedDeep(input);
    expect(out).toEqual({ arr: [{ a: 1 }, {}] });
  });

  test('returns primitives unchanged', () => {
    expect(removeUndefinedDeep(42)).toBe(42);
    expect(removeUndefinedDeep('hello')).toBe('hello');
    expect(removeUndefinedDeep(null)).toBeNull();
    expect(removeUndefinedDeep(undefined)).toBeUndefined();
  });

  test('preserves MockTimestamp instances (Firestore Timestamp passthrough)', () => {
    const ts = MockTimestamp.now();
    const input = { createdAt: ts, name: 'test' };
    const out = removeUndefinedDeep(input);
    expect(out).toEqual({ createdAt: ts, name: 'test' });
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// 7. BACKWARD COMPATIBILITY (older schema)
// ═══════════════════════════════════════════════════════════════════════════════

describe('7 — Backward compatibility', () => {
  test('legacy order with pickupAddress string instead of pickup object', async () => {
    const raw = {
      pickupAddress: 'Tevragh Zeina',
      dropoffAddress: 'Ksar',
      price: 150,
      ownerId: 'client_old',
      clientName: 'Fatima',
      status: 'matching',
      createdAt: MockTimestamp.now(),
      // No pickup.lat/lng → will fail validation, but must NOT crash
    };
    const p = await normalizeOrderForDispatch('legacy_1', raw);
    expect(p.pickupLabel).toBe('Tevragh Zeina');
    expect(p.dropoffLabel).toBe('Ksar');
    expect(p.clientName).toBe('Fatima');
    // Coords are NaN → validation catches it
    const v = validateDispatchPayload(p);
    expect(v.valid).toBe(false);
  });

  test('legacy order with pickupAddress as object — normalizer only reads string pickupAddress', async () => {
    // The normalizer checks `typeof raw.pickupAddress === 'string'` — objects fall through to null.
    // This documents actual behavior: object-format pickupAddress is NOT resolved as a label.
    const raw = {
      pickupAddress: { label: 'Old Format', latitude: 18.07, longitude: -15.95 },
      dropoffAddress: { label: 'Old Dest' },
      price: 100,
      ownerId: 'client_old2',
      status: 'matching',
    };
    const p = await normalizeOrderForDispatch('legacy_2', raw);
    // pickup?.label is undefined, pickupAddress is not a string → null
    expect(p.pickupLabel).toBeNull();
    expect(p.dropoffLabel).toBeNull();
  });

  test('order with no status field does not crash normalization', async () => {
    const raw = {
      pickup: { lat: 18.07, lng: -15.95 },
      price: 100,
    };
    const p = await normalizeOrderForDispatch('legacy_3', raw);
    expect(p.orderId).toBe('legacy_3');
    expect(p.pickupLat).toBe(18.07);
  });

  test('order with extra unknown fields does not leak into payload', async () => {
    const raw = validRawOrder({
      legacyField: 'old_value',
      internalNote: 'admin only',
      __metadata: { version: 1 },
    });
    const p = await normalizeOrderForDispatch('legacy_4', raw);
    expect((p as any).legacyField).toBeUndefined();
    expect((p as any).internalNote).toBeUndefined();
    expect((p as any).__metadata).toBeUndefined();
  });

  test('completely empty raw document does not crash', async () => {
    const p = await normalizeOrderForDispatch('legacy_5', {});
    expect(p.orderId).toBe('legacy_5');
    expect(p.clientName).toBe('عميل');
    expect(p.price).toBe(0);

    const v = validateDispatchPayload(p);
    expect(v.valid).toBe(false);
  });

  test('safeEnqueueOrder on empty doc quarantines without crash', async () => {
    const ok = await safeEnqueueOrder('legacy_6', {});
    expect(ok).toBe(false);
    expect(mockEnqueueOrder).not.toHaveBeenCalled();
  });
});
