/**
 * Cloud Function: Request Trip Start Extension
 *
 * Callable function (driver-only) to request additional time
 * before the accepted-order timeout triggers reassignment.
 *
 * Rules:
 * - Only the assigned driver can call
 * - Max 1 extension per order
 * - Grants 2 extra minutes on top of the 5-minute base timeout
 * - Must be called while order is still in 'accepted' status
 */

import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

const MAX_EXTENSIONS_ALLOWED = 1;
const EXTENSION_DURATION_MINUTES = 2;
const ACCEPTED_TIMEOUT_MINUTES = 5;

export const requestTripStartExtension = functions
  .region('us-central1')
  .https.onCall(async (data, context) => {
    // ── Auth check ──
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
    }

    const driverId = context.auth.uid;
    const orderId = data?.orderId as string | undefined;

    // ── Input validation ──
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

        // ── Status check ──
        if (order.status !== 'accepted') {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'الطلب ليس في حالة مقبول'
          );
        }

        // ── Ownership check ──
        if (order.assignedDriverId !== driverId) {
          throw new functions.https.HttpsError(
            'permission-denied',
            'أنت لست السائق المعين لهذا الطلب'
          );
        }

        // ── Extension limit check ──
        const currentExtensions: number = order.extensionRequestCount || 0;
        if (currentExtensions >= MAX_EXTENSIONS_ALLOWED) {
          throw new functions.https.HttpsError(
            'resource-exhausted',
            'لقد استخدمت التمديد بالفعل'
          );
        }

        // ── Timeout check (already expired?) ──
        const acceptedAtMs: number = order.acceptedAt?.toMillis?.() || 0;
        if (!acceptedAtMs) {
          throw new functions.https.HttpsError('failed-precondition', 'بيانات القبول مفقودة');
        }

        const totalTimeoutMs =
          (ACCEPTED_TIMEOUT_MINUTES + currentExtensions * EXTENSION_DURATION_MINUTES) * 60000;
        const nowMs = Date.now();

        if (nowMs - acceptedAtMs >= totalTimeoutMs) {
          throw new functions.https.HttpsError(
            'deadline-exceeded',
            'انتهى وقت الطلب بالفعل'
          );
        }

        // ── Grant extension ──
        const newExtensionCount = currentExtensions + 1;

        tx.update(orderRef, {
          extensionRequestCount: newExtensionCount,
          extensionGrantedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Calculate new deadline
        const newTotalTimeoutMs =
          (ACCEPTED_TIMEOUT_MINUTES + newExtensionCount * EXTENSION_DURATION_MINUTES) * 60000;
        const newDeadlineMs = acceptedAtMs + newTotalTimeoutMs;

        console.log('[TripExtension] Extension granted', {
          order_id: orderId,
          driver_id: driverId,
          extension_count: newExtensionCount,
          new_deadline: new Date(newDeadlineMs).toISOString(),
        });

        return {
          success: true,
          extensionGrantedMinutes: EXTENSION_DURATION_MINUTES,
          newDeadlineMs,
          remainingExtensions: MAX_EXTENSIONS_ALLOWED - newExtensionCount,
        };
      });

      return result;
    } catch (err: any) {
      // Re-throw HttpsErrors as-is
      if (err instanceof functions.https.HttpsError) throw err;

      console.error('[TripExtension] Unexpected error', {
        order_id: orderId,
        driver_id: driverId,
        error: err.message,
      });
      throw new functions.https.HttpsError('internal', 'حدث خطأ غير متوقع');
    }
  });
