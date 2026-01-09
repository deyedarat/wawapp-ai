# Firebase Production Project Setup Guide

**Date**: 2026-01-06
**Purpose**: Switch WawApp from dev Firebase (`wawapp-952d6`) to production Firebase
**Apps**: WawApp Client + WawApp Driver

---

## ⚠️ Prerequisites

You have already completed:
- ✅ Production keystores generated
- ✅ SHA-1 and SHA-256 fingerprints extracted
- ✅ Release AABs built with dev Firebase

**Fingerprints extracted (see output above or run `get_sha_fingerprints.ps1`)**

---

## Step 1: Create Firebase Production Project

### 1.1 Navigate to Firebase Console

1. Go to [https://console.firebase.google.com/](https://console.firebase.google.com/)
2. Sign in with your Google account (use the account that should own the production project)

### 1.2 Create New Project

1. Click **"Add project"** or **"Create a project"**
2. **Project name**: `wawapp-production` (or `wawapp-prod`)
3. **Project ID**: Will auto-generate (e.g., `wawapp-production-abc123`)
   - ⚠️ **IMPORTANT**: Note this Project ID - you'll need it for verification
4. Click **"Continue"**

### 1.3 Google Analytics (Optional)

- Choose whether to enable Google Analytics
- If enabled, select or create an Analytics account
- Click **"Create project"**

### 1.4 Wait for Project Creation

- Wait for Firebase to provision your project (~30 seconds)
- Click **"Continue"** when ready

---

## Step 2: Register Android Apps

### 2.1 Add Client App

1. In Firebase Console, click **"Add app"** → Select **Android** icon
2. **Android package name**: `com.wawapp.client`
3. **App nickname (optional)**: `WawApp Client`
4. **Debug signing certificate SHA-1** (REQUIRED):
   ```
   21:71:87:95:9E:2A:01:04:36:08:6A:03:26:B6:DC:7E:E2:C0:15:F9
   ```
5. Click **"Register app"**

### 2.2 Download Client google-services.json

1. Click **"Download google-services.json"**
2. **Save to**: `C:\Users\hp\Music\wawapp-ai\apps\wawapp_client\android\app\google-services.json`
3. ⚠️ **Overwrite the existing file** (backup not needed - it's the dev config)
4. Click **"Next"**
5. Skip the SDK setup steps (already configured)
6. Click **"Next"** → **"Continue to console"**

### 2.3 Add SHA-256 Fingerprint to Client App

1. In Firebase Console, go to **Project Settings** (gear icon)
2. Scroll down to **"Your apps"** section
3. Find **"WawApp Client"** (`com.wawapp.client`)
4. Click **"Add fingerprint"**
5. Paste SHA-256:
   ```
   A1:CC:9E:B3:8D:D4:20:89:E6:04:EF:C7:D6:9C:40:E0:72:36:3E:34:9E:57:C9:06:E8:59:77:B2:41:2F:89:18
   ```
6. Click **"Save"**

### 2.4 Add Driver App

1. In Firebase Console, click **"Add app"** → Select **Android** icon
2. **Android package name**: `com.wawapp.driver`
3. **App nickname (optional)**: `WawApp Driver`
4. **Debug signing certificate SHA-1** (REQUIRED):
   ```
   7E:8A:B8:EE:30:08:4C:36:ED:7C:F8:06:7B:67:41:FB:7E:22:3F:EC
   ```
5. Click **"Register app"**

### 2.5 Download Driver google-services.json

1. Click **"Download google-services.json"**
2. **Save to**: `C:\Users\hp\Music\wawapp-ai\apps\wawapp_driver\android\app\google-services.json`
3. ⚠️ **Overwrite the existing file**
4. Click **"Next"**
5. Skip SDK setup
6. Click **"Next"** → **"Continue to console"**

### 2.6 Add SHA-256 Fingerprint to Driver App

1. In **Project Settings** → **"Your apps"**
2. Find **"WawApp Driver"** (`com.wawapp.driver`)
3. Click **"Add fingerprint"**
4. Paste SHA-256:
   ```
   40:CF:9F:2B:18:F8:52:DC:8E:35:5B:A5:BC:BE:8E:89:DE:13:19:F7:E9:04:97:2C:AF:DA:AD:8C:D7:10:61:05
   ```
5. Click **"Save"**

---

## Step 3: Enable Firebase Services

### 3.1 Enable Authentication

1. In Firebase Console, go to **"Build"** → **"Authentication"**
2. Click **"Get started"**
3. Go to **"Sign-in method"** tab
4. Enable **"Phone"** provider:
   - Click on **"Phone"**
   - Toggle **"Enable"**
   - Click **"Save"**

### 3.2 Enable Firestore Database

1. Go to **"Build"** → **"Firestore Database"**
2. Click **"Create database"**
3. **Location**: Choose closest to Mauritania (e.g., `europe-west1` or `us-central1`)
4. **Security rules**: Start in **"production mode"** (you'll configure rules later)
5. Click **"Next"** → **"Enable"**
6. Wait for provisioning (~1 minute)

### 3.3 Enable Cloud Messaging (FCM)

1. Go to **"Build"** → **"Cloud Messaging"**
2. Click **"Get started"** (if prompted)
3. FCM should be auto-enabled for your Android apps
4. ✅ **Verify**: You should see API keys listed

### 3.4 Enable Crashlytics

1. Go to **"Release & Monitor"** → **"Crashlytics"**
2. Click **"Enable Crashlytics"**
3. Select both apps: **com.wawapp.client** and **com.wawapp.driver**
4. Click **"Enable"**

### 3.5 Enable Remote Config (If Used by Driver App)

1. Go to **"Build"** → **"Remote Config"**
2. Click **"Create configuration"** (if prompted)
3. ✅ Remote Config is now enabled

---

## Step 4: Configure Firestore Security Rules

1. Go to **"Firestore Database"** → **"Rules"** tab
2. Replace default rules with your production rules (copy from dev project if available)
3. **Example basic rules** (update based on your needs):
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Users can read/write their own data
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }

       // Rides - authenticated users only
       match /rides/{rideId} {
         allow read: if request.auth != null;
         allow create: if request.auth != null;
         allow update: if request.auth != null &&
           (request.resource.data.clientId == request.auth.uid ||
            request.resource.data.driverId == request.auth.uid);
       }

       // Add your other collections here
     }
   }
   ```
4. Click **"Publish"**

---

## Step 5: Verify Configuration

### 5.1 Check Project Settings

1. Go to **"Project Settings"** (gear icon)
2. **Verify**:
   - Project name: `wawapp-production` (or your chosen name)
   - Project ID: Note this down (e.g., `wawapp-production-abc123`)
   - Both apps listed under **"Your apps"**:
     - ✅ com.wawapp.client (with SHA-1 + SHA-256)
     - ✅ com.wawapp.driver (with SHA-1 + SHA-256)

### 5.2 Verify google-services.json Files

You should have downloaded **TWO** files:

1. **Client**: `apps/wawapp_client/android/app/google-services.json`
   - Should contain `"package_name": "com.wawapp.client"`
2. **Driver**: `apps/wawapp_driver/android/app/google-services.json`
   - Should contain `"package_name": "com.wawapp.driver"`

---

## Step 6: Next Steps (Automated by Claude)

Once you've completed Steps 1-5 above, return to Claude and confirm:

1. ✅ Firebase production project created
2. ✅ Both Android apps registered with SHA-1 + SHA-256
3. ✅ google-services.json files downloaded and saved
4. ✅ Authentication (Phone) enabled
5. ✅ Firestore enabled
6. ✅ Cloud Messaging enabled
7. ✅ Crashlytics enabled
8. ✅ Remote Config enabled (if needed)

**Claude will then**:
- Verify the google-services.json files
- Rebuild release AABs with production Firebase config
- Verify signatures are still valid
- Create completion report

---

## Troubleshooting

### Issue: "Package name already in use"
- **Cause**: Package name registered in another Firebase project
- **Solution**: Use a different Firebase account or delete the app from the old project

### Issue: "Invalid SHA-1 fingerprint"
- **Cause**: Typo or wrong keystore
- **Solution**: Re-run `get_sha_fingerprints.ps1` and copy/paste carefully

### Issue: "Can't download google-services.json"
- **Cause**: Browser issue
- **Solution**: Try different browser or download from Project Settings → Your Apps → google-services.json

---

## Checklist

Before returning to Claude, verify:

- [ ] Firebase project created: `wawapp-production`
- [ ] Project ID noted: `__________________`
- [ ] Client app registered: `com.wawapp.client`
- [ ] Client SHA-1 added: `21:71:87:...`
- [ ] Client SHA-256 added: `A1:CC:9E:...`
- [ ] Client google-services.json downloaded
- [ ] Driver app registered: `com.wawapp.driver`
- [ ] Driver SHA-1 added: `7E:8A:B8:...`
- [ ] Driver SHA-256 added: `40:CF:9F:...`
- [ ] Driver google-services.json downloaded
- [ ] Authentication (Phone) enabled
- [ ] Firestore enabled
- [ ] Cloud Messaging enabled
- [ ] Crashlytics enabled
- [ ] Remote Config enabled (if needed)

---

## Security Notes

- ⚠️ **Do NOT commit google-services.json to public repositories** (it contains API keys)
- ✅ Current .gitignore allows google-services.json for team builds (this is acceptable per Firebase guidelines)
- 🔒 Configure Firestore security rules before deploying to production
- 🔒 Enable App Check for additional security (optional, recommended)

---

**After completing this guide, reply to Claude with**:
- ✅ "Firebase production project created"
- 📝 Project ID: `[your-project-id]`
- 📁 Confirm google-services.json files are in place

Claude will then proceed with rebuilding the AABs.
