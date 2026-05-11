'use strict';
/**
 * SCENARIO: app_kill_mid_dispatch (TORTURE)
 *
 * Kill the app at 3 critical points in the dispatch pipeline:
 *   T1: After order created, before FCM arrives
 *   T2: After FCM arrives, before fullscreen opens
 *   T3: After fullscreen opens, before driver taps Accept
 *
 * Each must recover cleanly on relaunch without ghost UIs.
 */
const Device   = require('../../orchestrator/device');
const Timeline = require('../../orchestrator/timeline');
const { Reporter } = require('../../orchestrator/reporter');
const B        = require('../../backend/backend');
const { sleep, waitFor } = require('../../orchestrator/utils');
const { driver: drvCfg, timing } = require('../../orchestrator/config');

const SCENARIO = 'app_kill_mid_dispatch';

async function runKillPoint(dev, tl, label, killAfterMs) {
  const { orderId } = await B.createOrder({ scenario: `kill_${label}` });
  tl.emit('ORDER_CREATED', { orderId, device: 'backend', data: { killPoint: label } });

  dev.killApp(); dev.clearLogcat();
  dev.launchDriverApp();
  await sleep(timing.appBootWait);
  dev.tap(drvCfg.nearbyTabBounds.x, drvCfg.nearbyTabBounds.y);
  await sleep(killAfterMs);  // wait to the kill point

  tl.emit('APP_KILL_AT', { orderId, device: 'driver', data: { label } });
  dev.killApp();
  await sleep(timing.forceStopWait);

  // Relaunch
  dev.launchDriverApp();
  await sleep(timing.appBootWait);

  const ghostFullscreen = dev.isFullscreenActive();
  return { orderId, ghostFullscreen, label };
}

async function run(runId) {
  const tl  = new Timeline(runId);
  const rep = new Reporter(runId, SCENARIO);
  const dev = new Device(drvCfg.deviceId, drvCfg.packageName, 'driver');
  console.log(`\n${'─'.repeat(60)}\n  SCENARIO: ${SCENARIO}\n${'─'.repeat(60)}`);

  try {
    tl.emit('SCENARIO_START', { device: 'driver' });
    await B.cleanupOrders();

    const killPoints = [
      { label: 'T1_before_fcm',      killAfterMs: 3_000  },
      { label: 'T2_after_fcm',       killAfterMs: 15_000 },
      { label: 'T3_fullscreen_open', killAfterMs: 20_000 },
    ];

    for (const kp of killPoints) {
      const { orderId, ghostFullscreen, label } = await runKillPoint(
        dev, tl, kp.label, kp.killAfterMs
      );
      if (!ghostFullscreen) {
        rep.recordPass(`${label}: No ghost fullscreen after kill + relaunch`);
      } else {
        rep.recordFail(`${label}: No ghost fullscreen after kill + relaunch`, { ghost: true, orderId });
      }
      await sleep(3000);
      await B.cleanupOrders();
    }

  } catch (err) {
    rep.recordFail('Scenario completed without error', { error: err.message });
  } finally {
    tl.emit('SCENARIO_END', {});
    tl.close();
  }
  return rep.finalize(tl);
}

module.exports = { run, SCENARIO };
if (require.main === module) {
  const { runId: makeId } = require('../../orchestrator/utils');
  run(makeId('solo')).then(r => process.exit(r.passed ? 0 : 1));
}
