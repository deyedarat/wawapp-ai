# dispatch_accept_success
**Verdict:** FAIL  |  **Duration:** 79875ms  |  **Run:** smoke_1778604623348

## Assertions
- ✅ End-to-End dispatch pipeline cleared all stages successfully
- ❌ Order did not transition to accepted
- ✅ Driver UI successfully transitioned off offer screen

## SLA Metrics
| Metric | Actual | Max | Status |
|--------|--------|-----|--------|
| E2E Pipeline Latency | 50209ms | 15000ms | ❌ |

## Failures
### ❌ Order did not transition to accepted
```json
{
  "classification": "ACCEPT_FAILED",
  "actual": "matching"
}
```