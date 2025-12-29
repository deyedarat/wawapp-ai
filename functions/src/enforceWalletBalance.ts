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

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Send insufficient balance notification to driver
 */
async function sendInsufficientBalanceNotification(
  driverId: string,
  orderId: string
): Promise<void> {
  try {
    const driverDoc = await admin
      .firestore()
      .collection('drivers')
      .doc(driverId)
      .get();

    if (!driverDoc.exists) {
      console.warn('[WalletBalance] Driver not found for notification', { driver_id: driverId });
      return;
    }

    const driverData = driverDoc.data();
    const fcmToken = driverData?.fcmToken as string | undefined;

    if (!fcmToken) {
      console.log('[WalletBalance] No FCM token for driver', { driver_id: driverId });
      return;
    }

    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: 'رصيد غير كافي',
        body: 'تحتاج إلى رصيد في محفظتك لقبول الطلبات. يرجى طلب شحن المحفظة.',
      },
      data: {
        notificationType: 'insufficient_balance_order',
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

    console.log('[WalletBalance] Insufficient balance notification sent', {
      driver_id: driverId,
      order_id: orderId,
    });
  } catch (error) {
    console.error('[WalletBalance] Failed to send notification', {
      driver_id: driverId,
      order_id: orderId,
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

    console.log('[WalletBalance] Order accepted, checking driver wallet balance', {
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

      console.log('[WalletBalance] Driver wallet balance check', {
        order_id: orderId,
        driver_id: assignedDriverId,
        current_balance: currentBalance,
      });

      // If balance is 0 or negative, reject the acceptance
      if (currentBalance <= 0) {
        console.warn('[WalletBalance] Insufficient balance, reverting order acceptance', {
          order_id: orderId,
          driver_id: assignedDriverId,
          current_balance: currentBalance,
        });

        // Revert order to matching status
        await change.after.ref.update({
          status: 'matching',
          assignedDriverId: null,
          driverId: null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Send notification to driver
        await sendInsufficientBalanceNotification(assignedDriverId, orderId);

        console.log('[WalletBalance] Order reverted to matching due to insufficient balance', {
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
        console.log('[WalletBalance] Driver has sufficient balance, order acceptance allowed', {
          order_id: orderId,
          driver_id: assignedDriverId,
          current_balance: currentBalance,
        });
      }

    } catch (error) {
      console.error('[WalletBalance] Error checking wallet balance', {
        order_id: orderId,
        driver_id: assignedDriverId,
        error: error,
      });

      // On error, allow the order to proceed (fail-open for availability)
      // but log the issue for investigation
      console.warn('[WalletBalance] Allowing order due to wallet check error (fail-open)', {
        order_id: orderId,
        driver_id: assignedDriverId,
      });
    }

    return null;
  });