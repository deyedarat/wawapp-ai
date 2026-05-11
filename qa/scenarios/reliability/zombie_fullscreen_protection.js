'use strict';
/**
 * SCENARIO: zombie_fullscreen_protection (Refactored)
 *
 * Stage-Aware hardening applied. Differentiates CF cold start latency 
 * from actual app regression using the Pipeline tracer.
 */
const Device   = require('../../orchestrator/device');
const Timeline = require('../../orchestrator/timeline');
const { Reporter } = require('../../orchestrator/reporter');
const A        = require('../../orchestrator/assertions');
const B        = require('../../backend/backend');
const { prepareScenario } = require('../../orchestrator/watchdog');
const { waitForDispatchPipeline } = require('../../orchestrator/pipeline');
const { sleep } = require('../../orchestrator/utils');
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
    await prepareScenario(dev, B);

    // Create order
    const { orderId: oid } = await B.createOrder({ scenario: SCENARIO });
    orderId = oid;
    tl.emit('ORDER_CREATED', { orderId, device: 'backend' });

    dev.launchDriverApp();
    await sleep(timing.appBootWait);
    dev.tap(drvCfg.nearbyTabBounds.x, drvCfg.nearbyTabBounds.y);
    tl.emit('NEARBY_TAB_ACTIVATED', { orderId, device: 'driver' });
    await sleep(timing.listenerWait);

    // ── Stage-Aware Dispatch Trace ──
    // This replaces the previous blind 30s wait. Throws detailed PipelineError on timeout.
    let renderSuccess = false;
    try {
      await waitForDispatchPipeline({ orderId, dev, tl, rep });
      renderSuccess = true;
      tl.emit('FULLSCREEN_RENDERED', { orderId, device: 'driver' });
      rep.recordPass('Fullscreen rendered successfully before poison injection');
    } catch (e) {
      // Log the pipeline failure but continue logic check if classification allows
      console.log(`[Scenario] Pipeline tracking failed: ${e.stage} [${e.classification}]`);
      // If UI didn't render, we cannot proceed with the Zombie test.
      throw e; 
    }

    if (renderSuccess) {
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

      // After accept failure: fullscreen must be dismissed
      const zombieActive = dev.isFullscreenActive();
      if (!zombieActive) {
        tl.emit('ZOMBIE_DISMISSED', { orderId, device: 'driver' });
        rep.recordPass('Zombie fullscreen authority eliminated after accept failure');
      } else {
        tl.emit('ZOMBIE_DETECTED', { orderId, device: 'driver' });
        rep.recordFail('Zombie fullscreen authority eliminated after accept failure', {
          classification: 'APP_REGRESSION',
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
          rep.recordFail(e.assertion, { classification: 'APP_REGRESSION', evidence: e.evidence });
        } else {
          rep.recordFail('UI dump assertion', { classification: 'HARNESS_FLAKE', error: e.message });
        }
      }
    }

  } catch (err) {
    // Logged inside the reporter if it was a PipelineError
    console.error(`[Scenario Crash] ${err.message}`);
    if (!(err.stage)) {
       rep.recordFail('Scenario fatal crash', { error: err.message });
    }
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
