#!/usr/bin/env node
'use strict';
/**
 * Interactive Device Setup
 * 
 * Detects connected devices, identifies which has the driver app
 * and which has the rider app, then updates device_roles.json automatically.
 *
 * Usage:
 *   node qa/setup_devices.js
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROLES_PATH = path.join(__dirname, 'device_roles.json');

function exec(cmd) {
    try {
        return execSync(cmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
    } catch (_) {
        return '';
    }
}

function getConnectedDevices() {
    const out = exec('adb devices');
    return out.split('\n')
        .filter(line => line.includes('\tdevice'))
        .map(line => line.split('\t')[0].trim());
}

function hasPackage(deviceId, packageName) {
    const out = exec(`adb -s ${deviceId} shell pm list packages`);
    return out.includes(`package:${packageName}`);
}

function getDeviceModel(deviceId) {
    return exec(`adb -s ${deviceId} shell getprop ro.product.model`);
}

// ── Main ────────────────────────────────────────────────────────────────────

console.log('\n=== WawApp Device Auto-Setup ===\n');

const devices = getConnectedDevices();

if (devices.length === 0) {
    console.log('❌ No devices connected. Connect phones via USB and enable USB debugging.');
    process.exit(1);
}

console.log(`Found ${devices.length} device(s):\n`);

const deviceInfo = devices.map(id => {
    const model = getDeviceModel(id);
    const hasDriver = hasPackage(id, 'com.wawapp.driver');
    const hasRider = hasPackage(id, 'com.wawapp.client');
    console.log(`  ${id} (${model})`);
    console.log(`    Driver app: ${hasDriver ? '✅' : '❌'}`);
    console.log(`    Rider app:  ${hasRider ? '✅' : '❌'}`);
    console.log('');
    return { id, model, hasDriver, hasRider };
});

// Auto-assign roles
let driverDevice = deviceInfo.find(d => d.hasDriver && !d.hasRider);
let riderDevice = deviceInfo.find(d => d.hasRider && !d.hasDriver);

// If both apps on same device or ambiguous, use first/second order
if (!driverDevice || !riderDevice) {
    driverDevice = deviceInfo.find(d => d.hasDriver);
    riderDevice = deviceInfo.find(d => d.hasRider && d.id !== driverDevice?.id);
}

if (!driverDevice) {
    console.log('❌ No device found with com.wawapp.driver installed.');
    console.log('   Install the driver APK first: adb -s <device> install driver.apk');
    process.exit(1);
}

if (!riderDevice) {
    console.log('❌ No device found with com.wawapp.client installed.');
    console.log('   Install the client APK first: adb -s <device> install client.apk');
    process.exit(1);
}

// Write roles
const roles = {
    driver: {
        deviceId: driverDevice.id,
        packageName: 'com.wawapp.driver',
        role: 'driver',
        model: driverDevice.model
    },
    rider: {
        deviceId: riderDevice.id,
        packageName: 'com.wawapp.client',
        role: 'rider',
        model: riderDevice.model
    }
};

fs.writeFileSync(ROLES_PATH, JSON.stringify(roles, null, 2) + '\n', 'utf8');

console.log('═'.repeat(50));
console.log('✅ device_roles.json updated:');
console.log(`   Driver: ${driverDevice.id} (${driverDevice.model})`);
console.log(`   Rider:  ${riderDevice.id} (${riderDevice.model})`);
console.log('═'.repeat(50));
console.log('\nReady to run E2E tests:');
console.log('  powershell -File qa/run_e2e.ps1');
console.log('');
