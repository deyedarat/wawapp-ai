const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'wawapp-952d6'
    });
}
const db = admin.firestore();

async function directPoison(mode, orderId = null) {
    console.log(`[POISON_DIRECTOR] Mode: ${mode} for Target: ${orderId || "Next Wave"}`);
    
    const driverId = "49ZGFxTVAMaAMkVd4GQZ9Juyjgf1";

    // Step 1: Inject standard order via shell if not provided
    let targetOrderId = orderId;
    if (!targetOrderId) {
        const { execSync } = require('child_process');
        console.log("[POISON_DIRECTOR] Injecting absolute wave cannon...");
        const output = execSync(`node qa/scripts/submit_order.js "MITIGATION_GODMODE_${mode}"`).toString();
        const match = output.match(/ORDER_ID_CREATED:(e2e_[\w_]+)/);
        if (!match) throw new Error("Wave injection failed");
        targetOrderId = match[1];
        console.log(`[POISON_DIRECTOR] Generated Order ID: ${targetOrderId}`);
    }

    // Step 2: SYNTHETICALLY GENERATE THE DISPATCH_OFFER DOC 
    // This forces the App to see it in the realtime stream WITHOUT waiting for Cloud Functions!!!
    const offerId = `${targetOrderId}_${driverId}`;
    const offerRef = db.collection('dispatch_offers').doc(offerId);

    // Build fully valid synthetic payload mirroring actual cloud architecture
    const basePayload = {
        orderId: targetOrderId,
        driverId: driverId,
        status: 'sent', // The trigger state Flutter listens for!
        round: 1,
        priority: 1,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 600000)), // Expires in 10 mins
        distance: 0.1
    };

    console.log(`[POISON_DIRECTOR] 💥 MANUALLY CREATING SYNTHETIC DISPATCH DOC: ${offerId}`);
    await offerRef.set(basePayload);
    console.log(`[POISON_DIRECTOR] ✅ Synthetic doc established. Flutter UI will trigger NOW.`);

    // Step 3: Apply Scenario Poison Payload
    if (mode === 'TRANSIENT' || mode === 'REPEATED') {
        // Corrupt the very document we just made so acceptOfferV2 backend validation FAILS.
        // We update the 'status' to poison validation on the CLOUD FUNCTION side when it calls accept!
        console.log("[POISON_DIRECTOR] Applying poison corruption for fail logic simulation...");
        await offerRef.update({ status: 'poisoned_by_suite_corruption' });
        console.log(`[POISON_DIRECTOR] 💀 DOC POISONED IN FIRESTORE SUCCESS.`);

    } else if (mode === 'FATAL_ALREADY_TAKEN') {
        // Simulate fatal lock state
        await db.collection('orders').doc(targetOrderId).update({
            status: 'accepted',
            assignedDriverId: 'fake_other_driver_id',
            acceptedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`[POISON_DIRECTOR] 💀 Poisoned ORDER doc to status=accepted (simulating ALREADY TAKEN)`);

    } else if (mode === 'BACKEND_CANCEL') {
        // Simulate client cancelling
        await db.collection('orders').doc(targetOrderId).update({
            status: 'cancelledByClient',
            cancelledAt: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`[POISON_DIRECTOR] 💀 Poisoned ORDER doc directly to status=cancelledByClient`);
    }

    console.log(`[POISON_DIRECTOR] ✅ TOTAL OPERATION COMPLETED FOR ORDER: ${targetOrderId}`);
    return targetOrderId;
}

const args = process.argv.slice(2);
const mode = args[0] || 'TRANSIENT';
const oid = args[1];

directPoison(mode, oid).catch(e => {
    console.error("[POISON_DIRECTOR] ❌ FATAL:", e);
    process.exit(1);
});
