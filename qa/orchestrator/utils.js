'use strict';
/**
 * Shared scenario utilities — sleep, retry, wait-for-condition.
 */

/** Async sleep. */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Poll a condition function until it returns truthy or timeout elapses.
 * @param {Function} fn        - async or sync function returning boolean
 * @param {number}   timeoutMs
 * @param {number}   [intervalMs=1000]
 * @returns {boolean}  true if condition met before timeout
 */
async function waitFor(fn, timeoutMs, intervalMs = 1000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await fn()) return true;
    await sleep(intervalMs);
  }
  return false;
}

/**
 * Generate a unique QA run ID.
 */
function runId(prefix = 'run') {
  return `${prefix}_${Date.now()}`;
}

module.exports = { sleep, waitFor, runId };
