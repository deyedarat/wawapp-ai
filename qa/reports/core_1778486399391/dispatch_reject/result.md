# dispatch_reject
**Verdict:** FAIL  |  **Duration:** 54833ms  |  **Run:** core_1778486399391

## Assertions
- ❌ Fullscreen rendered within 30s
- ✅ Fullscreen dismissed after reject
- ✅ Order not accepted after driver reject

## SLA Metrics
| Metric | Actual | Max | Status |
|--------|--------|-----|--------|
| ORDER_CREATED → FULLSCREEN_RENDERED | N/Ams | 15000ms | ❌ |

## Failures
### ❌ Fullscreen rendered within 30s
```json
{
  "timeout": true
}
```