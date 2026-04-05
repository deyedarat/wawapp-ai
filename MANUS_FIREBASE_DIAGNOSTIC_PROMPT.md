# Firebase reCAPTCHA Diagnostic & Fix Prompt for Manus Browser Agent

## Context
WawApp is a Flutter app published on Google Play Store that uses Firebase Phone Authentication. Users are experiencing "about:blank" screens during OTP verification due to Firebase error: **17201 - reCAPTCHA token is missing**.

## Your Mission
Navigate to Firebase Console, diagnose the App Check and Phone Authentication configuration, and implement the correct settings to fix the reCAPTCHA token missing error.

---

## Step 1: Login to Firebase Console

1. Navigate to: https://console.firebase.google.com/
2. Login with the WawApp project owner account
3. Select the project: **wawapp-ai** (or similar - look for WawApp project)

---

## Step 2: Verify Phone Authentication Setup

1. In the left sidebar, click **Build** → **Authentication**
2. Click the **Sign-in method** tab
3. Verify **Phone** provider is **Enabled**
4. If disabled, click on it and enable it
5. Check **Phone numbers for testing** section:
   - If test numbers exist, note them
   - Ensure they are valid for testing only

---

## Step 3: Check App Check Configuration (CRITICAL)

1. In the left sidebar, click **Build** → **App Check**
2. Look for the Android app: `com.wawapp.client`
3. Check the current configuration status:

### If App Check is NOT configured:
- Click **Register app** or **Add app**
- Select **Android** platform
- Package name: `com.wawapp.client`
- Choose provider: **Play Integrity** (since app is on Google Play)
- Click **Save** and **Register**

### If App Check IS configured but showing errors:
- Check the provider type (should be **Play Integrity** for production)
- Verify the package name is correct: `com.wawapp.client`
- Check if there are any error messages or warnings

### Key Settings to Verify:
- **Enforcement mode**: Should be **Unenforced** initially for testing, then **Enforced** for production
- **Provider**: **Play Integrity** (for Google Play distribution)
- **Metrics**: Check if requests are being blocked

---

## Step 4: Check reCAPTCHA Configuration

1. Stay in **App Check** section
2. Look for **reCAPTCHA Enterprise** or **reCAPTCHA v3** settings
3. Verify:
   - reCAPTCHA keys are properly configured
   - The site key matches the Android app
   - No expired or invalid keys

### If reCAPTCHA is not configured:
1. Go to Google Cloud Console: https://console.cloud.google.com/
2. Select the same project (wawapp-ai)
3. Navigate to **Security** → **reCAPTCHA Enterprise**
4. Create a new key:
   - Type: **Android**
   - Package name: `com.wawapp.client`
   - Copy the **Site Key**
5. Return to Firebase Console
6. Paste the site key in App Check settings

---

## Step 5: Verify SHA-256 Fingerprints

1. In Firebase Console, go to **Project settings** (gear icon)
2. Scroll to **Your apps** section
3. Find the Android app: `com.wawapp.client`
4. Click on it to expand
5. Check **SHA certificate fingerprints** section

### Expected fingerprints:
The app should have SHA-256 fingerprints from:
- **Debug keystore** (for development)
- **Release keystore** (for Google Play - CRITICAL)

### If missing or incorrect:
The user needs to provide the correct SHA-256 from their release keystore:
```bash
# Command to extract SHA-256 from release keystore:
keytool -list -v -keystore <path-to-release-keystore.jks> -alias <key-alias>
```

---

## Step 6: Check Firestore Security Rules (Related)

1. Go to **Build** → **Firestore Database**
2. Click **Rules** tab
3. Verify rules allow Phone Auth users to read/write

Example rule that should exist:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## Step 7: Enable Required APIs in Google Cloud

1. Navigate to: https://console.cloud.google.com/
2. Select the wawapp-ai project
3. Go to **APIs & Services** → **Library**
4. Ensure these APIs are **ENABLED**:
   - ✅ **Identity Toolkit API** (for Firebase Auth)
   - ✅ **reCAPTCHA Enterprise API** (for App Check)
   - ✅ **Cloud Functions API** (if using Cloud Functions)

If any are disabled, click on them and enable.

---

## Step 8: Check for Quota/Billing Issues

1. In Google Cloud Console, go to **Billing**
2. Verify:
   - Billing account is linked to the project
   - No quota exceeded warnings
   - No outstanding invoices

3. Go to **IAM & Admin** → **Quotas**
4. Search for: **Identity Toolkit API**
5. Check daily quotas are not exceeded

---

## Step 9: Diagnostic Checklist Summary

After completing all steps, verify:

- [ ] Phone Authentication is **Enabled**
- [ ] App Check is **Registered** with **Play Integrity**
- [ ] App Check enforcement mode is set (Unenforced for testing, Enforced for production)
- [ ] SHA-256 fingerprints from **release keystore** are added
- [ ] reCAPTCHA Enterprise API is **Enabled**
- [ ] Identity Toolkit API is **Enabled**
- [ ] Firestore security rules allow authenticated users
- [ ] No billing or quota issues

---

## Step 10: Generate Diagnostic Report

