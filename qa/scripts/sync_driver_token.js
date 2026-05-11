const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();
const driverId = '49ZGFxTVAMaAMkVd4GQZ9Juyjgf1';

async function syncToken() {
  console.log(`Fetching current token from driver doc...`);
  const driverDoc = await db.collection('drivers').doc(driverId).get();
  const token = driverDoc.data().fcmToken;
  
  if (!token) {
    console.error("No token found in driver doc!");
    process.exit(1);
  }
  
  console.log(`Syncing token to driverTokens collection: ${token}`);
  
  await db.collection('driverTokens').doc(driverId).set({
    token: token,
    platform: 'android',
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  console.log("✅ Token successfully synced to driverTokens. Cloud Functions can now target this device!");
  process.exit(0);
}

syncToken().catch(console.error);
