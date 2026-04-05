# Download Fresh google-services.json from Firebase Console

## Mission
Download the latest `google-services.json` file from Firebase Console and provide its contents.

---

## Steps

### 1. Navigate to Firebase Project Settings
- Go to: https://console.firebase.google.com/
- Select project: **Waw App** (wawapp-952d6)
- Click the **gear icon** (⚙️) in the top left → **Project settings**

### 2. Select the Android App
- Scroll down to **Your apps** section
- Find the app: `com.wawapp.client` (Android icon)
- If multiple apps are listed, make sure you select the **Android** one, NOT iOS or Web

### 3. Download google-services.json
- In the `com.wawapp.client` app card, look for the **google-services.json** download button
- Click **Download google-services.json**
- The file will be downloaded to your browser's default download folder

### 4. Open and Copy the File Contents
- Open the downloaded `google-services.json` file in a text editor
- Copy the **entire contents** of the file
- Paste it in your response wrapped in a code block like this:

```json
{
  "project_info": {
    ...
  },
  ...
}
```

---

## Important Notes

- Make sure you download from the **Android** app (`com.wawapp.client`), NOT the driver app or iOS/Web apps
- The file should contain `appcheck_info` section if App Check is properly configured
- The file will contain sensitive API keys — this is normal and expected
- Do NOT share this file publicly; only provide it in this secure session

---

## Expected File Structure

The downloaded file should have sections like:
```json
{
  "project_info": { ... },
  "client": [ ... ],
  "configuration_version": "1"
}
```

If properly configured with App Check, it may also contain:
```json
{
  "appcheck_info": {
    "app_attest_config": { ... },
    "play_integrity_config": { ... }
  }
}
```

---

## After Download

Once you provide the file contents, I will:
1. Replace the old file in the Flutter project
2. Rebuild the APK
3. Test if App Check tokens are now valid
4. Verify that Error 17201 is resolved

---

**START NOW** — Navigate to Firebase Console and download the latest google-services.json file.
