/**
 * Migration Script: Refund Overcharged Drivers
 *
 * Purpose: Identify and refund drivers who were overcharged due to Bug #1
 * Bug #1: Drivers were charged 30% (10% trip start + 20% completion) instead of 20%
 *
 * This script:
 * 1. Finds all completed orders since the bug was deployed
 * 2. Calculates overcharge amount (10% of order price)
 * 3. Credits driver wallets with refund
 * 4. Creates compensatory transaction records
 * 5. Generates audit report
 *
 * Usage:
 *   DRY_RUN=true npm run refund-drivers  (preview only)
 *   DRY_RUN=false npm run refund-drivers (execute refunds)
 *
 * Author: WawApp Development Team
 * Created: 2026-01-01
 */

import * as admin from 'firebase-admin';
import { atomicWalletUpdate } from '../finance/walletOperations';
import { FINANCE_CONFIG } from '../finance/config';

// IMPORTANT: Set this date to when Bug #1 was deployed to production
// TODO: Update this date before running the script!
const BUG_START_DATE = new Date('2025-12-01'); // Placeholder - UPDATE THIS!

// Safety flag: Set to false to execute actual refunds
const DRY_RUN = process.env.DRY_RUN !== 'false';

interface RefundResult {
  totalOrders: number;
  totalRefundAmount: number;
  refundedDrivers: Set<string>;
  successfulRefunds: number;
  failedRefunds: number;
  errors: Array<{
    orderId: string;
    driverId: string;
    overcharge: number;
    error: string;
  }>;
  startTime: number;
  endTime: number;
}

