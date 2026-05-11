const admin = require('firebase-admin');

const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');
const driverId = '49ZGFxTVAMaAMkVd4GQZ9Juyjgf1';

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();

async function main() {
  const scenario = process.argv[2] || 'PHASE4_FINAL_VICTORY';
  const orderId = `e2e_${scenario.toLowerCase()}_${Date.now()}`;

  // THE REAL DEVICE GPS COORDINATES DETECTED IN DRIVER_LOCATIONS!!!
  const deviceLat = 18.0954303;
  const deviceLng = -15.9679639;

  console.log(`[SUBMIT_ORDER] Using LIVE DEVICE GPS COORDS: ${deviceLat}, ${deviceLng}`);
  
  // Set driver online and verified, don't overwrite existing valid spatial fields!
  await db.collection('drivers').doc(driverId).set({
    isOnline: true,
    isVerified: true,
    status: 'idle',
    lastOnlineAt: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });

  console.log(`[SUBMIT_ORDER] Creating order at device proximity: orders/${orderId}`);

  const orderData = {
    status: 'matching',
    pickup: {
      lat: deviceLat,
      lng: deviceLng,
      address: 'QA Proximity Pickup',
      label: 'موقعي الحالي'
    },
    dropoff: {
      lat: deviceLat + 0.002, // Tiny displacement
      lng: deviceLng + 0.002,
      address: 'QA Proximity Dropoff',
      label: 'موقعي الحالي'
    },
    price: 500,
    distance: 0.2,
    clientName: 'Phase 4 Runner Final',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('orders').doc(orderId).set(orderData);

  console.log(`ORDER_ID_CREATED:${orderId}`);

  setTimeout(() => {
    console.log('[SUBMIT_ORDER] Final injection completed. Handing over to telemetry.');
    process.exit(0);
  }, 10000);
}

main().catch(err => {
  console.error('[SUBMIT_ORDER] Error:', err);
  process.exit(1);
});
