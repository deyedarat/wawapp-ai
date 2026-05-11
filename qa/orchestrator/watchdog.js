'use strict';
/**
 * Scenario runner wrapper with watchdog timeout.
 * Every scenario is wrapped here so a hung scenario never blocks the suite.
 *
 * Also provides the standardized pre-scenario device preparation.
 */
const { sleep } = require('./utils');

const SCENARIO_TIMEOUT_MS = 5 * 60 * 1000;  // 5 minutes hard wall clock

/**
 * Run a scenario with a watchdog timeout.
 * If the scenario hangs beyond SCENARIO_TIMEOUT_MS, it is killed and marked FAIL.
 *
 * @param {Function} scenarioFn  - async (runId) => { passed, result }
 * @param {string}   name
 * @param {string}   runId
 * @returns {{ passed: boolean, result: object }}
 */
async function runWithWatchdog(scenarioFn, name, runId) {
  let timedOut = false;

  const timeout = new Promise((_, reject) =>
    setTimeout(() => {
      timedOut = true;
      reject(new Error(`WATCHDOG: scenario "${name}" exceeded ${SCENARIO_TIMEOUT_MS / 1000}s`));
    }, SCENARIO_TIMEOUT_MS)
  );

  try {
    const result = await Promise.race([scenarioFn(runId), timeout]);
    return result;
  } catch (err) {
    const msg = timedOut
      ? `⏱️  WATCHDOG TIMEOUT after ${SCENARIO_TIMEOUT_MS / 1000}s`
      : err.message;
    console.error(`[Watchdog] ${name}: ${msg}`);
    return {
      passed: false,
      result: {
        scenario: name,
        verdict: 'FAIL',
        passed: false,
        durationMs: SCENARIO_TIMEOUT_MS,
        failures: [{ label: msg, evidence: { timedOut } }],
        slaMetrics: [],
        screenshots: [],
        timelineFile: null,
      },
    };
  }
}

/**
 * Standard pre-scenario device reset sequence.
 * @param {Device} dev
 * @param {object} backend
 */
async function prepareScenario(dev, backend) {
  // Clear backend state first
  await backend.cleanupOrders();

  // Ensure driver is online and location fresh
  const { injectDriverLocation } = require('../backend/backend');
  await injectDriverLocation();

  // Prepare device: wake, kill app, clear notifications, clear logcat
  dev.prepareForScenario();

  // Brief settle time after kill
  await sleep(1500);
}

module.exports = { runWithWatchdog, prepareScenario, SCENARIO_TIMEOUT_MS };
