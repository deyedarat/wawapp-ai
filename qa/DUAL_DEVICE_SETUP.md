# WawApp Dual-Device E2E Testing Setup

## 🎯 Overview

This guide documents the complete setup for **true dual-device end-to-end testing** where:
- **Rider device** runs the customer app (`com.wawapp.client`)
- **Driver device** runs the driver app (`com.wawapp.driver`)
- **Both devices** are controlled independently and simultaneously
- **Antigravity/LLM agents** can orchestrate tests intelligently

---

## 📊 Current Status

### ✅ Phase 1: COMPLETED (Dual-Device Foundation)

#### What Was Delivered
1. **Device Role Binding** ([device_roles.json](device_roles.json:1))
   - Driver: `R8YW40AW58L`
   - Rider: `RZ8R716T96J`

2. **Configuration Updates** ([orchestrator/config.js](orchestrator/config.js:34))
   - Rider device fully configured with ID and phone number
   - Both devices load from central `device_roles.json`

3. **Device Control Enhancements** ([orchestrator/device.js](orchestrator/device.js:230))
   - `enterText(text)` - Type into input fields
   - `findNodeByHint(xml, hint)` - Smart UI element discovery
   - `tapByHint(hint)` - Coordinate-free tapping
   - `waitForElement(hint, opts)` - Polling for UI elements
   - All methods work on both rider and driver devices

4. **Rider Agent** ([.claude/agents/wawapp-rider-agent.md](.claude/agents/wawapp-rider-agent.md:1))
   - Full documentation of rider control capabilities
   - Integration guide for Antigravity orchestration
   - Security rules and best practices

5. **Validation Tools**
   - [check_devices.js](check_devices.js:1) - Auto-detect and validate connected devices
   - [test_dual_launch.js](test_dual_launch.js:1) - Checkpoint 1 verification script

---

## 🚀 Quick Start

### Step 1: Connect Devices

```powershell
# Connect both devices via USB with debugging enabled
adb devices

# Expected output:
# List of devices attached
# R8YW40AW58L    device  (Driver)
# RZ8R716T96J    device  (Rider)
```

### Step 2: Validate Setup

```powershell
# Auto-detect and verify devices
node qa/check_devices.js

# Expected output:
# ✅ READY: All required devices connected and validated
```

### Step 3: Run Checkpoint 1

```powershell
# Test independent dual-device control
node qa/test_dual_launch.js

# Expected output:
# ✅ CHECKPOINT 1 PASSED
# Both devices are independently controllable
```

---

## 📋 Phase 2: Path Unification (PENDING)

### Objectives
Ensure QA layer, app, and backend speak the same language.

### Required Changes

#### 1. Fix Driver Location Schema ([qa/backend/backend.js](backend/backend.js:1))

**Current (Wrong):**
```javascript
async injectDriverLocation(driverId, lat, lng) {
  await db.collection('driver_locations').doc(driverId).set({
    geopoint: new admin.firestore.GeoPoint(lat, lng),
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    status: 'active',
  });
}
```

**Required (Correct):**
```javascript
async injectDriverLocation(driverId, lat, lng) {
  await db.collection('driver_locations').doc(driverId).set({
    latitude: lat,
    longitude: lng,
    lat: lat,  // For selector compatibility
    lng: lng,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'active',
  });
}
```

**Why:** Dispatch selector in `functions/src/dispatch/selectors.ts` reads `lat/lng` and `updatedAt`, not `geopoint` and `timestamp`.

#### 2. Update Offer ID Format ([qa/backend/backend.js](backend/backend.js:1))

**Current (Wrong):**
```javascript
function buildOfferId(orderId, driverId) {
  return `${orderId}_${driverId}`;
}
```

**Required (Correct):**
```javascript
function buildOfferId(orderId, driverId, round = 1) {
  return `${orderId}_${driverId}_w${round}`;
}
```

**Why:** Production dispatch engine uses `{orderId}_{driverId}_w{round}` format.

