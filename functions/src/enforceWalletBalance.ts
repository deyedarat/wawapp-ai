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

    // Fix #2: Loop Guard - Check if walletGuard already exists
    const existingWalletGuard = afterData.walletGuard;
    if (existingWalletGuard && existingWalletGuard.reason) {
      console.log('[WalletBalanceGuard] walletGuard exists, skipping to prevent loops', {
        order_id: orderId,
        driver_id: assignedDriverId,
        existing_reason: existingWalletGuard.reason,
      });
      return null;
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
          walletGuard: {
            blockedAt: admin.firestore.FieldValue.serverTimestamp(),
            reason: 'INSUFFICIENT_BALANCE',
            driverId: assignedDriverId,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

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
        walletGuard: {
          blockedAt: admin.firestore.FieldValue.serverTimestamp(),
          reason: 'CHECK_FAILED',
          driverId: assignedDriverId,
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Send notification to driver
      await sendWalletNotification(assignedDriverId, orderId, 'CHECK_FAILED');
    }

    return null;
  });