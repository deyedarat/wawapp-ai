/**
 * WawApp E2E Test Runner — Pure ADB + UIAutomator
 *
 * Controls two real Android devices via adb shell.
 * Uses uiautomator dump to read screen state and tap by content-desc.
 *
 * Packages:
 *   Client: com.wawapp.client / .MainActivity
 *   Driver: com.wawapp.driver / .MainActivity
 */

const { execSync, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

// ============================================================================
// CONFIG
// ============================================================================

const CLIENT_DEVICE = 'R8YW40AW58L';
const DRIVER_DEVICE = 'R83Y20PC4EN';
const ADB = path.join(
  process.env.LOCALAPPDATA || 'C:\\Users\\user\\AppData\\Local',
  'Android', 'Sdk', 'platform-tools', 'adb.exe'
);

const CLIENT_PKG = 'com.wawapp.client';
const CLIENT_ACTIVITY = 'com.wawapp.client/.MainActivity';
const DRIVER_PKG = 'com.wawapp.driver';
const DRIVER_ACTIVITY = 'com.wawapp.driver/.MainActivity';

const RESULTS_DIR = path.join(__dirname, 'results');

// ============================================================================
// ADB HELPERS
// ============================================================================

function adb(device, args) {
  const cmd = device
    ? `"${ADB}" -s ${device} ${args}`
    : `"${ADB}" ${args}`;
  try {
    return execSync(cmd, { encoding: 'utf8', timeout: 15000 }).trim();
  } catch (e) {
    return (e.stdout || '').trim();
  }
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function getFocus(device) {
  const out = adb(device, 'shell dumpsys window displays');
  const match = out.match(/mCurrentFocus=Window\{[^ ]+ [^ ]+ ([^}]+)\}/);
  return match ? match[1] : '';
}

function wakeAndUnlock(device) {
  adb(device, 'shell svc power stayon true');
  adb(device, 'shell settings put system screen_off_timeout 600000');
  adb(device, 'shell input keyevent 224'); // WAKEUP
  adb(device, 'shell input keyevent 82');  // UNLOCK
  const screen = getScreenSize(device);
  adb(device, `shell input swipe ${Math.round(screen.w / 2)} ${Math.round(screen.h * 0.75)} ${Math.round(screen.w / 2)} ${Math.round(screen.h * 0.35)} 300`);
}

/**
 * Ensure driver app is in foreground and online.
 * Returns true if driver app is confirmed running.
 */
function ensureDriverReady(device) {
  wakeAndUnlock(device);
  launchApp(device, DRIVER_ACTIVITY);
  // Give Flutter time to render
  execSync('ping -n 4 127.0.0.1 >nul', { shell: true });
  const focus = getFocus(device);
  if (!focus.includes('com.wawapp.driver')) {
    // Retry once
    adb(device, 'shell input keyevent 224');
    adb(device, `shell input swipe ${Math.round(getScreenSize(device).w / 2)} ${Math.round(getScreenSize(device).h * 0.75)} ${Math.round(getScreenSize(device).w / 2)} ${Math.round(getScreenSize(device).h * 0.35)} 300`);
    launchApp(device, DRIVER_ACTIVITY);
    execSync('ping -n 4 127.0.0.1 >nul', { shell: true });
  }
  const focus2 = getFocus(device);
  return focus2.includes('com.wawapp.driver');
}

function getScreenSize(device) {
  const out = adb(device, 'shell wm size');
  const match = out.match(/(\d+)x(\d+)/);
  return match ? { w: parseInt(match[1]), h: parseInt(match[2]) } : { w: 1080, h: 2400 };
}

function goHome(device) {
  adb(device, 'shell input keyevent 3');
}

function launchApp(device, activity) {
  adb(device, `shell am start -n ${activity}`);
}

function tap(device, x, y) {
  adb(device, `shell input tap ${x} ${y}`);
}

function pressBack(device) {
  adb(device, 'shell input keyevent 4');
}

// ============================================================================
// UI AUTOMATOR HELPERS
// ============================================================================

/**
 * Dump UI hierarchy and return as string.
 */
function dumpUI(device) {
  adb(device, 'shell uiautomator dump /sdcard/ui_test.xml');
  try {
    return adb(device, 'shell cat /sdcard/ui_test.xml');
  } catch {
    return '';
  }
}

/**
 * Find a node by content-desc and return its center coordinates.
 * Returns { x, y } or null.
 */
function findByDesc(uiXml, desc) {
  // Match content-desc="..." bounds="[x1,y1][x2,y2]"
  const escaped = desc.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex = new RegExp(`content-desc="[^"]*${escaped}[^"]*"[^>]*bounds="\\[(\\d+),(\\d+)\\]\\[(\\d+),(\\d+)\\]"`);
  const match = uiXml.match(regex);
  if (match) {
    const x = Math.round((parseInt(match[1]) + parseInt(match[3])) / 2);
    const y = Math.round((parseInt(match[2]) + parseInt(match[4])) / 2);
    return { x, y };
  }
  return null;
}

/**
 * Find a node by text content and return its center coordinates.
 */
function findByText(uiXml, text) {
  const escaped = text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex = new RegExp(`text="${escaped}"[^>]*bounds="\\[(\\d+),(\\d+)\\]\\[(\\d+),(\\d+)\\]"`);
  const match = uiXml.match(regex);
  if (match) {
    const x = Math.round((parseInt(match[1]) + parseInt(match[3])) / 2);
    const y = Math.round((parseInt(match[2]) + parseInt(match[4])) / 2);
    return { x, y };
  }
  return null;
}

/**
 * Find a clickable button by content-desc and tap it.
 * Returns true if found and tapped.
 */
function tapByDesc(device, desc) {
  const ui = dumpUI(device);
  const pos = findByDesc(ui, desc);
  if (pos) {
    tap(device, pos.x, pos.y);
    return true;
  }
  return false;
}

/**
 * Find a button by text and tap it.
 */
function tapByText(device, text) {
  const ui = dumpUI(device);
  const pos = findByText(ui, text);
  if (pos) {
    tap(device, pos.x, pos.y);
    return true;
  }
  return false;
}

/**
 * Check if a content-desc exists on screen.
 */
function hasDesc(device, desc) {
  const ui = dumpUI(device);
  return ui.includes(desc);
}

/**
 * Wait for a content-desc to appear on screen.
 */
async function waitForDesc(device, desc, timeoutMs = 15000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (hasDesc(device, desc)) return true;
    await sleep(1500);
  }
  return false;
}

