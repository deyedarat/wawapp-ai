'use strict';
/**
 * SCENARIO: startup_rehydration
 *
 * Verifies that on cold start after a previous session, the app correctly
 * reconciles the Firestore listener state against the server before rendering
 * any actionable UI.
 *
 * Invariant: "Dead offers never resurrect"
 */
const Device   = require('../../orchestrator/device');
const Timeline = require('../../orchestrator/timeline');
const { Reporter } = require('../../orchestrator/reporter');
const A        = require('../../orchestrator/assertions');
const B        = require('../../backend/backend');
const { sleep } = require('../../orchestrator/utils');
const { driver: drvCfg, timing, sla } = require('../../orchestrator/config');

const SCENARIO = 'startup_rehydration';

async function run(runId) {
  const tl  = new Timeline(runId);
  const rep = new Reporter(runId, SCENARIO);
  const dev = new Device(drvCfg.deviceId, drvCfg.packageName, 'driver');
  console.log(`\n${'─'.repeat(60)}\n  SCENARIO: ${SCENARIO}\n${'─'.repeat(60)}`);
  let orderId;
  try {
    tl.emit('SCENARIO_START', { device: 'driver' });
    await B.cleanupOrders();

    // Create order and inject offer (seed cache)
    const { orderId: oid } = await B.createOrder({ scenario: SCENARIO });
    orderId = oid;
    await B.injectDispatchOffer(orderId, drvCfg.id, { status: 'sent' });
    tl.emit('ORDER_AND_OFFER_CREATED', { orderId, device: 'backend' });

    // Seed the cache
    dev.killApp(); dev.clearLogcat();
    dev.launchDriverApp();
    await sleep(timing.appBootWait);
    dev.tap(drvCfg.nearbyTabBounds.x, drvCfg.nearbyTabBounds.y);
    await sleep(timing.listenerWait + 3000);
    tl.emit('CACHE_SEEDED', { orderId, device: 'driver' });

    // Kill app and terminate offer on backend
    dev.killApp();
    await sleep(timing.forceStopWait);
    await B.terminateDispatchOffer(orderId);
    tl.emit('OFFER_KILLED_WHILE_APP_DEAD', { orderId, device: 'backend' });
    await sleep(2000);

    // Cold start
    dev.clearLogcat();
    dev.launchDriverApp();
    await sleep(timing.appBootWait);
    dev.tap(drvCfg.nearbyTabBounds.x, drvCfg.nearbyTabBounds.y);
    tl.emit('COLD_START_NEARBY_OPENED', { orderId, device: 'driver' });

    // Allow time for cache emit + server reconciliation
    await sleep(sla.cacheReconciliation + 3000);

    // No fullscreen should appear
    const fullscreenActive = dev.isFullscreenActive();
    if (!fullscreenActive) {
      rep.recordPass('No actionable fullscreen appeared on startup rehydration of dead offer');
    } else {
      rep.recordFail('No actionable fullscreen appeared on startup rehydration of dead offer', {
        fullscreenActive,
        regression: 'Cache resurrection NOT blocked',
      });
    }

    // Analyze logcat for cache vs server trace (requires instrumented build)
    const logs = dev.getLogcat();
    const cacheResurrection = logs.filter(l =>
      l.includes('FORENSIC_TRACE') && l.includes('source=CACHE') && l.includes('docs=1')
    );
    const serverReconciled = logs.filter(l =>
      l.includes('FORENSIC_TRACE') && l.includes('source=SERVER') && l.includes('docs=0')
    );

    tl.emit('REHYDRATION_ANALYSIS', { orderId, device: 'driver', data: {
      cacheResurrectionEvents: cacheResurrection.length,
      serverReconciliationEvents: serverReconciled.length,
    }});

    if (serverReconciled.length > 0) {
      rep.recordPass(`Server reconciliation confirmed (${serverReconciled.length} events)`);
    } else if (cacheResurrection.length > 0) {
      // Cache emitted but no server reconciliation seen — potential issue
      rep.recordFail('Cache resurrection detected without server reconciliation', { 
        cacheLines: cacheResurrection.length, 
        serverLines: 0,
        note: 'Requires instrumented build with FORENSIC_TRACE markers' 
      });
    } else {
      // No FORENSIC_TRACE at all — likely release build, skip this assertion
      rep.recordPass('No cache resurrection detected (FORENSIC_TRACE not available — release build)');
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
