const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();

async function auditLocations() {
  console.log("Scanning driverLocations collection samples...");
  const snapshot = await db.collection('driverLocations').limit(3).get();
  
  snapshot.forEach(doc => {
     console.log(`--- Doc ID: ${doc.id} ---`);
     console.log(JSON.stringify(doc.data(), null, 2));
  });
  
  process.exit(0);
}

auditLocations().catch(console.error);
