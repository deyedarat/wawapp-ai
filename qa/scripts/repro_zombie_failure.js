const admin = require('firebase-admin');
if (!admin.apps.length) {
    admin.initializeApp({
        projectId: 'wawapp-mvp'
    });
}
const db = admin.firestore();

async function runRepro() {
    console.log("[ZOMBIE_REPRO] 1. Cleaning existing legacy state...");
    // Ensure app is ready, clear state
    const driverId = "49ZGFxTVAMaAMkVd4GQZ9Juyjgf1";

    // Trigger genuine wave using existing script via exec, capture orderId
    const { execSync } = require('child_process');
    console.log("[ZOMBIE_REPRO] 2. Firing live wave cannon...");
    const output = execSync('node qa/scripts/submit_order.js "ZOMBIE_REPRO_TARGET"').toString();
    
    const match = output.match(/ORDER_ID_CREATED:(e2e_[\w_]+)/);
    if (!match) {
        console.error("Failed to get order id!");
        return;
    }
    const orderId = match[1];
    console.log(`[ZOMBIE_REPRO] Order Created: ${orderId}`);

    // Wait for Cloud function to generate the wave offer doc
    console.log("[ZOMBIE_REPRO] 3. Waiting 5 seconds for Wave generation...");
    await new Promise(r => setTimeout(r, 5000));

    // Find the generated offer doc for this driver
    const offersSnap = await db.collection('dispatch_offers')
        .where('orderId', '==', orderId)
        .where('driverId', '==', driverId)
        .get();

    if (offersSnap.empty) {
        console.error("[ZOMBIE_REPRO] FATAL: No offer doc found! Cloud functions slow?");
        return;
    }

    const offerDoc = offersSnap.docs[0];
    console.log(`[ZOMBIE_REPRO] Poisoning Offer Doc: ${offerDoc.id}`);
    
    // STEP 4: CORRUPT THE OFFER DOC STATUS SO CLOUD FUNCTION WILL FAIL, BUT ORDER DOC REMAINS VALID!
    await offerDoc.ref.update({
        status: 'corrupted_by_qa_agent', // Cloud Func expects 'pending' or 'sent'
        timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log("[ZOMBIE_REPRO] 💀 POISON INJECTED SUCCESSFULLY. Offer doc is now INVALID.");
    console.log("[ZOMBIE_REPRO] Ready for forensic UI Accept step. The app UI is live.");
    console.log(`[ZOMBIE_REPRO] ORDER_ID: ${orderId}`);
    console.log(`[ZOMBIE_REPRO] OFFER_ID: ${offerDoc.id}`);
}

runRepro().catch(console.error);
