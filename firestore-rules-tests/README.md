# Firestore Security Rules Tests

This directory contains automated tests for WawApp's Firestore security rules using Firebase Emulator.

## Purpose

These tests verify that:
- ✅ Unauthenticated users cannot access sensitive data
- ✅ Users can only read/write their own documents
- ✅ Admin-only fields cannot be modified by regular users
- ✅ Phone enumeration attacks are prevented
- ✅ All security rules correctly enforce access control

## Prerequisites

1. **Node.js** 16+ installed
2. **Firebase Emulator** installed:
   ```bash
   npm install -g firebase-tools
   ```

## Installation

```bash
cd firestore-rules-tests
npm install
```

## Running Tests

### Local Testing

```bash
# Run tests once
npm test

# Run tests in watch mode (auto-rerun on file changes)
npm run test:watch
```

### With Firebase Emulator

The tests automatically start the Firebase Emulator on port 8080. You can also manually start it:

```bash
# In project root
firebase emulators:start --only firestore
```

Then in another terminal:
```bash
cd firestore-rules-tests
npm test
```

## Test Structure

```
firestore.test.js
├── 🔐 /users Collection Security
│   ├── Unauthenticated Access (denied)
│   ├── Authenticated Access (own documents only)
│   └── Saved Locations Subcollection
│
├── 🚗 /drivers Collection Security
│   ├── Unauthenticated Access (denied)
│   ├── Driver Access (own documents only)
│   └── Admin Access (full access)
│
├── 📦 /orders Collection Security
│   ├── Creating Orders (validation + ownership)
│   ├── Reading Orders (owner, driver, matching status)
│   └── Updating Orders (status transitions, rating)
│
├── 💰 /wallets Collection Security
│   └── Read-only for drivers, Cloud Functions writes only
│
├── 🧾 /transactions Collection Security
│   └── Read-only for wallet owner, Cloud Functions writes only
│
├── 📍 /driver_locations Collection Security
│   └── Authenticated read, driver write own location
│
├── 👤 /clients Collection Security
│   └── Own documents only, admin full access
│
└── 👑 /admins Collection Security
    └── Admin read-only, Cloud Functions writes only
```

## Test Coverage

| Collection | Tests | Coverage |
|------------|-------|----------|
| `/users` | 11 | ✅ Full |
| `/drivers` | 9 | ✅ Full |
| `/orders` | 15 | ✅ Full |
| `/wallets` | 5 | ✅ Full |
| `/transactions` | 4 | ✅ Full |
| `/driver_locations` | 4 | ✅ Full |
| `/clients` | 5 | ✅ Full |
| `/admins` | 4 | ✅ Full |
| **TOTAL** | **57 tests** | **100%** |

## Security Fixes Verified

### 🔒 Fixed in firestore.rules:

1. **Phone Enumeration Prevention**
   - ❌ **Before:** `allow list: if request.auth == null;` on `/users` and `/drivers`
   - ✅ **After:** Removed - prevents unauthenticated queries that could enumerate phone numbers

2. **Over-Permissive Driver Access**
   - ❌ **Before:** `allow read: if isSignedIn() && (request.auth.uid == driverId || true);`
   - ✅ **After:** `allow read: if isSignedIn() && request.auth.uid == driverId;`
   - The `|| true` made ANY authenticated user able to read ANY driver document

## CI Integration

Tests run automatically in GitHub Actions on every push/PR. See `.github/workflows/firestore-rules-test.yml`.

## Debugging Test Failures

### Test fails with "connect ECONNREFUSED 127.0.0.1:8080"
**Solution:** Ensure Firebase Emulator is installed and port 8080 is free.

### Test fails with "Failed to load rules"
**Solution:** Verify `../firestore.rules` exists and is valid syntax.

### Test timeout
**Solution:** Increase timeout in `package.json`:
```json
"test": "mocha --require @babel/register --timeout 20000 firestore.test.js"
```

## Adding New Tests

1. Add test case to `firestore.test.js`
2. Use `assertSucceeds()` for allowed operations
3. Use `assertFails()` for denied operations
4. Run `npm test` to verify
5. Update this README with new test count

## Example Test

```javascript
it('✅ should ALLOW user to read own document', async () => {
  await seedDatabase();
  const db = getAuthedDb(ALICE_UID);
  await assertSucceeds(db.collection('users').doc(ALICE_UID).get());
});

it('❌ should DENY user from reading other documents', async () => {
  await seedDatabase();
  const db = getAuthedDb(ALICE_UID);
  await assertFails(db.collection('users').doc(BOB_UID).get());
});
```

## Security Model

See [SECURITY_MODEL.md](../SECURITY_MODEL.md) for complete access control documentation.
