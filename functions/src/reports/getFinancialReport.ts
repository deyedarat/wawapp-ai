import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

interface FinancialReportRequest {
  startDate: string; // ISO 8601 date string
  endDate: string;   // ISO 8601 date string
}

interface DailyFinancial {
  date: string;
  ordersCount: number;
  grossRevenue: number;
  driverEarnings: number;
  platformCommission: number;
}

interface FinancialReportResponse {
  summary: {
    totalOrders: number;
    grossRevenue: number;
    totalDriverEarnings: number;
    totalPlatformCommission: number;
    averageCommissionRate: number;
    // Phase 5.5: Wallet & Payout metrics
    totalPayoutsInPeriod: number;
    totalDriverOutstandingBalance: number;
    platformWalletBalance: number;
  };
  dailyBreakdown: DailyFinancial[];
  periodStart: string;
  periodEnd: string;
}

/**
 * Cloud Function to get financial report with revenue and commission breakdowns
 * Requires admin authentication
 */
export const getFinancialReport = functions.https.onCall(
  async (
    data: FinancialReportRequest,
    context: functions.https.CallableContext
  ): Promise<FinancialReportResponse> => {
    // Verify admin authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to access financial reports.'
      );
    }

    const isAdmin = context.auth.token.isAdmin === true;
    if (!isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can access financial reports.'
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

      // Query completed orders in the date range
      const ordersSnapshot = await db
        .collection('orders')
        .where('createdAt', '>=', startTimestamp)
        .where('createdAt', '<=', endTimestamp)
        .where('status', '==', 'completed')
        .get();

      // Platform commission rate (20% as per business model)
      const COMMISSION_RATE = 0.20;

      // Aggregate data
      let totalOrders = 0;
      let grossRevenue = 0;
      const dailyData: Map<string, DailyFinancial> = new Map();

      ordersSnapshot.forEach((doc) => {
        const order = doc.data();
        const orderPrice = order.price || 0;

        totalOrders++;
        grossRevenue += orderPrice;

        // Calculate driver earnings and platform commission
        const platformCommission = Math.round(orderPrice * COMMISSION_RATE);
        const driverEarnings = orderPrice - platformCommission;

        // Group by day
        const orderDate = order.createdAt.toDate();
        const dateKey = orderDate.toISOString().split('T')[0]; // YYYY-MM-DD

        if (!dailyData.has(dateKey)) {
          dailyData.set(dateKey, {
            date: dateKey,
            ordersCount: 0,
            grossRevenue: 0,
            driverEarnings: 0,
            platformCommission: 0,
          });
        }

        const dayData = dailyData.get(dateKey)!;
        dayData.ordersCount++;
        dayData.grossRevenue += orderPrice;
        dayData.driverEarnings += driverEarnings;
        dayData.platformCommission += platformCommission;
      });

      // Calculate totals
      const totalDriverEarnings = Math.round(grossRevenue * (1 - COMMISSION_RATE));
      const totalPlatformCommission = grossRevenue - totalDriverEarnings;
      const averageCommissionRate = Math.round(COMMISSION_RATE * 100);

      // Sort daily breakdown by date
      const dailyBreakdown = Array.from(dailyData.values())
        .sort((a, b) => a.date.localeCompare(b.date));

      // Phase 5.5: Query wallet & payout data
      
      // 1. Total payouts in period (completed payouts)
      const payoutsSnapshot = await db
        .collection('payouts')
        .where('completedAt', '>=', startTimestamp)
        .where('completedAt', '<=', endTimestamp)
        .where('status', '==', 'completed')
        .get();

      let totalPayoutsInPeriod = 0;
      payoutsSnapshot.forEach((doc) => {
        const payout = doc.data();
        totalPayoutsInPeriod += payout.amount || 0;
      });

      // 2. Total driver outstanding balance (current snapshot)
      const driverWalletsSnapshot = await db
        .collection('wallets')
        .where('type', '==', 'driver')
        .get();

      let totalDriverOutstandingBalance = 0;
      driverWalletsSnapshot.forEach((doc) => {
        const wallet = doc.data();
        totalDriverOutstandingBalance += wallet.balance || 0;
      });

      // 3. Platform wallet balance (current snapshot)
      const platformWalletDoc = await db
        .collection('wallets')
        .doc('platform_main')
        .get();

      const platformWalletBalance = platformWalletDoc.exists
        ? platformWalletDoc.data()!.balance || 0
        : 0;

      // Log action for audit
      await db.collection('admin_actions').add({
        action: 'viewFinancialReport',
        performedBy: context.auth.uid,
        performedAt: admin.firestore.FieldValue.serverTimestamp(),
        details: {
          startDate,
          endDate,
        },
      });

      return {
        summary: {
          totalOrders,
          grossRevenue,
          totalDriverEarnings,
          totalPlatformCommission,
          averageCommissionRate,
          // Phase 5.5: Wallet & Payout metrics
          totalPayoutsInPeriod,
          totalDriverOutstandingBalance,
          platformWalletBalance,
        },
        dailyBreakdown,
        periodStart: startDate,
        periodEnd: endDate,
      };
    } catch (error: any) {
      console.error('Error generating financial report:', error);
      throw new functions.https.HttpsError(
        'internal',
        `Failed to generate financial report: ${error.message}`
      );
    }
  }
);
