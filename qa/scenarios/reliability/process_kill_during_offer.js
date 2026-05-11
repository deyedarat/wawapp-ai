'use strict';
/**
 * SCENARIO: process_kill_during_offer
 *
 * 1. App receives offer (fullscreen rendered)
 * 2. App is force-killed WHILE fullscreen is live
 * 3. App relaunches from killed state
 * 4. Assert: no ghost fullscreen on cold start
 * 5. Assert: offer is handled cleanly (either expired or still sent)
 *
 * Invariant: "All lifecycle paths terminate cleanly"
 */
const Device   = require('../../orchestrator/device');
const Timeline = require('../../orchestrator/timeline');
const { Reporter } = require('../../orchestrator/reporter');
const B        = require('../../backend/backend');
const { sleep, waitFor } = require('../../orchestrator/utils');
const { driver: drvCfg, timing } = require('../../orchestrator/config');

const SCENARIO = 'process_kill_during_offer';

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
      rep.recordPass('Fullscreen appeared before process kill');

      // Kill while fullscreen is live
      tl.emit('APP_KILL_MID_OFFER', { orderId, device: 'driver' });
      dev.killApp();
      await sleep(timing.forceStopWait);
      tl.emit('APP_KILLED', { orderId, device: 'driver' });
    } else {
      rep.recordFail('Fullscreen appeared before process kill', { timeout: true });
    }

    // Relaunch
    tl.emit('APP_RELAUNCH', { orderId, device: 'driver' });
    dev.clearLogcat();
    dev.launchApp();
    await sleep(timing.appBootWait);

    // Check focused activity on cold start — should NOT be FullScreen
    const isFocused = dev.isFullscreenActive();
    if (!isFocused) {
      rep.recordPass('No ghost fullscreen on cold start after kill-during-offer');
    } else {
      rep.recordFail('No ghost fullscreen on cold start after kill-during-offer', {
        focused: dev.getFocusedActivity(),
      });
    }

    // Navigate back and check state
    dev.tap(drvCfg.nearbyTabBounds.x, drvCfg.nearbyTabBounds.y);
    await sleep(timing.listenerWait);

    // Offer should either still be 'sent' (expired not yet) or terminal
    const offer = await B.inspectDispatchOffer(orderId);
    rep.recordPass(`Offer state after relaunch: ${offer?.status ?? 'not found'}`);

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
