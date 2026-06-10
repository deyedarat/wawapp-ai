/**
 * Cloud Function: Enforce Wallet Balance for Order Acceptance
 * 
 * Phase D: Ensures drivers have positive wallet balance before accepting orders.
 * 
 * Rules:
 * - Triggers on order status transitions to 'accepted'
 * - Check assigned driver's wallet balance > 0
 * - If insufficient, revert to previous status and notify driver
 * 
 * Author: WawApp Development Team (Phase D Implementation)
 * Last Updated: 2025-12-28
 */

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v1';
import { safeEnqueueOrder } from './dispatch/intake';
import { releaseDriverState } from './dispatch/state';

/**
 * Send notification to driver based on wallet guard reason
 */
async function sendWalletNotification(
  driverId: string,
  orderId: string,
  reason: 'INSUFFICIENT_BALANCE' | 'CHECK_FAILED'
): Promise<void> {
  try {
    const driverDoc = await admin
      .firestore()
      .collection('drivers')
      .doc(driverId)
      .get();

    if (!driverDoc.exists) {
      console.warn('[WalletBalanceGuard] Driver not found for notification', { driver_id: driverId });
      return;
    }

    const driverData = driverDoc.data();
    const fcmToken = driverData?.fcmToken as string | undefined;

    if (!fcmToken) {
      console.log('[WalletBalanceGuard] No FCM token for driver', { driver_id: driverId });
      return;
    }

    const isCheckFailed = reason === 'CHECK_FAILED';
    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: isCheckFailed ? 'خطأ في التحقق من الرصيد' : 'رصيد غير كافي',
        body: isCheckFailed
          ? 'تعذر التحقق من الرصيد، حاول مرة أخرى بعد قليل'
          : 'تحتاج إلى رصيد في محفظتك لقبول الطلبات. يرجى طلب شحن المحفظة.',
      },
      data: {
        notificationType: isCheckFailed ? 'wallet_check_failed' : 'insufficient_balance_order',
        orderId: orderId,
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'wallet_notifications',
          priority: 'high',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    await admin.messaging().send(message);

    console.log('[WalletBalanceGuard] Notification sent', {
      driver_id: driverId,
      order_id: orderId,
      reason: reason,
    });
  } catch (error) {
    console.error('[WalletBalanceGuard] Failed to send notification', {
      driver_id: driverId,
      order_id: orderId,
      reason: reason,
      error: error,
    });
  }
}

/**
 * Cloud Function: Enforce wallet balance on order acceptance
 */
