/**
 * rejectOffer — Driver Explicit Rejection
 *
 * Allows driver to explicitly reject an offer.
 *
 * This is different from expiration:
 * - Rejection: driver taps "Reject" button
 * - Expiration: offer TTL reached without response
 *
 * @author WawApp Development Team
 * @version 2.0.0
 */

import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { handleOfferRejection } from './dispatch';

export const rejectOffer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const driverId = context.auth.uid;
  const { offerId } = data;

  if (!offerId || typeof offerId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'offerId is required');
  }

  const db = admin.firestore();

  // Verify driver is verified
  const driverDoc = await db.collection('drivers').doc(driverId).get();
  if (!driverDoc.exists || !driverDoc.data()?.isVerified) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Driver account is not verified'
    );
  }

  console.log('[RejectOffer] Processing rejection', {
    offer_id: offerId,
    driver_id: driverId,
  });

  try {
    const result = await handleOfferRejection(offerId, driverId);

    if (!result.success) {
      const errorMessages: Record<string, string> = {
        offer_not_found: 'العرض غير موجود',
        driver_mismatch: 'هذا العرض ليس لك',
        offer_accepted: 'تم قبول هذا العرض بالفعل',
        offer_rejected: 'تم رفض هذا العرض مسبقًا',
        offer_expired: 'انتهت صلاحية هذا العرض',
        offer_cancelled: 'تم إلغاء هذا العرض',
      };

      const arabicMessage = errorMessages[result.error || 'unknown'] || 'فشل الرفض';

      throw new functions.https.HttpsError('failed-precondition', arabicMessage);
    }

    console.log('[RejectOffer] Rejection successful', {
      offer_id: offerId,
      driver_id: driverId,
    });

    return { success: true };
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) throw error;

    console.error('[RejectOffer] Internal error', {
      offer_id: offerId,
      driver_id: driverId,
      error: error.message,
    });

    throw new functions.https.HttpsError('internal', 'فشل رفض الطلب');
  }
});
