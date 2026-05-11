const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();

async function inspect() {
  console.log("Fetching 10 most recent orders...");
  const snapshot = await db.collection('orders').orderBy('createdAt', 'desc').limit(10).get();
  
  snapshot.forEach(doc => {
    const data = doc.data();
    console.log(`ORDER: ${doc.id} | STATUS: ${data.status} | CREATED_AT: ${data.createdAt ? data.createdAt.toDate().toISOString() : 'null'}`);
  });
  process.exit(0);
}

inspect().catch(console.error);
