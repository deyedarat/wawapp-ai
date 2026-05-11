const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();
const driverId = '49ZGFxTVAMaAMkVd4GQZ9Juyjgf1';

async function fullDump() {
  const doc = await db.collection('drivers').doc(driverId).get();
  console.log(`=== DRIVER DOC DUMP ===`);
  console.log(JSON.stringify(doc.data(), null, 2));
  
  // Also dump the driverToken doc if exists
  const tokenDoc = await db.collection('driverTokens').doc(driverId).get();
  console.log(`=== TOKEN DOC DUMP ===`);
  if (tokenDoc.exists) {
    console.log(JSON.stringify(tokenDoc.data(), null, 2));
  } else {
    console.log("NO TOKEN DOCUMENT FOUND FOR DRIVER!!!");
  }
  
  process.exit(0);
}

fullDump().catch(console.error);
