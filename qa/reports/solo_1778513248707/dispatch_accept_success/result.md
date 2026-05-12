# dispatch_accept_success
**Verdict:** FAIL  |  **Duration:** 100988ms  |  **Run:** solo_1778513248707

## Assertions
- ❌ Pipeline stage failed: OFFER_NOT_WRITTEN

## Failures
### ❌ Pipeline stage failed: OFFER_NOT_WRITTEN
```json
{
  "classification": "INFRASTRUCTURE_LATENCY",
  "evidence": "Order was created but Cloud Functions failed to match/inject target Driver into dispatch_offers.",
  "stage": "OFFER_NOT_WRITTEN"
}
```