# Google Maps API - SHA-1 Fingerprint Registration Guide

## SHA-1 Fingerprints Extracted

### Client App (wawapp_client)
```
Package Name: com.wawapp.client
SHA-1: 24:77:F7:CD:96:0E:D7:A9:B9:D7:FC:17:4A:83:54:0B:4E:67:23:1A
SHA-256: C9:F8:D2:C5:08:16:14:CC:A2:CF:2D:6D:FC:BA:E9:07:10:B8:77:D4:20:1C:99:45:48:78:A1:70:6B:A5:93:6D
```

### Driver App (wawapp_driver)
```
Package Name: com.wawapp.driver
SHA-1: (Same as client - using same debug keystore)
SHA-256: (Same as client - using same debug keystore)
```

---

## Step-by-Step Registration in Google Cloud Console

### 1. Go to Google Cloud Console
Open: https://console.cloud.google.com/

### 2. Select Your Project
- Click on the project dropdown at the top
- Select your WawApp project (or the project where Maps API is enabled)

### 3. Navigate to APIs & Services
- Go to: **APIs & Services** → **Credentials**
- Direct link: https://console.cloud.google.com/apis/credentials

### 4. Add SHA-1 to API Key Restrictions

#### Option A: Create New API Key (Recommended)
1. Click **+ CREATE CREDENTIALS** → **API Key**
2. Copy the generated API key
3. Click **EDIT API KEY** (or the pencil icon)
4. Under **Application restrictions**:
   - Select **Android apps**
5. Click **+ ADD AN ITEM**
6. Enter:
   - **Package name**: `com.wawapp.client`
   - **SHA-1 certificate fingerprint**: `24:77:F7:CD:96:0E:D7:A9:B9:D7:FC:17:4A:83:54:0B:4E:67:23:1A`
7. Click **DONE**
8. Click **+ ADD AN ITEM** again for Driver app:
   - **Package name**: `com.wawapp.driver`
   - **SHA-1 certificate fingerprint**: `24:77:F7:CD:96:0E:D7:A9:B9:D7:FC:17:4A:83:54:0B:4E:67:23:1A`
9. Click **DONE**
10. Under **API restrictions**:
    - Select **Restrict key**
    - Enable these APIs:
      - ✅ Maps SDK for Android
      - ✅ Places API
      - ✅ Geocoding API
      - ✅ Geolocation API
      - ✅ Directions API (if using directions)
11. Click **SAVE**

#### Option B: Update Existing API Key
1. Find your existing Maps API key in the credentials list
2. Click on it to edit
3. Under **Application restrictions**:
   - Change to **Android apps** if not already set
4. Click **+ ADD AN ITEM**
5. Add both package names with SHA-1 fingerprints (as shown in Option A)
6. Click **SAVE**

### 5. Enable Required APIs
Make sure these APIs are enabled in your project:

Go to: **APIs & Services** → **Library**

Search and enable:
- ✅ **Maps SDK for Android**
- ✅ **Places API** (for autocomplete)
- ✅ **Geocoding API** (for address conversion)
- ✅ **Geolocation API** (for location services)
- ✅ **Directions API** (if using route planning)

### 6. Update AndroidManifest.xml (if needed)

Check that your API key is properly configured in both apps:

**Client App**: `apps/wawapp_client/android/app/src/main/AndroidManifest.xml`
**Driver App**: `apps/wawapp_driver/android/app/src/main/AndroidManifest.xml`

Should contain:
```xml
<manifest>
    <application>
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_API_KEY_HERE"/>
    </application>
</manifest>
```

---

## Verification Steps

### After Registration:
1. **Wait 2-5 minutes** for changes to propagate
2. **Restart your app** (kill and relaunch)
3. **Check logs** for any API errors:
   ```bash
   adb logcat | grep -E "Google Maps|API"
   ```

### Expected Success Indicators:
- ✅ Maps load correctly
- ✅ No "API key not authorized" errors
- ✅ Places autocomplete works
- ✅ Geocoding works

### Common Errors and Solutions:

#### Error: "API key not valid"
**Solution**: Make sure you copied the correct SHA-1 fingerprint and package name

#### Error: "This app is not authorized to use this API key"
**Solution**:
- Verify SHA-1 matches exactly
- Verify package name matches exactly (com.wawapp.client or com.wawapp.driver)
- Wait 2-5 minutes for changes to propagate

#### Error: "Maps SDK for Android is not enabled"
**Solution**: Go to APIs & Services → Library → Enable Maps SDK for Android

---

## Production Release Considerations

### For Production Release (Play Store):
You will need a **different SHA-1** from your **release keystore**!

#### Get Release SHA-1:
```bash
# If you have a release keystore
keytool -list -v -keystore /path/to/release.keystore -alias your-alias

# For Play Store signing (Google manages the key)
# Get SHA-1 from: Play Console → Release → Setup → App Integrity
```

#### Steps:
1. Generate release keystore (or use Play Store managed signing)
2. Get release SHA-1 fingerprint
3. Add release SHA-1 to the same API key in Google Cloud Console
4. You'll have both debug AND release SHA-1 registered

---

## Current Status

### Debug Build (Development):
- ✅ SHA-1 extracted: `24:77:F7:CD:96:0E:D7:A9:B9:D7:FC:17:4A:83:54:0B:4E:67:23:1A`
- ⏳ Pending registration in Google Cloud Console
- 📦 Package names:
  - Client: `com.wawapp.client`
  - Driver: `com.wawapp.driver`

### Next Action:
**Register the SHA-1 in Google Cloud Console** following the steps above.

---

## Quick Copy/Paste for Registration

**Client App:**
```
Package: com.wawapp.client
SHA-1: 24:77:F7:CD:96:0E:D7:A9:B9:D7:FC:17:4A:83:54:0B:4E:67:23:1A
```

**Driver App:**
```
Package: com.wawapp.driver
SHA-1: 24:77:F7:CD:96:0E:D7:A9:B9:D7:FC:17:4A:83:54:0B:4E:67:23:1A
```

---

## Firebase Configuration (Alternative Method)

If you're using Firebase for your project, you can also add SHA-1 there:

1. Go to **Firebase Console**: https://console.firebase.google.com/
2. Select your project
3. Go to **Project Settings** (gear icon)
4. Scroll to **Your apps** section
5. Find your Android app (Client or Driver)
6. Click **Add fingerprint**
7. Paste SHA-1: `24:77:F7:CD:96:0E:D7:A9:B9:D7:FC:17:4A:83:54:0B:4E:67:23:1A`
8. Click **Save**
9. Download new `google-services.json` (if needed)
10. Repeat for the other app

**Note**: Firebase will automatically sync with Google Cloud Console.

---

## Troubleshooting

### Maps still not working after registration?

1. **Clear app data**:
   ```bash
   adb shell pm clear com.wawapp.client
   adb shell pm clear com.wawapp.driver
   ```

2. **Rebuild and reinstall**:
   ```bash
   cd apps/wawapp_client
   flutter clean
   flutter build apk --debug
   flutter install
   ```

3. **Check API quotas**:
   - Go to Google Cloud Console → APIs & Services → Dashboard
   - Check if you've exceeded free tier limits

4. **Verify billing is enabled**:
   - Maps API requires billing to be enabled (even for free tier)
   - Go to Google Cloud Console → Billing

---

## Summary

✅ **SHA-1 Fingerprint Extracted**
📋 **Package Names Identified**
📝 **Registration Guide Created**
⏳ **Waiting for Manual Registration in Google Cloud Console**

**Estimated Time**: 5-10 minutes to register + 2-5 minutes for propagation

After registration, maps should work perfectly! 🗺️
