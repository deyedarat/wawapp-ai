/**
 * Firebase Security Rules Tests for WawApp
 *
 * These tests verify that Firestore security rules correctly enforce access control
 * for all user types: unauthenticated, regular users, drivers, clients, and admins.
 *
 * Run: npm test
 */

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { setLogLevel } from 'firebase/firestore';

// Disable Firestore logging for cleaner test output
setLogLevel('error');

const PROJECT_ID = 'wawapp-rules-test';
const RULES_PATH = '../firestore.rules';

// Test user IDs
const ALICE_UID = 'alice123';
const BOB_UID = 'bob456';
const CHARLIE_DRIVER_UID = 'charlie789';
const DAVE_DRIVER_UID = 'dave012';
const ADMIN_UID = 'admin345';

let testEnv;

/**
 * Setup: Initialize test environment before all tests
 */
before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, 'utf8'),
      host: 'localhost',
      port: 8080,
    },
  });
});

/**
 * Cleanup: Clear Firestore data between tests
 */
afterEach(async () => {
  await testEnv.clearFirestore();
});

/**
 * Teardown: Clean up test environment after all tests
 */
after(async () => {
  await testEnv.cleanup();
});

/**
 * Helper: Get Firestore instance for unauthenticated user
 */
function getUnauthedDb() {
  return testEnv.unauthenticatedContext().firestore();
}

/**
 * Helper: Get Firestore instance for authenticated user
 */
function getAuthedDb(uid, customClaims = {}) {
  return testEnv.authenticatedContext(uid, customClaims).firestore();
}

/**
 * Helper: Get Firestore instance for admin user
 */
function getAdminDb() {
  return testEnv.authenticatedContext(ADMIN_UID, { isAdmin: true }).firestore();
}

/**
 * Helper: Seed database with test data using admin context
 */
async function seedDatabase() {
  const adminDb = testEnv.authenticatedContext(ADMIN_UID, { isAdmin: true }).firestore();

  // Seed users
  await adminDb.collection('users').doc(ALICE_UID).set({
    phoneNumber: '+22200000001',
    pinHash: 'hash1',
    pinSalt: 'salt1',
    createdAt: new Date(),
  });

  await adminDb.collection('users').doc(BOB_UID).set({
    phoneNumber: '+22200000002',
    pinHash: 'hash2',
    pinSalt: 'salt2',
    createdAt: new Date(),
  });

  // Seed drivers
  await adminDb.collection('drivers').doc(CHARLIE_DRIVER_UID).set({
    phoneNumber: '+22200000003',
    isOnline: true,
    isVerified: true,
    rating: 4.5,
    totalTrips: 100,
    createdAt: new Date(),
  });

  await adminDb.collection('drivers').doc(DAVE_DRIVER_UID).set({
    phoneNumber: '+22200000004',
    isOnline: false,
    isVerified: false,
    rating: 0,
    totalTrips: 0,
    createdAt: new Date(),
  });

  // Seed clients
  await adminDb.collection('clients').doc(ALICE_UID).set({
    phoneNumber: '+22200000001',
    isVerified: true,
    totalTrips: 10,
    createdAt: new Date(),
  });

  // Seed orders
  await adminDb.collection('orders').doc('order1').set({
    ownerId: ALICE_UID,
    driverId: CHARLIE_DRIVER_UID,
    status: 'matching',
    price: 1000,
    distanceKm: 5.5,
    pickup: { lat: 18.0735, lng: -15.9582 },
    dropoff: { lat: 18.0835, lng: -15.9482 },
    pickupAddress: 'Nouakchott, Mauritania',
    dropoffAddress: 'Nouakchott, Mauritania',
    createdAt: new Date(),
  });

  // Seed wallets
  await adminDb.collection('wallets').doc(CHARLIE_DRIVER_UID).set({
    type: 'driver',
    balance: 5000,
    currency: 'MRU',
    createdAt: new Date(),
  });

  // Seed transactions
  await adminDb.collection('transactions').doc('txn1').set({
    walletId: CHARLIE_DRIVER_UID,
    type: 'earning',
    amount: 1000,
    orderId: 'order1',
    createdAt: new Date(),
  });
}

