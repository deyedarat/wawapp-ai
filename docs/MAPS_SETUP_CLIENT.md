# Google Maps SDK Setup - Client App

## Current Configuration

### API Key Location
**File:** `apps/wawapp_client/android/app/src/main/res/values/api_keys.xml`

```xml
<string name="google_maps_api_key">AIzaSyBkeDIcXg0M-zfXogKtHfyZWWdNb916vjU</string>
```

### Package Name
**File:** `apps/wawapp_client/android/app/build.gradle.kts`

```kotlin
applicationId = "com.wawapp.client"
```

### SHA-1 Fingerprint (Debug Build)
```
BA:DB:92:8D:91:F4:56:C8:F3:35:0C:E4:54:C3:80:C2:0F:54:EA:76
```

---

## Firebase Console Setup (REQUIRED)

### Step 1: Add SHA-1 to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **wawapp-952d6**
3. Go to **Project Settings** (gear icon)
4. Scroll to **Your apps** section
5. Find **com.wawapp.client** (Android app)
6. Click **Add fingerprint**
7. Paste SHA-1: `BA:DB:92:8D:91:F4:56:C8:F3:35:0C:E4:54:C3:80:C2:0F:54:EA:76`
8. Click **Save**
9. **Download new `google-services.json`**
10. Replace `apps/wawapp_client/android/app/google-services.json`

### Step 2: Enable Maps SDK for Android

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select project: **wawapp-952d6**
3. Go to **APIs & Services** → **Library**
4. Search for **Maps SDK for Android**
5. Click **Enable**

### Step 3: Restrict API Key (Recommended)

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Go to **APIs & Services** → **Credentials**
3. Find API key: `AIzaSyBkeDIcXg0M-zfXogKtHfyZWWdNb916vjU`
4. Click **Edit**
5. Under **Application restrictions**:
   - Select **Android apps**
   - Click **Add an item**
   - Package name: `com.wawapp.client`
   - SHA-1: `BA:DB:92:8D:91:F4:56:C8:F3:35:0C:E4:54:C3:80:C2:0F:54:EA:76`
6. Under **API restrictions**:
   - Select **Restrict key**
   - Check: **Maps SDK for Android**
7. Click **Save**

---

## Generate SHA-1 for Future Builds

### Debug Build
```bash
cd apps/wawapp_client/android
./gradlew signingReport
```

Look for **SHA1** under **Variant: debug**

### Release Build
After setting up release signing:
```bash
cd apps/wawapp_client/android
./gradlew signingReport
```

Look for **SHA1** under **Variant: release**

---

## Verification

After completing Firebase Console setup:

1. Rebuild app:
   ```bash
   cd apps/wawapp_client
   flutter clean
   flutter pub get
   flutter run
   ```

2. Check logs - should NOT see:
   ```
   E/Google Android Maps SDK: Authorization failure
   ```

3. Map should load correctly on home screen

---

## Troubleshooting

### Still seeing "Authorization failure"

**Check:**
1. SHA-1 added to Firebase Console
2. New `google-services.json` downloaded and replaced
3. Maps SDK for Android enabled in Google Cloud
4. API key restrictions match package name + SHA-1
5. App rebuilt after changes (`flutter clean`)

### Different SHA-1 for release builds

**Solution:**
1. Generate release SHA-1: `./gradlew signingReport`
2. Add release SHA-1 to Firebase Console
3. Update API key restrictions with release SHA-1

### Maps not loading

**Check:**
1. Internet permission in AndroidManifest.xml (already present)
2. Location permissions granted
3. API key in `api_keys.xml` matches Cloud Console
4. Check logcat for specific errors: `adb logcat | findstr "Maps"`

---

## Files Modified

- ✅ `android/app/src/main/res/values/api_keys.xml` - API key storage
- ✅ `android/app/src/main/AndroidManifest.xml` - API key reference
- ✅ `android/app/build.gradle.kts` - Package name

**No code changes needed** - only Firebase Console configuration required.
