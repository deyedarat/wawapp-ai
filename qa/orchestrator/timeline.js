'use strict';
/**
 * Timeline engine — all lifecycle events are written here as NDJSON.
 * One file per run: qa/reports/<runId>/timeline.ndjson
 *
 * Event shape:
 *   { event, orderId?, device?, ts, data? }
 */
const fs = require('fs');
const path = require('path');

class Timeline {
  constructor(runId, reportsDir = 'qa/reports') {
    this.runId = runId;
    this.dir = path.join(reportsDir, runId);
    fs.mkdirSync(this.dir, { recursive: true });
    this.file = path.join(this.dir, 'timeline.ndjson');
    this._stream = fs.createWriteStream(this.file, { flags: 'a' });
    this.events = [];
  }

  /**
   * Emit a named event.
   * @param {string}  event     - machine-readable event name (SCREAMING_SNAKE)
   * @param {object}  [opts]
   * @param {string}  [opts.orderId]
   * @param {string}  [opts.device]  - 'driver' | 'rider' | 'backend'
   * @param {object}  [opts.data]
   */
  emit(event, { orderId, device, data } = {}) {
    const entry = {
      event,
      orderId: orderId || null,
      device:  device  || null,
      ts:      Date.now(),
      data:    data    || null,
    };
    this.events.push(entry);
    this._stream.write(JSON.stringify(entry) + '\n');
    console.log(`[TL] ${new Date(entry.ts).toISOString()}  ${event}` +
                (orderId ? `  order=${orderId}` : '') +
                (device  ? `  dev=${device}`    : ''));
    return entry;
  }

  /** Duration in ms between two named events (first occurrences). */
  delta(eventA, eventB) {
    const a = this.events.find(e => e.event === eventA);
    const b = this.events.find(e => e.event === eventB);
    if (!a || !b) return null;
    return b.ts - a.ts;
  }

  /** Flush and close. */
  close() {
    this._stream.end();
  }

  /** Return path to the NDJSON file. */
  get filePath() { return this.file; }
}

module.exports = Timeline;
