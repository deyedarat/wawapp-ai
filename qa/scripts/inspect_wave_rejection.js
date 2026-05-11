const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'wawapp-952d6'
    });
}
const db = admin.firestore();

async function inspectWaves() {
    const docId = 'e2e_mitigation_scenario_transient_1778480735736';
    console.log("Inspecting Waves for " + docId);
    
    const wavesSnap = await db.collection('orders').doc(docId).collection('waves').get();
    console.log(`Found ${wavesSnap.size} wave documents.`);
    
    wavesSnap.forEach(doc => {
        const d = doc.data();
        console.log("--- WAVE DATA ---");
        console.log("Status:", d.status);
        console.log("Candidates Count:", d.candidatesCount);
        console.log("Eligible Count:", d.eligibleCount);
        console.log("Skipped/Excluded Drivers Log:", d.exclusionLog || d.skippedDrivers || "No log found");
        console.log("Potential Matches Detail:", JSON.stringify(d.matches || [], null, 2));
    });
}

inspectWaves().catch(console.error);
