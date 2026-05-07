const admin = require('firebase-admin');

const serviceAccount = require('C:/Users/user/Music/wawapp-mcp-debug-server/config/dev-service-account.json');
const driverId = '49ZGFxTVAMaAMkVd4GQZ9Juyjgf1';

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();

async function main() {
  const scenario = process.argv[2] || 'SCENARIO_A';
  const orderId = `e2e_${scenario.toLowerCase()}_${Date.now()}`;

  console.log(`[SUBMIT_ORDER] Configuring driver profile and location for driver: ${driverId}`);
  
  // Set driver online and verified
  await db.collection('drivers').doc(driverId).set({
    isOnline: true,
    isVerified: true,
    name: 'QA Driver (Device B)'
  }, { merge: true });

  // Update driver location to match pickup
  await db.collection('driverLocations').doc(driverId).set({
    lat: 18.0735,
    lng: -15.9582,
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });

  console.log(`[SUBMIT_ORDER] Creating order document: orders/${orderId}`);

  const orderData = {
    status: 'matching',
    pickup: {
      lat: 18.0735,
      lng: -15.9582,
      address: 'QA E2E Pickup Point'
    },
    dropoff: {
      lat: 18.0800,
      lng: -15.9500,
      address: 'QA E2E Dropoff Point'
    },
    price: 500,
    distance: 1.5,
    clientName: 'E2E Tester Device A',
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('orders').doc(orderId).set(orderData);

  console.log(`ORDER_ID_CREATED:${orderId}`);

  // Listen to order document to track backend acceptance confirmation
  const unsubscribe = db.collection('orders').doc(orderId).onSnapshot(doc => {
    if (doc.exists) {
      const status = doc.data().status;
      const assignedDriver = doc.data().assignedDriverId;
      console.log(`[SUBMIT_ORDER] Order ${orderId} updated: status=${status}, assignedDriver=${assignedDriver}`);
      if (status === 'accepted') {
        console.log(`BACKEND_ACCEPT_CONFIRMED:${Date.now()}`);
        unsubscribe();
        process.exit(0);
      }
    }
  });

  // Timeout after 60s
  setTimeout(() => {
    console.log('[SUBMIT_ORDER] Timeout waiting for order status accepted');
    unsubscribe();
    process.exit(0);
  }, 60000);
}

main().catch(err => {
  console.error('[SUBMIT_ORDER] Error:', err);
  process.exit(1);
});
