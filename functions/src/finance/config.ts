/**
 * Finance Configuration
 * WawApp Wallet & Payout System Constants
 */

export const FINANCE_CONFIG = {
  // Commission rates
  PLATFORM_COMMISSION_RATE: 0.20, // 20% platform fee
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