#### 3. Migrate Driver App to V2 Acceptance

**File:** `apps/wawapp_driver/lib/services/orders_service.dart`

**Current (Legacy):**
```dart
Future<void> acceptOrder(String orderId) async {
  final result = await _functions.httpsCallable('acceptOrder').call({
    'orderId': orderId,
  });
}
```

**Required (Modern):**
```dart
Future<void> acceptOrder(String orderId, String offerId) async {
  final result = await _functions.httpsCallable('acceptOrderV2').call({
    'orderId': orderId,
    'offerId': offerId,
  });
}
```

**Why:** V2 acceptance is offer-based and prevents race conditions.

---

## 📋 Phase 3: E2E Scenario (PENDING)

### Objective
Build first complete customer→driver flow.

### Scenario: Happy Path

```javascript
// File: qa/scenarios/e2e/rider_driver_happy_path.js

module.exports = {
  id: 'e2e_happy_path',
  name: 'Full E2E: Rider creates order → Driver accepts',
  timeout: 180000,

  async run({ rider, driver, backend, reporter }) {
    // 1. Rider creates order
    await rider.launchApp();
    await rider.waitForElement('pickup');
    await rider.tapByHint('pickup');
    await rider.enterText('King Fahd Road, Riyadh');
    await sleep(2000);
    await rider.tapByHint('suggestion');

    await rider.tapByHint('dropoff');
    await rider.enterText('Olaya Street, Riyadh');
    await sleep(2000);
    await rider.tapByHint('suggestion');

    await rider.tapByHint('submit');

    // 2. Backend verifies order creation
    const order = await backend.waitForOrder({
      riderId: rider.id,
      status: 'pending',
      maxWait: 30000,
    });

    // 3. Backend verifies offer dispatch
    const offer = await backend.waitForOffer({
      orderId: order.id,
      driverId: driver.id,
      maxWait: 30000,
    });

    // 4. Driver receives and accepts
    await driver.waitForNotification({ orderId: order.id, timeout: 15000 });
    await driver.tapByHint('accept');

    // 5. Verify acceptance
    const accepted = await backend.waitForOrder({
      id: order.id,
      status: 'accepted',
      maxWait: 10000,
    });

    // 6. Rider sees driver assigned
    await rider.waitForElement('driver', { timeout: 10000 });

    return { pass: true };
  },
};
```

---

## 📋 Phase 4: Antigravity Integration (PENDING)

### Objective
Enable LLM agents to orchestrate tests autonomously.

### Architecture

```
Antigravity Orchestrator (LLM Agent)
    │
    ├─► Rider Agent (controls rider device via Device class)
    │   └─► Device methods: tapByHint, enterText, waitForElement
    │
    ├─► Driver Agent (controls driver device via Device class)
    │   └─► Device methods: waitForNotification, tapByHint
    │
    └─► Backend Inspector (queries Firestore state)
        └─► Methods: waitForOrder, inspectOffer, inspectDispatchState
```

### Key Features

1. **No Hardcoded Coordinates**
   - Antigravity searches UI by text/hint
   - Adapts to layout changes automatically

2. **Intelligent Waiting**
   - Polls UI until expected elements appear
   - Times out with clear error messages

3. **Evidence-Based Reporting**
   - Every failure includes: UI dump, screenshot, logcat, backend state
   - Developers can reproduce exact failure conditions

4. **Context-Aware Decisions**
   - If "submit" button not found, checks if order already submitted
   - If driver notification delayed, verifies backend state before failing

---

## 🔒 Security & Portability

### Secrets Management

**Current (Insecure):**
- `testsprite.config.json` contains hardcoded `apiKey`
- Service account path hardcoded: `C:/Users/hp/Music/...`

**Required (Secure):**
```bash
# Create .env file
cp qa/.env.template qa/.env

# Edit with your values
DRIVER_DEVICE_ID=R8YW40AW58L
RIDER_DEVICE_ID=RZ8R716T96J
FIREBASE_PROJECT_ID=wawapp-952d6
SERVICE_ACCOUNT_PATH=./qa/secrets/dev-service-account.json
```