// ============================================================================
// USERS COLLECTION TESTS
// ============================================================================

describe('🔐 /users Collection Security', () => {
  describe('Unauthenticated Access', () => {
    it('❌ should DENY reading any user document', async () => {
      const db = getUnauthedDb();
      await assertFails(db.collection('users').doc(ALICE_UID).get());
    });

    it('❌ should DENY listing user documents (phone enumeration protection)', async () => {
      await seedDatabase();
      const db = getUnauthedDb();

      // This is the critical security fix - prevent phone number enumeration
      await assertFails(
        db.collection('users').where('phoneNumber', '==', '+22200000001').get()
      );
    });

    it('❌ should DENY creating user document', async () => {
      const db = getUnauthedDb();
      await assertFails(
        db.collection('users').doc('newuser').set({ phoneNumber: '+22200000099' })
      );
    });
  });

  describe('Authenticated Access (Own Document)', () => {
    it('✅ should ALLOW reading own user document', async () => {
      await seedDatabase();
      const db = getAuthedDb(ALICE_UID);
      await assertSucceeds(db.collection('users').doc(ALICE_UID).get());
    });

    it('❌ should DENY reading other user documents', async () => {
      await seedDatabase();
      const db = getAuthedDb(ALICE_UID);
      await assertFails(db.collection('users').doc(BOB_UID).get());
    });

    it('✅ should ALLOW creating own user document', async () => {
      const db = getAuthedDb('newuser123');
      await assertSucceeds(
        db.collection('users').doc('newuser123').set({
          phoneNumber: '+22200000099',
          pinHash: 'newhash',
          pinSalt: 'newsalt',
          createdAt: new Date(),
        })
      );
    });

    it('❌ should DENY creating document for another user', async () => {
      const db = getAuthedDb(ALICE_UID);
      await assertFails(
        db.collection('users').doc(BOB_UID).set({ phoneNumber: '+22200000098' })
      );
    });

    it('✅ should ALLOW updating own user document', async () => {
      await seedDatabase();
      const db = getAuthedDb(ALICE_UID);
      await assertSucceeds(
        db.collection('users').doc(ALICE_UID).update({ displayName: 'Alice Updated' })
      );
    });

    it('❌ should DENY updating admin-only fields', async () => {
      await seedDatabase();
      const db = getAuthedDb(ALICE_UID);

      // Try to modify admin fields
      await assertFails(
        db.collection('users').doc(ALICE_UID).update({ totalTrips: 999 })
      );

      await assertFails(
        db.collection('users').doc(ALICE_UID).update({ averageRating: 5.0 })
      );
    });

    it('❌ should DENY partial PIN updates (must update both hash and salt)', async () => {
      await seedDatabase();
      const db = getAuthedDb(ALICE_UID);

      // Try to update only PIN hash (security violation)
      await assertFails(
        db.collection('users').doc(ALICE_UID).update({ pinHash: 'newhash' })
      );
    });

    it('✅ should ALLOW updating both PIN hash and salt together', async () => {
      await seedDatabase();
      const db = getAuthedDb(ALICE_UID);

      await assertSucceeds(
        db.collection('users').doc(ALICE_UID).update({
          pinHash: 'newhash',
          pinSalt: 'newsalt',
        })
      );
    });
  });

  describe('Saved Locations Subcollection', () => {
    it('✅ should ALLOW owner to create saved location', async () => {
      await seedDatabase();
      const db = getAuthedDb(ALICE_UID);

      await assertSucceeds(
        db.collection('users').doc(ALICE_UID).collection('savedLocations').add({
          label: 'Home',
          address: 'Nouakchott, Mauritania',
          lat: 18.0735,
          lng: -15.9582,
        })
      );
    });

    it('❌ should DENY invalid coordinates', async () => {
      await seedDatabase();
      const db = getAuthedDb(ALICE_UID);

      await assertFails(
        db.collection('users').doc(ALICE_UID).collection('savedLocations').add({
          label: 'Invalid',
          lat: 200, // Invalid latitude
          lng: -15.9582,
        })
      );
    });

    it('❌ should DENY other users from reading saved locations', async () => {
      await seedDatabase();
      const db = getAuthedDb(BOB_UID);

      await assertFails(
        db.collection('users').doc(ALICE_UID).collection('savedLocations').get()
      );
    });
  });
});

