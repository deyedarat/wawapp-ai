# full_order_lifecycle
**Verdict:** FAIL  |  **Duration:** 113022ms  |  **Run:** e2e_1778740391969

## Assertions
- ✅ Both devices prepared and clean
- ✅ Driver app launched and listener active
- ❌ Failed to submit order from rider UI
- ❌ Unexpected error: Could not complete rider order submission

## Failures
### ❌ Failed to submit order from rider UI
```json
{
  "classification": "UI_NAVIGATION_FAILURE"
}
```
### ❌ Unexpected error: Could not complete rider order submission
```json
{
  "classification": "HARNESS_ERROR",
  "stack": "Error: Could not complete rider order submission\n    at run (C:\\Users\\hp\\Music\\wawapp-ai\\qa\\scenarios\\e2e\\full_order_lifecycle.js:270:19)"
}
```