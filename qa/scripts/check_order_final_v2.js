const admin = require('firebase-admin');
const fs = require('fs');
if (!admin.apps.length) admin.initializeApp({projectId:'wawapp-mvp'});
async function run() {
    const s = await admin.firestore().collection('orders').doc('e2e_zombie_repro_target_1778422946486').get();
    const status = s.exists ? s.data().status : "DELETED";
    console.log("WRITING_FINAL_VAL:", status);
    fs.writeFileSync('c:\\Users\\hp\\Music\\wawapp-ai\\final_order_status_reworked.txt', status);
    process.exit(0);
}
run().catch(console.error);
