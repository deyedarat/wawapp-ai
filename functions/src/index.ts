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
export { expireStaleOrders } from './expireStaleOrders';
export { aggregateDriverRating } from './aggregateDriverRating';
export { notifyOrderEvents } from './notifyOrderEvents';
export { cleanStaleDriverLocations } from './cleanStaleDriverLocations';

// Export Admin Functions
export { setAdminRole, removeAdminRole } from './admin/setAdminRole';

// Export Auth Functions
export { manualSetDriverClaims } from './auth/setDriverClaims';
export { getAdminStats } from './admin/getAdminStats';
export { adminCancelOrder, adminReassignOrder } from './admin/adminOrderActions';
export { adminBlockDriver, adminUnblockDriver, adminVerifyDriver } from './admin/adminDriverActions';
export { adminSetClientVerification, adminBlockClient, adminUnblockClient } from './admin/adminClientActions';
// export { adminFixMissingDriverData } from './admin/fixMissingDriverData';
// export { adminCreateTestClient } from './admin/createTestClient';

// Export Reports Functions
export { getReportsOverview } from './reports/getReportsOverview';
export { getFinancialReport } from './reports/getFinancialReport';
export { getDriverPerformanceReport } from './reports/getDriverPerformanceReport';

// Export Finance Functions (Wallet & Payout System)
export { onOrderCompleted } from './finance/orderSettlement';
export { adminCreatePayoutRequest, adminUpdatePayoutStatus } from './finance/adminPayouts';
