'use strict';
/**
 * WawApp Dispatch Reliability Platform
 * Central configuration — all constants live here.
 */

const fs = require('fs');
const path = require('path');

// Load dynamic device roles with runtime safety fallback
const rolesPath = path.join(__dirname, '..', 'device_roles.json');
let roles = { driver: {}, rider: {} };
try {
  roles = JSON.parse(fs.readFileSync(rolesPath, 'utf8'));
} catch (_) {
  console.warn('[Config] WARNING: Cannot read device_roles.json. Using empty defaults.');
}

module.exports = {
  // ── Firebase ──────────────────────────────────────────────────────────────
  firebase: {
    projectId: 'wawapp-952d6',
    serviceAccountPath: 'C:/Users/user/Music/wawapp-mcp-debug-server/config/dev-service-account.json',
  },

  // ── Actors ────────────────────────────────────────────────────────────────
  driver: {
    id: '49ZGFxTVAMaAMkVd4GQZ9Juyjgf1',
    deviceId: roles.driver?.deviceId || null,
    packageName: roles.driver?.packageName || 'com.wawapp.driver',
    nearbyTabBounds: { x: 532, y: 650 },
  },

  rider: {
    id: 'test_rider_001',  // Test rider account ID
    deviceId: roles.rider?.deviceId || null,
    packageName: roles.rider?.packageName || 'com.wawapp.client',
    phoneNumber: '+966501234001',
  },

  // ── Spatial anchor ────────────────────────────────────────────────────────
  // Validated GPS coordinates where the driver device actually sits.
  location: {
    lat: 18.0954303,
    lng: -15.9679639,
  },

  // ── SLA thresholds (milliseconds) ─────────────────────────────────────────
  sla: {
    dispatchToFCM:         15_000,   // rider commit → FCM received
    fcmToFullscreen:        3_000,   // FCM received → fullscreen rendered
    acceptRoundtrip:        8_000,   // driver tap → Firestore accepted
    cacheReconciliation:    5_000,   // cache emission → server reconciliation
    offerExpiryWindow:    120_000,   // max offer lifetime before timeout
  },

  // ── Paths ─────────────────────────────────────────────────────────────────
  paths: {
    reports:   'qa/reports',
    artifacts: 'qa/artifacts',
    timeline:  'qa/reports',   // timeline.ndjson lives inside run folder
  },

  // ── Timing ────────────────────────────────────────────────────────────────
  timing: {
    appBootWait:        14_000,   // ms after am start before tapping (covers Flutter init)
    listenerWait:       10_000,   // ms for Firestore listener to hydrate
    fullscreenWaitMs:   90_000,   // ms to wait for fullscreen (covers CF cold start + FCM + wake)
    offerVisibleWait:   10_000,   // ms to wait for offer card to appear in foreground
    postAcceptWait:     12_000,   // ms after accept tap before checking state
    forceStopWait:       3_000,
    backendTermWait:     3_000,
    scenarioCooldown:    4_000,   // ms between scenarios for device state to settle
    notifClearWait:      2_000,   // ms after notification clear before proceeding
  },

  // ── Operational invariants ─────────────────────────────────────────────────
  invariants: [
    'Dead offers never resurrect',
    'Fullscreen authority never zombifies',
    'Duplicate accept is impossible',
    'Silent suppression cannot persist',
    'Cache snapshots cannot create false authority',
    'Notification authority is singular',
    'FCM wake latency within SLA',
    'Driver cannot be silently starved',
    'Terminal states revoke actionable UI',
    'All lifecycle paths terminate cleanly',
  ],
};
