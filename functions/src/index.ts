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
export { aggregateDriverRating } from './aggregateDriverRating';
export { approveTopupRequest, rejectTopupRequest } from './approveTopupRequest'; // Phase D: Admin top-up approval
export { cleanStaleDriverLocations } from './cleanStaleDriverLocations';
export { createTopupRequest } from './createTopupRequest'; // Phase D: Driver top-up requests
export { enforceOrderExclusivity } from './enforceOrderExclusivity'; // Phase C: Order exclusivity guards
export { enforceWalletBalance } from './enforceWalletBalance'; // Phase D: Wallet balance enforcement
export { expireStaleOrders } from './expireStaleOrders';
export { notifyNewOrder } from './notifyNewOrder'; // FIX #1: Notify drivers on order creation
export { notifyOrderEvents } from './notifyOrderEvents';
export { notifyUnassignedOrders } from './notifyUnassignedOrders'; // Phase A: Repeated notifications for unassigned orders
export { processTripStartFee } from './processTripStartFee'; // Phase C: Trip start fee deduction
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
export { manualSetDriverClaims } from './auth/setDriverClaims';
// export { adminFixMissingDriverData } from './admin/fixMissingDriverData';
// export { adminCreateTestClient } from './admin/createTestClient';

// Export Reports Functions
export { getDriverPerformanceReport } from './reports/getDriverPerformanceReport';
export { getFinancialReport } from './reports/getFinancialReport';
export { getReportsOverview } from './reports/getReportsOverview';

// Export Finance Functions (Wallet & Payout System)
export { adminCreatePayoutRequest, adminUpdatePayoutStatus } from './finance/adminPayouts';
export { onOrderCompleted } from './finance/orderSettlement';

