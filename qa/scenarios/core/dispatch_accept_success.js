'use strict';
/**
 * SCENARIO: dispatch_accept_success  (hardened v2)
 *
 * Happy path — real order created, fullscreen rendered, driver accepts.
 * Asserts: order accepted, offer terminal, FCM SLA.
 *
 * Hardening:
 *  - prepareForScenario() ensures clean device state
 *  - fullscreenWaitMs=75s covers CF cold start + FCM + wake latency
 *  - am start used instead of monkey
 *  - getFocusedActivity uses Node string filtering (no grep)
 *  - watchdog in orchestrator prevents hangs
 */
const path     = require('path');
const fs       = require('fs');
const Device   = require('../../orchestrator/device');
const Timeline = require('../../orchestrator/timeline');
const { Reporter } = require('../../orchestrator/reporter');
const A        = require('../../orchestrator/assertions');
const B        = require('../../backend/backend');
const { prepareScenario } = require('../../orchestrator/watchdog');
const { sleep, waitFor } = require('../../orchestrator/utils');
const { driver: drvCfg, timing, sla } = require('../../orchestrator/config');

const SCENARIO = 'dispatch_accept_success';

async function run(runId) {
  const tl  = new Timeline(runId);
  const rep = new Reporter(runId, SCENARIO);
  const dev = new Device(drvCfg.deviceId, drvCfg.packageName, 'driver');

  console.log(`\n${'─'.repeat(60)}\n  SCENARIO: ${SCENARIO}\n${'─'.repeat(60)}`);

  let orderId;
  try {
    tl.emit('SCENARIO_START', { device: 'driver', data: { scenario: SCENARIO } });

    // ── Clean state ────────────────────────────────────────────────────────
    await prepareScenario(dev, B);
    await sleep(timing.notifClearWait);

    // ── Create order ───────────────────────────────────────────────────────
    tl.emit('ORDER_CREATE_START', { device: 'backend' });
    const { orderId: oid } = await B.createOrder({ scenario: SCENARIO });
    orderId = oid;
    tl.emit('ORDER_CREATED', { orderId, device: 'backend' });

    // ── Launch driver app ──────────────────────────────────────────────────
    tl.emit('APP_LAUNCH', { orderId, device: 'driver' });
    dev.launchApp();
    await sleep(timing.appBootWait);

    // Navigate to Nearby tab to activate Firestore listener
    dev.tap(drvCfg.nearbyTabBounds.x, drvCfg.nearbyTabBounds.y);
    tl.emit('NEARBY_TAB_ACTIVATED', { orderId, device: 'driver' });
    await sleep(timing.listenerWait);

    // ── Wait for fullscreen notification (75s covers CF cold start + FCM) ──
    tl.emit('WAITING_FOR_FULLSCREEN', { orderId, device: 'driver' });
    const fullscreenAppeared = await waitFor(
      () => dev.isFullscreenActive(),
      timing.fullscreenWaitMs,
      1500
    );

    if (fullscreenAppeared) {
      tl.emit('FULLSCREEN_RENDERED', { orderId, device: 'driver' });
      rep.recordPass('Fullscreen notification rendered');

      // Screenshot at fullscreen
      const ssDir = path.join('qa/artifacts', runId);
      fs.mkdirSync(ssDir, { recursive: true });
      const ssPath = path.join(ssDir, `${SCENARIO}_fullscreen.png`);
      dev.screencap(ssPath);
      rep.registerScreenshot(ssPath, 'Fullscreen notification');

      // ── Accept ─────────────────────────────────────────────────────────
      // Use dynamic coordinate from current UI dump
      const uiPath = path.join(ssDir, `${SCENARIO}_ui.xml`);
      let acceptX = 360, acceptY = 1300;
      try {
        const xml = dev.dumpUI(uiPath);
        // Look for the Accept button content-desc (Arabic: قبول)
        const match = xml.match(/content-desc="قبول"[^/]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/);
        if (match) {
          acceptX = Math.round((parseInt(match[1]) + parseInt(match[3])) / 2);
          acceptY = Math.round((parseInt(match[2]) + parseInt(match[4])) / 2);
          console.log(`  [ADB] Accept button detected at (${acceptX}, ${acceptY})`);
        }
      } catch (_) { /* fall back to default coords */ }

      tl.emit('ACCEPT_TAP', { orderId, device: 'driver', data: { x: acceptX, y: acceptY } });
      dev.tap(acceptX, acceptY);
      await sleep(timing.postAcceptWait);
      tl.emit('ACCEPT_TAP_DONE', { orderId, device: 'driver' });

    } else {
      tl.emit('FULLSCREEN_TIMEOUT', { orderId, device: 'driver',
        data: { waitedMs: timing.fullscreenWaitMs } });
      rep.recordFail('Fullscreen notification rendered within 75s', {
        waitedMs: timing.fullscreenWaitMs,
        focused: dev.getFocusedActivity(),
      });
    }

    // ── Verify Firestore ───────────────────────────────────────────────────
    const orderState = await B.inspectOrder(orderId);
    const status = orderState?.status;
    tl.emit('ORDER_INSPECT', { orderId, device: 'backend', data: { status } });

    if (status === 'accepted') {
      tl.emit('ORDER_ACCEPTED', { orderId, device: 'backend' });
      rep.recordPass('Order transitioned to accepted in Firestore');
    } else {
      rep.recordFail('Order transitioned to accepted', { actual: status });
    }

    // Offer terminal
    const offer = await B.inspectDispatchOffer(orderId);
    const terminal = ['accepted', 'rejected', 'expired', 'cancelled'];
    const offerTerminal = !offer || terminal.includes(offer.status);
    if (offerTerminal) {
      rep.recordPass('Dispatch offer is in terminal state');
    } else {
      rep.recordFail('Dispatch offer is in terminal state', { status: offer?.status });
    }

    // ── SLA ────────────────────────────────────────────────────────────────
    const latency = tl.delta('ORDER_CREATED', 'FULLSCREEN_RENDERED');
    rep.recordSLA('ORDER_CREATED → FULLSCREEN_RENDERED', latency, sla.dispatchToFCM);
    if (latency !== null && latency <= sla.dispatchToFCM) {
      rep.recordPass(`Dispatch SLA within ${sla.dispatchToFCM}ms (actual: ${latency}ms)`);
    } else {
      rep.recordFail(`Dispatch SLA within ${sla.dispatchToFCM}ms`, { actual: latency });
    }

  } catch (err) {
    tl.emit('SCENARIO_ERROR', { orderId, data: { error: err.message } });
    rep.recordFail('Scenario completed without uncaught error', { error: err.message });
    console.error(`[${SCENARIO}] Fatal:`, err.message);
  } finally {
    // Post-scenario: kill app and clear notifications so next scenario starts clean
    dev.killApp();
    dev.clearNotifications();
    tl.emit('SCENARIO_END', { orderId });
    tl.close();
  }

  return rep.finalize(tl);
}

module.exports = { run, SCENARIO };
if (require.main === module) {
  const { runId: makeId } = require('../../orchestrator/utils');
  run(makeId('solo')).then(r => process.exit(r.passed ? 0 : 1));
}
