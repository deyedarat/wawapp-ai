# WawApp Client - Demo Account for Google Play Reviewers

**App Name:** WawApp Client
**Package Name:** com.wawapp.client
**Platform:** Android (Flutter)

---

## 🔐 Demo Account Credentials

### **Test Phone Number (for Google Play Reviewers)**

**Phone Number (E.164 format):**
```
+22241410000
```

**OTP Code:**
```
123456
```

**PIN (after OTP verification):**
```
2026
```

---

## 📱 How to Access the App (Step-by-Step)

### **Step 1: Install and Launch**
1. Install the APK/AAB from Google Play Console
2. Launch the WawApp Client app
3. The app will open to the authentication screen

### **Step 2: Phone Number Authentication**
1. On the login screen, enter the phone number:
   **+22241410000**
2. Tap "Request OTP" or equivalent button
3. Enter the OTP code when prompted:
   **123456**
4. Tap "Verify" or equivalent button

### **Step 3: PIN Authentication**
1. After OTP verification, you will be prompted to enter PIN
2. Enter the PIN:
   **2026**
3. Tap "Login" or equivalent button

### **Step 4: Access Granted**
You now have full access to the app as a test user.

---

## ✅ What You Can Test

Once logged in, you can:

- ✅ Browse the home screen and cargo categories
- ✅ Select pickup and drop-off locations (within Nouakchott, Mauritania)
- ✅ Get price quotes for deliveries
- ✅ View order history (if any test orders exist)
- ✅ Access profile settings
- ✅ Test account deletion feature (Settings → Delete Account)
- ✅ Change language (Arabic/English)
- ✅ View saved locations
- ✅ Test notifications (if any)

---

## ⚠️ Important Notes for Reviewers

### **Language Support:**
- **Primary Language:** Arabic (ar)
- **Secondary Language:** English (en)
- The app UI will display in the device's system language if supported

### **Location Services:**
- The app requires location permission for selecting pickup/drop-off points
- Location is only used when the user explicitly taps "Select Location" or similar buttons
- **No background location tracking**

### **Test Account Persistence:**
- This test account is permanent and will not be deleted
- You can safely test the "Delete Account" feature with other test accounts
- The demo account (+22241410000) will remain available for future reviews

### **Firebase Phone Auth Test Mode:**
- This phone number is configured in Firebase Console as a test number
- No actual SMS will be sent
- The OTP code (123456) is hardcoded for this number only

---

## 🔧 Technical Details

### **Authentication Flow:**
1. Phone Number → Firebase Phone Auth (OTP)
2. OTP Verification → Firebase Custom Token
3. PIN Authentication → Firestore validation → Sign In

### **Data Storage:**
- User data: Firebase Firestore (`users` collection)
- Authentication: Firebase Authentication
- Files/Media: None (text-based app)

### **Permissions Required:**
- `INTERNET` - Required for Firebase/API communication
- `ACCESS_FINE_LOCATION` - Required for selecting delivery locations (foreground only)
- `ACCESS_COARSE_LOCATION` - Required for approximate location
- `POST_NOTIFICATIONS` - Required for order status updates
- `ACCESS_NETWORK_STATE` - Required for checking connectivity

### **No Dangerous Permissions:**
- ❌ No SMS read/send
- ❌ No background location
- ❌ No camera/microphone
- ❌ No contacts access
- ❌ No storage access

---

## 📞 Support Contact

If you encounter any issues during the review:

**Email:** support@wawappmr.com
**Privacy Policy:** https://wawappmr.com/privacy
**Account Deletion:** https://wawappmr.com/delete-account

---

## ✅ Google Play Compliance

This app complies with:
- ✅ Account Deletion Requirement (2024-2025)
- ✅ Data Safety Form (all data declared)
- ✅ Privacy Policy (publicly accessible)
- ✅ Web-based account deletion (email: support@wawappmr.com)
- ✅ Minimum functionality standards
- ✅ User data protection policies

---

**Last Updated:** 2026-01-14
**App Version:** 1.0.0+1
**Firebase Project:** wawapp-952d6
