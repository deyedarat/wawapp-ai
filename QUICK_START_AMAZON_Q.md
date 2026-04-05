# 🚀 Quick Start: Amazon Q Execution Guide

## 📁 Main File
[Q_PROMPTS_ADMIN_MAP_ENHANCEMENT.md](Q_PROMPTS_ADMIN_MAP_ENHANCEMENT.md)

---

## ⚡ How to Use

### Step 1: Open Target File
```bash
code apps/wawapp_admin/lib/features/orders/widgets/map_location_picker.dart
```

### Step 2: Execute Prompts ONE BY ONE

#### ✅ PROMPT 1: GPS "My Location" Button
**Location in file:** Lines 18-97
**Copy from:** "## 📋 **PROMPT 1: Add GPS "My Location" Button**"
**Copy until:** "---" (before PROMPT 2)

**Paste entire section into Amazon Q chat**

**Test before moving to PROMPT 2:**
```bash
flutter analyze apps/wawapp_admin
flutter run -d <device>
```

---

#### ✅ PROMPT 2: Draggable Marker
**Location in file:** Lines 99-237
**Copy from:** "## 📋 **PROMPT 2: Make Marker Draggable**"
**Copy until:** "---" (before PROMPT 3)

**Test after completion**

---

#### ✅ PROMPT 3: Nominatim Autocomplete Search
**Location in file:** Lines 239-445
**Copy from:** "## 📋 **PROMPT 3: Add Nominatim Autocomplete Search**"
**Copy until:** "---" (before PROMPT 4)

**Test after completion**

---

#### ✅ PROMPT 4: Saved Locations (Firestore)
**Location in file:** Lines 447-726
**Copy from:** "## 📋 **PROMPT 4: Add Saved Locations Feature**"
**Copy until:** "---" (before PROMPT 5)

**⚠️ Important:** After completion, update Firestore rules:
```javascript
// Add to firestore.rules
match /admin_saved_locations/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

**Test after completion**

---

#### ✅ PROMPT 5: UI/UX Polish
**Location in file:** Lines 728-897
**Copy from:** "## 📋 **PROMPT 5: UI/UX Polish**"
**Copy until:** End of prompt

**Test after completion**

---

## 🎯 Verification After Each Prompt

```bash
# 1. Check for errors
flutter analyze apps/wawapp_admin

# 2. Format code
flutter format apps/wawapp_admin/lib/features/orders/widgets/map_location_picker.dart

# 3. Run on device
flutter run -d <your-device>
```

---

## ⚠️ Critical Rules for Amazon Q

### ✅ DO:
- Execute prompts **sequentially** (one at a time)
- Test after each prompt
- Keep OpenStreetMap (don't switch to Google Maps)
- Preserve all existing features

### ❌ DON'T:
- Skip testing between prompts
- Remove districts/POIs/legend
- Switch to Google Maps
- Add packages without verifying pubspec.yaml

---

## 📊 Expected Results

After all 5 prompts:
- ✅ GPS location button
- ✅ Draggable marker
- ✅ Smart search (local + Nominatim)
- ✅ Saved locations (Firestore)
- ✅ Recent locations chips
- ✅ Long-press gesture
- ✅ Haptic feedback

**Cost:** $0/month (OpenStreetMap is free)

---

## 🆘 Troubleshooting

### If Amazon Q fails on a prompt:
1. Check Flutter version: `flutter --version`
2. Verify dependencies: `flutter pub get`
3. Clean build: `flutter clean && flutter pub get`
4. Try prompt again

### If marker gestures conflict (PROMPT 2):
Amazon Q will try two approaches:
1. Manual GestureDetector (preferred)
2. flutter_map_dragmarker plugin (fallback)

### If Nominatim search fails (PROMPT 3):
- Check internet connection
- Verify Nominatim API is accessible
- Check user agent header is set

### If Firestore fails (PROMPT 4):
- Verify Firebase is initialized
- Check user authentication
- Update security rules in Firebase Console

---

## 📝 Commit Message Template

After completing all prompts:

```
feat(admin): enhance map with GPS, draggable marker, and saved locations

- Add GPS "My Location" button for current position
- Make marker draggable like Google Maps
- Enhance search with Nominatim API autocomplete
- Add Firestore-backed saved locations feature
- Improve UX with recent locations and haptic feedback
- Preserve OpenStreetMap (zero API costs)

Brings admin map to feature parity with client app without Google Maps costs.
Estimated savings: $500-1500/month

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

## 📞 Need Help?

If you encounter issues:
1. Check logs: `flutter logs`
2. Review error in Amazon Q output
3. Verify target file hasn't been modified by other tools
4. Ask Claude Code for assistance

---

**Good luck! 🚀**

Execute prompts slowly and test thoroughly between each one.