export async function refundOverchargedDrivers(): Promise<RefundResult> {
  // Initialize Firebase Admin if not already initialized
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }

  const db = admin.firestore();

  console.log('='.repeat(60));
  console.log('REFUND OVERCHARGED DRIVERS - BUG #1 FIX');
  console.log('='.repeat(60));
  console.log(`Mode: ${DRY_RUN ? '🔍 DRY RUN (Preview Only)' : '⚠️  PRODUCTION (Real Refunds)'}`);
  console.log(`Bug Start Date: ${BUG_START_DATE.toISOString()}`);
  console.log(`Timestamp: ${new Date().toISOString()}`);
  console.log('='.repeat(60));
  console.log('');

  if (!DRY_RUN) {
    console.warn('⚠️  WARNING: This will modify driver wallets in PRODUCTION!');
    console.warn('⚠️  Press Ctrl+C in the next 5 seconds to abort...');
    console.log('');
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }

  const results: RefundResult = {
    totalOrders: 0,
    totalRefundAmount: 0,
    refundedDrivers: new Set<string>(),
    successfulRefunds: 0,
    failedRefunds: 0,
    errors: [],
    startTime: Date.now(),
    endTime: 0,
  };

  // Find all completed orders since bug deployment
  console.log('[Migration] Querying affected orders...');

  const affectedOrdersSnap = await db
    .collection('orders')
    .where('status', '==', 'completed')
    .where('completedAt', '>=', admin.firestore.Timestamp.fromDate(BUG_START_DATE))
    .get();

  results.totalOrders = affectedOrdersSnap.size;

  console.log(`[Migration] Found ${results.totalOrders} affected orders`);
  console.log('');

  if (results.totalOrders === 0) {
    console.log('[Migration] No affected orders found. Exiting.');
    return results;
  }

  let processed = 0;

  for (const orderDoc of affectedOrdersSnap.docs) {
    processed++;
    const orderId = orderDoc.id;
    const order = orderDoc.data();

    if (processed % 10 === 0) {
      console.log(`[Migration] Progress: ${processed}/${results.totalOrders}`);
    }

    // Calculate overcharge amount (10% of order price)
    const orderPrice = order.price || 0;
    const overcharge = Math.round(orderPrice * FINANCE_CONFIG.COMPLETION_FEE_RATE);
    const driverId = order.assignedDriverId || order.driverId;

    if (!driverId) {
      console.warn(`[Migration] ⚠️  Order ${orderId} has no driverId, skipping`);
      continue;
    }

    if (orderPrice <= 0) {
      console.warn(`[Migration] ⚠️  Order ${orderId} has invalid price ${orderPrice}, skipping`);
      continue;
    }

    // Check if refund already processed
    const existingRefundSnap = await db
      .collection('transactions')
      .where('orderId', '==', orderId)
      .where('type', '==', 'refund')
      .where('description', '==', `Bug #1 refund: overcharge for order #${orderId}`)
      .limit(1)
      .get();

    if (!existingRefundSnap.empty) {
      console.log(`[Migration] ℹ️  Order ${orderId} already refunded, skipping`);
      continue;
    }

    try {
      if (!DRY_RUN) {
        // Execute actual refund
        await atomicWalletUpdate(db, driverId, overcharge, {
          orderId,
          type: 'refund',
          description: `Bug #1 refund: overcharge for order #${orderId}`,
          metadata: {
            orderPrice,
            overchargeRate: FINANCE_CONFIG.COMPLETION_FEE_RATE,
            bugFixDate: new Date().toISOString(),
            migrationScript: 'refund-overcharged-drivers.ts',
          },
        });

        console.log(`[Migration] ✅ Refunded ${overcharge} MRU to driver ${driverId} for order ${orderId}`);
      } else {
        console.log(
          `[Migration] 🔍 [DRY RUN] Would refund ${overcharge} MRU to driver ${driverId} for order ${orderId}`
        );
      }

      results.totalRefundAmount += overcharge;
      results.refundedDrivers.add(driverId);
      results.successfulRefunds++;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);

      results.failedRefunds++;
      results.errors.push({
        orderId,
        driverId,
        overcharge,
        error: errorMsg,
      });

      console.error(`[Migration] ❌ Failed to refund order ${orderId}:`, errorMsg);
    }
  }

  results.endTime = Date.now();
  const duration = (results.endTime - results.startTime) / 1000;

  console.log('');
  console.log('='.repeat(60));
  console.log('MIGRATION SUMMARY');
  console.log('='.repeat(60));
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN' : 'PRODUCTION'}`);
  console.log(`Total Orders Processed: ${results.totalOrders}`);
  console.log(`Successful Refunds: ${results.successfulRefunds}`);
  console.log(`Failed Refunds: ${results.failedRefunds}`);
  console.log(`Total Refund Amount: ${results.totalRefundAmount} MRU`);
  console.log(`Unique Drivers Refunded: ${results.refundedDrivers.size}`);
  console.log(`Duration: ${duration.toFixed(2)}s`);

  if (results.errors.length > 0) {
    console.log('');
    console.log('ERRORS:');
    results.errors.forEach((error, index) => {
      console.log(`  ${index + 1}. Order ${error.orderId} (Driver ${error.driverId}): ${error.error}`);
    });
  }

  console.log('='.repeat(60));
  console.log('');

  // Save migration report to Firestore
  if (!DRY_RUN) {
    await db.collection('admin_reports').add({
      type: 'bug1_driver_refunds',
      dryRun: DRY_RUN,
      results: {
        totalOrders: results.totalOrders,
        successfulRefunds: results.successfulRefunds,
        failedRefunds: results.failedRefunds,
        totalRefundAmount: results.totalRefundAmount,
        uniqueDrivers: results.refundedDrivers.size,
        duration,
      },
      errors: results.errors,
      bugStartDate: BUG_START_DATE.toISOString(),
      executedAt: admin.firestore.FieldValue.serverTimestamp(),
      timestamp: new Date().toISOString(),
    });

    console.log('[Migration] ✅ Report saved to Firestore collection: admin_reports');
  }

  return results;
}

// Run if called directly
if (require.main === module) {
  refundOverchargedDrivers()
    .then((results) => {
      console.log(`\n[Migration] ✅ Migration complete`);
      process.exit(results.failedRefunds > 0 ? 1 : 0);
    })
    .catch((error) => {
      console.error('\n[Migration] ❌ Migration failed:', error);
      process.exit(2);
    });
}
