# full_order_lifecycle
**Verdict:** FAIL  |  **Duration:** 53647ms  |  **Run:** e2e_1778740193097

## Assertions
- ✅ Both devices prepared and clean
- ❌ Driver app not in foreground after launch
- ❌ Unexpected error: Driver app failed to launch

## Failures
### ❌ Driver app not in foreground after launch
```json
{
  "classification": "APP_LAUNCH_FAILURE",
  "focused": ""
}
```
### ❌ Unexpected error: Driver app failed to launch
```json
{
  "classification": "HARNESS_ERROR",
  "stack": "Error: Driver app failed to launch\n    at run (C:\\Users\\hp\\Music\\wawapp-ai\\qa\\scenarios\\e2e\\full_order_lifecycle.js:96:19)\n    at runNextTicks (node:internal/process/task_queues:60:5)\n    at listOnTimeout (node:internal/timers:545:9)\n    at process.processTimers (node:internal/timers:519:7)"
}
```