// ============================================================================
// DRIVERS COLLECTION TESTS
// ============================================================================

describe('🚗 /drivers Collection Security', () => {
  describe('Unauthenticated Access', () => {
    it('❌ should DENY reading any driver document', async () => {
      const db = getUnauthedDb();
      await assertFails(db.collection('drivers').doc(CHARLIE_DRIVER_UID).get());
    });

    it('❌ should DENY listing driver documents (phone enumeration protection)', async () => {
      await seedDatabase();
      const db = getUnauthedDb();

      // Critical security fix - prevent driver phone enumeration
      await assertFails(
        db.collection('drivers').where('isOnline', '==', true).get()
      );
    });
  });

  describe('Driver Access (Own Document)', () => {
    it('✅ should ALLOW reading own driver document', async () => {
      await seedDatabase();
      const db = getAuthedDb(CHARLIE_DRIVER_UID);
      await assertSucceeds(db.collection('drivers').doc(CHARLIE_DRIVER_UID).get());
    });

    it('❌ should DENY reading other driver documents', async () => {
      await seedDatabase();
      const db = getAuthedDb(CHARLIE_DRIVER_UID);

      // SECURITY FIX: Removed "|| true" - now properly denies access
      await assertFails(db.collection('drivers').doc(DAVE_DRIVER_UID).get());
    });

    it('✅ should ALLOW creating own driver document', async () => {
      const db = getAuthedDb('newdriver123');
      await assertSucceeds(
        db.collection('drivers').doc('newdriver123').set({
          phoneNumber: '+22200000099',
          isOnline: false,
          vehicleType: 'sedan',
          createdAt: new Date(),
        })
      );
    });

    it('✅ should ALLOW updating own driver document', async () => {
      await seedDatabase();
      const db = getAuthedDb(CHARLIE_DRIVER_UID);
      await assertSucceeds(
        db.collection('drivers').doc(CHARLIE_DRIVER_UID).update({ isOnline: false })
      );
    });

    it('❌ should DENY updating admin-only fields', async () => {
      await seedDatabase();
      const db = getAuthedDb(CHARLIE_DRIVER_UID);

      // Try to self-verify (admin-only operation)
      await assertFails(
        db.collection('drivers').doc(CHARLIE_DRIVER_UID).update({ isVerified: true })
      );

      // Try to modify rating
      await assertFails(
        db.collection('drivers').doc(CHARLIE_DRIVER_UID).update({ rating: 5.0 })
      );

      // Try to modify total trips
      await assertFails(
        db.collection('drivers').doc(CHARLIE_DRIVER_UID).update({ totalTrips: 999 })
      );
    });
  });

  describe('Admin Access', () => {
    it('✅ should ALLOW admin to read any driver document', async () => {
      await seedDatabase();
      const db = getAdminDb();
      await assertSucceeds(db.collection('drivers').doc(CHARLIE_DRIVER_UID).get());
      await assertSucceeds(db.collection('drivers').doc(DAVE_DRIVER_UID).get());
    });

    it('✅ should ALLOW admin to update driver verification', async () => {
      await seedDatabase();
      const db = getAdminDb();
      await assertSucceeds(
        db.collection('drivers').doc(DAVE_DRIVER_UID).update({ isVerified: true })
      );
    });

    it('✅ should ALLOW admin to list all drivers', async () => {
      await seedDatabase();
      const db = getAdminDb();
      await assertSucceeds(db.collection('drivers').get());
    });
  });
});

// ============================================================================
// ORDERS COLLECTION TESTS
// ============================================================================

