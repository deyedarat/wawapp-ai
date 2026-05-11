const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

async function run() {
  const uid = '49ZGFxTVAMaAMkVd4GQZ9Juyjgf1';
  try {
    const user = await auth.getUser(uid);
    console.log("Auth record:", JSON.stringify(user, null, 2));
    
    const doc = await db.collection('drivers').doc(uid).get();
    if (doc.exists) {
      console.log("Driver data:", JSON.stringify(doc.data(), null, 2));
    } else {
      console.log("No Firestore document found for driver.");
    }
  } catch (e) {
    console.error("Error:", e);
  }
}

run();
