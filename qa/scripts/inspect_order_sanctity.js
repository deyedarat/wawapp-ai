const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'wawapp-952d6'
    });
}
const db = admin.firestore();

async function inspectOrder() {
    const docId = 'e2e_mitigation_scenario_transient_1778480735736';
    console.log("DUMPING ORDER DATA FOR " + docId);
    
    const snap = await db.collection('orders').doc(docId).get();
    if (!snap.exists) {
        console.log("ORDER DOES NOT EXIST IN THIS DATABASE!!!!!!");
    } else {
        console.log(JSON.stringify(snap.data(), null, 2));
    }
}

inspectOrder().catch(console.error);
