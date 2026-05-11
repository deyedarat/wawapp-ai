'use strict';
/**
 * Role Validator
 * Executes strict architectural validation on all connected hardware before scenario execution starts.
 * Provides Hard-Fail Protections for device-role ambiguity.
 */
const { execSync } = require('child_process');

function checkConnectedDevices() {
  try {
    const out = execSync('adb devices', { encoding: 'utf8' });
    return out.split('\n')
      .filter(line => line.includes('\tdevice'))
      .map(line => line.split('\t')[0].trim());
  } catch (_) {
    return [];
  }
}

function isPackageInstalled(deviceId, packageName) {
  try {
    const out = execSync(`adb -s ${deviceId} shell pm list packages`, {
      encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe']
    });
    return out.includes(`package:${packageName}`);
  } catch (_) {
    return false;
  }
}

/**
 * Validates critical device bindings before suite run.
 * Throws immediate fatal exception on mismatch.
 * @param {object} config
 */
function validateDeviceRoles(config) {
  console.log('\n' + '═'.repeat(60));
  console.log('  🛡️  STARTUP DEVICE AUDIT & ROLE VALIDATION');
  console.log('═'.repeat(60));

  const connected = checkConnectedDevices();
  console.log(`  [Audit] Connected Devices: [${connected.join(', ') || 'NONE'}]`);

  const { driver, rider } = config;

  // 1. Config check
  if (!driver.deviceId) throw new Error('DEVICE_ROLE_MISMATCH: Driver deviceId is not defined in config.');
  if (!rider.deviceId)  throw new Error('DEVICE_ROLE_MISMATCH: Rider deviceId is not defined in config.');

  // 2. Duplicate Check
  if (driver.deviceId === rider.deviceId) {
    throw new Error(`DEVICE_ROLE_MISMATCH: Duplicate Device ID assigned! driver and rider both point to ${driver.deviceId}`);
  }

  // 3. Connectivity Check
  if (!connected.includes(driver.deviceId)) {
    throw new Error(`DEVICE_ROLE_MISMATCH: Configured Driver Device ${driver.deviceId} NOT DETECTED via adb.`);
  }
  if (!connected.includes(rider.deviceId)) {
    throw new Error(`DEVICE_ROLE_MISMATCH: Configured Rider Device ${rider.deviceId} NOT DETECTED via adb.`);
  }

  console.log('  [Audit] ✅ Connectivity Verified.');

  // 4. Package Presence Check
  console.log(`  [Audit] Validating packages...`);
  
  if (!isPackageInstalled(driver.deviceId, driver.packageName)) {
    throw new Error(`DEVICE_ROLE_MISMATCH: Driver package ${driver.packageName} NOT FOUND on driver device ${driver.deviceId}.`);
  }
  console.log(`  [Audit] ✅ Driver package verified on ${driver.deviceId}`);

  if (!isPackageInstalled(rider.deviceId, rider.packageName)) {
    throw new Error(`DEVICE_ROLE_MISMATCH: Rider package ${rider.packageName} NOT FOUND on rider device ${rider.deviceId}.`);
  }
  console.log(`  [Audit] ✅ Rider package verified on ${rider.deviceId}`);

  console.log('  [Audit] 🟢 ALL ROLES VALIDATED SUCCESSFULLY. Suite safe to launch.');
  console.log('═'.repeat(60) + '\n');
  
  return {
    verifiedAt: new Date().toISOString(),
    driverDevice: driver.deviceId,
    riderDevice: rider.deviceId
  };
}

module.exports = { validateDeviceRoles };
