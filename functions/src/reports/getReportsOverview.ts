import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

interface OverviewReportRequest {
  startDate: string; // ISO 8601 date string
  endDate: string;   // ISO 8601 date string
}

interface OverviewReportResponse {
  totalOrders: number;
  completedOrders: number;
  cancelledOrders: number;
  completionRate: number;
  averageOrderValue: number;
  totalActiveDrivers: number;
  newClients: number;
  periodStart: string;
  periodEnd: string;
}

/**
 * Cloud Function to get overview report with global KPIs
 * Requires admin authentication
 */
export const getReportsOverview = functions.https.onCall(
  async (
    data: OverviewReportRequest,
    context: functions.https.CallableContext
  ): Promise<OverviewReportResponse> => {
    // Verify admin authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to access reports.'
      );
    }

    const isAdmin = context.auth.token.isAdmin === true;
    if (!isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can access reports.'
      );
    }

    try {
      const { startDate, endDate } = data;

      if (!startDate || !endDate) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'startDate and endDate are required.'
        );
      }

      const startTimestamp = admin.firestore.Timestamp.fromDate(new Date(startDate));
      const endTimestamp = admin.firestore.Timestamp.fromDate(new Date(endDate));

      const db = admin.firestore();

      // Query orders in the date range
      const ordersSnapshot = await db
        .collection('orders')
        .where('createdAt', '>=', startTimestamp)
        .where('createdAt', '<=', endTimestamp)
        .get();

      let totalOrders = 0;
      let completedOrders = 0;
      let cancelledOrders = 0;
      let totalRevenue = 0;

      ordersSnapshot.forEach((doc) => {
        const order = doc.data();
        totalOrders++;

        if (order.status === 'completed') {
          completedOrders++;
          totalRevenue += order.price || 0;
        } else if (
          order.status === 'cancelled' ||
          order.status === 'cancelled_by_admin' ||
          order.status === 'cancelled_by_driver' ||
          order.status === 'cancelled_by_client'
        ) {
          cancelledOrders++;
        }
      });

      const completionRate = totalOrders > 0 
        ? Math.round((completedOrders / totalOrders) * 100) 
        : 0;

      const averageOrderValue = completedOrders > 0 
        ? Math.round(totalRevenue / completedOrders) 
        : 0;

      // Count active drivers (drivers with at least one trip)
      const driversSnapshot = await db
        .collection('drivers')
        .where('totalTrips', '>', 0)
        .get();

      const totalActiveDrivers = driversSnapshot.size;

      // Count new clients in the period
      const clientsSnapshot = await db
        .collection('clients')
        .where('createdAt', '>=', startTimestamp)
        .where('createdAt', '<=', endTimestamp)
        .get();

      const newClients = clientsSnapshot.size;

      // Log action for audit
      await db.collection('admin_actions').add({
        action: 'viewReportsOverview',
        performedBy: context.auth.uid,
        performedAt: admin.firestore.FieldValue.serverTimestamp(),
        details: {
          startDate,
          endDate,
        },
      });

      return {
        totalOrders,
        completedOrders,
        cancelledOrders,
        completionRate,
        averageOrderValue,
        totalActiveDrivers,
        newClients,
        periodStart: startDate,
        periodEnd: endDate,
      };
    } catch (error: any) {
      console.error('Error generating overview report:', error);
      throw new functions.https.HttpsError(
        'internal',
        `Failed to generate overview report: ${error.message}`
      );
    }
  }
);
