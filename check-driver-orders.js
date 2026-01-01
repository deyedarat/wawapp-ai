const admin = require('firebase-admin');

// Initialize Firebase
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();

async function checkDriverOrders() {
  const driverId = 'kEvNpIoDYzPByklrafRswR5Vy2y1';

  console.log(`\n=== Checking orders for driver: ${driverId} ===\n`);

  // 1. Check driver profile
  const driverDoc = await db.collection('drivers').doc(driverId).get();
  if (!driverDoc.exists) {
    console.log('❌ Driver profile not found!');
    return;
  }

  const driver = driverDoc.data();
  console.log('✅ Driver profile found:');
  console.log(`   - Name: ${driver.name}`);
  console.log(`   - Online: ${driver.isOnline}`);
  console.log(`   - Verified: ${driver.isVerified}`);
  console.log(`   - City: ${driver.city || 'N/A'}`);

  // 2. Check driver location
  const locationDoc = await db.collection('driverLocations').doc(driverId).get();
  if (!locationDoc.exists) {
    console.log('\n❌ Driver location not found!');
    console.log('   → Driver needs to turn on location services');
    return;
  }

  const location = locationDoc.data();
  console.log(`\n✅ Driver location found:`);
  console.log(`   - Lat: ${location.lat}`);
  console.log(`   - Lng: ${location.lng}`);
  console.log(`   - Last update: ${location.timestamp?.toDate?.() || 'N/A'}`);

  // 3. Query available orders
  const ordersSnapshot = await db.collection('orders')
    .where('assignedDriverId', '==', null)
    .orderBy('createdAt', 'desc')
    .limit(50)
    .get();

  console.log(`\n📦 Total unassigned orders: ${ordersSnapshot.size}`);

  if (ordersSnapshot.empty) {
    console.log('   → No orders available in the system');
    return;
  }

  // 4. Filter orders by status and distance
  const validStatuses = ['matching', 'requested', 'assigning'];
  const radiusKm = 6.0;
  let nearbyOrders = [];

  ordersSnapshot.forEach(doc => {
    const order = doc.data();

    // Check status
    if (!validStatuses.includes(order.status)) {
      return;
    }

    // Check pickup location
    if (!order.pickup || !order.pickup.lat || !order.pickup.lng) {
      return;
    }

    // Calculate distance (Haversine formula)
    const distance = calculateDistance(
      location.lat,
      location.lng,
      order.pickup.lat,
      order.pickup.lng
    );

    if (distance <= radiusKm) {
      nearbyOrders.push({
        id: doc.id,
        status: order.status,
        pickup: {
          lat: order.pickup.lat,
          lng: order.pickup.lng,
          address: order.pickup.address || 'N/A'
        },
        distanceKm: Math.round(distance * 10) / 10,
        createdAt: order.createdAt?.toDate?.() || 'N/A'
      });
    }
  });

  nearbyOrders.sort((a, b) => a.distanceKm - b.distanceKm);

  console.log(`\n🎯 Orders within ${radiusKm}km: ${nearbyOrders.length}`);

  if (nearbyOrders.length === 0) {
    console.log('   → No orders found within range');
    console.log(`   → Driver location: (${location.lat}, ${location.lng})`);
    console.log(`   → Search radius: ${radiusKm}km`);
  } else {
    console.log('\n📍 Nearby orders:');
    nearbyOrders.forEach((order, i) => {
      console.log(`\n   ${i + 1}. Order ID: ${order.id}`);
      console.log(`      Status: ${order.status}`);
      console.log(`      Distance: ${order.distanceKm}km`);
      console.log(`      Pickup: ${order.pickup.address}`);
      console.log(`      Created: ${order.createdAt}`);
    });
  }

  // 5. Check why orders might not be visible
  console.log('\n\n=== Diagnostic Summary ===\n');

  const issues = [];

  if (!driver.isOnline) {
    issues.push('❌ Driver is OFFLINE - orders won\'t appear');
  } else {
    console.log('✅ Driver is ONLINE');
  }

  if (!driver.isVerified) {
    issues.push('⚠️  Driver is not verified');
  } else {
    console.log('✅ Driver is verified');
  }

  if (!location) {
    issues.push('❌ Driver location not available');
  } else {
    console.log('✅ Driver location is available');
  }

  if (nearbyOrders.length === 0) {
    issues.push('❌ No orders within range');
  } else {
    console.log(`✅ ${nearbyOrders.length} orders within range`);
  }

  if (issues.length > 0) {
    console.log('\n🔍 Issues found:');
    issues.forEach(issue => console.log(`   ${issue}`));
  } else {
    console.log('\n✅ No issues found - orders should be visible!');
  }
}

// Haversine distance formula
function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371; // Earth's radius in km
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(deg) {
  return deg * (Math.PI / 180);
}

// Run
checkDriverOrders()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('\n❌ Error:', error);
    process.exit(1);
  });
