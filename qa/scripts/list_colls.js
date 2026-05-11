const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();

async function listCollections() {
  console.log("Listing all root collections...");
  const colls = await db.listCollections();
  colls.forEach(c => console.log(`- Collection: ${c.id}`));
  process.exit(0);
}

listCollections().catch(console.error);
