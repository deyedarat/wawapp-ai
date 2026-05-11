const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'wawapp-952d6'
    });
}
const db = admin.firestore();

async function cleanOffers() {
    const driverId = "49ZGFxTVAMaAMkVd4GQZ9Juyjgf1";
    console.log(`[CLEANUP_OFFERS] Commencing purge for Driver: ${driverId}`);
    
    // 1. Find ALL offers currently tying down this driver
    const snap = await db.collection('dispatch_offers')
        .where('driverId', '==', driverId)
        .get();

    console.log(`Found ${snap.size} total offer documents to evaluate.`);
    let count = 0;
    const batch = db.batch();

    snap.forEach(doc => {
        // Nuke them from orbit. It's the only way to be sure.
        batch.delete(doc.ref);
        count++;
    });

    if (count > 0) {
        await batch.commit();
        console.log(`✅ DELETED ${count} STALE OFFER DOCUMENTS. Driver memory cleared.`);
    } else {
        console.log("✅ No stale offers found. Driver memory is already pristine.");
    }
}

cleanOffers().catch(console.error);
