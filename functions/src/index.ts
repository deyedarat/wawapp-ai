/**
 * Firebase Cloud Functions Entry Point
 * WawApp - Mauritania Ride & Delivery Platform
 *
 * This file exports all Cloud Functions for the WawApp backend.
 */

import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK
admin.initializeApp();

// Export Cloud Functions
export { acceptOrder } from './acceptOrder';
export { rejectDispatchOffer } from './rejectDispatchOffer';

// ============================================================================
// V2 DISPATCH ENGINE (Production-Grade Offer System)
// ============================================================================
export { acceptOrderV2 } from './acceptOrder.v2';
export { aggregateDriverRating } from './aggregateDriverRating';
export { approveTopupRequest, rejectTopupRequest } from './approveTopupRequest'; // Phase D: Admin top-up approval
export { cleanStaleDriverLocations } from './cleanStaleDriverLocations';
export { createTopupRequest } from './createTopupRequest'; // Phase D: Driver top-up requests
export { enforceOrderExclusivity } from './enforceOrderExclusivity'; // Phase C: Order exclusivity guards
export { enforceWalletBalance } from './enforceWalletBalance'; // Phase D: Wallet balance enforcement
export { expireStaleDrivers } from './expireStaleDrivers'; // Auto-offline drivers with stale location (>30 min)
export { expireStaleOrders } from './expireStaleOrders';
export { getNearbyOrders } from './getNearbyOrders'; // FIX: Get nearby orders for drivers (bypasses Firestore Rules)
export { notifyNewOrderV2 } from './notifyNewOrder.v2';
export { processExpiredWaves } from './processExpiredWaves';
export { rejectOffer } from './rejectOffer';
// export { notifyNewOrder } from './notifyNewOrder'; // ❌ DISABLED: Replaced by notifyNewOrderV2
export { notifyOrderEvents } from './notifyOrderEvents';
// export { notifyUnassignedOrders } from './notifyUnassignedOrders'; // ❌ DISABLED: v2.0 handles retries via processExpiredWaves
export { autoForceUpdate } from './autoForceUpdate'; // Auto-enable force update after deadline
export { cleanupRejectedOrders } from './cleanupRejectedOrders'; // Cleanup expired driver rejection records
export { handleDriverCancellation } from './handleDriverCancellation'; // Phase D: Return cancelled orders to matching
export { handleWaveExpirationTask } from './handleWaveExpiration'; // Cloud Tasks: precise wave expiration
export { initAppConfig } from './initAppConfig'; // One-time setup for app update config
export { monitorAcceptedOrders } from './monitorAcceptedOrders'; // Phase D: Monitor accepted orders timeout & reminders
export { processTripStartFee } from './processTripStartFee'; // Phase C: Trip start fee deduction
export { requestTripStartExtension } from './requestTripStartExtension'; // Phase D: Driver requests extra time
export { trackOrderAcceptance } from './trackOrderAcceptance'; // Phase B: Track order acceptance timestamp
export { updateOrderLocation } from './updateOrderLocation'; // P0-FATAL FIX: Secure driver tracking

// Export Admin Functions
export { removeAdminRole, setAdminRole } from './admin/setAdminRole';

// Export Auth Functions
export { adminBlockClient, adminSetClientVerification, adminUnblockClient } from './admin/adminClientActions';
export { adminBlockDriver, adminUnblockDriver, adminVerifyDriver } from './admin/adminDriverActions';
export { adminCancelOrder, adminReassignOrder } from './admin/adminOrderActions';
export { getAdminStats } from './admin/getAdminStats';
export { checkPhoneExists } from './auth/checkPhoneExists';
export { createCustomToken } from './auth/createCustomToken';
export { deleteAccount } from './auth/deleteAccount'; // Google Play Compliance: Account deletion
export { sendOtp } from './auth/sendOtp';
export { manualSetDriverClaims } from './auth/setDriverClaims';
export { verifyOtp } from './auth/verifyOtp';
// export { adminFixMissingDriverData } from './admin/fixMissingDriverData';
// export { adminCreateTestClient } from './admin/createTestClient';

// Export Reports Functions
export { getDriverPerformanceReport } from './reports/getDriverPerformanceReport';
export { getFinancialReport } from './reports/getFinancialReport';
export { getReportsOverview } from './reports/getReportsOverview';

// Export Finance Functions (Wallet & Payout System)
export { adminCreatePayoutRequest, adminUpdatePayoutStatus } from './finance/adminPayouts';
export { onOrderCompleted } from './finance/orderSettlement';

// Export Analytics Functions
export { aggregateNotificationMetrics } from './analytics/aggregateNotificationMetrics';

