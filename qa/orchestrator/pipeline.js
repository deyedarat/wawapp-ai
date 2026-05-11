'use strict';
/**
 * Dispatch Pipeline Orchestrator & Analyzer
 * 
 * Instead of one blind aggregate wait for "fullscreen", this module executes 
 * a granular stage-aware tracking flow, verifying each micro-step of the backend->FCM->Android lifecycle.
 *
 * This differentiates between Cloud Function latency, backend defects, FCM lag, and UI render bugs.
 */
const B = require('../backend/backend');
const { sleep, waitFor } = require('./utils');
const { driver: drvCfg } = require('./config');

/**
 * Defines standardized dispatch pipeline failure classifications.
 */
const FailClass = {
  APP_REGRESSION: 'APP_REGRESSION',
  HARNESS_FLAKE: 'HARNESS_FLAKE',
  INFRASTRUCTURE_LATENCY: 'INFRASTRUCTURE_LATENCY',
  DEVICE_STATE_CONTAMINATION: 'DEVICE_STATE_CONTAMINATION',
  UNKNOWN_NEEDS_REPRO: 'UNKNOWN_NEEDS_REPRO'
};

/**
 * Comprehensive multi-stage wait for dispatch end-to-end.
 * 
 * @param {object} args
 * @param {string} args.orderId
 * @param {Device} args.dev
 * @param {Timeline} args.tl
 * @param {Reporter} args.rep
 * @returns {Promise<boolean>} true if success, throws Descriptive Error with classification on fail.
 */
async function waitForDispatchPipeline({ orderId, dev, tl, rep }) {
  const reportStep = (step, pass, detail) => {
    const sym = pass ? '✅' : '❌';
    console.log(`  [Pipeline] ${sym} ${step}`);
    if (tl) tl.emit(`PIPELINE_STEP_${step}`, { orderId, pass, ...detail });
  };

  try {
    console.log(`\n[Pipeline] --- Starting Stage-Aware Trace for ${orderId} ---`);
    
    // 1. Wait for Dispatch Offer Written (Cloud Function matching logic)
    try {
      console.log(`  [Pipeline] Awaiting dispatch injection to driver ${drvCfg.id}...`);
      await B.waitForOfferForOrder(orderId, drvCfg.id, 60_000); // Increased time for full matching
      reportStep('OFFER_WRITTEN', true);
    } catch (e) {
      reportStep('OFFER_WRITTEN', false, { error: e.message });
      throw new PipelineError('OFFER_NOT_WRITTEN', FailClass.INFRASTRUCTURE_LATENCY, 'Order was created but Cloud Functions failed to match/inject target Driver into dispatch_offers.');
    }

    // 2. Wait for Native FCM Log on Device
    console.log(`  [Pipeline] Waiting for Native FCM Receive logs on device...`);
    let fcmDetected = false;
    const fcmStart = Date.now();
    
    // Poll logcat for up to 45s for the FCM reception
    while (Date.now() - fcmStart < 45_000) {
      const logs = dev.getLogcat({ limit: 300 }); // last 300 lines
      const hasLog = logs.some(l => 
        (l.includes('Native FCM received') || l.includes('PUSH_RECEIVED')) && 
        l.includes(orderId)
      );
      if (hasLog) {
        fcmDetected = true;
        break;
      }
      await sleep(3000);
    }

    if (!fcmDetected) {
      reportStep('FCM_RECEIVED', false);
      throw new PipelineError('FCM_NOT_RECEIVED', FailClass.INFRASTRUCTURE_LATENCY, 'FCM transport layer failed to deliver the notification to the handset within time limit.');
    }
    reportStep('FCM_RECEIVED', true);

    // 4. Wait for Fullscreen Render / Topmost Activity state
    console.log(`  [Pipeline] FCM confirmed on device. Checking UI render...`);
    const renderDetected = await waitFor(
      () => dev.isFullscreenActive(),
      15_000, // Should be fast once FCM hits
      1000
    );

    if (!renderDetected) {
      reportStep('UI_RENDERED', false);
      
      // Deep Inspection: Did FCM Service suppress it?
      const finalLogs = dev.getLogcat({ limit: 500 });
      const suppressLog = finalLogs.find(l => l.includes('suppressing new offer') && l.includes(orderId));
      
      if (suppressLog) {
        throw new PipelineError('UI_NOT_RENDERED', FailClass.APP_REGRESSION, `App actively suppressed valid offer! Log: ${suppressLog}`);
      } else {
        throw new PipelineError('UI_NOT_RENDERED', FailClass.APP_REGRESSION, 'FCM arrived but UI Activity failed to launch or render foreground.');
      }
    }

    reportStep('UI_RENDERED', true);
    console.log(`[Pipeline] --- Complete: Valid E2E Delivery ---\n`);
    return true;

  } catch (err) {
    console.log(`\n[Pipeline] 🔴 PIPELINE FAILED: ${err.stage || 'FATAL'}\n`);
    if (err instanceof PipelineError) {
      // Auto-register failure with reporter
      if (rep) {
        rep.recordFail(`Pipeline stage failed: ${err.stage}`, {
          classification: err.classification,
          evidence: err.message,
          stage: err.stage
        });
      }
    }
    throw err; // bubble up to scenario runner
  }
}

class PipelineError extends Error {
  constructor(stage, classification, message) {
    super(message);
    this.stage = stage;
    this.classification = classification;
  }
}

module.exports = {
  waitForDispatchPipeline,
  FailClass,
  PipelineError
};
