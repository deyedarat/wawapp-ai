import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

export const acceptOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const driverId = context.auth.uid;
  const { orderId } = data;
  const offerId = data.offerId as string | undefined;

  if (!orderId || typeof orderId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'orderId is required');
  }

  const db = admin.firestore();

  // Verify driver is verified
  const driverDoc = await db.collection('drivers').doc(driverId).get();
  if (!driverDoc.exists || !driverDoc.data()?.isVerified) {
    throw new functions.https.HttpsError('permission-denied', 'Driver account is not verified');
  }

  try {
    let customerPhone: string | null = null;

    await db.runTransaction(async (transaction) => {
      const orderRef = db.collection('orders').doc(orderId);
      const orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Order not found');
      }

      const orderData = orderDoc.data()!;

      if (orderData.status !== 'matching') {
        throw new functions.https.HttpsError('failed-precondition', 'Order was already taken');
      }

      if (orderData.assignedDriverId) {
        throw new functions.https.HttpsError('failed-precondition', 'Order already assigned');
      }

      // Fetch customer phone number
      const ownerId = orderData.ownerId as string;

      if (ownerId) {
        try {
          const userDoc = await transaction.get(db.collection('users').doc(ownerId));
          if (userDoc.exists) {
            const userData = userDoc.data();
            customerPhone = (userData?.phone as string) || (userData?.phoneNumber as string) || null;
          }
        } catch (phoneErr) {
          console.warn('[AcceptOrder] Failed to fetch customer phone', {
            order_id: orderId,
            owner_id: ownerId,
            error: phoneErr,
          });
        }
      }

      transaction.update(orderRef, {
        status: 'accepted',
        assignedDriverId: driverId,
        driverId: driverId,
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        customerPhone: customerPhone,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    console.log('[AcceptOrder] Order accepted with customer phone', {
      order_id: orderId,
      driver_id: driverId,
      has_phone: customerPhone !== null,
    });

    // Update dispatch_offers after successful acceptance (non-blocking)
    if (offerId) {
      try {
        await db.collection('dispatch_offers').doc(offerId).update({
          status: 'accepted',
          respondedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Expire all other sent offers for this order
        const otherOffers = await db.collection('dispatch_offers')
          .where('orderId', '==', orderId)
          .where('status', '==', 'sent')
          .get();

        if (!otherOffers.empty) {
          const batch = db.batch();
          for (const doc of otherOffers.docs) {
            if (doc.id !== offerId) {
              batch.update(doc.ref, { status: 'expired' });
            }
          }
          await batch.commit();
        }

        console.log('[AcceptOrder] Dispatch offers updated', {
          accepted_offer: offerId,
          expired_count: otherOffers.size > 0 ? otherOffers.size - 1 : 0,
        });
      } catch (offerErr: any) {
        console.warn('[AcceptOrder] Failed to update dispatch offers (non-critical)', {
          offer_id: offerId,
          error: offerErr.message,
        });
      }
    }

    return { success: true };
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) throw error;
    console.error('[acceptOrder] Error:', error.message);
    throw new functions.https.HttpsError('internal', 'Failed to accept order');
  }
});
