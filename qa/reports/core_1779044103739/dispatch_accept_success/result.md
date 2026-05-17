# dispatch_accept_success
**Verdict:** FAIL  |  **Duration:** 79755ms  |  **Run:** core_1779044103739

## Assertions
- ✅ End-to-End dispatch pipeline cleared all stages successfully
- ❌ Order did not transition to accepted
- ❌ Offer UI persisted after accept click

## SLA Metrics
| Metric | Actual | Max | Status |
|--------|--------|-----|--------|
| E2E Pipeline Latency | 47249ms | 15000ms | ❌ |

## Failures
### ❌ Order did not transition to accepted
```json
{
  "classification": "ACCEPT_FAILED",
  "actual": "matching"
}
```
### ❌ Offer UI persisted after accept click
```json
{
  "classification": "UI_ZOMBIE",
  "focused": "ResumedActivity: ActivityRecord{ae85743 u0 com.wawapp.driver/.FullScreenNotificationActivity t110}"
}
```