describe('📦 /orders Collection Security', () => {
  describe('Creating Orders', () => {
    it('✅ should ALLOW authenticated user to create order', async () => {
      const db = getAuthedDb(ALICE_UID);
      await assertSucceeds(
        db.collection('orders').add({
          ownerId: ALICE_UID,
          status: 'matching',
          price: 2000,
          distanceKm: 10.5,
          pickup: { lat: 18.0735, lng: -15.9582 },
          dropoff: { lat: 18.1735, lng: -15.8582 },
          pickupAddress: 'Nouakchott',
          dropoffAddress: 'Nouakchott Airport',
          createdAt: new Date(),
        })
      );
    });

    it('❌ should DENY creating order with invalid status', async () => {
      const db = getAuthedDb(ALICE_UID);
      await assertFails(
        db.collection('orders').add({
          ownerId: ALICE_UID,
          status: 'completed', // Must be 'matching' on create
          price: 2000,
          distanceKm: 10.5,
          pickup: { lat: 18.0735, lng: -15.9582 },
          dropoff: { lat: 18.1735, lng: -15.8582 },
          pickupAddress: 'Nouakchott',
          dropoffAddress: 'Nouakchott Airport',
        })
      );
    });

    it('❌ should DENY creating order for another user', async () => {
      const db = getAuthedDb(ALICE_UID);
      await assertFails(
        db.collection('orders').add({
          ownerId: BOB_UID, // Can't create order for Bob
          status: 'matching',
          price: 2000,
          distanceKm: 10.5,
          pickup: { lat: 18.0735, lng: -15.9582 },
          dropoff: { lat: 18.1735, lng: -15.8582 },
          pickupAddress: 'Nouakchott',
          dropoffAddress: 'Nouakchott Airport',
        })
      );
    });

    it('❌ should DENY creating order with invalid coordinates', async () => {
      const db = getAuthedDb(ALICE_UID);
      await assertFails(
        db.collection('orders').add({
          ownerId: ALICE_UID,
          status: 'matching',
          price: 2000,
          distanceKm: 10.5,
          pickup: { lat: 200, lng: -15.9582 }, // Invalid latitude
          dropoff: { lat: 18.1735, lng: -15.8582 },
          pickupAddress: 'Nouakchott',
          dropoffAddress: 'Nouakchott Airport',
        })
      );
    });

    it('❌ should DENY creating order with excessive distance', async () => {
      const db = getAuthedDb(ALICE_UID);
      await assertFails(
        db.collection('orders').add({
          ownerId: ALICE_UID,
          status: 'matching',
          price: 2000,
          distanceKm: 150, // > 100 km limit
          pickup: { lat: 18.0735, lng: -15.9582 },
          dropoff: { lat: 18.1735, lng: -15.8582 },
          pickupAddress: 'Nouakchott',
          dropoffAddress: 'Nouadhibou',
        })
      );
    });
  });

  describe('Reading Orders', () => {
    it('✅ should ALLOW owner to read their order', async () => {
      await seedDatabase();
      const db = getAuthedDb(ALICE_UID);
      await assertSucceeds(db.collection('orders').doc('order1').get());
    });

    it('✅ should ALLOW assigned driver to read order', async () => {
      await seedDatabase();
      const db = getAuthedDb(CHARLIE_DRIVER_UID);
      await assertSucceeds(db.collection('orders').doc('order1').get());
    });

    it('✅ should ALLOW reading matching orders (for driver discovery)', async () => {
      await seedDatabase();
      const db = getAuthedDb(CHARLIE_DRIVER_UID);
      await assertSucceeds(
        db.collection('orders').where('status', '==', 'matching').get()
      );
    });

    it('❌ should DENY non-owner/non-driver from reading non-matching order', async () => {
      await seedDatabase();

      // Update order to accepted status
      const adminDb = getAdminDb();
      await adminDb.collection('orders').doc('order1').update({ status: 'accepted' });

      // Try to read as different user
      const db = getAuthedDb(BOB_UID);
      await assertFails(db.collection('orders').doc('order1').get());
    });

    it('✅ should ALLOW admin to read any order', async () => {
      await seedDatabase();
      const db = getAdminDb();
      await assertSucceeds(db.collection('orders').doc('order1').get());
    });
  });

  describe('Updating Orders', () => {
    it('✅ should ALLOW driver to accept matching order', async () => {
      await seedDatabase();
      const db = getAuthedDb(CHARLIE_DRIVER_UID);

      await assertSucceeds(
        db.collection('orders').doc('order1').update({
          status: 'accepted',
          driverId: CHARLIE_DRIVER_UID,
        })
      );
    });

    it('❌ should DENY invalid status transition', async () => {
      await seedDatabase();
      const db = getAuthedDb(ALICE_UID);

      // Try to go from matching → completed (invalid transition)
      await assertFails(
        db.collection('orders').doc('order1').update({ status: 'completed' })
      );
    });

    it('❌ should DENY modifying price after creation', async () => {
      await seedDatabase();
      const db = getAuthedDb(ALICE_UID);

      await assertFails(
        db.collection('orders').doc('order1').update({ price: 99999 })
      );
    });

    it('❌ should DENY modifying ownerId', async () => {
      await seedDatabase();
      const db = getAuthedDb(ALICE_UID);

      await assertFails(
        db.collection('orders').doc('order1').update({ ownerId: BOB_UID })
      );
    });

    it('✅ should ALLOW client to cancel their own order', async () => {
      await seedDatabase();
      const db = getAuthedDb(ALICE_UID);

      await assertSucceeds(
        db.collection('orders').doc('order1').update({ status: 'cancelledByClient' })
      );
    });

    it('✅ should ALLOW admin to update any order', async () => {
      await seedDatabase();
      const db = getAdminDb();

      await assertSucceeds(
        db.collection('orders').doc('order1').update({ status: 'cancelled' })
      );
    });
  });
});

