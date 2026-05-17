# client_cancel_before_accept
**Verdict:** FAIL  |  **Duration:** 77528ms  |  **Run:** core_1779044103739

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