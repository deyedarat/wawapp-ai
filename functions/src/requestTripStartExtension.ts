/**
 * Cloud Function: Request Trip Start Extension (Enhanced v2)
 *
 * Callable function (driver-only) to request additional time.
 * No auto-cancellation — extensions just track driver intent.
 *
 * Rules:
 * - Max 2 extensions per order (was 1)
 * - Each grants +5 minutes (was 2)
 * - Only available within first 6 minutes after acceptance
 * - Logs each extension to order.extensionRequests[]
 */

import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

const MAX_EXTENSIONS_ALLOWED = 2;
const EXTENSION_DURATION_MINUTES = 5;
const EXTENSION_WINDOW_MINUTES = 6;

export const requestTripStartExtension = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }

    const driverId = context.auth.uid;
    const orderId = data?.orderId as string | undefined;

    if (!orderId || typeof orderId !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'orderId مطلوب');
    }

    const db = admin.firestore();
    const orderRef = db.collection('orders').doc(orderId);

    try {
      const result = await db.runTransaction(async (tx) => {
        const snap = await tx.get(orderRef);

        if (!snap.exists) {
          throw new functions.https.HttpsError('not-found', 'الطلب غير موجود');
        }

        const order = snap.data()!;

        if (order.status !== 'accepted') {
          throw new functions.https.HttpsError('failed-precondition', 'الطلب ليس في حالة مقبول');
        }

        if (order.assignedDriverId !== driverId) {
          throw new functions.https.HttpsError('permission-denied', 'أنت لست السائق المعين لهذا الطلب');
        }

        const currentExtensions: number = order.extensionRequestCount || 0;
        if (currentExtensions >= MAX_EXTENSIONS_ALLOWED) {
          throw new functions.https.HttpsError('resource-exhausted', 'لقد استخدمت جميع التمديدات المتاحة');
        }

        const acceptedAtMs: number = order.acceptedAt?.toMillis?.() || 0;
        if (!acceptedAtMs) {
          throw new functions.https.HttpsError('failed-precondition', 'بيانات القبول مفقودة');
        }

        // Only allow extensions within the first 6 minutes
        const elapsedMinutes = (Date.now() - acceptedAtMs) / 60000;
        if (elapsedMinutes > EXTENSION_WINDOW_MINUTES) {
          throw new functions.https.HttpsError(
            'deadline-exceeded',
            'انتهت فترة طلب التمديد (6 دقائق)'
          );
        }

        const newExtensionCount = currentExtensions + 1;

        tx.update(orderRef, {
          extensionRequestCount: newExtensionCount,
          extensionGrantedAt: admin.firestore.FieldValue.serverTimestamp(),
          extensionRequests: admin.firestore.FieldValue.arrayUnion({
            requestedAt: new Date(),
            grantedMinutes: EXTENSION_DURATION_MINUTES,
            extensionNumber: newExtensionCount,
          }),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log('[TripExtension] Extension granted', {
          order_id: orderId,
          driver_id: driverId,
          extension_count: newExtensionCount,
          elapsed_minutes: Math.floor(elapsedMinutes),
        });

        return {
          success: true,
          extensionGrantedMinutes: EXTENSION_DURATION_MINUTES,
          extensionNumber: newExtensionCount,
          remainingExtensions: MAX_EXTENSIONS_ALLOWED - newExtensionCount,
        };
      });

      return result;
    } catch (err: any) {
      if (err instanceof functions.https.HttpsError) throw err;

      console.error('[TripExtension] Unexpected error', {
        order_id: orderId,
        driver_id: driverId,
        error: err.message,
      });
      throw new functions.https.HttpsError('internal', 'حدث خطأ غير متوقع');
    }
  });
