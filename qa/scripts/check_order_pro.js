const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();

async function run() {
    const docId = 'e2e_zombie_repro_target_1778422946486';
    const snap = await db.collection('orders').doc(docId).get();
    if (snap.exists) {
        console.log(`[ZOMBIE_DISPATCH_CONFIRMED_STATUS] Status is: ${snap.data().status}`);
    } else {
        console.log(`[ZOMBIE_DISPATCH_CONFIRMED_STATUS] ORDER_DELETED`);
    }
    process.exit(0);
}

run().catch(console.error);
