const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'wawapp-952d6'
    });
}
const db = admin.firestore();

async function run(phase, forcedId = null) {
    const fs = require('fs');
    const trackingPath = 'qa_forensics/active_repro_oid.txt';
    
    let orderId;
    if (phase === 'inject') {
        orderId = `repro_order_${Date.now()}`;
        fs.writeFileSync(trackingPath, orderId);
    } else {
        try {
            orderId = fs.readFileSync(trackingPath, 'utf8').trim();
        } catch(e) {
            console.error("No active repro OID found in temp store.");
            process.exit(1);
        }
    }
    
    const driverId = "49ZGFxTVAMaAMkVd4GQZ9Juyjgf1";
    const offerId = `${orderId}_${driverId}`;
    const offerRef = db.collection('dispatch_offers').doc(offerId);

    if (phase === 'inject') {
        console.log(`[REPRO] Phase 1: Injecting offer ${orderId} as 'sent'`);
        await offerRef.set({
            orderId: orderId,
            driverId: "49ZGFxTVAMaAMkVd4GQZ9Juyjgf1",
            status: 'sent',
            round: 1,
            priority: 1,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 600000)),
            distance: 0.5
        });
        console.log("[REPRO] ✅ Document injected.");
    } else if (phase === 'terminate') {
        console.log("[REPRO] Phase 2: Terminating offer in backend (setting to 'accepted')");
        await offerRef.update({
            status: 'accepted',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log("[REPRO] ✅ Document terminated in Firestore.");
    } else if (phase === 'cleanup') {
        console.log("[REPRO] Cleanup: Deleting doc.");
        await offerRef.delete();
        console.log("[REPRO] ✅ Cleanup complete.");
    }
    process.exit(0);
}

const mode = process.argv[2] || 'inject';
run(mode).catch(e => {
    console.error(e);
    process.exit(1);
});
