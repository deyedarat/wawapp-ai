import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

export const rejectDispatchOffer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const driverId = context.auth.uid;
  const { offerId, orderId } = data;

  if (!offerId || typeof offerId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'offerId is required');
  }
  if (!orderId || typeof orderId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'orderId is required');
  }

  const db = admin.firestore();

  try {
    await db.runTransaction(async (transaction) => {
      const offerRef = db.collection('dispatch_offers').doc(offerId);
      const offerDoc = await transaction.get(offerRef);

      if (!offerDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Offer not found');
      }

      const offerData = offerDoc.data()!;

      if (offerData.driverId !== driverId) {
        throw new functions.https.HttpsError('permission-denied', 'Not your offer');
      }

      if (offerData.status !== 'sent') {
        throw new functions.https.HttpsError('failed-precondition', `Offer already ${offerData.status}`);
      }

      transaction.update(offerRef, {
        status: 'rejected',
        respondedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const rejectionRef = db.collection('driver_rejected_orders').doc();
      transaction.set(rejectionRef, {
        driverId,
        orderId,
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 24 * 60 * 60 * 1000)
        ),
      });
    });

    console.log('[RejectDispatchOffer] Offer rejected', {
      offer_id: offerId,
      order_id: orderId,
      driver_id: driverId,
    });

    return { success: true };
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) throw error;
    console.error('[RejectDispatchOffer] Error:', error.message);
    throw new functions.https.HttpsError('internal', 'Failed to reject offer');
  }
});