Create a report with:

1. **App Check Status**:
   - Provider: [Play Integrity / Debug / Not Configured]
   - Enforcement: [Enforced / Unenforced]
   - Errors: [List any errors shown]

2. **Phone Auth Status**:
   - Enabled: [Yes / No]
   - Test numbers: [Count]

3. **SHA Fingerprints**:
   - Debug SHA-256: [Present / Missing]
   - Release SHA-256: [Present / Missing]

4. **APIs Status**:
   - Identity Toolkit API: [Enabled / Disabled]
   - reCAPTCHA Enterprise API: [Enabled / Disabled]

5. **Errors Found**: [List all warnings/errors from console]

6. **Recommended Actions**: [What needs to be fixed]

---

## Expected Error Code 17201 - Root Causes

Based on Firebase documentation, error **17201** (reCAPTCHA token missing) occurs when:

1. ❌ **App Check is not configured** for the Android app
2. ❌ **Play Integrity provider is not registered** in App Check
3. ❌ **SHA-256 fingerprint** from release keystore is missing
4. ❌ **reCAPTCHA Enterprise API** is disabled in Google Cloud
5. ❌ App Check is in **Enforced mode** but the app doesn't pass verification

---

## Common Fixes for Error 17201

### Fix 1: Enable App Check with Play Integrity
```
Firebase Console → App Check → Register app → Select Play Integrity
```

### Fix 2: Add Release Keystore SHA-256
```
Firebase Console → Project Settings → Your apps → Add fingerprint
```

### Fix 3: Set App Check to Unenforced (for testing)
```
Firebase Console → App Check → Select app → Enforcement → Unenforced
```

### Fix 4: Enable reCAPTCHA Enterprise API
```
Google Cloud Console → APIs & Services → Enable API → reCAPTCHA Enterprise API
```

---

## Testing After Changes

After making changes in Firebase Console:

1. **Wait 5-10 minutes** for changes to propagate
2. **Uninstall and reinstall** the app on the device
3. **Clear app data** if reinstalling doesn't help
4. Try the Phone Authentication flow again
5. Monitor Firebase Console **App Check** → **Metrics** for verification attempts

---

## Emergency Debug Mode (If Production is Broken)

If production users are affected, temporarily:

1. Go to **App Check** → Click on the app
2. Set **Enforcement mode** to **Unenforced**
3. This will allow authentication to work while you fix the underlying issue
4. **IMPORTANT**: Re-enable enforcement after fixing!

---

## Output Format

Please provide your findings in this format:

```markdown
# Firebase Diagnostic Report for WawApp

## 1. App Check Configuration
- Status: [Configured / Not Configured]
- Provider: [Play Integrity / Other]
- Enforcement: [Enforced / Unenforced]
- Issues Found: [List]

## 2. Phone Authentication
- Status: [Enabled / Disabled]
- Configuration: [Correct / Incorrect]
- Issues Found: [List]

## 3. SHA-256 Fingerprints
- Debug SHA: [Present / Missing]
- Release SHA: [Present / Missing]
- Count: [Number]

## 4. Google Cloud APIs
- Identity Toolkit API: [Enabled / Disabled]
- reCAPTCHA Enterprise API: [Enabled / Disabled]
- Other relevant APIs: [Status]

## 5. Critical Issues Requiring Action
1. [Issue 1 with recommended fix]
2. [Issue 2 with recommended fix]
3. [etc.]

## 6. Screenshot Evidence
[Provide screenshots of key settings]

## 7. Recommended Next Steps
1. [Action 1]
2. [Action 2]
3. [etc.]
```

---

## Additional Context

- **App Package**: `com.wawapp.client`
- **Platform**: Android (published on Google Play)
- **Firebase Project**: wawapp-ai (verify exact name)
- **Error Code**: 17201 - reCAPTCHA token is missing
- **Error Message**: "SMS verification code request failed: unknown status code: 17201 reCAPTCHA token is missing"
- **User Experience**: Sees "about:blank" when reCAPTCHA fails

---

## Success Criteria

You will have successfully completed this task when:

1. ✅ You can confirm App Check is properly configured with Play Integrity
2. ✅ All required APIs are enabled in Google Cloud Console
3. ✅ SHA-256 fingerprints from release keystore are added
4. ✅ No errors or warnings in Firebase Console
5. ✅ A comprehensive diagnostic report is provided

---

## Questions to Ask User (If Information is Missing)

If you find missing configuration during diagnosis, ask:

1. "Do you have the SHA-256 fingerprint from your **release keystore** (the one used for Google Play signing)?"
   - If yes: "Please provide it so I can add it to Firebase"
   - If no: "Please run this command and provide the output: `keytool -list -v -keystore <release-keystore> -alias <alias>`"

2. "Is the Firebase project name exactly 'wawapp-ai' or something different?"

3. "Are you using Google Play App Signing (recommended) or managing your own keystore?"
   - If Google Play App Signing: Get SHA-256 from Google Play Console → Setup → App Integrity

---

## START HERE

Begin by navigating to: https://console.firebase.google.com/

Login and select the WawApp project, then follow steps 1-10 above.

Good luck! 🚀
