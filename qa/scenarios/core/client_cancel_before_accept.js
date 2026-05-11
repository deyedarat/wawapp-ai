'use strict';
/**
 * SCENARIO: client_cancel_before_accept
 * Client cancels the order while the fullscreen is open on the driver device.
 * The driver must NOT be able to accept a cancelled order.
 * The fullscreen must dismiss.
 */
const Device   = require('../../orchestrator/device');
const Timeline = require('../../orchestrator/timeline');
const { Reporter } = require('../../orchestrator/reporter');
const B        = require('../../backend/backend');
const { prepareScenario } = require('../../orchestrator/watchdog');
const { sleep, waitFor } = require('../../orchestrator/utils');
const { driver: drvCfg, timing } = require('../../orchestrator/config');

const SCENARIO = 'client_cancel_before_accept';

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
      rep.recordPass('Fullscreen rendered before client cancel');
    } else {
      rep.recordFail('Fullscreen rendered before client cancel', { timeout: true });
    }

    // Client cancels WHILE fullscreen is open
    tl.emit('CLIENT_CANCEL_START', { orderId, device: 'backend' });
    await B.cancelOrder(orderId);
    tl.emit('CLIENT_CANCEL_DONE', { orderId, device: 'backend' });

    // Wait for Firestore listener to propagate cancellation to driver device
    await sleep(6_000);

    // Fullscreen should auto-dismiss
    const stillActive = dev.isFullscreenActive();
    if (!stillActive) {
      tl.emit('FULLSCREEN_DISMISSED', { orderId, device: 'driver' });
      rep.recordPass('Fullscreen dismissed after client cancellation');
    } else {
      rep.recordFail('Fullscreen dismissed after client cancellation', { stillActive: true });
    }

    // Verify order is cancelled
    const order = await B.inspectOrder(orderId);
    if (order?.status === 'cancelledByClient') {
      rep.recordPass('Order status is cancelledByClient');
    } else {
      rep.recordFail('Order status is cancelledByClient', { actual: order?.status });
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
