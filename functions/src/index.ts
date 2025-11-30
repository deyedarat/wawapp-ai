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
