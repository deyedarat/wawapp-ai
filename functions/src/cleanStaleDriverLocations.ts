/**
 * Cloud Function: Clean Stale Driver Locations
 * 
 * Deletes driver_locations documents older than 1 hour to prevent
 * accumulation of stale location data.
 * 
 * Scheduled: Every 1 hour
 * 
 * Author: WawApp Development Team
 * Created: 2025-11-30
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cleanup configuration
 */
const STALE_THRESHOLD_MS = 3600000; // 1 hour in milliseconds
const BATCH_SIZE = 500; // Firestore batch write limit

/**
 * Scheduled function: Clean stale driver locations
 * Runs every 1 hour
 */
export const cleanStaleDriverLocations = functions.pubsub
  .schedule('every 1 hours')
  .timeZone('Africa/Nouakchott') // Mauritania timezone
  .onRun(async (context) => {
    console.log('[CleanStaleDriverLocations] Starting cleanup job');

    try {
      // Calculate cutoff timestamp (1 hour ago)
      const cutoffTime = new Date(Date.now() - STALE_THRESHOLD_MS);
      const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffTime);

      console.log('[CleanStaleDriverLocations] Cutoff time:', {
        cutoff_time: cutoffTime.toISOString(),
        threshold_hours: STALE_THRESHOLD_MS / 3600000,
      });

      // Query stale driver locations
      const staleLocations = await admin.firestore()
        .collection('driver_locations')
        .where('updatedAt', '<', cutoffTimestamp)
        .limit(BATCH_SIZE)
        .get();

      if (staleLocations.empty) {
        console.log('[CleanStaleDriverLocations] No stale locations found');
        return null;
      }

      console.log('[CleanStaleDriverLocations] Found stale locations:', {
        count: staleLocations.size,
      });

      // Delete in batch
      const batch = admin.firestore().batch();
      const deletedDriverIds: string[] = [];

      staleLocations.docs.forEach((doc) => {
        batch.delete(doc.ref);
        deletedDriverIds.push(doc.id);
      });

      await batch.commit();

      console.log('[CleanStaleDriverLocations] Cleanup completed successfully', {
        deleted_count: deletedDriverIds.length,
        deleted_driver_ids: deletedDriverIds.slice(0, 10), // Log first 10 for audit
      });

      // Log analytics event
      console.log('[Analytics] driver_locations_cleaned', {
        deleted_count: deletedDriverIds.length,
        cutoff_time: cutoffTime.toISOString(),
      });

      return null;
    } catch (error: any) {
      console.error('[CleanStaleDriverLocations] Cleanup failed', {
        error_message: error.message,
        error_code: error.code || 'unknown',
      });

      // Log analytics event for failure
      console.log('[Analytics] driver_locations_cleanup_failed', {
        error_message: error.message,
      });

      // Don't throw - we want this to run again next hour
      return null;
    }
  });