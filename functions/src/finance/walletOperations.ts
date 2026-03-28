/**
 * Atomic Wallet Operations
 *
 * Provides atomic wallet balance updates with accurate transaction ledger recording.
 * Fixes Bug #2: Transaction Ledger Race Condition
 *
 * Problem: Using FieldValue.increment() for atomicity but recording balance snapshots
 * outside the transaction causes incorrect balanceBefore/After in concurrent scenarios.
 *
 * Solution: Encapsulate read-modify-write-log in a single Firestore transaction.
 *
 * Author: WawApp Development Team
 * Created: 2026-01-01
 */

import * as admin from 'firebase-admin';

export interface WalletUpdateMetadata {
  orderId: string;
  type: 'trip_start_fee' | 'completion_fee' | 'driver_payout' | 'refund' | 'topup' | 'withdrawal';
  description: string;
  metadata?: Record<string, any>;
}

export interface WalletUpdateResult {
  transactionId: string;
  balanceBefore: number;
  balanceAfter: number;
}

/**
 * Atomically update wallet balance and record transaction with accurate ledger
 *
 * Uses Firestore transaction to ensure:
 * - Balance read, update, and ledger record happen atomically
 * - No race conditions between concurrent updates
 * - balanceBefore/After accurately reflect THIS transaction's effect
 *
 * @param db - Firestore instance
 * @param walletId - Wallet document ID (usually driverId)
 * @param amount - Amount to add (positive) or deduct (negative)
 * @param metadata - Transaction metadata for ledger
 * @returns Transaction ID and balance snapshots
 * @throws Error if wallet not found or insufficient balance
 */
export async function atomicWalletUpdate(
  db: admin.firestore.Firestore,
  walletId: string,
  amount: number,
  metadata: WalletUpdateMetadata
): Promise<WalletUpdateResult> {

  let balanceBefore = 0;
  let balanceAfter = 0;
  let transactionId = '';

  await db.runTransaction(async (txn) => {
    // 1. Read current balance
    const walletRef = db.collection('wallets').doc(walletId);
    const walletSnap = await txn.get(walletRef);

    if (!walletSnap.exists) {
      throw new Error(`Wallet ${walletId} not found`);
    }

    const walletData = walletSnap.data();
    balanceBefore = walletData?.balance || 0;
    balanceAfter = balanceBefore + amount;

    // 2. Validate: prevent negative balance for debits
    if (amount < 0 && balanceAfter < 0) {
      throw new Error(
        `Insufficient balance: wallet=${walletId}, current=${balanceBefore}, ` +
        `required=${Math.abs(amount)}, shortfall=${Math.abs(balanceAfter)}`
      );
    }

    // 3. Update wallet balance
    txn.update(walletRef, {
      balance: balanceAfter,
      lastTransactionAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 4. Create transaction record (ledger entry)
    const transactionRef = db.collection('transactions').doc();
    transactionId = transactionRef.id;

    txn.set(transactionRef, {
      id: transactionId,
      walletId,
      orderId: metadata.orderId,
      type: metadata.type,
      source: metadata.type, // For compatibility with existing queries
      amount,
      balanceBefore,
      balanceAfter,
      description: metadata.description,
      note: metadata.description, // For compatibility
      metadata: metadata.metadata || {},
      currency: 'MRU',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  console.log('[WalletOps] Atomic update completed', {
    walletId,
    amount,
    balanceBefore,
    balanceAfter,
    transactionId,
    type: metadata.type,
    orderId: metadata.orderId,
  });

  return { transactionId, balanceBefore, balanceAfter };
}

/**
 * Validate wallet ledger integrity
 * Recalculates balance from transaction history and compares with actual wallet balance
 *
 * @param db - Firestore instance
 * @param walletId - Wallet to validate
 * @returns Validation result with discrepancy details if any
 */
export async function validateWalletLedger(
  db: admin.firestore.Firestore,
  walletId: string
): Promise<{
  valid: boolean;
  discrepancy?: number;
  details: {
    walletId: string;
    actualBalance: number;
    calculatedBalance: number;
    transactionCount: number;
    ledgerErrors?: Array<{
      transactionId: string;
      index: number;
      recorded: { before: number; after: number };
      expected: { before: number; after: number };
      discrepancy: { before: number; after: number };
    }>;
    error?: string;
  };
}> {
  const walletRef = db.collection('wallets').doc(walletId);
  const walletSnap = await walletRef.get();

  if (!walletSnap.exists) {
    return {
      valid: false,
      details: {
        walletId,
        actualBalance: 0,
        calculatedBalance: 0,
        transactionCount: 0,
        error: 'Wallet not found',
      },
    };
  }

  const actualBalance = walletSnap.data()?.balance || 0;

  // Get all transactions ordered by timestamp
  const transactionsSnap = await db
    .collection('transactions')
    .where('walletId', '==', walletId)
    .orderBy('timestamp', 'asc')
    .get();

  let calculatedBalance = 0;
  const ledgerErrors: any[] = [];
  let txIndex = 0;

  transactionsSnap.forEach((doc) => {
    const txn = doc.data();
    const expectedBalanceBefore = calculatedBalance;
    const expectedBalanceAfter = calculatedBalance + txn.amount;

    // Check if recorded balances match calculated
    if (
      txn.balanceBefore !== expectedBalanceBefore ||
      txn.balanceAfter !== expectedBalanceAfter
    ) {
      ledgerErrors.push({
        transactionId: doc.id,
        index: txIndex,
        recorded: { before: txn.balanceBefore, after: txn.balanceAfter },
        expected: { before: expectedBalanceBefore, after: expectedBalanceAfter },
        discrepancy: {
          before: txn.balanceBefore - expectedBalanceBefore,
          after: txn.balanceAfter - expectedBalanceAfter,
        },
      });
    }

    txIndex++;

    calculatedBalance = expectedBalanceAfter;
  });

  const balanceMatches = calculatedBalance === actualBalance;
  const discrepancy = actualBalance - calculatedBalance;

  return {
    valid: balanceMatches && ledgerErrors.length === 0,
    discrepancy: balanceMatches ? undefined : discrepancy,
    details: {
      walletId,
      actualBalance,
      calculatedBalance,
      transactionCount: transactionsSnap.size,
      ledgerErrors: ledgerErrors.length > 0 ? ledgerErrors : undefined,
    },
  };
}
