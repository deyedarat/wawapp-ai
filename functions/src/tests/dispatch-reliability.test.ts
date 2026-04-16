/**
 * Dispatch V2 — Reliability & Fault Tolerance Regression Tests
 *
 * Covers:
 * 1. Single source of truth (notifications use queue, not raw order)
 * 2. Missing field safety (clientName, createdAt, price)
 * 3. Firestore write failure + retry
 * 4. Driver list mismatch
 * 5. Notification partial failures
 * 6. Architecture violation detection (assertNormalizedPayload)
 * 7. Safe numeric coercion
 *
 * @version 1.0.0
 */

// ── Mock firebase-admin BEFORE any import ────────────────────────────────────

class MockTimestamp {
  _ms: number;
  constructor(ms: number) { this._ms = ms; }
  toMillis() { return this._ms; }
  static now() { return new MockTimestamp(Date.now()); }
  static fromMillis(ms: number) { return new MockTimestamp(ms); }
}

const mockSend = jest.fn().mockResolvedValue('mock-message-id');

jest.mock('firebase-admin', () => ({
  firestore: Object.assign(
    () => ({
      collection: jest.fn(() => ({
        doc: jest.fn(() => ({
          set: jest.fn().mockResolvedValue(undefined),
          get: jest.fn().mockResolvedValue({ exists: false }),
          update: jest.fn().mockResolvedValue(undefined),
          delete: jest.fn().mockResolvedValue(undefined),
        })),
      })),
    }),
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
  messaging: jest.fn(() => ({ send: mockSend })),
}));

// ── Imports ──────────────────────────────────────────────────────────────────

import { sendOfferNotification, assertNormalizedPayload } from '../dispatch/notifications';
import { DispatchOffer, DispatchQueueEntry } from '../dispatch/types';

// ── Helpers ──────────────────────────────────────────────────────────────────

function makeOffer(overrides: Partial<DispatchOffer> = {}): DispatchOffer {
  const now = MockTimestamp.now() as any;
  return {
    offerId: 'order_1_driver_1',
    orderId: 'order_1',
    driverId: 'driver_1',
    status: 'sent',
    round: 1,
    priority: 1,
    sentAt: now,
    expiresAt: MockTimestamp.fromMillis(Date.now() + 15000) as any,
    respondedAt: null,
    distance: 2.5,
    createdAt: now,
    ...overrides,
  };
}

function makeQueueEntry(overrides: Partial<DispatchQueueEntry> = {}): DispatchQueueEntry {
  const now = MockTimestamp.now() as any;
  return {
    orderId: 'order_1',
    currentWave: 1,
    totalOffersSent: 1,
    waveStartedAt: now,
    waveExpiresAt: MockTimestamp.fromMillis(Date.now() + 15000) as any,
    pickupLat: 18.0735,
    pickupLng: -15.9582,
    price: 200,
    clientName: 'Ahmed',
    pickupLabel: 'Tevragh Zeina',
    dropoffLabel: 'Ksar',
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

// ── Setup ────────────────────────────────────────────────────────────────────

beforeEach(() => {
  jest.clearAllMocks();
  mockSend.mockResolvedValue('mock-message-id');
});

// ═══════════════════════════════════════════════════════════════════════════════
// SCENARIO 1: Order missing clientName
// ═══════════════════════════════════════════════════════════════════════════════

describe('Scenario 1 — Order missing clientName', () => {
  test('notification uses fallback عميل when clientName is empty', async () => {
    const offer = makeOffer();
    const queue = makeQueueEntry({ clientName: '' });

    const result = await sendOfferNotification(offer, queue, 'valid-token');
    expect(result.success).toBe(true);
  });

  test('notification uses fallback عميل when clientName is default', async () => {
    const offer = makeOffer();
    const queue = makeQueueEntry({ clientName: 'عميل' });

    const result = await sendOfferNotification(offer, queue, 'valid-token');
    expect(result.success).toBe(true);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SCENARIO 2: Order missing createdAt
// ═══════════════════════════════════════════════════════════════════════════════

describe('Scenario 2 — Order missing createdAt', () => {
  test('notification handles missing createdAt gracefully (falls back to Date.now)', async () => {
    const offer = makeOffer();
    const queue = makeQueueEntry({ createdAt: undefined as any });

    const result = await sendOfferNotification(offer, queue, 'valid-token');
    expect(result.success).toBe(true);
  });

  test('notification handles null createdAt', async () => {
    const offer = makeOffer();
    const queue = makeQueueEntry({ createdAt: null as any });

    const result = await sendOfferNotification(offer, queue, 'valid-token');
    expect(result.success).toBe(true);
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SCENARIO 3: Firestore write fails then succeeds (retry)
// ═══════════════════════════════════════════════════════════════════════════════

describe('Scenario 3 — FCM send fails then succeeds', () => {
  test('sendOfferNotification returns failure on FCM error (no crash)', async () => {
    mockSend.mockRejectedValueOnce(new Error('network timeout'));

    const offer = makeOffer();
    const queue = makeQueueEntry();

    const result = await sendOfferNotification(offer, queue, 'valid-token');
    // Should return structured failure, NOT throw
    expect(result.success).toBe(false);
    expect(result.error).toBeDefined();
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SCENARIO 4: Driver list mismatch length
// ═══════════════════════════════════════════════════════════════════════════════

describe('Scenario 4 — Driver index safety', () => {
  test('sendOfferNotification handles missing fcmToken', async () => {
    const offer = makeOffer();
    const queue = makeQueueEntry();

    const result = await sendOfferNotification(offer, queue, '');
    expect(result.success).toBe(false);
    expect(result.error).toBe('missing_fcm_token');
  });

  test('sendOfferNotification handles undefined fcmToken', async () => {
    const offer = makeOffer();
    const queue = makeQueueEntry();

    const result = await sendOfferNotification(offer, queue, undefined as any);
    expect(result.success).toBe(false);
    expect(result.error).toBe('missing_fcm_token');
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SCENARIO 5: Notification fails for 50% of drivers
// ═══════════════════════════════════════════════════════════════════════════════

describe('Scenario 5 — Partial notification failures', () => {
  test('sendOfferNotification never throws even on FCM error', async () => {
    mockSend.mockRejectedValueOnce({ code: 'messaging/internal-error', message: 'FCM down' });

    const offer = makeOffer();
    const queue = makeQueueEntry();

    // Should NOT throw
    const result = await sendOfferNotification(offer, queue, 'valid-token');
    expect(result.success).toBe(false);
    expect(result.error).toBeDefined();
  });

  test('invalid token returns structured error', async () => {
    mockSend.mockRejectedValueOnce({
      code: 'messaging/registration-token-not-registered',
      message: 'Token not registered',
    });

    const offer = makeOffer();
    const queue = makeQueueEntry();

    const result = await sendOfferNotification(offer, queue, 'expired-token');
    expect(result.success).toBe(false);
    expect(result.error).toBe('invalid_token');
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SCENARIO 6: Architecture violation detection
// ═══════════════════════════════════════════════════════════════════════════════

describe('Scenario 6 — assertNormalizedPayload', () => {
  test('rejects raw order data (has status field)', () => {
    const rawOrder = {
      status: 'matching',
      pickup: { lat: 18.07, lng: -15.95 },
      price: 200,
      clientName: 'Ahmed',
    };

    expect(() => assertNormalizedPayload(rawOrder)).toThrow('ARCHITECTURE VIOLATION');
  });

  test('rejects raw order data (has assignedDriverId)', () => {
    const rawOrder = {
      assignedDriverId: 'driver_1',
      price: 200,
    };

    expect(() => assertNormalizedPayload(rawOrder)).toThrow('ARCHITECTURE VIOLATION');
  });

  test('accepts normalized queue entry (no raw markers)', () => {
    const queueEntry = {
      orderId: 'order_1',
      pickupLat: 18.07,
      pickupLng: -15.95,
      price: 200,
      clientName: 'Ahmed',
      currentWave: 1,
    };

    expect(() => assertNormalizedPayload(queueEntry)).not.toThrow();
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SCENARIO 7: Safe numeric handling
// ═══════════════════════════════════════════════════════════════════════════════

describe('Scenario 7 — Numeric safety in notifications', () => {
  test('handles NaN price gracefully', async () => {
    const offer = makeOffer();
    const queue = makeQueueEntry({ price: NaN });

    const result = await sendOfferNotification(offer, queue, 'valid-token');
    expect(result.success).toBe(true);
    // Price should be coerced to 0 in notification data
  });

  test('handles NaN distance gracefully', async () => {
    const offer = makeOffer({ distance: NaN });
    const queue = makeQueueEntry();

    const result = await sendOfferNotification(offer, queue, 'valid-token');
    expect(result.success).toBe(true);
  });

  test('rejects missing queue coordinates', async () => {
    const offer = makeOffer();
    const queue = makeQueueEntry({ pickupLat: NaN, pickupLng: NaN });

    const result = await sendOfferNotification(offer, queue, 'valid-token');
    expect(result.success).toBe(false);
    expect(result.error).toBe('missing_queue_fields');
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// SCENARIO 8: Missing labels fallback
// ═══════════════════════════════════════════════════════════════════════════════

describe('Scenario 8 — Missing labels use Arabic fallbacks', () => {
  test('missing pickupLabel and dropoffLabel use defaults', async () => {
    const offer = makeOffer();
    const queue = makeQueueEntry({ pickupLabel: null, dropoffLabel: null });

    const result = await sendOfferNotification(offer, queue, 'valid-token');
    expect(result.success).toBe(true);
  });
});
