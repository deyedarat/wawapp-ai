/**
 * Temporary admin function to fix duplicate driver registrations
 * caused by phone number format mismatch (local vs E.164)
 * 
 * Can be removed after running once.
 */
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v1';

export const fixDuplicateDrivers = functions.https.onCall(async (_data, context) => {
    // Require admin authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }

    // Check admin claims
    const claims = context.auth.token;
    if (!claims.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    const db = admin.firestore();
    const driversSnapshot = await db.collection('drivers').get();

    const results: any[] = [];
    const localPhoneDrivers: any[] = [];

    driversSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.phone && typeof data.phone === 'string' && !data.phone.startsWith('+')) {
            localPhoneDrivers.push({ id: doc.id, ...data });
        }
    });

    console.log(`[fixDuplicateDrivers] Found ${localPhoneDrivers.length} drivers with local phone format`);

    for (const localDriver of localPhoneDrivers) {
        const e164Phone = `+222${localDriver.phone}`;

        // Check if E.164 version exists
        const e164Snapshot = await db.collection('drivers')
            .where('phone', '==', e164Phone)
            .limit(1)
            .get();

        if (!e164Snapshot.empty) {
            // Duplicate found - delete the local format one
            const e164Doc = e164Snapshot.docs[0];
            const e164Data = e164Doc.data();

            // Merge important data before deleting
            const mergeData: any = {};
            if (localDriver.pinHash && !e164Data.pinHash) {
                mergeData.pinHash = localDriver.pinHash;
                mergeData.pinSalt = localDriver.pinSalt;
                mergeData.hasPin = true;
            }
            if (localDriver.name && !e164Data.name) {
                mergeData.name = localDriver.name;
            }

            if (Object.keys(mergeData).length > 0) {
                await db.collection('drivers').doc(e164Doc.id).update(mergeData);
            }

            // Delete duplicate
            await db.collection('drivers').doc(localDriver.id).delete();

            // Delete Auth user if exists
            try {
                await admin.auth().deleteUser(localDriver.id);
            } catch (e: any) {
                // Ignore if not found
            }

            results.push({
                action: 'deleted_duplicate',
                deletedId: localDriver.id,
                keptId: e164Doc.id,
                phone: e164Phone,
                name: localDriver.name || e164Data.name || 'N/A',
            });
        } else {
            // No duplicate - just fix the phone format
            await db.collection('drivers').doc(localDriver.id).update({ phone: e164Phone });
            results.push({
                action: 'fixed_format',
                id: localDriver.id,
                oldPhone: localDriver.phone,
                newPhone: e164Phone,
                name: localDriver.name || 'N/A',
            });
        }
    }

    return {
        totalScanned: driversSnapshot.size,
        localFormatFound: localPhoneDrivers.length,
        actions: results,
    };
});
