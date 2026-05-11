'use strict';
/**
 * ADB device control abstraction — hardened for unattended execution.
 * All shell commands are synchronous for determinism.
 * grep is not available on Windows — all filtering uses Node.js string ops.
 */
const { execSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

class Device {
  /**
   * @param {string} deviceId   - ADB serial (e.g. R83Y20PC4EN)
   * @param {string} packageName
   * @param {string} [label]    - 'driver' | 'rider'
   */
  constructor(deviceId, packageName, label = 'device') {
    this.deviceId    = deviceId;
    this.packageName = packageName;
    this.label       = label;
  }

  // ── Internal ──────────────────────────────────────────────────────────────
  _adb(args, opts = {}) {
    const cmd = `adb -s ${this.deviceId} ${args}`;
    try {
      const out = execSync(cmd, {
        encoding: 'utf8',
        timeout: opts.timeout || 30_000,
        stdio: ['pipe', 'pipe', 'pipe'],  // suppress stderr (adb pull progress noise)
      });
      return out.trim();
    } catch (err) {
      if (opts.ignoreError) return '';
      throw new Error(`[Device:${this.label}] ADB error: ${cmd}\n${err.message}`);
    }
  }

  _shell(cmd, opts = {}) {
    return this._adb(`shell "${cmd}"`, opts);
  }

  // ── App lifecycle ─────────────────────────────────────────────────────────
  /** Explicit wrapper enforcing correct role binding before execution */
  launchDriverApp() {
    if (this.packageName !== 'com.wawapp.driver') {
      throw new Error(`SECURITY_VIOLATION: Attempted to launch Driver app on non-driver device package: ${this.packageName}`);
    }
    return this.launchApp();
  }

  /** Explicit wrapper enforcing correct role binding before execution */
  launchRiderApp() {
    if (this.packageName !== 'com.wawapp.client') {
      throw new Error(`SECURITY_VIOLATION: Attempted to launch Rider app on non-rider device package: ${this.packageName}`);
    }
    return this.launchApp();
  }

  /**
   * Launch via am start — deterministic, no monkey stderr noise.
   * Falls back to monkey if am start fails (some OS versions restrict it).
   */
  launchApp() {
    try {
      this._adb(
        `shell am start -n ${this.packageName}/.MainActivity`,
        { ignoreError: false }
      );
    } catch (_) {
      // Fallback: monkey (suppress its chatty stdout via redirect)
      this._adb(
        `shell monkey -p ${this.packageName} -c android.intent.category.LAUNCHER 1`,
        { ignoreError: true }
      );
    }
  }

  killApp() {
    this._adb(`shell am force-stop ${this.packageName}`);
  }

  clearLogcat() {
    this._adb('logcat -c');
  }

  /**
   * Wake the screen and dismiss the lock screen.
   * Safe to call even if screen is already on.
   */
  wakeDevice() {
    // Send WAKEUP keyevent
    this._shell('input keyevent KEYCODE_WAKEUP', { ignoreError: true });
    // Swipe up to dismiss lock screen (works for swipe-only locks)
    this._shell('input swipe 360 800 360 400 300', { ignoreError: true });
    // Press MENU to ensure we are past lock screen
    this._shell('input keyevent 82', { ignoreError: true });
  }

  /**
   * Ensure device is awake and app state is clean before a scenario.
   * Call at the start of every scenario.
   */
  prepareForScenario() {
    this.wakeDevice();
    this.killApp();
    this.clearNotifications();
    this.clearLogcat();
  }

  /**
   * Cancel all active notifications for this package.
   */
  clearNotifications() {
    this._shell(
      `service call notification 1 i32 0`,
      { ignoreError: true }
    );
    // Also clear via cmd
    this._shell('cmd notification clear', { ignoreError: true });
  }

  // ── Screen control ────────────────────────────────────────────────────────
  lockScreen() {
    this._shell('input keyevent 26');   // KEYCODE_POWER
  }

  unlockScreen() {
    this._shell('input keyevent 26');   // wake
    this._shell('input keyevent 82');   // MENU / unlock
  }

  tap(x, y) {
    this._shell(`input tap ${x} ${y}`);
  }

  swipe(x1, y1, x2, y2, durationMs = 300) {
    this._shell(`input swipe ${x1} ${y1} ${x2} ${y2} ${durationMs}`);
  }

  pressBack() { this._shell('input keyevent 4'); }
  pressHome() { this._shell('input keyevent 3'); }

  // ── Network ───────────────────────────────────────────────────────────────
  setWifi(enable) {
    this._shell(`svc wifi ${enable ? 'enable' : 'disable'}`);
  }

  setData(enable) {
    this._shell(`svc data ${enable ? 'enable' : 'disable'}`);
  }

  setAirplaneMode(enable) {
    const val = enable ? '1' : '0';
    this._shell(`settings put global airplane_mode_on ${val}`);
    this._shell(`am broadcast -a android.intent.action.AIRPLANE_MODE --ez state ${enable}`);
  }

  goOffline() { this.setWifi(false); this.setData(false); }
  goOnline()  { this.setWifi(true);  this.setData(true);  }

  // ── Inspection ────────────────────────────────────────────────────────────
  dumpUI(localPath) {
    const remote = '/sdcard/qa_ui_dump.xml';
    this._shell(`uiautomator dump ${remote}`);
    this._adb(`pull ${remote} ${localPath}`);
    return fs.readFileSync(localPath, 'utf8');
  }

  screencap(localPath) {
    const remote = '/sdcard/qa_screencap.png';
    this._shell(`screencap -p ${remote}`);
    this._adb(`pull ${remote} ${localPath}`);
  }

  /**
   * Returns the currently focused/resumed activity string.
   * Uses Node string filtering (grep not available on Windows).
   */
  getFocusedActivity() {
    const raw = this._shell('dumpsys activity activities', { ignoreError: true });
    const lines = raw.split('\n');
    const resumed = lines.find(l => l.includes('mResumedActivity'));
    return (resumed || '').trim();
  }

  getNotifications() {
    // Returns raw dumpsys output for the notification manager
    return this._shell('dumpsys notification --noredact', { ignoreError: true });
  }

  /**
   * Read filtered logcat lines. JS filtering applied since shell grep fails on Windows.
   * @param {object} [opts] - options
   * @param {string} [opts.tag] - keyword/tag filter
   * @param {number} [opts.limit] - return last N lines
   * @returns {string[]}
   */
  getLogcat(opts = {}) {
    // -d dumps buffer. -t counts back from bottom.
    const tParam = opts.limit ? `-t ${opts.limit}` : '-d';
    const raw = this._adb(`logcat ${tParam}`, { ignoreError: true });
    let lines = raw.split('\n').filter(Boolean);
    
    if (opts.tag) {
      lines = lines.filter(l => l.includes(opts.tag));
    }
    return lines;
  }

  /** Returns true if the fullscreen notification activity is currently focused. */
  isFullscreenActive() {
    const focused = this.getFocusedActivity();
    return focused.includes('FullScreenNotificationActivity');
  }

  /** Returns true if any notification for this package is currently posted. */
  hasActiveNotification() {
    const notifs = this.getNotifications();
    return notifs.includes(this.packageName);
  }

  /** Returns true if app is in foreground. */
  isAppForegrounded() {
    const focused = this.getFocusedActivity();
    return focused.includes(this.packageName);
  }

  /** Pull logcat lines matching pattern, return them. */
  findLogLines(pattern) {
    const lines = this.getLogcat();
    return lines.filter(l => l.includes(pattern));
  }
}

module.exports = Device;
