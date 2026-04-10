/**
 * Diagnostic Script: Check Driver Notification Eligibility
 *
 * This script checks why driver 49ZGFxTVAMaAMkVd4GQZ9Juyjg might not receive notifications.
 *
 * Usage: node check_driver_notification_status.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const DRIVER_ID = '49ZGFxTVAMaAMkVd4GQZ9Juyjg';

async function checkDriverStatus() {
  console.log('\n=== Driver Notification Eligibility Check ===\n');
  console.log('Driver ID:', DRIVER_ID);
  console.log('Timestamp:', new Date().toISOString());
  console.log('\n');

  const issues = [];
  const warnings = [];

  try {
    // 1. Check driver document
    console.log('1️⃣ Checking driver document...');
    const driverDoc = await db.collection('drivers').doc(DRIVER_ID).get();

    if (!driverDoc.exists) {
      issues.push('❌ Driver document does not exist');
      console.log('   ❌ Driver document NOT FOUND\n');
      return { issues, warnings };
    }

    const driverData = driverDoc.data();
    console.log('   ✅ Driver document exists');
    console.log('   - isOnline:', driverData.isOnline);
    console.log('   - isVerified:', driverData.isVerified);
    console.log('   - fcmToken:', driverData.fcmToken ? `${driverData.fcmToken.substring(0, 20)}...` : 'MISSING');
    console.log('   - phone:', driverData.phone);
    console.log('\n');

    if (!driverData.isOnline) {
      issues.push('❌ Driver is OFFLINE (isOnline: false)');
    }
    if (!driverData.isVerified) {
      issues.push('❌ Driver is NOT VERIFIED (isVerified: false)');
    }
    if (!driverData.fcmToken) {
      issues.push('❌ Driver has NO FCM TOKEN');
    }

    // 2. Check driver_locations document
    console.log('2️⃣ Checking driver_locations...');
    const locationDoc = await db.collection('driver_locations').doc(DRIVER_ID).get();

    if (!locationDoc.exists) {
      issues.push('❌ Driver location document does not exist');
      console.log('   ❌ Location document NOT FOUND\n');
    } else {
      const locationData = locationDoc.data();
      const updatedAt = locationData.updatedAt?.toDate();
      const now = new Date();
      const minutesAgo = updatedAt ? Math.floor((now - updatedAt) / 60000) : null;

      console.log('   ✅ Location document exists');
      console.log('   - lat:', locationData.lat || locationData.latitude);
      console.log('   - lng:', locationData.lng || locationData.longitude);
      console.log('   - accuracy:', locationData.accuracy, 'meters');
      console.log('   - updatedAt:', updatedAt?.toISOString());
      console.log('   - Minutes ago:', minutesAgo);
      console.log('\n');

      if (!locationData.lat && !locationData.latitude) {
        issues.push('❌ Driver location missing latitude');
      }
      if (!locationData.lng && !locationData.longitude) {
        issues.push('❌ Driver location missing longitude');
      }
      if (minutesAgo > 15) {
        issues.push(`❌ Driver location is STALE (${minutesAgo} minutes old, must be < 15 minutes)`);
      }
      if (locationData.accuracy && locationData.accuracy > 100) {
        warnings.push(`⚠️ Driver location accuracy is LOW (${locationData.accuracy}m, should be < 100m)`);
      }
    }

    // 3. Check for active orders
    console.log('3️⃣ Checking for active orders...');
    const activeByDriverId = await db
      .collection('orders')
      .where('driverId', '==', DRIVER_ID)
      .where('status', 'in', ['accepted', 'onRoute'])
      .limit(1)
      .get();

    const activeByAssignedId = await db
      .collection('orders')
      .where('assignedDriverId', '==', DRIVER_ID)
      .where('status', 'in', ['accepted', 'onRoute'])
      .limit(1)
      .get();

    if (!activeByDriverId.empty || !activeByAssignedId.empty) {
      issues.push('❌ Driver has ACTIVE ORDER (accepted or onRoute)');
      console.log('   ❌ Driver has active order\n');
    } else {
      console.log('   ✅ No active orders\n');
    }

    // 4. Summary
    console.log('=== SUMMARY ===\n');

    if (issues.length === 0 && warnings.length === 0) {
      console.log('✅ Driver is ELIGIBLE to receive notifications!\n');
    } else {
      if (issues.length > 0) {
        console.log('CRITICAL ISSUES (must fix):');
        issues.forEach(issue => console.log(`   ${issue}`));
        console.log('');
      }

      if (warnings.length > 0) {
        console.log('WARNINGS (should fix):');
        warnings.forEach(warning => console.log(`   ${warning}`));
        console.log('');
      }
    }

    // 5. Recommendations
    console.log('=== RECOMMENDATIONS ===\n');

    if (!driverData.isOnline) {
      console.log('📱 Driver needs to open the app and go online\n');
    }
    if (!driverData.fcmToken) {
      console.log('📱 Driver needs to close and reopen the app to register FCM token\n');
    }
    if (!locationDoc.exists || (locationDoc.exists && (!locationDoc.data().lat && !locationDoc.data().latitude))) {
      console.log('📍 Driver needs to enable GPS and grant location permissions\n');
    }
    if (locationDoc.exists) {
      const locationData = locationDoc.data();
      const updatedAt = locationData.updatedAt?.toDate();
      const minutesAgo = updatedAt ? Math.floor((new Date() - updatedAt) / 60000) : null;
      if (minutesAgo > 15) {
        console.log('📍 Driver location is stale - driver needs to move or restart the app\n');
      }
    }

    return { issues, warnings };

  } catch (error) {
    console.error('\n❌ ERROR:', error.message);
    console.error(error.stack);
    return { issues: [`Error: ${error.message}`], warnings };
  }
}

// Run the check
checkDriverStatus()
  .then(() => {
    console.log('✅ Check completed\n');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  });
