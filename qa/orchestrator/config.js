'use strict';
/**
 * WawApp Dispatch Reliability Platform
 * Central configuration — all constants live here.
 */

module.exports = {
  // ── Firebase ──────────────────────────────────────────────────────────────
  firebase: {
    projectId: 'wawapp-952d6',
    serviceAccountPath: 'C:/Users/hp/Music/wawapp-mcp-debug-server/config/dev-service-account.json',
  },

  // ── Actors ────────────────────────────────────────────────────────────────
  driver: {
    id: '49ZGFxTVAMaAMkVd4GQZ9Juyjgf1',
    deviceId: 'R83Y20PC4EN',         // Samsung SM-A065F, Android 15
    packageName: 'com.wawapp.driver',
    nearbyTabBounds: { x: 532, y: 650 },  // center of "Nearby" tab
  },

  rider: {
    // Populated once rider device is added.  Scripts gracefully skip rider steps when null.
    id: null,
    deviceId: null,
    packageName: 'com.wawapp.client',
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
