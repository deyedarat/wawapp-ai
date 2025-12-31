/**
 * Admin Dashboard Statistics
 * Provides aggregated stats for the admin panel
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

interface AdminStats {
  totalDrivers: number;
  onlineDrivers: number;
  totalOrdersToday: number;
  completedOrdersToday: number;
  cancelledOrdersToday: number;
  activeOrdersNow: number;
  totalClients: number;
  verifiedClients: number;
}

/**
 * Get admin dashboard statistics
 * Requires admin authentication
 */
export const getAdminStats = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to access admin stats'
    );
  }

  // Require admin role
  const userClaims = context.auth.token;
  if (!userClaims.isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can access statistics'
    );
  }

  try {
    const db = admin.firestore();
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // Get drivers stats
    const driversSnapshot = await db.collection('drivers').get();
    const totalDrivers = driversSnapshot.size;
    const onlineDrivers = driversSnapshot.docs.filter(
      doc => doc.data().isOnline === true
    ).length;

    // Get orders stats
    const ordersSnapshot = await db.collection('orders').get();
    
    // Today's orders
    const todayOrders = ordersSnapshot.docs.filter(doc => {
      const createdAt = doc.data().createdAt?.toDate();
      return createdAt && createdAt >= todayStart;
    });

    const totalOrdersToday = todayOrders.length;
    const completedOrdersToday = todayOrders.filter(
      doc => doc.data().status === 'completed'
    ).length;
    const cancelledOrdersToday = todayOrders.filter(
      doc => doc.data().status === 'cancelled' || 
            doc.data().status === 'cancelled_by_driver' ||
            doc.data().status === 'cancelled_by_client'
    ).length;

    // Active orders (assigning, accepted, on_route)
    const activeOrdersNow = ordersSnapshot.docs.filter(doc => {
      const status = doc.data().status;
      return status === 'assigning' || status === 'accepted' || status === 'on_route';
    }).length;

    // Get clients stats
    const clientsSnapshot = await db.collection('clients').get();
    const totalClients = clientsSnapshot.size;
    const verifiedClients = clientsSnapshot.docs.filter(
      doc => doc.data().isVerified === true
    ).length;

    const stats: AdminStats = {
      totalDrivers,
      onlineDrivers,
      totalOrdersToday,
      completedOrdersToday,
      cancelledOrdersToday,
      activeOrdersNow,
      totalClients,
      verifiedClients,
    };

    return { success: true, data: stats };
  } catch (error) {
    console.error('Error fetching admin stats:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch statistics'
    );
  }
});
