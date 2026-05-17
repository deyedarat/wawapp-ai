# client_cancel_before_accept
**Verdict:** FAIL  |  **Duration:** 170434ms  |  **Run:** regression_1779041872277

## Assertions
- ✅ Fullscreen rendered before client cancel
- ❌ Fullscreen dismissed after client cancellation
- ✅ Order status is cancelledByClient

## Failures
### ❌ Fullscreen dismissed after client cancellation
```json
{
  "stillActive": true
}
```