// ============================================================================
// WALLETS & TRANSACTIONS TESTS
// ============================================================================

describe('💰 /wallets Collection Security', () => {
  it('❌ should DENY unauthenticated read', async () => {
    const db = getUnauthedDb();
    await assertFails(db.collection('wallets').doc(CHARLIE_DRIVER_UID).get());
  });

  it('✅ should ALLOW driver to read own wallet', async () => {
    await seedDatabase();
    const db = getAuthedDb(CHARLIE_DRIVER_UID);
    await assertSucceeds(db.collection('wallets').doc(CHARLIE_DRIVER_UID).get());
  });

  it('❌ should DENY driver from reading another wallet', async () => {
    await seedDatabase();
    const db = getAuthedDb(CHARLIE_DRIVER_UID);
    await assertFails(db.collection('wallets').doc(DAVE_DRIVER_UID).get());
  });

  it('❌ should DENY driver from writing to wallet (Cloud Functions only)', async () => {
    await seedDatabase();
    const db = getAuthedDb(CHARLIE_DRIVER_UID);

    await assertFails(
      db.collection('wallets').doc(CHARLIE_DRIVER_UID).update({ balance: 999999 })
    );
  });

  it('✅ should ALLOW admin to read any wallet', async () => {
    await seedDatabase();
    const db = getAdminDb();
    await assertSucceeds(db.collection('wallets').doc(CHARLIE_DRIVER_UID).get());
  });
});

describe('🧾 /transactions Collection Security', () => {
  it('❌ should DENY unauthenticated read', async () => {
    const db = getUnauthedDb();
    await assertFails(db.collection('transactions').doc('txn1').get());
  });

  it('✅ should ALLOW driver to read own transactions', async () => {
    await seedDatabase();
    const db = getAuthedDb(CHARLIE_DRIVER_UID);
    await assertSucceeds(db.collection('transactions').doc('txn1').get());
  });

  it('❌ should DENY driver from writing transactions (Cloud Functions only)', async () => {
    await seedDatabase();
    const db = getAuthedDb(CHARLIE_DRIVER_UID);

    await assertFails(
      db.collection('transactions').add({
        walletId: CHARLIE_DRIVER_UID,
        type: 'earning',
        amount: 99999,
      })
    );
  });

  it('✅ should ALLOW admin to read any transaction', async () => {
    await seedDatabase();
    const db = getAdminDb();
    await assertSucceeds(db.collection('transactions').doc('txn1').get());
  });
});

// ============================================================================
// DRIVER LOCATIONS TESTS
// ============================================================================

