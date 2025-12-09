import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

interface DriverPerformanceRequest {
  startDate: string; // ISO 8601 date string
  endDate: string;   // ISO 8601 date string
  limit?: number;    // Max drivers to return (default 50)
}

interface DriverPerformance {
  driverId: string;
  name: string;
  phone: string;
  operator: string;
  totalTrips: number;
  totalEarnings: number;
  averageRating: number;
  cancellationRate: number;
  completedTrips: number;
  cancelledTrips: number;
}

interface DriverPerformanceReportResponse {
  drivers: DriverPerformance[];
  periodStart: string;
  periodEnd: string;
  totalDrivers: number;
}

/**
 * Cloud Function to get driver performance report
 * Requires admin authentication
 */
export const getDriverPerformanceReport = functions.https.onCall(
  async (
    data: DriverPerformanceRequest,
    context: functions.https.CallableContext
  ): Promise<DriverPerformanceReportResponse> => {
    // Verify admin authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to access driver performance reports.'
      );
    }

    const isAdmin = context.auth.token.isAdmin === true;
    if (!isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can access driver performance reports.'
      );
    }

    try {
      const { startDate, endDate, limit = 50 } = data;

      if (!startDate || !endDate) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'startDate and endDate are required.'
        );
      }

      const startTimestamp = admin.firestore.Timestamp.fromDate(new Date(startDate));
      const endTimestamp = admin.firestore.Timestamp.fromDate(new Date(endDate));

      const db = admin.firestore();

      // Platform commission rate (20%)
      const COMMISSION_RATE = 0.20;

      // Query all orders in the date range with driverId
      const ordersSnapshot = await db
        .collection('orders')
        .where('createdAt', '>=', startTimestamp)
        .where('createdAt', '<=', endTimestamp)
        .get();

      // Aggregate driver performance data
      const driverStats: Map<string, {
        totalTrips: number;
        completedTrips: number;
        cancelledTrips: number;
        totalEarnings: number;
        totalRating: number;
        ratedTrips: number;
      }> = new Map();

      ordersSnapshot.forEach((doc) => {
        const order = doc.data();
        const driverId = order.driverId || order.assignedDriverId;

        if (!driverId) return; // Skip unassigned orders

        if (!driverStats.has(driverId)) {
          driverStats.set(driverId, {
            totalTrips: 0,
            completedTrips: 0,
            cancelledTrips: 0,
            totalEarnings: 0,
            totalRating: 0,
            ratedTrips: 0,
          });
        }

        const stats = driverStats.get(driverId)!;
        stats.totalTrips++;

        if (order.status === 'completed') {
          stats.completedTrips++;
          const driverEarnings = Math.round((order.price || 0) * (1 - COMMISSION_RATE));
          stats.totalEarnings += driverEarnings;

          if (order.driverRating) {
            stats.totalRating += order.driverRating;
            stats.ratedTrips++;
          }
        } else if (
          order.status === 'cancelled_by_driver' ||
          order.status === 'cancelled'
        ) {
          stats.cancelledTrips++;
        }
      });

      // Fetch driver details
      const driverIds = Array.from(driverStats.keys());
      const driverPerformances: DriverPerformance[] = [];

      // Batch fetch drivers (Firestore has a limit of 10 for 'in' queries, so we chunk)
      const chunkSize = 10;
      for (let i = 0; i < driverIds.length; i += chunkSize) {
        const chunk = driverIds.slice(i, i + chunkSize);
        const driversSnapshot = await db
          .collection('drivers')
          .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
          .get();

        driversSnapshot.forEach((driverDoc) => {
          const driver = driverDoc.data();
          const stats = driverStats.get(driverDoc.id)!;

          // Determine operator from phone prefix
          let operator = 'Unknown';
          if (driver.phone) {
            const prefix = driver.phone.substring(4, 5); // After +222
            if (prefix === '2') operator = 'Chinguitel';
            else if (prefix === '3') operator = 'Mattel';
            else if (prefix === '4') operator = 'Mauritel';
          }

          const averageRating = stats.ratedTrips > 0 
            ? Math.round((stats.totalRating / stats.ratedTrips) * 10) / 10 
            : 0;

          const cancellationRate = stats.totalTrips > 0 
            ? Math.round((stats.cancelledTrips / stats.totalTrips) * 100) 
            : 0;

          driverPerformances.push({
            driverId: driverDoc.id,
            name: driver.name || 'N/A',
            phone: driver.phone || 'N/A',
            operator,
            totalTrips: stats.totalTrips,
            totalEarnings: stats.totalEarnings,
            averageRating,
            cancellationRate,
            completedTrips: stats.completedTrips,
            cancelledTrips: stats.cancelledTrips,
          });
        });
      }

      // Sort by total earnings (descending) and limit results
      driverPerformances.sort((a, b) => b.totalEarnings - a.totalEarnings);
      const limitedDrivers = driverPerformances.slice(0, limit);

      // Log action for audit
      await db.collection('admin_actions').add({
        action: 'viewDriverPerformanceReport',
        performedBy: context.auth.uid,
        performedAt: admin.firestore.FieldValue.serverTimestamp(),
        details: {
          startDate,
          endDate,
          driversReturned: limitedDrivers.length,
        },
      });

      return {
        drivers: limitedDrivers,
        periodStart: startDate,
        periodEnd: endDate,
        totalDrivers: driverPerformances.length,
      };
    } catch (error: any) {
      console.error('Error generating driver performance report:', error);
      throw new functions.https.HttpsError(
        'internal',
        `Failed to generate driver performance report: ${error.message}`
      );
    }
  }
);
