'use strict';
/**
 * SCENARIO: dispatch_timeout
 *
 * An order is created. Driver receives fullscreen notification.
 * Driver does NOT interact. Backend expires the order.
 * Fullscreen must auto-dismiss or at least offer is in terminal state.
 */
const Device   = require('../../orchestrator/device');
const Timeline = require('../../orchestrator/timeline');
const { Reporter } = require('../../orchestrator/reporter');
const B        = require('../../backend/backend');
const { prepareScenario } = require('../../orchestrator/watchdog');
const { sleep, waitFor } = require('../../orchestrator/utils');
const { driver: drvCfg, timing } = require('../../orchestrator/config');

const SCENARIO = 'dispatch_timeout';

async function run(runId) {
  const tl  = new Timeline(runId);
  const rep = new Reporter(runId, SCENARIO);
  const dev = new Device(drvCfg.deviceId, drvCfg.packageName, 'driver');
  console.log(`\n${'─'.repeat(60)}\n  SCENARIO: ${SCENARIO}\n${'─'.repeat(60)}`);
  let orderId;
  try {
    tl.emit('SCENARIO_START', { device: 'driver' });
    await prepareScenario(dev, B);
    await sleep(timing.notifClearWait);

    const { orderId: oid } = await B.createOrder({ scenario: SCENARIO });
    orderId = oid;
    tl.emit('ORDER_CREATED', { orderId, device: 'backend' });

    dev.launchDriverApp();
    await sleep(timing.appBootWait);
    dev.tap(drvCfg.nearbyTabBounds.x, drvCfg.nearbyTabBounds.y);
    await sleep(timing.listenerWait);

    const appeared = await waitFor(
      () => dev.isFullscreenActive(),
      timing.fullscreenWaitMs,
      1500
    );
    if (appeared) {
      tl.emit('FULLSCREEN_RENDERED', { orderId, device: 'driver' });
      rep.recordPass('Fullscreen rendered before timeout');
    } else {
      rep.recordFail('Fullscreen rendered before timeout', { timeout: true });
    }

    // Expire on the backend (simulate timeout)
    tl.emit('ORDER_EXPIRE_START', { orderId, device: 'backend' });
    await B.expireOrder(orderId);
    tl.emit('ORDER_EXPIRED', { orderId, device: 'backend' });

    // Wait for fullscreen to auto-dismiss
    await sleep(8_000);
    const stillFullscreen = dev.isFullscreenActive();
    if (!stillFullscreen) {
      tl.emit('FULLSCREEN_DISMISSED', { orderId, device: 'driver' });
      rep.recordPass('Fullscreen auto-dismissed after order expiry');
    } else {
      rep.recordFail('Fullscreen auto-dismissed after order expiry', { stillActive: true });
    }

    // Verify offer terminal state
    const offer = await B.inspectDispatchOffer(orderId);
    const terminalStates = ['expired', 'accepted', 'rejected', 'cancelled'];
    const isTerminal = !offer || terminalStates.includes(offer.status);
    if (isTerminal) {
      rep.recordPass('Offer is in terminal state after timeout');
    } else {
      rep.recordFail('Offer is in terminal state after timeout', { status: offer?.status });
    }

  } catch (err) {
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
