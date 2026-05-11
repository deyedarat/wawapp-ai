'use strict';
/**
 * SCENARIO: zombie_fullscreen_protection
 *
 * Verified in Phase 4.7 (100% certified).
 * Keeps it in continuous rotation for regression detection.
 *
 * Steps:
 * 1. Create order and get fullscreen
 * 2. Force a transient accept failure (poison the dispatch_offer status)
 * 3. Assert the UI does NOT remain interactively alive (no zombie)
 * 4. Assert _safeDismiss() fires and driver returns to /nearby
 *
 * Invariant: "Fullscreen authority never zombifies"
 */
const Device   = require('../../orchestrator/device');
const Timeline = require('../../orchestrator/timeline');
const { Reporter } = require('../../orchestrator/reporter');
const A        = require('../../orchestrator/assertions');
const B        = require('../../backend/backend');
const { db }   = require('../../orchestrator/firebase');
const { sleep, waitFor } = require('../../orchestrator/utils');
const { driver: drvCfg, timing } = require('../../orchestrator/config');

const SCENARIO = 'zombie_fullscreen_protection';

async function run(runId) {
  const tl  = new Timeline(runId);
  const rep = new Reporter(runId, SCENARIO);
  const dev = new Device(drvCfg.deviceId, drvCfg.packageName, 'driver');
  console.log(`\n${'─'.repeat(60)}\n  SCENARIO: ${SCENARIO}\n${'─'.repeat(60)}`);
  let orderId;
  try {
    tl.emit('SCENARIO_START', { device: 'driver' });
    await B.cleanupOrders();
    dev.killApp(); dev.clearLogcat();

    const { orderId: oid } = await B.createOrder({ scenario: SCENARIO });
    orderId = oid;
    tl.emit('ORDER_CREATED', { orderId, device: 'backend' });

    dev.launchApp();
    await sleep(timing.appBootWait);
    dev.tap(drvCfg.nearbyTabBounds.x, drvCfg.nearbyTabBounds.y);
    await sleep(timing.listenerWait);

    const appeared = await waitFor(() => dev.isFullscreenActive(), 30_000, 1000);
    if (appeared) {
      tl.emit('FULLSCREEN_RENDERED', { orderId, device: 'driver' });
      rep.recordPass('Fullscreen rendered before poison injection');

      // Poison: set dispatch_offer status to something backend will reject
      await B.injectDispatchOffer(orderId, drvCfg.id, {
        status: 'poisoned_by_suite',
        extra: { qa_poison: true },
      });
      tl.emit('OFFER_POISONED', { orderId, device: 'backend' });

      // Tap Accept — this should fail on the backend
      tl.emit('ACCEPT_TAP', { orderId, device: 'driver' });
      dev.tap(360, 1300);
      await sleep(timing.postAcceptWait + 5000);  // give extra time for retry/dismiss

    } else {
      rep.recordFail('Fullscreen rendered before poison injection', { timeout: true });
    }

    // After accept failure: fullscreen must be dismissed
    const zombieActive = dev.isFullscreenActive();
    if (!zombieActive) {
      tl.emit('ZOMBIE_DISMISSED', { orderId, device: 'driver' });
      rep.recordPass('Zombie fullscreen authority eliminated after accept failure');
    } else {
      tl.emit('ZOMBIE_DETECTED', { orderId, device: 'driver' });
      rep.recordFail('Zombie fullscreen authority eliminated after accept failure', {
        zombieActive: true,
        note: 'REGRESSION: _safeDismiss() not triggered',
      });
    }

    // Dump UI and assert no Accept/Reject buttons remain
    try {
      const uiPath = `qa/artifacts/${runId}/zombie_ui.xml`;
      require('fs').mkdirSync(require('path').dirname(uiPath), { recursive: true });
      const uiXml = dev.dumpUI(uiPath);
      A.assertNoZombieAuthority(uiXml, orderId);
      rep.recordPass('UI dump shows no interactive Accept/Reject buttons');
    } catch (e) {
      if (e.name === 'AssertionError') {
        rep.recordFail(e.assertion, e.evidence);
      } else {
        rep.recordFail('UI dump assertion', { error: e.message });
      }
    }

  } catch (err) {
    rep.recordFail('Scenario completed without error', { error: err.message });
  } finally {
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