describe('📍 /driver_locations Collection Security', () => {
  it('✅ should ALLOW any authenticated user to read driver locations', async () => {
    await seedDatabase();

    // Seed a driver location
    const adminDb = getAdminDb();
    await adminDb.collection('driver_locations').doc(CHARLIE_DRIVER_UID).set({
      lat: 18.0735,
      lng: -15.9582,
      updatedAt: new Date(),
    });

    // Any authenticated user can read (for order matching)
    const db = getAuthedDb(ALICE_UID);
    await assertSucceeds(db.collection('driver_locations').doc(CHARLIE_DRIVER_UID).get());
  });

  it('✅ should ALLOW driver to write own location', async () => {
    const db = getAuthedDb(CHARLIE_DRIVER_UID);
    await assertSucceeds(
      db.collection('driver_locations').doc(CHARLIE_DRIVER_UID).set({
        lat: 18.0735,
        lng: -15.9582,
        updatedAt: new Date(),
      })
    );
  });

  it('❌ should DENY driver from writing another driver location', async () => {
    const db = getAuthedDb(CHARLIE_DRIVER_UID);
    await assertFails(
      db.collection('driver_locations').doc(DAVE_DRIVER_UID).set({
        lat: 18.0735,
        lng: -15.9582,
        updatedAt: new Date(),
      })
    );
  });

  it('❌ should DENY unauthenticated read', async () => {
    const db = getUnauthedDb();
    await assertFails(db.collection('driver_locations').doc(CHARLIE_DRIVER_UID).get());
  });
});

// ============================================================================
// CLIENTS COLLECTION TESTS
// ============================================================================

describe('👤 /clients Collection Security', () => {
  it('✅ should ALLOW client to read own document', async () => {
    await seedDatabase();
    const db = getAuthedDb(ALICE_UID);
    await assertSucceeds(db.collection('clients').doc(ALICE_UID).get());
  });

  it('❌ should DENY client from reading another client document', async () => {
    await seedDatabase();
    const db = getAuthedDb(ALICE_UID);
    await assertFails(db.collection('clients').doc(BOB_UID).get());
  });

  it('❌ should DENY client from modifying admin-only fields', async () => {
    await seedDatabase();
    const db = getAuthedDb(ALICE_UID);

    await assertFails(
      db.collection('clients').doc(ALICE_UID).update({ isVerified: true })
    );

    await assertFails(
      db.collection('clients').doc(ALICE_UID).update({ totalTrips: 999 })
    );
  });

  it('✅ should ALLOW admin to read any client', async () => {
    await seedDatabase();
    const db = getAdminDb();
    await assertSucceeds(db.collection('clients').doc(ALICE_UID).get());
  });

  it('✅ should ALLOW admin to update client verification', async () => {
    await seedDatabase();
    const db = getAdminDb();
    await assertSucceeds(
      db.collection('clients').doc(ALICE_UID).update({ isVerified: true })
    );
  });
});

// ============================================================================
// ADMINS COLLECTION TESTS
// ============================================================================

describe('👑 /admins Collection Security', () => {
  it('❌ should DENY unauthenticated read', async () => {
    const db = getUnauthedDb();
    await assertFails(db.collection('admins').doc(ADMIN_UID).get());
  });

  it('❌ should DENY regular user from reading admins', async () => {
    const db = getAuthedDb(ALICE_UID);
    await assertFails(db.collection('admins').doc(ADMIN_UID).get());
  });

  it('✅ should ALLOW admin to read admin documents', async () => {
    await seedDatabase();

    // Seed admin document
    const adminDb = getAdminDb();
    await adminDb.collection('admins').doc(ADMIN_UID).set({
      email: 'admin@wawapp.mr',
      role: 'super_admin',
      createdAt: new Date(),
    });

    await assertSucceeds(adminDb.collection('admins').doc(ADMIN_UID).get());
  });

  it('❌ should DENY all client SDK writes (Cloud Functions only)', async () => {
    const db = getAdminDb();

    await assertFails(
      db.collection('admins').doc('newadmin').set({
        email: 'newadmin@wawapp.mr',
        role: 'admin',
      })
    );
  });
});

console.log('\n✅ All Firestore security rules tests completed!\n');
