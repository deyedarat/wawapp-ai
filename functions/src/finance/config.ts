/**
 * Finance Configuration
 * WawApp Wallet & Payout System Constants
 */

export const FINANCE_CONFIG = {
  // Commission rates (Bug #1 Fix: Split into two-phase structure)
  // Total platform commission = TRIP_START_FEE_RATE + COMPLETION_FEE_RATE = 20%
  PLATFORM_COMMISSION_RATE: 0.20, // 20% total platform fee
  TRIP_START_FEE_RATE: 0.10, // 10% deducted when trip starts (status → onRoute)
  COMPLETION_FEE_RATE: 0.10, // 10% deducted at order completion (status → completed)
  DRIVER_COMMISSION_RATE: 0.80, // 80% driver earning

  // Currency
  DEFAULT_CURRENCY: 'MRU',

  // Platform wallet
  PLATFORM_WALLET_ID: 'platform_main',

  // Payout limits (in MRU)
  MIN_PAYOUT_AMOUNT: 10000, // 10,000 MRU minimum
  MAX_PAYOUT_AMOUNT: 1000000, // 1,000,000 MRU maximum

  // Audit
  ENABLE_AUDIT_LOGGING: true,
};

export type TransactionSource =
  | 'order_settlement'
  | 'trip_start_fee'
  | 'completion_fee'
  | 'driver_payout'
  | 'payout'
  | 'manual_adjustment'
  | 'refund'
  | 'bonus'
  | 'penalty';

export type PayoutMethod =
  | 'manual'
  | 'bank_transfer'
  | 'wise'
  | 'stripe'
  | 'mobile_money';

export type PayoutStatus =
  | 'requested'
  | 'approved'
  | 'processing'
  | 'completed'
  | 'rejected';