export const enforceWalletBalance = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const orderId = context.params.orderId;

    const beforeStatus = beforeData.status as string;
    const afterStatus = afterData.status as string;
    const assignedDriverId = afterData.assignedDriverId as string | null;

    // Check if order was just accepted
    const wasJustAccepted =
      beforeStatus !== 'accepted' &&
      afterStatus === 'accepted' &&
      assignedDriverId !== null;

    if (!wasJustAccepted) {
      return null;
    }

    // Bug #3 FIX: Driver-scoped guard check
    // walletGuard must be for THIS specific driver to skip enforcement
    // If guard exists but for a DIFFERENT driver, we must re-check the new driver's balance
    const existingWalletGuard = afterData.walletGuard;
    if (existingWalletGuard && existingWalletGuard.reason) {
      // Check if guard is for THIS driver — means they already failed wallet check
      // They should NOT be able to accept again without topping up
      if (existingWalletGuard.driverId === assignedDriverId) {
        console.warn('[WalletBalanceGuard] Same driver re-accepted after wallet rejection, reverting again', {
          order_id: orderId,
          driver_id: assignedDriverId,
          existing_reason: existingWalletGuard.reason,
          blocked_at: existingWalletGuard.blockedAt,
        });

        // Revert again — this driver still has no balance
        await change.after.ref.update({
          status: 'matching',
          assignedDriverId: null,
          driverId: null,
          driverName: admin.firestore.FieldValue.delete(),
          driverPhone: admin.firestore.FieldValue.delete(),
          vehiclePlate: admin.firestore.FieldValue.delete(),
          vehicleType: admin.firestore.FieldValue.delete(),
          driverLocation: admin.firestore.FieldValue.delete(),
          acceptedAt: null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await releaseDriverState(assignedDriverId);

        // Cancel any open offers for this driver on this order
        const openOffersRepeat = await admin.firestore()
          .collection('dispatch_offers')
          .where('orderId', '==', orderId)
          .where('driverId', '==', assignedDriverId)
          .where('status', '==', 'sent')
          .get();
        if (!openOffersRepeat.empty) {
          const batch = admin.firestore().batch();
          openOffersRepeat.docs.forEach(doc => {
            batch.update(doc.ref, { status: 'cancelled', respondedAt: admin.firestore.FieldValue.serverTimestamp() });
          });
          await batch.commit();
        }

        // Ensure driver_rejected_orders entry exists (in case previous one was missed)
        await admin.firestore().collection('driver_rejected_orders').doc().set({
          driverId: assignedDriverId,
          orderId,
          rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
          reason: 'wallet_repeat_rejection',
          expiresAt: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + 24 * 60 * 60 * 1000)
          ),
        });

        const freshOrderRepeat = await change.after.ref.get();
        if (freshOrderRepeat.exists) {
          await safeEnqueueOrder(orderId, freshOrderRepeat.data()!);
        }

        await sendWalletNotification(assignedDriverId, orderId, 'INSUFFICIENT_BALANCE');
        return null;
      } else {
        // Guard exists but for a DIFFERENT driver - we must check NEW driver's balance
        console.log('[WalletBalanceGuard] walletGuard exists for DIFFERENT driver, re-checking balance', {
          order_id: orderId,
          current_driver_id: assignedDriverId,
          previous_blocked_driver_id: existingWalletGuard.driverId,
          previous_reason: existingWalletGuard.reason,
        });
        // Fall through to balance check
      }
    }

    console.log('[WalletBalanceGuard] Order accepted, checking driver wallet balance', {
      order_id: orderId,
      driver_id: assignedDriverId,
      status_transition: `${beforeStatus} → ${afterStatus}`,
    });

    try {
      // Check driver's wallet balance
      const walletDoc = await admin
        .firestore()
        .collection('wallets')
        .doc(assignedDriverId)
        .get();

      let currentBalance = 0;
      if (walletDoc.exists) {
        currentBalance = walletDoc.data()?.balance || 0;
      }

      console.log('[WalletBalanceGuard] Driver wallet balance check', {
        order_id: orderId,
        driver_id: assignedDriverId,
        current_balance: currentBalance,
      });

      // If balance is 0 or negative, reject the acceptance
      if (currentBalance <= 0) {
        console.warn('[WalletBalanceGuard] Insufficient balance, reverting order acceptance', {
          order_id: orderId,
          driver_id: assignedDriverId,
          current_balance: currentBalance,
        });

        // Revert order to matching status with walletGuard
        await change.after.ref.update({
          status: 'matching',
          assignedDriverId: null,
          driverId: null,
          driverName: admin.firestore.FieldValue.delete(),
          driverPhone: admin.firestore.FieldValue.delete(),
          vehiclePlate: admin.firestore.FieldValue.delete(),
          vehicleType: admin.firestore.FieldValue.delete(),
          driverLocation: admin.firestore.FieldValue.delete(),
          acceptedAt: null,
          walletGuard: {
            blockedAt: admin.firestore.FieldValue.serverTimestamp(),
            reason: 'INSUFFICIENT_BALANCE',
            driverId: assignedDriverId,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Release driver dispatch state so they can receive new offers later
        await releaseDriverState(assignedDriverId);

        // Cancel any open offers for this driver on this order to prevent re-dispatch loop
        const openOffers = await admin.firestore()
          .collection('dispatch_offers')
          .where('orderId', '==', orderId)
          .where('driverId', '==', assignedDriverId)
          .where('status', '==', 'sent')
          .get();
        if (!openOffers.empty) {
          const batch = admin.firestore().batch();
          openOffers.docs.forEach(doc => {
            batch.update(doc.ref, { status: 'cancelled', respondedAt: admin.firestore.FieldValue.serverTimestamp() });
          });
          await batch.commit();
          console.log('[WalletBalanceGuard] Cancelled open offers for blocked driver', {
            order_id: orderId,
            driver_id: assignedDriverId,
            cancelled_count: openOffers.size,
          });
        }

        // Mark this order as rejected for this driver so dispatch won't re-offer it
        await admin.firestore().collection('driver_rejected_orders').doc().set({
          driverId: assignedDriverId,
          orderId,
          rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
          reason: 'wallet_insufficient_balance',
          expiresAt: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours
          ),
        });

        // Re-enqueue order into dispatch engine so other drivers can see it
        const freshOrder = await change.after.ref.get();
        if (freshOrder.exists) {
          await safeEnqueueOrder(orderId, freshOrder.data()!);
          console.log('[WalletBalanceGuard] Order re-enqueued for dispatch', {
            order_id: orderId,
          });
        }

        // Send notification to driver
        await sendWalletNotification(assignedDriverId, orderId, 'INSUFFICIENT_BALANCE');

        console.log('[WalletBalanceGuard] Order reverted to matching due to insufficient balance', {
          order_id: orderId,
          driver_id: assignedDriverId,
        });

        // Log analytics event
        console.log('[Analytics] order_rejected_insufficient_balance', {
          order_id: orderId,
          driver_id: assignedDriverId,
          balance: currentBalance,
        });
      } else {
        console.log('[WalletBalanceGuard] Driver has sufficient balance, order acceptance allowed', {
          order_id: orderId,
          driver_id: assignedDriverId,
          current_balance: currentBalance,
        });
      }

    } catch (error) {
      console.error('[WalletBalanceGuard] Error checking wallet balance', {
        order_id: orderId,
        driver_id: assignedDriverId,
        error: error,
      });

      // Fix #1: Change to Fail-Closed - revert order on wallet check error
      console.warn('[WalletBalanceGuard] Reverting order due to wallet check error (fail-closed)', {
        order_id: orderId,
        driver_id: assignedDriverId,
      });

      // Revert order to matching status with walletGuard
      await change.after.ref.update({
        status: 'matching',
        assignedDriverId: null,
        driverId: null,
        driverName: admin.firestore.FieldValue.delete(),
        driverPhone: admin.firestore.FieldValue.delete(),
        vehiclePlate: admin.firestore.FieldValue.delete(),
        vehicleType: admin.firestore.FieldValue.delete(),
        driverLocation: admin.firestore.FieldValue.delete(),
        acceptedAt: null,
        walletGuard: {
          blockedAt: admin.firestore.FieldValue.serverTimestamp(),
          reason: 'CHECK_FAILED',
          driverId: assignedDriverId,
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Release driver dispatch state so they can receive new offers later
      await releaseDriverState(assignedDriverId);

      // Cancel any open offers for this driver on this order
      const openOffersOnError = await admin.firestore()
        .collection('dispatch_offers')
        .where('orderId', '==', orderId)
        .where('driverId', '==', assignedDriverId)
        .where('status', '==', 'sent')
        .get();
      if (!openOffersOnError.empty) {
        const batch = admin.firestore().batch();
        openOffersOnError.docs.forEach(doc => {
          batch.update(doc.ref, { status: 'cancelled', respondedAt: admin.firestore.FieldValue.serverTimestamp() });
        });
        await batch.commit();
      }

      // Mark this order as rejected for this driver so dispatch won't re-offer it
      await admin.firestore().collection('driver_rejected_orders').doc().set({
        driverId: assignedDriverId,
        orderId,
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        reason: 'wallet_check_failed',
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 60 * 60 * 1000) // 1 hour (shorter for check_failed)
        ),
      });

      // Re-enqueue order into dispatch engine so other drivers can see it
      const freshOrderOnError = await change.after.ref.get();
      if (freshOrderOnError.exists) {
        await safeEnqueueOrder(orderId, freshOrderOnError.data()!);
        console.log('[WalletBalanceGuard] Order re-enqueued after check failure', {
          order_id: orderId,
        });
      }

      // Send notification to driver
      await sendWalletNotification(assignedDriverId, orderId, 'CHECK_FAILED');
    }

    return null;
  });