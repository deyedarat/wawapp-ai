# Admin Panel Phase 2 - Deployment Guide

This guide explains how to deploy the WawApp Admin Panel Phase 2 with backend integration.

## Prerequisites

- Firebase CLI installed: `npm install -g firebase-tools`
- Firebase project configured: `wawapp-952d6`
- Admin access to Firebase Console
- Node.js 20+ installed

## 1. Deploy Cloud Functions

### Build Functions
```bash
cd functions
npm install
npm run build
```

### Deploy All Functions
```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific admin functions only
firebase deploy --only functions:setAdminRole,functions:getAdminStats,functions:adminCancelOrder,functions:adminBlockDriver,functions:adminUnblockDriver,functions:adminSetClientVerification
```

### Verify Deployment
```bash
# List deployed functions
firebase functions:list

# View function logs
firebase functions:log
```

## 2. Deploy Firestore Rules

### Review Rules
Check `firestore.rules` file for admin access rules:

```
match /orders/{orderId} {
  // Admin can read/write all orders
  allow read, write: if request.auth.token.isAdmin == true;
}

match /drivers/{driverId} {
  // Admin can read/write all drivers
  allow read, write: if request.auth.token.isAdmin == true;
}

match /clients/{clientId} {
  // Admin can read/write all clients
  allow read, write: if request.auth.token.isAdmin == true;
}

match /admin_actions/{actionId} {
  // Only admins can read/write admin actions
  allow read, write: if request.auth.token.isAdmin == true;
}
```

### Deploy Rules
```bash
firebase deploy --only firestore:rules
```

## 3. Deploy Firestore Indexes

### Review Indexes
Check `firestore.indexes.json` for required indexes.

### Deploy Indexes
```bash
firebase deploy --only firestore:indexes
```

## 4. Set Up First Admin User

### Option A: Using Firebase Console

1. Go to Firebase Console → Authentication
2. Find your user account
3. Note the UID
4. Go to Cloud Functions → setAdminRole
5. Test with payload:
```json
{
  "uid": "YOUR_USER_UID"
}
```

**Note:** First admin must be set manually via Firebase Console or Admin SDK directly.

### Option B: Using Admin SDK Script

Create a one-time script:

```javascript
// scripts/setFirstAdmin.js
const admin = require('firebase-admin');
const serviceAccount = require('./path/to/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const uid = 'YOUR_USER_UID'; // Replace with your UID

admin.auth().setCustomUserClaims(uid, {
  isAdmin: true,
  role: 'admin',
  assignedAt: Date.now()
}).then(() => {
  console.log(`Admin role set for user ${uid}`);
  process.exit(0);
}).catch((error) => {
  console.error('Error setting admin role:', error);
  process.exit(1);
});
```

Run:
```bash
node scripts/setFirstAdmin.js
```

## 5. Deploy Admin Web App

### Build Admin App
```bash
cd apps/wawapp_admin
flutter pub get
flutter build web
```

### Deploy to Firebase Hosting (Optional)

Add to `firebase.json`:
```json
{
  "hosting": {
    "public": "apps/wawapp_admin/build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

Deploy:
```bash
firebase deploy --only hosting
```

## 6. Environment Variables

### Set Firebase Configuration

Ensure the admin app has correct Firebase configuration in:
- `apps/wawapp_admin/lib/firebase_options.dart`
- `apps/wawapp_admin/web/index.html` (Firebase SDK scripts)

### Required Environment Variables

No additional environment variables required for Phase 2.
All configuration is in Firebase project settings.

## 7. Testing Deployment

### Test Cloud Functions

```bash
# Test getAdminStats
curl -X POST https://us-central1-wawapp-952d6.cloudfunctions.net/getAdminStats \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ID_TOKEN" \
  -d '{}'

# Test with Firebase CLI
firebase functions:shell
> getAdminStats()
```

### Test Admin Login

1. Open admin panel: `http://localhost:8080` (or hosting URL)
2. Login with admin account
3. Verify dashboard loads with real data
4. Test admin actions:
   - Cancel an order
   - Block/unblock a driver
   - Verify/unverify a client

### Check Audit Logs

```bash
# View admin_actions collection
firebase firestore:get admin_actions --limit 10
```

## 8. Monitoring

### Function Logs
```bash
# Real-time logs
firebase functions:log --only getAdminStats

# Filter by severity
firebase functions:log --only adminCancelOrder --severity ERROR
```

### Firestore Usage
Monitor in Firebase Console:
- Firestore → Usage
- Check read/write operations
- Monitor document counts

### Performance
- Firebase Console → Performance
- Monitor function execution times
- Check for cold starts

## 9. Rollback (If Needed)

### Rollback Functions
```bash
# List function versions
firebase functions:list

# Rollback to previous version
firebase rollback functions:getAdminStats
```

### Rollback Rules
```bash
# Deploy previous rules file
firebase deploy --only firestore:rules
```

## 10. Security Checklist

- [x] Admin custom claims properly set
- [x] Firestore rules require admin authentication
- [x] Cloud Functions validate admin role
- [x] Admin actions logged to audit collection
- [x] Sensitive operations require confirmation
- [x] HTTPS only for all endpoints
- [x] Rate limiting configured (Firebase default)

## 11. Maintenance

### Update Functions
```bash
cd functions
npm run build
firebase deploy --only functions:FUNCTION_NAME
```

### Monitor Costs
- Firebase Console → Usage and billing
- Set budget alerts
- Monitor Firestore operations
- Track Cloud Functions invocations

### Regular Tasks
1. Review admin_actions logs weekly
2. Monitor error logs
3. Update functions for bug fixes
4. Test admin panel after Firebase SDK updates

## Troubleshooting

### Function Deployment Fails
```bash
# Check function build
cd functions
npm run build

# Check for TypeScript errors
npx tsc --noEmit

# View detailed error
firebase deploy --only functions --debug
```

### Admin Auth Not Working
1. Verify custom claims are set: Check Authentication → Users → Custom claims
2. Force token refresh in admin app
3. Check Firestore rules allow admin access
4. Verify function logs for auth errors

### Firestore Permission Denied
1. Check rules deployed correctly
2. Verify admin custom claims
3. Test with Firebase emulators locally
4. Check indexes are deployed

## Support

For deployment issues:
1. Check Firebase status: https://status.firebase.google.com
2. Review function logs: `firebase functions:log`
3. Test with emulators: `firebase emulators:start`
4. Contact dev team with error logs

---

**Last Updated**: 2024-12-09  
**Phase**: Phase 2 - Backend Integration  
**Status**: Ready for deployment
