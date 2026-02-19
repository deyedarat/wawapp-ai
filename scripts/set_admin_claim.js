/**
 * Set Admin Custom Claim
 *
 * This script sets the isAdmin custom claim for a user
 * Run with: node scripts/set_admin_claim.js <email>
 *
 * Example:
 *   node scripts/set_admin_claim.js myadmin@wawapp.co
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'wawapp-952d6'
});

async function setAdminClaim(email) {
  try {
    // Get user by email
    console.log(`🔍 Looking up user: ${email}`);
    const user = await admin.auth().getUserByEmail(email);

    console.log(`✅ User found: ${user.uid}`);
    console.log(`   Email: ${user.email}`);
    console.log(`   Display Name: ${user.displayName || 'N/A'}`);

    // Set custom claims
    console.log(`\n🔧 Setting admin custom claims...`);
    await admin.auth().setCustomUserClaims(user.uid, {
      isAdmin: true,
      role: 'admin',
      assignedAt: Date.now(),
    });

    console.log(`✅ Admin claims set successfully!`);

    // Create/update admin profile in Firestore
    console.log(`\n📝 Creating admin profile in Firestore...`);
    await admin.firestore().collection('admins').doc(user.uid).set({
      email: user.email,
      displayName: user.displayName || 'Admin',
      role: 'admin',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`✅ Admin profile created/updated in Firestore`);

    // Log the action
    await admin.firestore().collection('admin_actions').add({
      action: 'setAdminClaim_via_script',
      targetUserId: user.uid,
      targetEmail: user.email,
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`\n${'='.repeat(60)}`);
    console.log(`✅ SUCCESS! Admin access granted to: ${email}`);
    console.log(`${'='.repeat(60)}`);
    console.log(`\n📌 Next steps:`);
    console.log(`   1. User must sign out and sign back in`);
    console.log(`   2. Or wait 1 hour for token to refresh automatically`);
    console.log(`   3. Then access admin panel at: https://wawapp-952d6.web.app`);
    console.log(`\n`);

  } catch (error) {
    console.error(`\n❌ Error:`, error.message);

    if (error.code === 'auth/user-not-found') {
      console.error(`\n💡 User not found. Please create the user first using:`);
      console.error(`   - Firebase Console`);
      console.error(`   - Or the create_admin_user.html script`);
    }
  } finally {
    process.exit();
  }
}

// Get email from command line args
const email = process.argv[2];

if (!email) {
  console.error('❌ Error: Email not provided');
  console.log('\nUsage:');
  console.log('  node scripts/set_admin_claim.js <email>');
  console.log('\nExample:');
  console.log('  node scripts/set_admin_claim.js myadmin@wawapp.co');
  process.exit(1);
}

setAdminClaim(email);
