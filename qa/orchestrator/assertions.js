'use strict';
/**
 * Deterministic assertion engine.
 * Each assertion either PASSES (returns true) or FAILS (throws AssertionError with evidence).
 */

class AssertionError extends Error {
  constructor(assertion, evidence) {
    super(`[ASSERT FAIL] ${assertion}\n  Evidence: ${JSON.stringify(evidence)}`);
    this.name = 'AssertionError';
    this.assertion = assertion;
    this.evidence = evidence;
  }
}

/**
 * Core assert helper.
 * @param {boolean} condition
 * @param {string}  label
 * @param {any}     evidence
 */
function assert(condition, label, evidence = null) {
  if (!condition) throw new AssertionError(label, evidence);
  console.log(`  [PASS] ${label}`);
  return true;
}

// ── UI assertions ─────────────────────────────────────────────────────────

/**
 * Assert the FullScreenNotificationActivity is currently focused on the device.
 * @param {Device} device
 */
function assertFullscreenVisible(device) {
  const focused = device.getFocusedActivity();
  return assert(
    focused.includes('FullScreenNotificationActivity'),
    'FullScreenNotificationActivity is focused',
    { focused }
  );
}

/**
 * Assert the app is in the foreground (any activity).
 */
function assertAppForegrounded(device) {
  return assert(
    device.isAppForegrounded(),
    `${device.label} app is foregrounded`,
    { activity: device.getFocusedActivity() }
  );
}

/**
 * Assert the UI XML dump does NOT contain zombie fullscreen artifacts after acceptance.
 * Checks there is no interactive Accept/Reject button still visible outside context.
 */
function assertNoZombieAuthority(uiXml, orderId) {
  // If fullscreen is gone, there should be no "قبول" (Accept) button in the tree
  const hasAccept  = uiXml.includes('قبول');
  const hasReject  = uiXml.includes('رفض');
  return assert(
    !hasAccept && !hasReject,
    'No zombie fullscreen authority (Accept/Reject buttons absent)',
    { hasAccept, hasReject, orderId }
  );
}

// ── Backend / Firestore assertions ───────────────────────────────────────

/**
 * Assert a Firestore document has the expected field value.
 * @param {FirebaseFirestore.DocumentReference} docRef
 * @param {string} field
 * @param {any}    expected
 */
async function assertFirestoreField(docRef, field, expected) {
  const snap = await docRef.get();
  const actual = snap.exists ? snap.data()[field] : undefined;
  return assert(
    actual === expected,
    `Firestore ${docRef.path}.${field} === ${expected}`,
    { actual, expected }
  );
}

/**
 * Assert the order document has a specific status.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} orderId
 * @param {string} expectedStatus
 */
async function assertOrderStatus(db, orderId, expectedStatus) {
  return assertFirestoreField(
    db.collection('orders').doc(orderId),
    'status',
    expectedStatus
  );
}

/**
 * Assert that the dispatch_offer document for this (orderId, driverId) either
 * does not exist or has a terminal status.
 */
async function assertOfferDead(db, orderId, driverId) {
  const offerId = `${orderId}_${driverId}`;
  const snap = await db.collection('dispatch_offers').doc(offerId).get();
  if (!snap.exists) {
    console.log(`  [PASS] Offer ${offerId} does not exist (already cleaned up)`);
    return true;
  }
  const status = snap.data().status;
  const isTerminal = ['accepted', 'rejected', 'expired', 'cancelled'].includes(status);
  return assert(isTerminal, `Offer ${offerId} is in terminal state`, { status });
}

// ── Logcat / trace assertions ────────────────────────────────────────────

/**
 * Assert that the device logcat contains a specific FORENSIC_TRACE event.
 * @param {Device} device
 * @param {string} traceTag  - partial string to match
 */
function assertLogContains(device, traceTag, label) {
  const lines = device.findLogLines(traceTag);
  return assert(
    lines.length > 0,
    label || `Log contains: ${traceTag}`,
    { matchCount: lines.length, traceTag }
  );
}

/**
 * Assert no duplicate FORENSIC_TRACE snapshot emitted from CACHE for the same offerId.
 * Detects stale-cache resurrection.
 */
function assertNoCacheResurrection(device, offerId) {
  const cacheLines = device.findLogLines(`FORENSIC_TRACE`).filter(
    l => l.includes('source=CACHE') && l.includes('docs=1') && l.includes(offerId)
  );
  return assert(
    cacheLines.length === 0,
    `No stale-cache resurrection for offer ${offerId}`,
    { cacheLines }
  );
}

// ── SLA assertions ────────────────────────────────────────────────────────

/**
 * Assert a timeline delta is within the SLA window.
 * @param {Timeline} timeline
 * @param {string}   eventA
 * @param {string}   eventB
 * @param {number}   maxMs
 */
function assertSLAWithin(timeline, eventA, eventB, maxMs) {
  const delta = timeline.delta(eventA, eventB);
  return assert(
    delta !== null && delta <= maxMs,
    `SLA: ${eventA} → ${eventB} within ${maxMs}ms`,
    { delta, maxMs, slaBreached: delta === null || delta > maxMs }
  );
}

module.exports = {
  AssertionError,
  assert,
  assertFullscreenVisible,
  assertAppForegrounded,
  assertNoZombieAuthority,
  assertFirestoreField,
  assertOrderStatus,
  assertOfferDead,
  assertLogContains,
  assertNoCacheResurrection,
  assertSLAWithin,
};
