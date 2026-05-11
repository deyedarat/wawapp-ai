const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

const db = admin.firestore();

async function scanDrivers() {
  console.log("Scanning top 5 other drivers to understand spatial schema...");
  const snapshot = await db.collection('drivers').limit(5).get();
  snapshot.forEach(doc => {
    const data = doc.data();
    console.log(`--- Driver: ${doc.id} ---`);
    console.log(JSON.stringify(data, (key, value) => {
        // Exclude long strings/blobs to avoid noise, just show structure
        if (key === 'fcmToken' || key === 'pinHash') return '[REDACTED]';
        return value;
    }, 2));
  });
  process.exit(0);
}

scanDrivers().catch(console.error);
