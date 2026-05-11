'use strict';
/**
 * SCENARIO: dispatch_accept_success (Certified Dual-Device Edition)
 *
 * Full happy-path flow leveraging hard role binding and the stage-aware pipeline tracer.
 * Uses both Rider and Driver devices to guarantee environment isolation.
 */
const path     = require('path');
const fs       = require('fs');
const Device   = require('../../orchestrator/device');
const Timeline = require('../../orchestrator/timeline');
const { Reporter } = require('../../orchestrator/reporter');
const A        = require('../../orchestrator/assertions');
const B        = require('../../backend/backend');
const { prepareScenario } = require('../../orchestrator/watchdog');
const { waitForDispatchPipeline, FailClass } = require('../../orchestrator/pipeline');
const { sleep } = require('../../orchestrator/utils');
const { driver: drvCfg, rider: rdrCfg, timing, sla } = require('../../orchestrator/config');

const SCENARIO = 'dispatch_accept_success';

async function run(runId) {
  const tl  = new Timeline(runId);
  const rep = new Reporter(runId, SCENARIO);
  
  // Instantiate BOTH devices securely mapped to their respective configs
  const driverDev = new Device(drvCfg.deviceId, drvCfg.packageName, 'driver');
  const riderDev  = new Device(rdrCfg.deviceId, rdrCfg.packageName, 'rider');

  console.log(`\n${'═'.repeat(60)}\n  SCENARIO: ${SCENARIO} (DUAL-DEVICE MODE)\n${'═'.repeat(60)}`);

  let orderId;
  try {
    tl.emit('SCENARIO_START', { device: 'driver', data: { driver: drvCfg.deviceId, rider: rdrCfg.deviceId } });

    // 1. Role Proof-of-Isolation: Clean and prep BOTH devices
    console.log('[Dual-Device] Preparing both handsets for scenario isolaton...');
    await prepareScenario(driverDev, B);
    riderDev.prepareForScenario(); // wakes, kills client app, clears notifs

    // 2. Dynamically capture REAL device reported location to create zero-distance targeting
    console.log('[Dual-Device] Interrogating live spatial anchors...');
    const liveStat = await B.inspectDriverStatus(drvCfg.id);
    const realLat = liveStat.location?.lat || drvCfg.location.lat;
    const realLng = liveStat.location?.lng || drvCfg.location.lng;
    console.log(`[Dual-Device] Validated Targeting Center: (${realLat}, ${realLng})`);

    // 3. Launch Rider app to demonstrate live separation
    console.log(`[Dual-Device] Activating Rider application on device: ${rdrCfg.deviceId}`);
    tl.emit('RIDER_APP_LAUNCH', { device: 'rider' });
    riderDev.launchRiderApp(); 
    await sleep(3000);

    // 4. Backend Order Creation pinned EXACTLY to current driver GPS
    tl.emit('ORDER_CREATE_START', { device: 'backend' });
    const { orderId: oid } = await B.createOrder({ 
      scenario: SCENARIO, 
      lat: realLat, 
      lng: realLng 
    });
    orderId = oid;
    tl.emit('ORDER_CREATED', { orderId, device: 'backend' });

    // 4. Activate Driver listening post
    console.log(`[Dual-Device] Activating Driver application on device: ${drvCfg.deviceId}`);
    tl.emit('APP_LAUNCH', { orderId, device: 'driver' });
    driverDev.launchDriverApp(); // Hard-enforced method
    await sleep(timing.appBootWait);

    driverDev.tap(drvCfg.nearbyTabBounds.x, drvCfg.nearbyTabBounds.y);
    tl.emit('NEARBY_TAB_ACTIVATED', { orderId, device: 'driver' });
    await sleep(timing.listenerWait);

    // 5. ── Stage-Aware Dispatch Pipeline Tracer ──
    let pipelineCleared = false;
    try {
      await waitForDispatchPipeline({ orderId, dev: driverDev, tl, rep });
      pipelineCleared = true;
      tl.emit('FULLSCREEN_RENDERED', { orderId, device: 'driver' });
      rep.recordPass('End-to-End dispatch pipeline cleared all stages successfully');
    } catch (err) {
      // Classification and details already recorded inside the Pipeline wrapper
      console.log(`[Scenario] Dispatch pipeline stalled at stage: ${err.stage || 'UNKNOWN'}`);
      throw err;
    }

    // 6. Evidence Collection & Accept Interaction
    if (pipelineCleared) {
      const ssDir = path.join('qa/artifacts', runId);
      fs.mkdirSync(ssDir, { recursive: true });
      
      // Fetch UI mapping to dynamically click Accept
      const uiPath = path.join(ssDir, `${SCENARIO}_ui.xml`);
      let acceptX = 360, acceptY = 1300; // fallback defaults
      try {
        const xml = driverDev.dumpUI(uiPath);
        const match = xml.match(/content-desc="قبول"[^/]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/);
        if (match) {
          acceptX = Math.round((parseInt(match[1]) + parseInt(match[3])) / 2);
          acceptY = Math.round((parseInt(match[2]) + parseInt(match[4])) / 2);
          console.log(`  [ADB] UI Parser located Arabic 'Accept' button at (${acceptX}, ${acceptY})`);
        }
      } catch (_) {
         console.log('  [ADB] Falling back to standard device accept coordinates.');
      }

      // Click Accept
      tl.emit('ACCEPT_TAP', { orderId, device: 'driver', data: { x: acceptX, y: acceptY } });
      driverDev.tap(acceptX, acceptY);
      await sleep(timing.postAcceptWait);

      // 7. Backend and UI Verification post-accept
      const orderState = await B.inspectOrder(orderId);
      const status = orderState?.status;
      tl.emit('ORDER_INSPECT', { orderId, device: 'backend', data: { status } });

      if (status === 'accepted' || status === 'active_trip') {
        rep.recordPass('Firestore confirmed: Order transitioned correctly upon accept');
      } else {
        rep.recordFail('Order did not transition to accepted', {
          classification: 'ACCEPT_FAILED',
          actual: status
        });
      }

      // Confirm offer screen disappeared
      if (!driverDev.isFullscreenActive()) {
        rep.recordPass('Driver UI successfully transitioned off offer screen');
      } else {
        rep.recordFail('Offer UI persisted after accept click', {
          classification: 'UI_ZOMBIE',
          focused: driverDev.getFocusedActivity()
        });
      }

      // Verify SLA
      const latency = tl.delta('ORDER_CREATED', 'FULLSCREEN_RENDERED');
      rep.recordSLA('E2E Pipeline Latency', latency, sla.dispatchToFCM);
    }

  } catch (err) {
    console.error(`\n🔴 SCENARIO HALTED: ${err.message}\n`);
    if (!err.stage) {
      rep.recordFail('Scenario encountered unexpected crash', {
        classification: 'HARNESS_FLAKE',
        error: err.message
      });
    }
  } finally {
    console.log('[Dual-Device] Finalizing isolation clean-up...');
    driverDev.killApp();
    driverDev.clearNotifications();
    riderDev.killApp();
    
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
