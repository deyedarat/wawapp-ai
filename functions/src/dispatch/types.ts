/**
 * WawApp Dispatch Engine — Type Definitions
 *
 * Core types for the hybrid sequential-wave dispatch system.
 *
 * @author WawApp Development Team
 * @version 2.0.0 (Production-Grade)
 */

import * as admin from 'firebase-admin';

// ============================================================================
// DRIVER STATE
// ============================================================================

/**
 * Driver availability status
 */
export type DriverStatus =
  | 'available'    // Ready to receive offers
  | 'busy'         // Has active order
  | 'offline';     // Not accepting orders

/**
 * Driver dispatch state (single source of truth per driver)
 *
 * Collection: driver_dispatch_state/{driverId}
 */
export interface DriverDispatchState {
  driverId: string;
  status: DriverStatus;

  // Active assignments
  activeOfferId: string | null;
  activeOrderId: string | null;

  // Lock mechanism (prevents double-acceptance)
  acceptanceLock: boolean;
  lockExpiresAt: admin.firestore.Timestamp | null;

  // Rate limiting
  lastOfferAt: admin.firestore.Timestamp | null;
  offerCount24h: number;

  // Metadata
  updatedAt: admin.firestore.Timestamp;
  createdAt: admin.firestore.Timestamp;
}

// ============================================================================
// OFFER LIFECYCLE
// ============================================================================

/**
 * Offer status lifecycle
 */
export type OfferStatus =
  | 'sent'       // Initial state: sent to driver
  | 'accepted'   // Driver accepted
  | 'rejected'   // Driver explicitly rejected
  | 'expired'    // Timeout or TTL reached
  | 'cancelled'; // Admin/system cancelled

/**
 * Dispatch offer document
 *
 * Collection: dispatch_offers/{offerId}
 * ID format: {orderId}_{driverId}
 */
export interface DispatchOffer {
  offerId: string;
  orderId: string;
  driverId: string;

  // Lifecycle
  status: OfferStatus;
  round: number;              // Wave number (1, 2, 3 for hybrid model)
  priority: number;           // Within-wave priority (distance-based)

  // Timing
  sentAt: admin.firestore.Timestamp;
  expiresAt: admin.firestore.Timestamp;
  respondedAt: admin.firestore.Timestamp | null;

  // Metadata
  distance: number;           // km from pickup
  fcmMessageId?: string;
  createdAt: admin.firestore.Timestamp;
}

// ============================================================================
// DISPATCH WAVES (Hybrid Model)
// ============================================================================

/**
 * Wave configuration for hybrid dispatch
 */
export interface DispatchWave {
  round: number;
  maxDrivers: number;
  ttl: number;              // seconds
  maxDistance: number;      // km
}

/**
 * Default wave configuration (Option C: Hybrid)
 *
 * Wave 1: Closest driver (15s timeout)
 * Wave 2: 3 nearby drivers (30s timeout)
 * Wave 3: 5 farther drivers (45s timeout)
 */
export const DEFAULT_WAVES: DispatchWave[] = [
  { round: 1, maxDrivers: 1, ttl: 15, maxDistance: 3 },   // Closest only, fast
  { round: 2, maxDrivers: 3, ttl: 30, maxDistance: 8 },   // Nearby backup
  { round: 3, maxDrivers: 5, ttl: 45, maxDistance: 15 },  // Wider net
];

// ============================================================================
// DISPATCH QUEUE
// ============================================================================

/**
 * Dispatch queue entry (orders waiting for dispatch)
 *
 * Collection: dispatch_queue/{orderId}
 */
export interface DispatchQueueEntry {
  orderId: string;
  currentWave: number;
  totalOffersSent: number;

  // Wave tracking
  waveStatus?: 'idle' | 'sending' | 'sent';
  waveStartedAt: admin.firestore.Timestamp | null;
  waveExpiresAt: admin.firestore.Timestamp | null;

  // Metadata
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;

  // Order snapshot (normalized by intake — single source of truth for downstream)
  pickupLat: number;
  pickupLng: number;
  dropoffLat?: number;
  dropoffLng?: number;
  price: number;
  clientName: string;       // Always populated by intake normalization
  pickupLabel?: string | null;   // Normalized label for notifications
  dropoffLabel?: string | null;  // Normalized label for notifications
}

// ============================================================================
// DRIVER ELIGIBILITY
// ============================================================================

/**
 * Eligible driver candidate with metadata
 */
export interface EligibleDriver {
  driverId: string;
  distance: number;        // km from pickup
  fcmToken: string;

  // Profile snapshot
  isOnline: boolean;
  isVerified: boolean;
  city: string;
  vehicleType: string;
}

// ============================================================================
// DISPATCH METRICS
// ============================================================================

/**
 * Per-order dispatch metrics
 *
 * Collection: dispatch_metrics/{orderId}
 */
export interface DispatchMetrics {
  orderId: string;

  // Wave performance
  waveMetrics: {
    round: number;
    driversSent: number;
    rejections: number;
    expirations: number;
    startedAt: admin.firestore.Timestamp;
    completedAt: admin.firestore.Timestamp | null;
  }[];

  // Outcome
  acceptedByDriverId: string | null;
  acceptedAtWave: number | null;
  totalDriversNotified: number;

  // Timing
  firstOfferAt: admin.firestore.Timestamp;
  acceptedAt: admin.firestore.Timestamp | null;
  timeToAcceptSeconds: number | null;

  createdAt: admin.firestore.Timestamp;
}

// ============================================================================
// NOTIFICATION PAYLOAD
// ============================================================================

/**
 * FCM notification data payload
 */
export interface NotificationData {
  messageId: string;
  notificationType: 'new_order' | 'wave_offer';
  type: 'new_order' | 'wave_offer';

  // Order info
  orderId: string;
  offerId: string;

  // Display data
  title: string;
  body: string;
  pickupLabel: string;
  dropoffLabel: string;

  // Coordinates (as strings for FCM)
  pickupLat: string;
  pickupLng: string;
  dropoffLat: string;
  dropoffLng: string;

  // Metadata
  price: string;
  distance: string;
  clientName: string;
  createdAt: string;
  expiresAt: string;
  round: string;
}
