#!/usr/bin/env node
'use strict';
/**
 * Device Detection & Validation Script
 *
 * Automatically detects connected ADB devices and validates they match
 * the expected roles in device_roles.json.
 *
 * Usage:
 *   node qa/check_devices.js
 *
 * Exit codes:
 *   0 - Both devices connected and valid
 *   1 - Missing or mismatched devices
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Colors for terminal output
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

function exec(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
  } catch (err) {
    return '';
  }
}

// ── Step 1: Load expected device roles ──────────────────────────────────────
log('\n=== WawApp Device Detection ===\n', 'bright');

const rolesPath = path.join(__dirname, 'device_roles.json');
if (!fs.existsSync(rolesPath)) {
  log('❌ ERROR: device_roles.json not found', 'red');
  log(`   Expected at: ${rolesPath}`, 'yellow');
  process.exit(1);
}

const roles = JSON.parse(fs.readFileSync(rolesPath, 'utf8'));
log('📋 Expected devices:', 'blue');
log(`   Driver: ${roles.driver.deviceId} (${roles.driver.packageName})`, 'blue');
log(`   Rider:  ${roles.rider.deviceId} (${roles.rider.packageName})`, 'blue');

// ── Step 2: Query connected ADB devices ─────────────────────────────────────
log('\n🔍 Scanning ADB devices...', 'blue');
const adbOutput = exec('adb devices');
const lines = adbOutput.split('\n').slice(1).filter(l => l.trim() && !l.includes('List of'));

if (lines.length === 0) {
  log('❌ ERROR: No devices connected', 'red');
  log('   Please connect devices and ensure USB debugging is enabled', 'yellow');
  process.exit(1);
}

const connectedDevices = lines.map(line => {
  const parts = line.trim().split(/\s+/);
  return { id: parts[0], state: parts[1] };
});

log(`✅ Found ${connectedDevices.length} device(s):`, 'green');
connectedDevices.forEach(d => {
  log(`   ${d.id} (${d.state})`, 'green');
});

// ── Step 3: Validate expected devices are present ───────────────────────────
log('\n🔎 Validating device roles...', 'blue');

const driverConnected = connectedDevices.find(d => d.id === roles.driver.deviceId);
const riderConnected = connectedDevices.find(d => d.id === roles.rider.deviceId);

let exitCode = 0;

if (driverConnected) {
  log(`✅ Driver device connected: ${roles.driver.deviceId}`, 'green');

  // Verify driver app is installed
  const driverPkgs = exec(`adb -s ${roles.driver.deviceId} shell pm list packages`);
  if (driverPkgs.includes(roles.driver.packageName)) {
    log(`   ✅ Driver app installed: ${roles.driver.packageName}`, 'green');
  } else {
    log(`   ⚠️  WARNING: Driver app not installed: ${roles.driver.packageName}`, 'yellow');
  }
} else {
  log(`❌ Driver device NOT connected: ${roles.driver.deviceId}`, 'red');
  exitCode = 1;
}

if (riderConnected) {
  log(`✅ Rider device connected: ${roles.rider.deviceId}`, 'green');

  // Verify rider app is installed
  const riderPkgs = exec(`adb -s ${roles.rider.deviceId} shell pm list packages`);
  if (riderPkgs.includes(roles.rider.packageName)) {
    log(`   ✅ Rider app installed: ${roles.rider.packageName}`, 'green');
  } else {
    log(`   ⚠️  WARNING: Rider app not installed: ${roles.rider.packageName}`, 'yellow');
  }
} else {
  log(`❌ Rider device NOT connected: ${roles.rider.deviceId}`, 'red');
  exitCode = 1;
}

// ── Step 4: Check for unexpected devices ────────────────────────────────────
const expectedIds = [roles.driver.deviceId, roles.rider.deviceId];
const unexpectedDevices = connectedDevices.filter(d => !expectedIds.includes(d.id));

if (unexpectedDevices.length > 0) {
  log('\n⚠️  WARNING: Unexpected devices detected:', 'yellow');
  unexpectedDevices.forEach(d => {
    log(`   ${d.id} (not defined in device_roles.json)`, 'yellow');
  });
  log('   These devices will be ignored during test execution.', 'yellow');
}

// ── Step 5: Final verdict ───────────────────────────────────────────────────
log('\n' + '='.repeat(60), 'blue');
if (exitCode === 0) {
  log('✅ READY: All required devices connected and validated', 'green');
  log('   You can now run dual-device E2E tests.', 'green');
} else {
  log('❌ NOT READY: Missing required devices', 'red');
  log('   Please connect all devices and try again.', 'yellow');
}
log('='.repeat(60) + '\n', 'blue');

process.exit(exitCode);