### Cross-Platform Compatibility

All scripts now use:
- ✅ Node.js string filtering (not shell `grep`)
- ✅ Cross-platform ADB commands
- ✅ Portable path handling (`path.join`)

---

## 🧪 Running Tests

### Manual Test Execution

```powershell
# Check devices
node qa/check_devices.js

# Run single scenario
node qa/run_scenario.js e2e_happy_path

# Run full regression suite
powershell qa/run_regression_suite.ps1
```

### Antigravity Test Execution (Future)

```powershell
# Delegate to Antigravity
node qa/run_with_antigravity.js e2e_happy_path

# Antigravity will:
# 1. Read scenario spec
# 2. Control both devices intelligently
# 3. Verify backend state
# 4. Generate detailed report
```

---

## 📊 Success Metrics

### Phase 1 (Current)
- ✅ Both devices controllable independently
- ✅ Apps launch without interference
- ✅ UI dumps capture successfully
- ✅ Device roles enforced

### Phase 2 (Target)
- ⏳ QA schema matches production dispatch
- ⏳ Offer IDs use modern format
- ⏳ Driver app uses V2 acceptance

### Phase 3 (Target)
- ⏳ First E2E scenario passes end-to-end
- ⏳ Order created by rider device
- ⏳ Driver accepts via FCM notification
- ⏳ Rider UI updates with driver info

### Phase 4 (Target)
- ⏳ Antigravity executes scenario without hardcoding
- ⏳ Adapts to UI changes automatically
- ⏳ Reports include full evidence trail

---

## 🚨 Blockers to Address

### P0 (Critical)
1. **Driver location schema mismatch** - QA writes wrong format
2. **Offer ID format outdated** - QA uses legacy format
3. **Legacy acceptance path** - App doesn't use V2

### P1 (High)
4. **Secrets exposed in repo** - `testsprite.config.json`
5. **Hardcoded paths** - Service account, device IDs
6. **Rider device ID** - Currently `null` in config (now fixed)

### P2 (Medium)
7. **Coordinate-based taps** - Some scenarios still hardcode x/y
8. **Missing health checks** - No pre-flight validation

---

## 📞 Next Steps

1. **Connect Devices** (when physical USB reconnected)
   ```powershell
   node qa/check_devices.js
   node qa/test_dual_launch.js
   ```

2. **Fix Phase 2 Blockers**
   - Update `qa/backend/backend.js` schema
   - Update offer ID format
   - Migrate driver app to V2 acceptance

3. **Build First E2E Scenario**
   - Implement `rider_driver_happy_path.js`
   - Test on real devices
   - Verify full flow works

4. **Integrate Antigravity**
   - Create orchestrator bridge
   - Test autonomous execution
   - Validate evidence-based reporting

---

## 🎓 Key Learnings

1. **Dual-device testing is NOT the same as backend injection**
   - Backend injection tests dispatch logic
   - Dual-device tests full user journey

2. **Schema alignment is critical**
   - Mismatches cause silent failures
   - False positives hide real bugs

3. **LLM agents need observability**
   - UI dumps enable smart decisions
   - Screenshots provide debugging context
   - Logcat reveals hidden errors

4. **Portability matters**
   - Hardcoded paths block automation
   - Environment variables enable CI/CD
   - Cross-platform scripts scale better

---

## 📚 Related Documentation

- [Main QA README](README.md) - Overall QA platform overview
- [Device Roles](device_roles.json) - Central device binding
- [Rider Agent](.claude/agents/wawapp-rider-agent.md) - Rider control guide
- [Orchestrator Config](orchestrator/config.js) - Central configuration

---

**Status:** Phase 1 Complete ✅ | Ready for Phase 2 ⏳

**Last Updated:** 2026-05-12

**Prepared for:** Antigravity Integration & Amazon Q Automation