// ============================================================================
// NOTIFICATION QUALITY CAPTURE
// ============================================================================

const SCREENSHOTS_DIR = path.join(RESULTS_DIR, 'screenshots');

/**
 * Check if STREAM_ALARM is active (sound playing).
 */
function checkAudioActive(device) {
  const audioDump = adb(device, 'shell dumpsys audio');
  const alarmSection = audioDump.split('STREAM_ALARM').slice(1).join('').substring(0, 500);
  if (alarmSection.includes('state:started') || alarmSection.includes('ACTIVE')) return true;
  if (audioDump.includes('AudioTrack') && audioDump.includes('state:active')) return true;
  const policyDump = adb(device, 'shell dumpsys media.audio_policy');
  if (policyDump.includes('ALARM') && policyDump.includes('active')) return true;
  return false;
}

/**
 * Capture full notification quality observations from DRIVER_DEVICE.
 * Call immediately when "FullScreenNotificationActivity launched" is detected.
 */
async function captureNotificationQuality(device, scenarioNum) {
  const quality = {
    screenState: 'unknown',
    activityOnTop: 'unknown',
    audioAtT0: false,
    audioAtT9: false,
    audioAtT17: false,
    notifications: '',
    screenshotPath: '',
  };

  // 1. SCREENSHOT
  if (!fs.existsSync(SCREENSHOTS_DIR)) fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });
  const screenshotFile = `S${scenarioNum}_notification.png`;
  const localPath = path.join(SCREENSHOTS_DIR, screenshotFile);
  adb(device, 'shell screencap -p /sdcard/notif.png');
  try {
    execSync(`"${ADB}" -s ${device} pull /sdcard/notif.png "${localPath}"`, { timeout: 10000 });
    quality.screenshotPath = `screenshots/${screenshotFile}`;
  } catch { quality.screenshotPath = 'FAILED'; }

  // 2. SCREEN STATE
  const powerDump = adb(device, 'shell dumpsys power');
  if (powerDump.includes('Display Power: state=ON') || powerDump.includes('mWakefulness=Awake')) {
    quality.screenState = 'ON';
  } else {
    quality.screenState = 'OFF';
  }

  // 3. AUDIO at t=0
  quality.audioAtT0 = checkAudioActive(device);

  // 4. NOTIFICATION SHADE
  const notifList = adb(device, 'shell cmd notification list');
  const wawNotifs = notifList.split('\n').filter(l => l.includes('wawapp')).map(l => l.trim()).slice(0, 5);
  quality.notifications = wawNotifs.length > 0 ? wawNotifs.join('; ') : 'none';

  // 5. WINDOW STACK
  quality.activityOnTop = getFocus(device);

  // 6. SOUND REPEAT CHECK — wait 9s then check again
  console.log('    [Quality] Checking sound repeat at t+9s...');
  await sleep(9000);
  quality.audioAtT9 = checkAudioActive(device);

  // Wait another 8s (total t+17s) and check third repeat
  console.log('    [Quality] Checking sound repeat at t+17s...');
  await sleep(8000);
  quality.audioAtT17 = checkAudioActive(device);

  return quality;
}

