/**
 * acceptOrder v2.0 — Offer-Based Acceptance
 *
 * BREAKING CHANGE: Now requires offerId for acceptance.
 *
 * Previous behavior:
 * - Accepted any matching order by orderId
 * - offerId was optional
 *
 * New behavior:
 * - Requires valid offerId
 * - Validates offer belongs to this driver
 * - Validates offer is not expired
 * - Uses dispatch engine for atomic acceptance
 *
 * Migration path: Old apps will get clear error "offerId is required"
 *
 * @author WawApp Development Team
 * @version 2.0.0
 */

import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { handleOfferAcceptance } from './dispatch';

export const acceptOrderV2 = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated');
  }

  const driverId = context.auth.uid;
  const { offerId } = data;

  // ❌ BREAKING CHANGE: offerId is now required
  if (!offerId || typeof offerId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'offerId is required. Please update your app to the latest version.'
    );
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

  console.log('[AcceptOrderV2] Processing acceptance', {
    offer_id: offerId,
    driver_id: driverId,
  });

  try {
    // Use dispatch engine for atomic acceptance
    const result = await handleOfferAcceptance(offerId, driverId);

    if (!result.success) {
      // Map errors to user-friendly messages
      const errorMessages: Record<string, string> = {
        offer_not_found: 'العرض غير موجود',
        driver_mismatch: 'هذا العرض ليس لك',
        offer_accepted: 'تم قبول هذا العرض بالفعل',
        offer_rejected: 'تم رفض هذا العرض مسبقًا',
        offer_expired: 'انتهت صلاحية هذا العرض',
        offer_cancelled: 'تم إلغاء هذا العرض',
        driver_locked: 'لديك طلب نشط بالفعل',
        order_not_found: 'الطلب غير موجود',
        order_already_assigned: 'تم أخذ الطلب بالفعل',
      };

      const arabicMessage = errorMessages[result.error || 'unknown'] || 'فشل القبول';

      throw new functions.https.HttpsError('failed-precondition', arabicMessage);
    }

    // ✅ Success
    console.log('[AcceptOrderV2] Acceptance successful', {
      offer_id: offerId,
      driver_id: driverId,
    });

    return { success: true };
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) throw error;

    console.error('[AcceptOrderV2] Internal error', {
      offer_id: offerId,
      driver_id: driverId,
      error: error.message,
    });

    throw new functions.https.HttpsError('internal', 'فشل قبول الطلب');
  }
});
