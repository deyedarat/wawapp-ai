# stale_cache_resurrection
**Verdict:** FAIL  |  **Duration:** 60638ms  |  **Run:** regression_1779041872277

## Assertions
- ✅ Stale cache did NOT trigger fullscreen authority after restart
- ❌ Server reconciliation did not occur after cache emission

## SLA Metrics
| Metric | Actual | Max | Status |
|--------|--------|-----|--------|
| Cache emission → server reconciliation | 5000ms | 5000ms | ✅ |

## Failures
### ❌ Server reconciliation did not occur after cache emission
```json
{
  "cacheLines": 1,
  "serverLines": 0
}
```