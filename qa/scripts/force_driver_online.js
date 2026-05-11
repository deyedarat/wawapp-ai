const admin = require('firebase-admin');
const serviceAccount = require('C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json');

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'wawapp-952d6'
    });
}
const db = admin.firestore();

async function goOnline() {
    const driverId = "49ZGFxTVAMaAMkVd4GQZ9Juyjgf1";
    console.log(`[FORCE_ONLINE] DEFINITIVE ONLINE BOOTSTRAP FOR ${driverId}`);
    
    // Standard coordinate anchor used in all QA orders to ensure 100% dispatch match probability
    const lat = 18.0954303;
    const lng = -15.9679639;

    // 1. Update Driver Root Document
    await db.collection('drivers').doc(driverId).update({
        status: 'online',
        isAvailable: true,
        lastActive: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log("[FORCE_ONLINE] 🟢 Set Driver Doc status=online");

    // 2. Force Location Document explicitly at target injection coordinate
    const locRef = db.collection('driver_locations').doc(driverId);
    await locRef.set({
        driverId: driverId,
        geopoint: new admin.firestore.GeoPoint(lat, lng),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'online',
        bearing: 0,
        speed: 0
    }, { merge: true });
    console.log("[FORCE_ONLINE] 📍 Forced Spatial Location to Wave Epicenter: " + lat + ", " + lng);
    console.log("[FORCE_ONLINE] ✅ BOOTSTRAP COMPLETE. 100% MATCH CERTAINTY ACHIEVED.");
}

goOnline().catch(console.error);
