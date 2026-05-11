'use strict';
/**
 * Operational Metrics Aggregator
 * Reads all certification_report.json files in qa/reports/
 * and produces a comprehensive reliability metrics summary.
 *
 * Usage:
 *   node qa/metrics.js
 *   node qa/metrics.js --since 2026-05-11
 */
const fs   = require('fs');
const path = require('path');

const REPORTS_DIR = 'qa/reports';
const since = (() => {
  const idx = process.argv.indexOf('--since');
  return idx !== -1 ? new Date(process.argv[idx + 1]).getTime() : 0;
})();

// ── Collect all run results ────────────────────────────────────────────────────
function collectAllResults() {
  const allResults = [];
  if (!fs.existsSync(REPORTS_DIR)) return allResults;

  const runs = fs.readdirSync(REPORTS_DIR, { withFileTypes: true })
    .filter(d => d.isDirectory())
    .map(d => d.name);

  for (const runDir of runs) {
    const certFile = path.join(REPORTS_DIR, runDir, 'certification_report.json');
    if (!fs.existsSync(certFile)) continue;

    try {
      const cert = JSON.parse(fs.readFileSync(certFile, 'utf8'));
      // Apply --since filter using runId timestamp suffix
      const ts = parseInt(runDir.split('_').pop());
      if (!isNaN(ts) && ts < since) continue;

      allResults.push({ runId: runDir, cert, ts: ts || 0 });
    } catch (_) {}
  }

  return allResults.sort((a, b) => a.ts - b.ts);
}

// ── Per-scenario aggregation ────────────────────────────────────────────────────
function aggregateScenarios(allResults) {
  const byScenario = {};

  for (const { cert } of allResults) {
    for (const r of (cert.results || [])) {
      if (!byScenario[r.scenario]) {
        byScenario[r.scenario] = { total: 0, passed: 0, failed: 0, durations: [], slaBreaches: 0 };
      }
      const s = byScenario[r.scenario];
      s.total++;
      if (r.passed) s.passed++; else s.failed++;
      if (r.durationMs) s.durations.push(r.durationMs);

      for (const sla of (r.slaMetrics || [])) {
        if (!sla.passed) s.slaBreaches++;
      }
    }
  }

  return byScenario;
}

// ── SLA percentile ─────────────────────────────────────────────────────────────
function percentile(arr, p) {
  if (!arr.length) return null;
  const sorted = [...arr].sort((a, b) => a - b);
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, idx)];
}

// ── Regression memory cross-check ─────────────────────────────────────────────
function loadRegressionMemory() {
  const memFile = 'qa/regression_memory.json';
  if (!fs.existsSync(memFile)) return [];
  return JSON.parse(fs.readFileSync(memFile, 'utf8')).regressions || [];
}

// ── Main ───────────────────────────────────────────────────────────────────────
function main() {
  const allResults = collectAllResults();
  if (!allResults.length) {
    console.log('No certification reports found in qa/reports/');
    console.log('Run: node qa/orchestrator/orchestrate.js --suite regression');
    process.exit(0);
  }

  const byScenario = aggregateScenarios(allResults);
  const memory     = loadRegressionMemory();

  const totalRuns  = allResults.length;
  const totalPass  = allResults.filter(r => r.cert.overall === 'CERTIFIED').length;
  const totalFail  = totalRuns - totalPass;
  const stabilityPct = totalRuns > 0 ? ((totalPass / totalRuns) * 100).toFixed(1) : 0;

  console.log('\n' + '═'.repeat(64));
  console.log('  WawApp Dispatch Reliability — Operational Metrics');
  console.log('═'.repeat(64));
  console.log(`  Total Certification Runs : ${totalRuns}`);
  console.log(`  Passed                   : ${totalPass}`);
  console.log(`  Failed                   : ${totalFail}`);
  console.log(`  Overnight Stability      : ${stabilityPct}%`);
  console.log('');

  console.log('  Scenario Metrics:');
  console.log('  ' + '─'.repeat(60));
  const header = '  Scenario'.padEnd(38) + 'Pass%'.padEnd(8) + 'P50'.padEnd(8) + 'P95'.padEnd(8) + 'SLA Breaks';
  console.log(header);
  console.log('  ' + '─'.repeat(60));

  for (const [name, s] of Object.entries(byScenario)) {
    const passRate = s.total > 0 ? ((s.passed / s.total) * 100).toFixed(0) : 0;
    const p50 = percentile(s.durations, 50);
    const p95 = percentile(s.durations, 95);
    const row = `  ${name.padEnd(36)}${(passRate + '%').padEnd(8)}${(p50 ? Math.round(p50 / 1000) + 's' : 'N/A').padEnd(8)}${(p95 ? Math.round(p95 / 1000) + 's' : 'N/A').padEnd(8)}${s.slaBreaches}`;
    console.log(row);
  }
  console.log('');

  // Regression memory status
  console.log('  Regression Memory Coverage:');
  console.log('  ' + '─'.repeat(60));
  for (const bug of memory) {
    const scenData = byScenario[bug.detection_scenario];
    let status;
    if (!scenData) {
      status = 'NOT EXECUTED';
    } else if (scenData.failed > 0) {
      status = `REGRESSION DETECTED (${scenData.failed}/${scenData.total} runs FAILED)`;
    } else {
      status = `PROTECTED (${scenData.passed}/${scenData.total} runs PASSED)`;
    }
    const pending = bug.fix_build === 'PENDING' ? ' [FIX PENDING]' : '';
    console.log(`  [${bug.id.substring(0, 28).padEnd(28)}] ${status}${pending}`);
  }
  console.log('');

  // Overnight history
  const nightlyFile = path.join(REPORTS_DIR, 'overnight_history.jsonl');
  if (fs.existsSync(nightlyFile)) {
    const lines = fs.readFileSync(nightlyFile, 'utf8').trim().split('\n').filter(Boolean);
    const nightlyRuns = lines.map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
    if (nightlyRuns.length) {
      const lastN = nightlyRuns.slice(-5);
      console.log('  Last 5 Overnight Runs:');
      lastN.forEach(n => {
        console.log(`    ${n.date}  ${n.suite}  Runs:${n.totalRuns}  Pass:${n.passed}  Fail:${n.failed}  Stability:${n.stabilityPct}%`);
      });
      console.log('');
    }
  }

  console.log('═'.repeat(64));

  // Write metrics to file
  const output = {
    generatedAt:    new Date().toISOString(),
    totalRuns,
    totalPass,
    totalFail,
    stabilityPct:   parseFloat(stabilityPct),
    scenarioMetrics: Object.entries(byScenario).map(([name, s]) => ({
      scenario:    name,
      total:       s.total,
      passed:      s.passed,
      failed:      s.failed,
      passRate:    s.total > 0 ? parseFloat(((s.passed / s.total) * 100).toFixed(1)) : 0,
      p50Ms:       percentile(s.durations, 50),
      p95Ms:       percentile(s.durations, 95),
      slaBreaches: s.slaBreaches,
    })),
    regressionMemoryCoverage: memory.map(bug => {
      const s = byScenario[bug.detection_scenario];
      return {
        id:         bug.id,
        scenario:   bug.detection_scenario,
        executed:   !!s,
        passing:    s ? s.failed === 0 : null,
        fixPending: bug.fix_build === 'PENDING',
      };
    }),
  };

  const outPath = path.join(REPORTS_DIR, 'operational_metrics.json');
  fs.writeFileSync(outPath, JSON.stringify(output, null, 2));
  console.log(`\n  Metrics written to: ${outPath}\n`);

  process.exit(totalFail === 0 ? 0 : 1);
}

main();
