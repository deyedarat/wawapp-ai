# dispatch_reject
**Verdict:** FAIL  |  **Duration:** 77898ms  |  **Run:** core_1779043656102

## Assertions
- ✅ Fullscreen rendered for reject scenario
- ❌ Fullscreen dismissed after reject
- ✅ Order not accepted after driver reject

## SLA Metrics
| Metric | Actual | Max | Status |
|--------|--------|-----|--------|
| ORDER_CREATED → FULLSCREEN_RENDERED | 55448ms | 15000ms | ❌ |

## Failures
### ❌ Fullscreen dismissed after reject
```json
{
  "stillActive": true
}
```