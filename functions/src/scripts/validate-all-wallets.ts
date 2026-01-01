/**
 * Wallet Ledger Validation Script
 *
 * Purpose: Audit tool to detect race condition damage in wallet ledgers
 * Validates that transaction ledger balanceBefore/After match calculated values
 *
 * Bug #2 Fix: This script helps identify wallets affected by the ledger race condition
 *
 * Usage:
 *   npm run validate-wallets
 *
 * Author: WawApp Development Team
 * Created: 2026-01-01
 */

import * as admin from 'firebase-admin';
import { validateWalletLedger } from '../finance/walletOperations';

async function validateAllWallets() {
  // Initialize Firebase Admin if not already initialized
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }

  const db = admin.firestore();

  console.log('[Validation] Starting wallet ledger validation...');
  console.log('[Validation] Timestamp:', new Date().toISOString());

  const walletsSnap = await db.collection('wallets').get();

  const results = {
    total: walletsSnap.size,
    valid: 0,
    invalid: 0,
    errors: [] as any[],
    startTime: Date.now(),
    endTime: 0,
  };

  console.log(`[Validation] Found ${results.total} wallets to validate`);

  let processed = 0;

  for (const walletDoc of walletsSnap.docs) {
    processed++;

    if (processed % 10 === 0) {
      console.log(`[Validation] Progress: ${processed}/${results.total}`);
    }

    const validation = await validateWalletLedger(db, walletDoc.id);

    if (validation.valid) {
      results.valid++;
    } else {
      results.invalid++;
      results.errors.push({
        walletId: walletDoc.id,
        walletType: walletDoc.data().type,
        ownerId: walletDoc.data().ownerId,
        ...validation,
      });

      console.error(`[Validation] ❌ INVALID: Wallet ${walletDoc.id}`, {
        discrepancy: validation.discrepancy,
        actualBalance: validation.details.actualBalance,
        calculatedBalance: validation.details.calculatedBalance,
        transactionCount: validation.details.transactionCount,
      });
    }
  }

  results.endTime = Date.now();
  const duration = (results.endTime - results.startTime) / 1000;

  console.log('\n=== VALIDATION SUMMARY ===');
  console.log(`Total wallets: ${results.total}`);
  console.log(`✅ Valid: ${results.valid}`);
  console.log(`❌ Invalid: ${results.invalid}`);
  console.log(`Duration: ${duration.toFixed(2)}s`);

  if (results.invalid > 0) {
    console.log('\n=== INVALID WALLETS DETAILS ===');
    results.errors.forEach((error, index) => {
      console.log(`\n${index + 1}. Wallet ID: ${error.walletId}`);
      console.log(`   Type: ${error.walletType}`);
      console.log(`   Owner ID: ${error.ownerId}`);
      console.log(`   Discrepancy: ${error.discrepancy} MRU`);
      console.log(`   Actual Balance: ${error.details.actualBalance} MRU`);
      console.log(`   Calculated Balance: ${error.details.calculatedBalance} MRU`);
      console.log(`   Transactions: ${error.details.transactionCount}`);

      if (error.details.ledgerErrors && error.details.ledgerErrors.length > 0) {
        console.log(`   Ledger Errors: ${error.details.ledgerErrors.length}`);
        error.details.ledgerErrors.slice(0, 3).forEach((le: any) => {
          console.log(`     - Transaction ${le.transactionId.substring(0, 8)}:`);
          console.log(`       Expected: ${le.expected.before} → ${le.expected.after}`);
          console.log(`       Recorded: ${le.recorded.before} → ${le.recorded.after}`);
        });
      }
    });
  }

  // Write results to Firestore for admin review
  await db.collection('admin_reports').add({
    type: 'wallet_ledger_validation',
    results: {
      total: results.total,
      valid: results.valid,
      invalid: results.invalid,
      errorCount: results.errors.length,
      duration,
    },
    errors: results.errors,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    timestamp: new Date().toISOString(),
  });

  console.log('\n[Validation] Results saved to Firestore collection: admin_reports');

  return results;
}

// Run if called directly
if (require.main === module) {
  validateAllWallets()
    .then((results) => {
      console.log('\n[Validation] ✅ Validation complete');
      process.exit(results.invalid > 0 ? 1 : 0);
    })
    .catch((error) => {
      console.error('\n[Validation] ❌ Validation failed:', error);
      process.exit(2);
    });
}

export { validateAllWallets };
