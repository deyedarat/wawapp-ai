# dispatch_accept_success
**Verdict:** FAIL  |  **Duration:** 56795ms  |  **Run:** core_1778486399391

## Assertions
- ❌ Fullscreen notification rendered within 30s
- ❌ Order transitioned to accepted in Firestore
- ✅ Dispatch offer is in terminal state
- ❌ SLA: ORDER_CREATED → FULLSCREEN_RENDERED within 15000ms

## SLA Metrics
| Metric | Actual | Max | Status |
|--------|--------|-----|--------|
| ORDER_CREATED → FULLSCREEN_RENDERED | N/Ams | 15000ms | ❌ |

## Failures
### ❌ Fullscreen notification rendered within 30s
```json
{
  "timeout": true
}
```
### ❌ Order transitioned to accepted in Firestore
```json
{
  "actualStatus": "matching"
}
```
### ❌ SLA: ORDER_CREATED → FULLSCREEN_RENDERED within 15000ms
```json
{
  "delta": null,
  "maxMs": 15000,
  "slaBreached": true
}
```