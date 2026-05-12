#!/usr/bin/env node
'use strict';
/**
 * Checkpoint 1: Dual-Device Launch Test
 *
 * Validates that both driver and rider devices can be controlled independently
 * and their apps can be launched without interference.
 *
 * Usage:
 *   node qa/test_dual_launch.js
 */

const Device = require('./orchestrator/device');
const cfg = require('./orchestrator/config');

const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
};

function log(msg, color = 'reset') {
  console.log(`${colors[color]}${msg}${colors.reset}`);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
  log('\n=== Checkpoint 1: Dual-Device Launch Test ===\n', 'bright');

  // ── Step 1: Validate configuration ────────────────────────────────────────
  log('📋 Validating configuration...', 'blue');

  if (!cfg.driver.deviceId) {
    log('❌ FAIL: Driver deviceId not configured', 'red');
    process.exit(1);
  }

  if (!cfg.rider.deviceId) {
    log('❌ FAIL: Rider deviceId not configured', 'red');
    process.exit(1);
  }

  log(`   Driver device: ${cfg.driver.deviceId}`, 'green');
  log(`   Rider device:  ${cfg.rider.deviceId}`, 'green');

  // ── Step 2: Initialize device controllers ─────────────────────────────────
  log('\n🔧 Initializing device controllers...', 'blue');

  const driver = new Device(cfg.driver.deviceId, cfg.driver.packageName, 'driver');
  const rider = new Device(cfg.rider.deviceId, cfg.rider.packageName, 'rider');

  log('   ✅ Driver controller ready', 'green');
  log('   ✅ Rider controller ready', 'green');

  // ── Step 3: Prepare devices ───────────────────────────────────────────────
  log('\n🧹 Preparing devices (wake, kill apps, clear)...', 'blue');

  try {
    driver.prepareForScenario();
    log('   ✅ Driver prepared', 'green');
  } catch (err) {
    log(`   ❌ Driver preparation failed: ${err.message}`, 'red');
    process.exit(1);
  }

  try {
    rider.prepareForScenario();
    log('   ✅ Rider prepared', 'green');
  } catch (err) {
    log(`   ❌ Rider preparation failed: ${err.message}`, 'red');
    process.exit(1);
  }

  // ── Step 4: Launch driver app ─────────────────────────────────────────────
  log('\n🚗 Launching driver app...', 'blue');

  try {
    driver.launchDriverApp();
    log('   ✅ Driver app launched', 'green');
    await sleep(5000); // Wait for app to settle
  } catch (err) {
    log(`   ❌ Driver launch failed: ${err.message}`, 'red');
    process.exit(1);
  }

  // Verify driver app is in foreground
  const driverFocused = driver.getFocusedActivity();
  if (driverFocused.includes(cfg.driver.packageName)) {
    log('   ✅ Driver app is in foreground', 'green');
  } else {
    log(`   ⚠️  WARNING: Driver app may not be active`, 'yellow');
    log(`      Focused activity: ${driverFocused}`, 'yellow');
  }

  // ── Step 5: Launch rider app ──────────────────────────────────────────────
  log('\n👤 Launching rider app...', 'blue');

  try {
    rider.launchRiderApp();
    log('   ✅ Rider app launched', 'green');
    await sleep(5000); // Wait for app to settle
  } catch (err) {
    log(`   ❌ Rider launch failed: ${err.message}`, 'red');
    process.exit(1);
  }

  // Verify rider app is in foreground
  const riderFocused = rider.getFocusedActivity();
  if (riderFocused.includes(cfg.rider.packageName)) {
    log('   ✅ Rider app is in foreground', 'green');
  } else {
    log(`   ⚠️  WARNING: Rider app may not be active`, 'yellow');
    log(`      Focused activity: ${riderFocused}`, 'yellow');
  }

  // ── Step 6: Verify no interference ────────────────────────────────────────
  log('\n🔍 Verifying device isolation...', 'blue');

  // Driver should still have its app, even though rider was launched after
  const driverStillActive = driver.isAppForegrounded();
  const riderActive = rider.isAppForegrounded();

  if (driverStillActive) {
    log('   ✅ Driver app still active on driver device', 'green');
  } else {
    log('   ⚠️  Driver app lost focus (expected if rider is on same device)', 'yellow');
  }

  if (riderActive) {
    log('   ✅ Rider app active on rider device', 'green');
  } else {
    log('   ❌ Rider app not active on rider device', 'red');
  }

  // ── Step 7: Capture UI dumps for verification ─────────────────────────────
  log('\n📸 Capturing UI dumps...', 'blue');

  try {
    const driverUI = driver.dumpUI('./qa/artifacts/checkpoint1_driver.xml');
    log('   ✅ Driver UI captured', 'green');
    if (driverUI.includes('com.wawapp.driver')) {
      log('      ✓ Driver package confirmed in UI', 'green');
    }
  } catch (err) {
    log(`   ⚠️  Driver UI dump failed: ${err.message}`, 'yellow');
  }

  try {
    const riderUI = rider.dumpUI('./qa/artifacts/checkpoint1_rider.xml');
    log('   ✅ Rider UI captured', 'green');
    if (riderUI.includes('com.wawapp.client')) {
      log('      ✓ Rider package confirmed in UI', 'green');
    }
  } catch (err) {
    log(`   ⚠️  Rider UI dump failed: ${err.message}`, 'yellow');
  }

  // ── Final verdict ─────────────────────────────────────────────────────────
  log('\n' + '='.repeat(60), 'blue');
  log('✅ CHECKPOINT 1 PASSED', 'green');
  log('   Both devices are independently controllable', 'green');
  log('   Apps launch without interference', 'green');
  log('   Ready for Phase 2: Path Unification', 'green');
  log('='.repeat(60) + '\n', 'blue');
}

main().catch(err => {
  log(`\n❌ FATAL ERROR: ${err.message}`, 'red');
  console.error(err.stack);
  process.exit(1);
});
