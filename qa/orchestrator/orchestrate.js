'use strict';
/**
 * WawApp Dispatch Reliability Orchestrator
 * Master entry point — runs all scenarios and produces the certification report.
 *
 * Usage:
 *   node qa/orchestrator/orchestrate.js [--suite regression|torture|all]
 */
const { runId: makeId } = require('./utils');
const { writeCertificationReport } = require('./reporter');

// ── Scenario registry ─────────────────────────────────────────────────────────

const CORE_SCENARIOS = [
  require('../scenarios/core/dispatch_accept_success'),
  require('../scenarios/core/dispatch_reject'),
  require('../scenarios/core/dispatch_timeout'),
  require('../scenarios/core/client_cancel_before_accept'),
];

const RELIABILITY_SCENARIOS = [
  require('../scenarios/reliability/stale_cache_resurrection'),
  require('../scenarios/reliability/zombie_fullscreen_protection'),
  require('../scenarios/reliability/process_kill_during_offer'),
  require('../scenarios/reliability/duplicate_accept_guard'),
  require('../scenarios/reliability/startup_rehydration'),
];

const TORTURE_SCENARIOS = [
  require('../scenarios/torture/rapid_sequential_orders'),
  require('../scenarios/torture/app_kill_mid_dispatch'),
];

const SUITE_MAP = {
  core:        CORE_SCENARIOS,
  reliability: RELIABILITY_SCENARIOS,
  regression:  [...CORE_SCENARIOS, ...RELIABILITY_SCENARIOS],
  torture:     TORTURE_SCENARIOS,
  all:         [...CORE_SCENARIOS, ...RELIABILITY_SCENARIOS, ...TORTURE_SCENARIOS],
};

// ── Run ────────────────────────────────────────────────────────────────────────

async function main() {
  const suiteArg = process.argv.includes('--suite')
    ? process.argv[process.argv.indexOf('--suite') + 1]
    : 'regression';

  const suite = SUITE_MAP[suiteArg] || SUITE_MAP.regression;
  const id = makeId(suiteArg);

  console.log(`\n${'═'.repeat(60)}`);
  console.log(`  WawApp Dispatch Reliability Platform`);
  console.log(`  Suite: ${suiteArg.toUpperCase()}  |  Run: ${id}`);
  console.log(`  Scenarios: ${suite.length}`);
  console.log(`${'═'.repeat(60)}\n`);

  const results = [];
  const { runWithWatchdog } = require('./watchdog');
  const { sleep } = require('./utils');
  const { timing } = require('./config');

  for (const scenario of suite) {
    const { passed, result } = await runWithWatchdog(scenario.run, scenario.SCENARIO, id);
    results.push({
      scenario:   scenario.SCENARIO,
      passed,
      durationMs: result.durationMs,
      failures:   result.failures,
      slaMetrics: result.slaMetrics,
    });

    // Inter-scenario cooldown — gives device time to settle
    if (suite.indexOf(scenario) < suite.length - 1) {
      console.log(`  [Orchestrator] Cooling down ${timing.scenarioCooldown}ms before next scenario...`);
      await sleep(timing.scenarioCooldown);
    }
  }

  const verdict = writeCertificationReport(id, results);
  process.exit(verdict === 'CERTIFIED' ? 0 : 1);
}

main().catch(err => {
  console.error('[Orchestrator] Fatal crash:', err);
  process.exit(1);
});
