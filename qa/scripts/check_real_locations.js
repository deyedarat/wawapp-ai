const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();

async function checkRealLocations() {
  console.log("Inspecting production-like driver_locations (with underscore)...");
  const snapshot = await db.collection('driver_locations').limit(3).get();
  
  snapshot.forEach(doc => {
     console.log(`--- Driver ID: ${doc.id} ---`);
     console.log(JSON.stringify(doc.data(), null, 2));
  });
  
  process.exit(0);
}

checkRealLocations().catch(console.error);
