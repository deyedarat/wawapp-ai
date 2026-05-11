const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();
const driverId = '49ZGFxTVAMaAMkVd4GQZ9Juyjgf1';

async function checkDriver() {
  const doc = await db.collection('drivers').doc(driverId).get();
  if (!doc.exists) {
    console.log("Driver doc missing!");
    process.exit(0);
  }
  const data = doc.data();
  console.log(`DRIVER STATUS: ${data.status}`);
  console.log(`ONLINE: ${data.isOnline}`);
  console.log(`LOCATION: ${JSON.stringify(data.location)}`);
  console.log(`LAST LOCATION UPDATE: ${data.lastLocationUpdate ? data.lastLocationUpdate.toDate().toISOString() : 'never'}`);
  console.log(`SERVER TIMESTAMP NOW: ${new Date().toISOString()}`);
  process.exit(0);
}

checkDriver().catch(console.error);
