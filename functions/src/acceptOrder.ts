import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

export const acceptOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const driverId = context.auth.uid;
  const { orderId } = data;

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

      transaction.update(orderRef, {
        status: 'accepted',
        assignedDriverId: driverId,
        driverId: driverId,
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    console.log(`[acceptOrder] Order ${orderId} accepted by driver ${driverId}`);
    return { success: true };
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) throw error;
    console.error('[acceptOrder] Error:', error.message);
    throw new functions.https.HttpsError('internal', 'Failed to accept order');
  }
});
