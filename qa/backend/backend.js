'use strict';
/**
 * Backend control module — all Firebase/Firestore operations.
 * All functions accept an options object and return structured results.
 */
const { db, FieldValue, Timestamp, GeoPoint } = require('../orchestrator/firebase');
const { driver: driverCfg, location } = require('../orchestrator/config');

const DRIVER_ID = driverCfg.id;

// ─────────────────────────────────────────────────────────────────────────────
// ORDER LIFECYCLE
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Create a QA test order in Firestore.
 * Also ensures driver is online and location is set.
 * @param {object} [opts]
 * @param {string} [opts.scenario]   - label for orderId prefix
 * @param {number} [opts.lat]        - pickup lat (defaults to config)
 * @param {number} [opts.lng]
 * @param {number} [opts.price]
 * @param {boolean} [opts.tagQA]     - adds qa_test:true to order
 * @returns {{ orderId: string, offerWillDispatchTo: string }}
 */
async function createOrder(opts = {}) {
  const scenario = opts.scenario || 'qa';
  const orderId  = `qa_${scenario}_${Date.now()}`;
  const lat  = opts.lat ?? location.lat;
  const lng  = opts.lng ?? location.lng;

  // Ensure driver is online and location is fresh
  await db.collection('drivers').doc(DRIVER_ID).set({
    isOnline: true, isVerified: true, status: 'idle',
    lastOnlineAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await db.collection('driver_locations').doc(DRIVER_ID).set({
    driverId: DRIVER_ID,
    geopoint: new GeoPoint(lat, lng),
    timestamp: FieldValue.serverTimestamp(),
    status: 'online', bearing: 0, speed: 0,
  }, { merge: true });

  const orderData = {
    status:     'matching',
    pickup:     { lat, lng, address: 'QA Pickup', label: 'QA' },
    dropoff:    { lat: lat + 0.003, lng: lng + 0.003, address: 'QA Dropoff', label: 'QA' },
    price:      opts.price ?? 500,
    distance:   0.3,
    clientName: `QA Runner (${scenario})`,
    createdAt:  FieldValue.serverTimestamp(),
    correlationId: orderId,
    qa_test: true,
    ...(opts.extra || {}),
  };

  await db.collection('orders').doc(orderId).set(orderData);
  console.log(`[backend] createOrder → ${orderId}`);
  return { orderId };
}

/**
 * Cancel an order (client-side cancellation).
 */
async function cancelOrder(orderId) {
  await db.collection('orders').doc(orderId).update({
    status: 'cancelledByClient',
    cancelledAt: FieldValue.serverTimestamp(),
  });
  console.log(`[backend] cancelOrder → ${orderId}`);
}

/**
 * Forcefully expire an order (simulate timeout).
 */
async function expireOrder(orderId) {
  await db.collection('orders').doc(orderId).update({
    status: 'expired',
    expiredAt: FieldValue.serverTimestamp(),
  });
  // Also expire the dispatch offer if it exists
  const snap = await db.collection('dispatch_offers')
    .where('orderId', '==', orderId).limit(5).get();
  for (const doc of snap.docs) {
    await doc.ref.update({ status: 'expired', expiredAt: FieldValue.serverTimestamp() });
  }
  console.log(`[backend] expireOrder → ${orderId}`);
}

/**
 * Clean up all QA test orders (status != 'active_trip') tagged with qa_test=true.
 */
async function cleanupOrders() {
  const snap = await db.collection('orders')
    .where('qa_test', '==', true).limit(50).get();
  let count = 0;
  for (const doc of snap.docs) {
    const s = doc.data().status;
    if (!['active_trip'].includes(s)) {
      await doc.ref.delete();
      count++;
    }
  }
  // Clean orphaned dispatch offers
  const offers = await db.collection('dispatch_offers')
    .where('orderId', '>=', 'qa_').limit(100).get();
  for (const doc of offers.docs) {
    if (doc.id.startsWith('qa_')) await doc.ref.delete();
  }
  console.log(`[backend] cleanupOrders → removed ${count} orders`);
  return { removed: count };
}

// ─────────────────────────────────────────────────────────────────────────────
// INSPECTION
// ─────────────────────────────────────────────────────────────────────────────

async function inspectOrder(orderId) {
  const snap = await db.collection('orders').doc(orderId).get();
  return snap.exists ? snap.data() : null;
}

async function inspectDispatchOffer(orderId, driverId = DRIVER_ID) {
  const offerId = `${orderId}_${driverId}`;
  const snap = await db.collection('dispatch_offers').doc(offerId).get();
  return snap.exists ? { id: snap.id, ...snap.data() } : null;
}

async function inspectWave(orderId) {
  const snap = await db.collection('dispatch_waves')
    .where('orderId', '==', orderId).orderBy('createdAt', 'desc').limit(5).get();
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}

async function inspectDriverStatus(driverId = DRIVER_ID) {
  const [driverSnap, locSnap] = await Promise.all([
    db.collection('drivers').doc(driverId).get(),
    db.collection('driver_locations').doc(driverId).get(),
  ]);
  return {
    driver:   driverSnap.exists   ? driverSnap.data()   : null,
    location: locSnap.exists ? locSnap.data() : null,
  };
}

async function injectDriverLocation(lat = location.lat, lng = location.lng, driverId = DRIVER_ID) {
  await db.collection('driver_locations').doc(driverId).set({
    driverId, geopoint: new GeoPoint(lat, lng),
    timestamp: FieldValue.serverTimestamp(),
    status: 'online', bearing: 0, speed: 0,
  }, { merge: true });
  console.log(`[backend] injectDriverLocation → (${lat}, ${lng})`);
}

/**
 * Inject a synthetic dispatch offer directly (bypassing Cloud Functions).
 * Used in reliability tests to seed the local Firestore cache.
 */
async function injectDispatchOffer(orderId, driverId = DRIVER_ID, opts = {}) {
  const offerId = `${orderId}_${driverId}`;
  const payload = {
    orderId, driverId,
    status: opts.status ?? 'sent',
    round:  opts.round  ?? 1,
    priority: 1,
    sentAt:   FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromDate(new Date(Date.now() + (opts.ttlMs ?? 600_000))),
    distance: 0.3,
    qa_test: true,
    ...(opts.extra || {}),
  };
  await db.collection('dispatch_offers').doc(offerId).set(payload);
  console.log(`[backend] injectDispatchOffer → ${offerId} status=${payload.status}`);
  return offerId;
}

/**
 * Terminate a dispatch offer (set status=accepted).
 */
async function terminateDispatchOffer(orderId, driverId = DRIVER_ID) {
  const offerId = `${orderId}_${driverId}`;
  await db.collection('dispatch_offers').doc(offerId).update({
    status: 'accepted',
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log(`[backend] terminateDispatchOffer → ${offerId}`);
}

async function inspectFirestoreState(orderId) {
  const [order, offer, waves] = await Promise.all([
    inspectOrder(orderId),
    inspectDispatchOffer(orderId),
    inspectWave(orderId),
  ]);
  return { orderId, order, offer, waves };
}

module.exports = {
  createOrder,
  cancelOrder,
  expireOrder,
  cleanupOrders,
  inspectOrder,
  inspectDispatchOffer,
  inspectWave,
  inspectDriverStatus,
  injectDriverLocation,
  injectDispatchOffer,
  terminateDispatchOffer,
  inspectFirestoreState,
};
