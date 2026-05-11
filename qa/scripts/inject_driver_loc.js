const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();
const driverId = '49ZGFxTVAMaAMkVd4GQZ9Juyjgf1';

async function fixLocation() {
  console.log(`Injecting valid location for driver ${driverId}...`);
  
  await db.collection('drivers').doc(driverId).update({
    isOnline: true,
    status: 'idle',
    location: new admin.firestore.GeoPoint(18.077, -15.958),
    lastLocationUpdate: admin.firestore.FieldValue.serverTimestamp()
  });
  
  console.log("✅ Location fixed. Driver now considered eligible and fresh by matcher.");
  process.exit(0);
}

fixLocation().catch(console.error);
