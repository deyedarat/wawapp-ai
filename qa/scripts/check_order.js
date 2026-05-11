const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp({projectId:'wawapp-mvp'});
async function run() {
    const s = await admin.firestore().collection('orders').doc('e2e_zombie_repro_target_1778422946486').get();
    console.log("EXPLICIT_FINAL_STATUS:" + (s.exists ? s.data().status : "DELETED"));
}
run().catch(console.error);