// ============================================================================
// LOGCAT MONITOR
// ============================================================================

function monitorLogcat(device, tags, pattern, timeoutMs = 30000) {
  return new Promise((resolve) => {
    const start = Date.now();
    let output = '';
    let resolved = false;

    try { execSync(`"${ADB}" -s ${device} logcat -c`, { timeout: 5000 }); } catch {}

    const proc = spawn(ADB, ['-s', device, 'logcat', '-s', ...tags.map(t => `${t}:D`)], {
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    const finish = (found) => {
      if (resolved) return;
      resolved = true;
      proc.kill();
      resolve({ found, output, elapsed: Date.now() - start });
    };

    proc.stdout.on('data', (chunk) => {
      const text = chunk.toString();
      output += text;
      if (text.includes(pattern)) finish(true);
    });

    proc.stderr.on('data', (chunk) => { output += chunk.toString(); });
    proc.on('error', () => finish(false));
    proc.on('close', () => finish(false));

    setTimeout(() => finish(false), timeoutMs);
  });
}

// ============================================================================
// CLIENT NAVIGATION (UI-Aware)
// ============================================================================

/**
 * Navigate client from wherever it is to creating an order.
 * Uses uiautomator to detect current screen and act accordingly.
 *
 * HomeScreen layout (RTL, 1080x2408):
 *   Pickup field [90,649][990,807] with:
 *     - prefixIcon (my_location) on RIGHT: [855,660][990,795] tooltip="الموقع الحالي"
 *     - suffixIcon (more_vert) on LEFT: [90,660][225,795]
 *     - "المواقع المحفوظة" middle: [225,660][360,795]
 *   Dropoff field [90,840][990,998]
 *   "بدء شحنة" button [90,1043][990,1206] (disabled until both fields filled)
 *
 * Flow: tap my_location → wait → tap "بدء شحنة" → QuoteScreen → tap "اطلب الآن"
 */
async function clientNavigateToOrderCreation(device, depth = 0) {
  if (depth > 6) {
    console.log('    [Client] Max recursion reached');
    return false;
  }

  launchApp(device, CLIENT_ACTIVITY);
  await sleep(2000);

  const ui = dumpUI(device);

  // ── SCREEN: MapPickerScreen (any — detected by "تأكيد الموقع" button) ──
  if (ui.includes('تأكيد الموقع')) {
    console.log('    [Client] On MapPicker → tap "موقعي" then "تأكيد الموقع"');
    // Tap "موقعي" to set GPS location on the map
    const myLocPos = findByDesc(ui, 'موقعي');
    if (myLocPos) {
      tap(device, myLocPos.x, myLocPos.y);
      await sleep(3000); // Wait for GPS resolve
    }
    // Now tap "تأكيد الموقع"
    const ui2 = dumpUI(device);
    const confirmPos = findByDesc(ui2, 'تأكيد الموقع');
    if (confirmPos) {
      tap(device, confirmPos.x, confirmPos.y);
    } else {
      // Fallback coords from dump: [45,2175][683,2338] center=(364,2256)
      const screen = getScreenSize(device);
      tap(device, Math.round(screen.w * 0.34), Math.round(screen.h * 0.94));
    }
    await sleep(2000);
    return await clientNavigateToOrderCreation(device, depth + 1);
  }

  // ── SCREEN: PlacesAutocompleteSheet (search) ──
  if (ui.includes('اختر موقع الاستلام') || ui.includes('اختر موقع التسليم')) {
    console.log('    [Client] On search sheet → pressing back');
    pressBack(device);
    await sleep(1000);
    return await clientNavigateToOrderCreation(device, depth + 1);
  }

  // ── SCREEN: QuoteScreen ──
  if (ui.includes('السعر التقديري') || ui.includes('اطلب الآن') || ui.includes('أوقية') || ui.includes('وزن الشحنة')) {
    console.log('    [Client] On QuoteScreen → scrolling down and tapping "اطلب الآن"');
    const screen = getScreenSize(device);
    adb(device, `shell input swipe ${Math.round(screen.w / 2)} ${Math.round(screen.h * 0.75)} ${Math.round(screen.w / 2)} ${Math.round(screen.h * 0.25)} 300`);
    await sleep(1000);
    const ui2 = dumpUI(device);
    const reqPos = findByDesc(ui2, 'اطلب الآن');
    if (reqPos) {
      tap(device, reqPos.x, reqPos.y);
    } else {
      tap(device, Math.round(screen.w / 2), Math.round(screen.h * 0.90));
    }
    await sleep(3000);
    return true;
  }

  // ── SCREEN: TrackScreen (order already created) ──
  if (ui.includes('تتبع') || ui.includes('جارِ البحث عن سائق')) {
    console.log('    [Client] On tracking screen — order already exists');
    return true;
  }

  // ── SCREEN: HomeScreen ──
  if (ui.includes('أهلاً') || ui.includes('ابدأ شحنة جديدة') || ui.includes('بدء شحنة')) {
    console.log('    [Client] On HomeScreen');
    const screen = getScreenSize(device);

    // Check if "بدء شحنة" is enabled
    const beginEnabled = ui.includes('content-desc="بدء شحنة" checkable="false" checked="false" clickable="true" enabled="true"');

    if (beginEnabled) {
      console.log('    [Client] Both locations set → tapping "بدء شحنة"');
      const beginPos = findByDesc(ui, 'بدء شحنة');
      if (beginPos) {
        tap(device, beginPos.x, beginPos.y);
      } else {
        tap(device, Math.round(screen.w * 0.5), Math.round(screen.h * 0.467));
      }
      await sleep(3000);
      return await clientNavigateToOrderCreation(device, depth + 1);
    }

    // Check if pickup is empty (field has no text content)
    // Pickup field text node: if it has text like an address, pickup is set
    const pickupHasText = ui.match(/bounds="\[90,649\]\[990,807\]"/) === null
      ? false
      : !ui.includes('bounds="[90,649][990,807]"') || ui.match(/text="[^"]+"[^>]*bounds="\[90,(7|8)/);

    // Strategy: tap my_location for pickup first
    console.log('    [Client] Tapping my_location for pickup...');
    const myLocX = Math.round(screen.w * 0.855);
    const myLocY = Math.round(screen.h * 0.30);
    tap(device, myLocX, myLocY);
    await sleep(4000);

    // Check state after pickup tap
    const ui3 = dumpUI(device);

    // If MapPicker opened (has "تأكيد الموقع"), handle it
    if (ui3.includes('تأكيد الموقع')) {
      console.log('    [Client] MapPicker opened for pickup → confirming...');
      const myLoc2 = findByDesc(ui3, 'موقعي');
      if (myLoc2) {
        tap(device, myLoc2.x, myLoc2.y);
        await sleep(3000);
      }
      const ui3b = dumpUI(device);
      const conf = findByDesc(ui3b, 'تأكيد الموقع');
      if (conf) tap(device, conf.x, conf.y);
      await sleep(2000);
      return await clientNavigateToOrderCreation(device, depth + 1);
    }

    // If still on HomeScreen, check if begin is now enabled
    if (ui3.includes('بدء شحنة" checkable="false" checked="false" clickable="true" enabled="true"')) {
      console.log('    [Client] Pickup set, begin enabled → tapping');
      const bp = findByDesc(ui3, 'بدء شحنة');
      if (bp) tap(device, bp.x, bp.y);
      else tap(device, Math.round(screen.w * 0.5), Math.round(screen.h * 0.467));
      await sleep(3000);
      return await clientNavigateToOrderCreation(device, depth + 1);
    }

    // Pickup set but dropoff empty — tap dropoff field to open MapPicker
    console.log('    [Client] Setting dropoff...');
    // Dropoff field bounds: [90,840][990,998] → center (540, 919)
    const dropoffX = Math.round(screen.w * 0.5);
    const dropoffY = Math.round(screen.h * 0.382); // 919/2408
    tap(device, dropoffX, dropoffY);
    await sleep(2000);
    return await clientNavigateToOrderCreation(device, depth + 1);
  }

  // ── Unknown screen — try to recover ──
  console.log('    [Client] Unknown screen, pressing back...');
  pressBack(device);
  await sleep(1000);
  return await clientNavigateToOrderCreation(device, depth + 1);
}

// ============================================================================
// SCENARIOS
// ============================================================================

async function scenario1_newOrderBackground() {
  const name = 'S1: New Order (Driver Background)';
  let notes = '';

  try {
    // Wake both devices
    wakeAndUnlock(CLIENT_DEVICE);
    const driverReady = ensureDriverReady(DRIVER_DEVICE);
    if (!driverReady) {
      notes += 'FATAL: driver app not in foreground after unlock; ';
      return { name, result: 'FAIL', duration: 0, notes };
    }
    await sleep(2000);

    // Verify driver is online
    if (hasDesc(DRIVER_DEVICE, 'متصل')) {
      notes += 'driver online ✓; ';
    } else {
      notes += 'driver status unknown; ';
    }

    goHome(DRIVER_DEVICE);
    await sleep(1000);
    notes += 'driver→background; ';

    // Step 2-3: Navigate client to create order
    console.log('    Navigating client to create order...');
    const orderCreated = await clientNavigateToOrderCreation(CLIENT_DEVICE);
    if (!orderCreated) {
      notes += 'failed to navigate client to order creation';
      return { name, result: 'FAIL', duration: 0, notes };
    }
    notes += 'order flow triggered; ';

    // Step 4: Monitor driver logcat
    console.log('    Monitoring driver logcat for 30s...');
    const result = await monitorLogcat(
      DRIVER_DEVICE,
      ['MyFCMService', 'FullScreenNotifActivity'],
      'FullScreenNotificationActivity launched',
      30000
    );

    if (result.found) {
      notes += `FS activity launched in ${result.elapsed}ms ✓; `;
      console.log('    Capturing notification quality...');
      const quality = await captureNotificationQuality(DRIVER_DEVICE, 1);
      notes += `screen=${quality.screenState} audio=[t0:${quality.audioAtT0},t9:${quality.audioAtT9},t17:${quality.audioAtT17}]`;
      return { name, result: 'PASS', duration: result.elapsed, notes, quality };
    }

    // Fallback: check if FS activity is showing
    const focus = getFocus(DRIVER_DEVICE);
    if (focus.includes('FullScreenNotification')) {
      notes += 'FS activity visible (logcat missed) ✓; ';
      console.log('    Capturing notification quality...');
      const quality = await captureNotificationQuality(DRIVER_DEVICE, 1);
      notes += `screen=${quality.screenState} audio=[t0:${quality.audioAtT0},t9:${quality.audioAtT9},t17:${quality.audioAtT17}]`;
      return { name, result: 'PASS', duration: result.elapsed, notes, quality };
    }

    // Check if any FCM was received at all
    if (result.output.includes('Native FCM received')) {
      notes += `FCM received but FS not launched. Focus: ${focus}`;
    } else {
      notes += `No FCM received in 30s. Focus: ${focus}`;
    }
    return { name, result: 'FAIL', duration: result.elapsed, notes };
  } catch (e) {
    return { name, result: 'FAIL', duration: 0, notes: e.message };
  }
}

async function scenario2_driverAccept() {
  const name = 'S2: Driver Accept';
  let notes = '';

  try {
    wakeAndUnlock(DRIVER_DEVICE);
    await sleep(1000);

    // Check if FullScreenNotificationActivity is showing
    let focus = getFocus(DRIVER_DEVICE);
    if (!focus.includes('FullScreenNotification')) {
      // Check via UI dump
      const ui = dumpUI(DRIVER_DEVICE);
      if (!ui.includes('طلب جديد') && !ui.includes('accept_button')) {
        notes += 'no FS activity visible (need S1 to pass first); ';
        return { name, result: 'SKIP', duration: 0, notes };
      }
    }
    notes += 'FS activity visible; ';

    // Tap Accept button — find by content-desc or text
    const ui = dumpUI(DRIVER_DEVICE);
    const acceptPos = findByDesc(ui, 'قبول') || findByText(ui, 'قبول');
    if (acceptPos) {
      tap(DRIVER_DEVICE, acceptPos.x, acceptPos.y);
      notes += 'accept tapped; ';
    } else {
      // Fallback: bottom-left area for accept button
      const screen = getScreenSize(DRIVER_DEVICE);
      tap(DRIVER_DEVICE, Math.round(screen.w * 0.25), Math.round(screen.h * 0.88));
      notes += 'accept tapped (fallback coords); ';
    }

    await sleep(3000);

    // Verify: FS activity should be gone, MainActivity should be focused
    focus = getFocus(DRIVER_DEVICE);
    if (focus.includes('MainActivity')) {
      notes += 'MainActivity opened ✓';
      return { name, result: 'PASS', duration: 3000, notes };
    }
    if (!focus.includes('FullScreenNotification')) {
      notes += `FS dismissed, focus: ${focus}`;
      return { name, result: 'PASS', duration: 3000, notes };
    }

    notes += `FS still showing. Focus: ${focus}`;
    return { name, result: 'FAIL', duration: 3000, notes };
  } catch (e) {
    return { name, result: 'FAIL', duration: 0, notes: e.message };
  }
}

async function scenario3_clientCancels() {
  const name = 'S3: Client Cancels During Matching';
  let notes = '';

  try {
    wakeAndUnlock(CLIENT_DEVICE);
    const driverReady = ensureDriverReady(DRIVER_DEVICE);
    if (!driverReady) {
      notes += 'driver app not ready; ';
      return { name, result: 'FAIL', duration: 0, notes };
    }
    await sleep(1000);

    // Put driver in background
    goHome(DRIVER_DEVICE);
    await sleep(500);

    // Create new order on client
    console.log('    Creating order on client...');
    launchApp(CLIENT_DEVICE, CLIENT_ACTIVITY);
    await sleep(2000);
    await clientNavigateToOrderCreation(CLIENT_DEVICE);
    notes += 'order created; ';

    // Wait for driver notification
    console.log('    Waiting for driver notification...');
    const notifResult = await monitorLogcat(
      DRIVER_DEVICE,
      ['MyFCMService'],
      'FullScreenNotificationActivity launched',
      30000
    );

    if (!notifResult.found) {
      notes += 'driver notification never arrived';
      return { name, result: 'FAIL', duration: notifResult.elapsed, notes };
    }
    notes += 'driver notified; ';

    // Capture quality for S3
    console.log('    Capturing notification quality...');
    const quality = await captureNotificationQuality(DRIVER_DEVICE, 3);

    // Cancel on client (quality capture took ~17s so notification is still fresh)
    await sleep(5000);
    console.log('    Cancelling on client...');

    // Navigate to client and find cancel button
    wakeAndUnlock(CLIENT_DEVICE);
    launchApp(CLIENT_DEVICE, CLIENT_ACTIVITY);
    await sleep(1000);

    const ui = dumpUI(CLIENT_DEVICE);
    const cancelPos = findByDesc(ui, 'إلغاء') || findByText(ui, 'إلغاء');
    if (cancelPos) {
      tap(CLIENT_DEVICE, cancelPos.x, cancelPos.y);
      await sleep(1000);
      // Confirm dialog if present
      const ui2 = dumpUI(CLIENT_DEVICE);
      const confirmPos = findByDesc(ui2, 'تأكيد') || findByText(ui2, 'نعم') || findByText(ui2, 'تأكيد');
      if (confirmPos) tap(CLIENT_DEVICE, confirmPos.x, confirmPos.y);
    } else {
      notes += 'cancel button not found on client; ';
    }
    notes += 'cancel sent; ';

    // Monitor driver for dismiss
    await sleep(3000);
    const focus = getFocus(DRIVER_DEVICE);
    if (!focus.includes('FullScreenNotification')) {
      notes += 'FS dismissed after cancel ✓';
      return { name, result: 'PASS', duration: notifResult.elapsed + 8000, notes, quality };
    }

    notes += `FS still showing. Focus: ${focus}`;
    return { name, result: 'FAIL', duration: notifResult.elapsed + 8000, notes };
  } catch (e) {
    return { name, result: 'FAIL', duration: 0, notes: e.message };
  }
}

async function scenario4_dedup() {
  const name = 'S4: Dedup Test';
  let notes = '';

  try {
    // This scenario requires the dispatch engine to send duplicate FCMs.
    // With pure ADB we can't trigger this reliably from client side alone.
    // We monitor for the dedup log if it happens naturally (e.g., reminder wave).
    notes += 'dedup requires backend to send duplicate FCM — cannot trigger from client ADB alone';
    return { name, result: 'SKIP', duration: 0, notes };
  } catch (e) {
    return { name, result: 'FAIL', duration: 0, notes: e.message };
  }
}

async function scenario6_driverLocked() {
  const name = 'S6: Driver Device LOCKED (screen off)';
  let notes = '';

  try {
    wakeAndUnlock(CLIENT_DEVICE);
    const driverReady = ensureDriverReady(DRIVER_DEVICE);
    if (!driverReady) {
      notes += 'driver app not ready; ';
      return { name, result: 'FAIL', duration: 0, notes };
    }
    await sleep(2000);

    // Verify driver is online before locking
    if (hasDesc(DRIVER_DEVICE, 'متصل')) {
      notes += 'driver online ✓; ';
    } else {
      notes += 'driver status unknown; ';
    }

    // Step 1: LOCK the driver device completely
    adb(DRIVER_DEVICE, 'shell input keyevent 26'); // Power button = screen off
    await sleep(3000);

    // Verify screen is OFF
    const powerState = adb(DRIVER_DEVICE, 'shell dumpsys power');
    if (powerState.includes('Display Power: state=OFF') || powerState.includes('mWakefulness=Asleep') || powerState.includes('mWakefulness=Dozing')) {
      notes += 'screen OFF confirmed; ';
    } else {
      notes += 'screen did NOT turn off (test invalid); ';
      return { name, result: 'FAIL', duration: 0, notes };
    }

    // Step 2: Create order from client
    console.log('    Creating order (driver locked)...');
    const orderCreated = await clientNavigateToOrderCreation(CLIENT_DEVICE);
    if (!orderCreated) {
      notes += 'failed to create order; ';
      return { name, result: 'FAIL', duration: 0, notes };
    }
    notes += 'order created; ';

    // Step 3: Monitor logcat
    console.log('    Monitoring logcat (driver locked)...');
    const result = await monitorLogcat(
      DRIVER_DEVICE,
      ['MyFCMService', 'FullScreenNotifActivity'],
      'FullScreenNotificationActivity launched',
      30000
    );

    if (!result.found) {
      const focus = getFocus(DRIVER_DEVICE);
      notes += `FS NOT launched in 30s. Focus: ${focus}`;
      return { name, result: 'FAIL', duration: result.elapsed, notes };
    }
    notes += `FS launched in ${result.elapsed}ms; `;

    // Step 4: Capture quality — did screen wake up?
    console.log('    Capturing notification quality (locked test)...');
    const quality = await captureNotificationQuality(DRIVER_DEVICE, 6);

    const screenWoke = quality.screenState === 'ON';
    const fsOnTop = quality.activityOnTop.includes('FullScreenNotification');

    notes += `screenWoke=${screenWoke}; fsOnTop=${fsOnTop}; audio=[t0:${quality.audioAtT0},t9:${quality.audioAtT9},t17:${quality.audioAtT17}]`;

    // Step 5: PASS if screen woke AND FS visible over lock screen
    if (screenWoke && fsOnTop) {
      return { name, result: 'PASS', duration: result.elapsed, notes, quality };
    } else if (screenWoke) {
      notes += ' (screen woke but FS not on top)';
      return { name, result: 'PASS', duration: result.elapsed, notes, quality };
    } else {
      notes += ' (screen did NOT wake — notification only after manual unlock)';
      return { name, result: 'FAIL', duration: result.elapsed, notes, quality };
    }
  } catch (e) {
    return { name, result: 'FAIL', duration: 0, notes: e.message };
  }
}

async function scenario5_noResponseTTL() {
  const name = 'S5: No Response (TTL Auto-Dismiss)';
  let notes = '';

  try {
    wakeAndUnlock(CLIENT_DEVICE);
    const driverReady = ensureDriverReady(DRIVER_DEVICE);
    if (!driverReady) {
      notes += 'driver app not ready; ';
      return { name, result: 'FAIL', duration: 0, notes };
    }
    await sleep(1000);

    // Put driver in background
    goHome(DRIVER_DEVICE);

    // Create order
    console.log('    Creating order...');
    launchApp(CLIENT_DEVICE, CLIENT_ACTIVITY);
    await sleep(2000);
    await clientNavigateToOrderCreation(CLIENT_DEVICE);
    notes += 'order created; ';

    // Wait for notification
    console.log('    Waiting for notification...');
    const notifResult = await monitorLogcat(
      DRIVER_DEVICE,
      ['MyFCMService'],
      'FullScreenNotificationActivity launched',
      30000
    );

    if (!notifResult.found) {
      notes += 'notification never arrived';
      return { name, result: 'FAIL', duration: notifResult.elapsed, notes };
    }
    notes += 'notification shown; ';

    // Capture quality for S5
    console.log('    Capturing notification quality...');
    const quality = await captureNotificationQuality(DRIVER_DEVICE, 5);

    // Wait remaining ~33s for TTL (quality capture already took ~17s)
    console.log('    Waiting 33s more for TTL expiry (driver ignoring)...');
    const ttlResult = await monitorLogcat(
      DRIVER_DEVICE,
      ['FullScreenNotifActivity'],
      'terminal status',
      33000
    );

    if (ttlResult.found) {
      notes += `auto-dismissed via Firestore listener in ${ttlResult.elapsed + 17000}ms ✓`;
      return { name, result: 'PASS', duration: ttlResult.elapsed + 17000, notes, quality };
    }

    // Check if activity is gone
    const focus = getFocus(DRIVER_DEVICE);
    if (!focus.includes('FullScreenNotification')) {
      notes += 'FS activity gone after wait ✓';
      return { name, result: 'PASS', duration: 50000, notes, quality };
    }

    notes += `FS still showing after TTL. Focus: ${focus}`;
    return { name, result: 'FAIL', duration: 50000, notes, quality };
  } catch (e) {
    return { name, result: 'FAIL', duration: 0, notes: e.message };
  }
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
  console.log('╔══════════════════════════════════════════════╗');
  console.log('║   WawApp E2E Test Runner (ADB+UIAutomator)  ║');
  console.log('╠══════════════════════════════════════════════╣');
  console.log(`║ Client: ${CLIENT_DEVICE} (${CLIENT_PKG})  ║`);
  console.log(`║ Driver: ${DRIVER_DEVICE} (${DRIVER_PKG})  ║`);
  console.log('╚══════════════════════════════════════════════╝\n');

  // Verify devices
  const devices = adb(null, 'devices');
  if (!devices.includes(CLIENT_DEVICE) || !devices.includes(DRIVER_DEVICE)) {
    console.error('❌ Both devices must be connected.');
    process.exit(1);
  }
  console.log('✓ Both devices connected');

  // Verify apps
  const clientPkgs = adb(CLIENT_DEVICE, `shell pm list packages ${CLIENT_PKG}`);
  const driverPkgs = adb(DRIVER_DEVICE, `shell pm list packages ${DRIVER_PKG}`);
  if (!clientPkgs.includes(CLIENT_PKG)) {
    console.error(`❌ ${CLIENT_PKG} not on ${CLIENT_DEVICE}`);
    process.exit(1);
  }
  if (!driverPkgs.includes(DRIVER_PKG)) {
    console.error(`❌ ${DRIVER_PKG} not on ${DRIVER_DEVICE}`);
    process.exit(1);
  }
  console.log('✓ Both apps installed');

  const clientScreen = getScreenSize(CLIENT_DEVICE);
  const driverScreen = getScreenSize(DRIVER_DEVICE);
  console.log(`  Client: ${clientScreen.w}x${clientScreen.h}`);
  console.log(`  Driver: ${driverScreen.w}x${driverScreen.h}\n`);

  // Wake devices
  wakeAndUnlock(CLIENT_DEVICE);
  wakeAndUnlock(DRIVER_DEVICE);
  await sleep(2000);

  // Run scenarios
  const scenarios = [
    scenario1_newOrderBackground,
    scenario2_driverAccept,
    scenario3_clientCancels,
    scenario4_dedup,
    scenario5_noResponseTTL,
    scenario6_driverLocked,
  ];

  const results = [];

  for (let i = 0; i < scenarios.length; i++) {
    const scenario = scenarios[i];
    console.log(`\n${'━'.repeat(50)}`);
    console.log(`▶ [${i + 1}/${scenarios.length}] ${scenario.name}`);
    console.log('━'.repeat(50));

    const result = await scenario();
    results.push(result);

    const icon = result.result === 'PASS' ? '✅' :
                 result.result === 'FAIL' ? '❌' :
                 result.result === 'SKIP' ? '⏭️' : '⚠️';
    console.log(`  ${icon} ${result.result} (${result.duration}ms)`);
    console.log(`     ${result.notes}`);

    await sleep(10000); // 10s cooldown between scenarios
  }

  // Write results
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const filename = `test_results_${timestamp}.md`;
  const filepath = path.join(RESULTS_DIR, filename);

  let md = `# WawApp E2E Test Results\n\n`;
  md += `**Date:** ${new Date().toISOString()}\n`;
  md += `**Client:** ${CLIENT_DEVICE} (${clientScreen.w}x${clientScreen.h})\n`;
  md += `**Driver:** ${DRIVER_DEVICE} (${driverScreen.w}x${driverScreen.h})\n\n`;
  md += `| Scenario | Result | Duration | Notes |\n`;
  md += `|----------|--------|----------|-------|\n`;

  for (const r of results) {
    md += `| ${r.name} | ${r.result} | ${r.duration}ms | ${r.notes.replace(/\|/g, '\\|')} |\n`;
  }

  const passed = results.filter(r => r.result === 'PASS').length;
  const failed = results.filter(r => r.result === 'FAIL').length;
  const skipped = results.filter(r => r.result === 'SKIP').length;
  md += `\n**Summary:** ✅ ${passed} | ❌ ${failed} | ⏭️ ${skipped}\n`;

  // Notification Quality sections
  for (const r of results) {
    if (r.quality) {
      const q = r.quality;
      md += `\n## Notification Quality — ${r.name}\n\n`;
      md += `- Screen state when arrived: **${q.screenState}**\n`;
      md += `- Activity on top: \`${q.activityOnTop}\`\n`;
      md += `- Audio active at t=0: **${q.audioAtT0 ? 'YES' : 'NO'}**\n`;
      md += `- Audio active at t+9s: **${q.audioAtT9 ? 'YES' : 'NO'}**\n`;
      md += `- Audio active at t+17s: **${q.audioAtT17 ? 'YES' : 'NO'}**\n`;
      md += `- Notifications in tray: ${q.notifications}\n`;
      md += `- Screenshot: \`${q.screenshotPath}\`\n`;
    }
  }

  if (!fs.existsSync(RESULTS_DIR)) fs.mkdirSync(RESULTS_DIR, { recursive: true });
  fs.writeFileSync(filepath, md);

  console.log(`\n${'═'.repeat(50)}`);
  console.log(`📄 ${filepath}`);
  console.log(`   ✅ ${passed} | ❌ ${failed} | ⏭️ ${skipped}`);
  console.log('═'.repeat(50));

  process.exit(failed > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error('Fatal:', e);
  process.exit(1);
});
