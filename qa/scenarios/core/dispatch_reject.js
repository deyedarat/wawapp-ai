'use strict';
/**
 * SCENARIO: dispatch_reject
 *
 * Driver receives a fullscreen notification and taps Reject.
 * Order must NOT transition to 'accepted'.
 * The fullscreen UI must dismiss cleanly.
 */
const path   = require('path');
const Device  = require('../../orchestrator/device');
const Timeline = require('../../orchestrator/timeline');
const { Reporter } = require('../../orchestrator/reporter');
const A       = require('../../orchestrator/assertions');
const B       = require('../../backend/backend');
const { prepareScenario } = require('../../orchestrator/watchdog');
const { sleep, waitFor } = require('../../orchestrator/utils');
const { driver: drvCfg, timing, sla } = require('../../orchestrator/config');

const SCENARIO = 'dispatch_reject';

async function run(runId) {
  const tl  = new Timeline(runId);
  const rep = new Reporter(runId, SCENARIO);
  const dev = new Device(drvCfg.deviceId, drvCfg.packageName, 'driver');

  console.log(`\n${'─'.repeat(60)}\n  SCENARIO: ${SCENARIO}\n${'─'.repeat(60)}`);

  let orderId;
  try {
    tl.emit('SCENARIO_START', { device: 'driver', data: { scenario: SCENARIO } });
    await prepareScenario(dev, B);
    await sleep(timing.notifClearWait);

    const { orderId: oid } = await B.createOrder({ scenario: SCENARIO });
    orderId = oid;
    tl.emit('ORDER_CREATED', { orderId, device: 'backend' });

    dev.launchDriverApp();
    await sleep(timing.appBootWait);
    dev.tap(drvCfg.nearbyTabBounds.x, drvCfg.nearbyTabBounds.y);
    tl.emit('NEARBY_TAB_ACTIVATED', { orderId, device: 'driver' });
    await sleep(timing.listenerWait);

    const appeared = await waitFor(
      () => dev.isFullscreenActive(),
      timing.fullscreenWaitMs,
      1500
    );
    if (appeared) {
      tl.emit('FULLSCREEN_RENDERED', { orderId, device: 'driver' });
      rep.recordPass('Fullscreen rendered for reject scenario');
      tl.emit('REJECT_TAP', { orderId, device: 'driver' });
      dev.tap(360, 1400);
      await sleep(timing.postAcceptWait);
      tl.emit('REJECT_TAP_DONE', { orderId, device: 'driver' });
    } else {
      rep.recordFail('Fullscreen rendered within 75s', { timeout: true });
    }

    // Fullscreen must be gone
    const stillFullscreen = dev.isFullscreenActive();
    if (!stillFullscreen) {
      rep.recordPass('Fullscreen dismissed after reject');
    } else {
      rep.recordFail('Fullscreen dismissed after reject', { stillActive: true });
    }

    // Order should NOT be accepted
    const order = await B.inspectOrder(orderId);
    const notAccepted = order?.status !== 'accepted';
    if (notAccepted) {
      rep.recordPass('Order not accepted after driver reject');
    } else {
      rep.recordFail('Order not accepted after driver reject', { status: order?.status });
    }

    const dispatchLatency = tl.delta('ORDER_CREATED', 'FULLSCREEN_RENDERED');
    rep.recordSLA('ORDER_CREATED → FULLSCREEN_RENDERED', dispatchLatency, sla.dispatchToFCM);

  } catch (err) {
    tl.emit('SCENARIO_ERROR', { orderId, data: { error: err.message } });
    rep.recordFail('Scenario completed without error', { error: err.message });
  } finally {
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
