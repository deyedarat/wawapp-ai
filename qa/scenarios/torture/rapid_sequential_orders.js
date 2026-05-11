'use strict';
/**
 * SCENARIO: rapid_sequential_orders (TORTURE)
 *
 * Create N orders in rapid succession. Each must be dispatched and handled.
 * No offer from a previous order may contaminate a subsequent one.
 * No zombie from a previous fullscreen may block the next.
 *
 * Invariant: "All lifecycle paths terminate cleanly"
 * Invariant: "Notification authority is singular"
 */
const Device   = require('../../orchestrator/device');
const Timeline = require('../../orchestrator/timeline');
const { Reporter } = require('../../orchestrator/reporter');
const B        = require('../../backend/backend');
const { sleep, waitFor } = require('../../orchestrator/utils');
const { driver: drvCfg, timing } = require('../../orchestrator/config');

const SCENARIO = 'rapid_sequential_orders';
const ORDER_COUNT = 3;  // Run 3 rapid orders

async function run(runId) {
  const tl  = new Timeline(runId);
  const rep = new Reporter(runId, SCENARIO);
  const dev = new Device(drvCfg.deviceId, drvCfg.packageName, 'driver');
  console.log(`\n${'─'.repeat(60)}\n  SCENARIO: ${SCENARIO} (N=${ORDER_COUNT})\n${'─'.repeat(60)}`);

  const orderIds = [];
  try {
    tl.emit('SCENARIO_START', { device: 'driver', data: { orderCount: ORDER_COUNT } });
    await B.cleanupOrders();
    dev.killApp(); dev.clearLogcat();
    dev.launchDriverApp();
    await sleep(timing.appBootWait);
    dev.tap(drvCfg.nearbyTabBounds.x, drvCfg.nearbyTabBounds.y);
    await sleep(timing.listenerWait);

    for (let i = 0; i < ORDER_COUNT; i++) {
      const label = `order_${i + 1}`;
      console.log(`\n  [Torture] Round ${i + 1}/${ORDER_COUNT}`);

      const { orderId } = await B.createOrder({ scenario: `rapid_${i}` });
      orderIds.push(orderId);
      tl.emit('ORDER_CREATED', { orderId, device: 'backend', data: { round: i + 1 } });

      // Wait for offer to appear
      const appeared = await waitFor(() => dev.isFullscreenActive(), 30_000, 1000);

      if (appeared) {
        tl.emit('FULLSCREEN_RENDERED', { orderId, device: 'driver', data: { round: i + 1 } });
        rep.recordPass(`Round ${i + 1}: Fullscreen rendered`);

        // Reject (so we can test next order without accepting)
        dev.tap(360, 1400);
        await sleep(5000);
      } else {
        rep.recordFail(`Round ${i + 1}: Fullscreen rendered`, { timeout: true, round: i + 1 });
      }

      // No zombie between rounds
      const zombie = dev.isFullscreenActive();
      if (!zombie) {
        rep.recordPass(`Round ${i + 1}: No zombie authority after reject`);
      } else {
        rep.recordFail(`Round ${i + 1}: No zombie authority after reject`, { zombie: true });
        // Kill the zombie to not block remaining rounds
        dev.pressBack();
        await sleep(2000);
      }

      tl.emit('ROUND_COMPLETE', { orderId, device: 'driver', data: { round: i + 1 } });
      await sleep(2000);  // brief gap between rounds
    }

    rep.recordPass(`Completed ${ORDER_COUNT} rapid sequential orders`);

  } catch (err) {
    rep.recordFail('Scenario completed without error', { error: err.message });
  } finally {
    tl.emit('SCENARIO_END', { device: 'driver', data: { orderIds } });
    tl.close();
    await B.cleanupOrders();
  }
  return rep.finalize(tl);
}

module.exports = { run, SCENARIO };
if (require.main === module) {
  const { runId: makeId } = require('../../orchestrator/utils');
  run(makeId('solo')).then(r => process.exit(r.passed ? 0 : 1));
}
