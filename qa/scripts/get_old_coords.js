const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();

async function getOldCoords() {
  const doc = await db.collection('orders').doc('m84aR9I0vlCsNJwC7lBc').get();
  const data = doc.data();
  console.log(`=== OLD SUCCESSFUL ORDER COORDS ===`);
  console.log(`PICKUP: ${JSON.stringify(data.pickup)}`);
  console.log(`DROPOFF: ${JSON.stringify(data.dropoff)}`);
  process.exit(0);
}

getOldCoords().catch(console.error);
