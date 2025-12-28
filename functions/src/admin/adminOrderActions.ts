/**
 * Admin Order Management Actions
 * Cancel orders and manage order lifecycle
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cancel an order (admin action)
 * Validates admin permissions and order state
 */
export const adminCancelOrder = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to cancel orders'
    );
  }

  // Require admin role
  const userClaims = context.auth.token;
  if (!userClaims.isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can cancel orders'
    );
  }

  const { orderId, reason } = data;

  if (!orderId || typeof orderId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Must provide a valid order ID'
    );
  }

  try {
    const db = admin.firestore();
    const orderRef = db.collection('orders').doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Order not found'
      );
    }

    const orderData = orderDoc.data()!;
    const currentStatus = orderData.status;

    // Check if order can be cancelled
    const cancellableStatuses = ['assigning', 'accepted', 'on_route'];
    if (!cancellableStatuses.includes(currentStatus)) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Cannot cancel order with status: ${currentStatus}`
      );
    }

    // Update order status
    await orderRef.update({
      status: 'cancelled_by_admin',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelledBy: context.auth.uid,
      cancellationReason: reason || 'Cancelled by admin',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log the action
    await db.collection('admin_actions').add({
      action: 'cancelOrder',
      orderId,
      reason: reason || 'No reason provided',
      performedBy: context.auth.uid,
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
      previousStatus: currentStatus,
    });

    // TODO: Send notification to client and driver if assigned

    return {
      success: true,
      message: `Order ${orderId} has been cancelled`,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error cancelling order:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to cancel order'
    );
  }
});

/**
 * Reassign an order to a different driver (admin action)
 */
export const adminReassignOrder = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated'
    );
  }

  // Require admin role
  const userClaims = context.auth.token;
  if (!userClaims.isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can reassign orders'
    );
  }

  const { orderId, newDriverId } = data;

  if (!orderId || !newDriverId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Must provide order ID and new driver ID'
    );
  }

  try {
    const db = admin.firestore();
    
    // Check if driver exists and is available
    const driverDoc = await db.collection('drivers').doc(newDriverId).get();
    if (!driverDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Driver not found'
      );
    }

    const driverData = driverDoc.data()!;
    if (driverData.isBlocked) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Cannot assign to a blocked driver'
      );
    }

    // Update order
    const orderRef = db.collection('orders').doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Order not found'
      );
    }

    const previousDriverId = orderDoc.data()!.driverId;

    await orderRef.update({
      driverId: newDriverId,
      assignedDriverId: newDriverId,
      reassignedAt: admin.firestore.FieldValue.serverTimestamp(),
      reassignedBy: context.auth.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log the action
    await db.collection('admin_actions').add({
      action: 'reassignOrder',
      orderId,
      previousDriverId,
      newDriverId,
      performedBy: context.auth.uid,
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: `Order ${orderId} has been reassigned`,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error reassigning order:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to reassign order'
    );
  }
});
