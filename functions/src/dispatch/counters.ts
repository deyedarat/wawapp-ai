/**
 * WawApp Dispatch Engine — Lightweight Metrics Counters
 *
 * Emits structured log lines that Cloud Logging can parse into
 * log-based metrics (Monitoring → Log-based Metrics → Create Metric).
 *
 * No external dependencies. Works with Cloud Functions out of the box.
 *
 * To create dashboards:
 *   Filter: jsonPayload.metric EXISTS
 *   Group by: jsonPayload.metric
 *
 * @version 1.0.0
 */

export type DispatchMetricName =
  | 'dispatch_intake_started'
  | 'dispatch_intake_succeeded'
  | 'dispatch_intake_failed_validation'
  | 'dispatch_intake_failed_firestore'
  | 'dispatch_intake_failed_unknown'
  | 'dispatch_queue_duplicate_skipped'
  | 'wave_creation_started'
  | 'wave_creation_succeeded'
  | 'wave_creation_failed'
  | 'wave_no_eligible_drivers'
  | 'wave_all_exhausted'
  | 'offer_accepted'
  | 'offer_rejected'
  | 'offer_expired'
  | 'notification_sent'
  | 'notification_failed'
  | 'circuit_breaker_order_stuck'
  | 'circuit_breaker_global_opened';

/**
 * Emit a structured counter event.
 *
 * Cloud Logging query:  jsonPayload.metric = "dispatch_intake_started"
 * Log-based metric:     counter on jsonPayload.metric
 */
export function emitMetric(
  metric: DispatchMetricName,
  labels: Record<string, string | number | boolean | null> = {}
): void {
  console.log(JSON.stringify({
    metric,
    ...labels,
    _ts: Date.now(),
  }));
}
