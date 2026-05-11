const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();
const driverId = '49ZGFxTVAMaAMkVd4GQZ9Juyjgf1';

async function inspect() {
  const orderId = 'e2e_phase4_final_victory_1778421393814';
  console.log(`Inspecting Order ${orderId}...`);
  const doc = await db.collection('orders').doc(orderId).get();
  if (!doc.exists) {
    console.log("Order doesn't exist!");
    process.exit(0);
  }
  console.log("STATUS:", doc.data().status);
  
  const wavesSnapshot = await db.collection('orders').doc(orderId).collection('waves').get();
  console.log(`Found ${wavesSnapshot.size} waves.`);
  wavesSnapshot.forEach(w => {
    const data = w.data();
    console.log(`WAVE ${w.id} | STATUS: ${data.status} | TARGETS: ${data.drivers?.length || 0}`);
    if (data.drivers?.includes(driverId)) {
      console.log(`>>> SUCCESS: Target driver included in wave ${w.id}!`);
    }
  });
  process.exit(0);
}

inspect().catch(console.error);
