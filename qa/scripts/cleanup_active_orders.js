const admin = require('firebase-admin');

const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();

async function cleanup() {
  console.log("Fetching active/matching orders to clear...");
  
  const activeStatuses = ['matching', 'created', 'assigned', 'accepted'];
  let cleanedCount = 0;
  
  for (const status of activeStatuses) {
    const snapshot = await db.collection('orders').where('status', '==', status).get();
    
    for (const doc of snapshot.docs) {
       console.log(`Cancelling legacy order ${doc.id} (status: ${status})`);
       await doc.ref.update({
         status: 'cancelledByClient',
         cancellationReason: 'QA_ISOLATION_PURGE',
         updatedAt: admin.firestore.FieldValue.serverTimestamp()
       });
       cleanedCount++;
    }
  }
  
  console.log(`✅ Cleanup complete. Cancelled ${cleanedCount} legacy orders.`);
  process.exit(0);
}

cleanup().catch(err => {
  console.error("Cleanup error:", err);
  process.exit(1);
});
