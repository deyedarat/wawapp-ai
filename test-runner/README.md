# WawApp E2E Test Runner (Pure ADB)

Zero dependencies. Controls two real Android devices via `adb shell`.

## Prerequisites

1. Both devices connected via USB:
   - `R83Y20PC4EN` — Client device (com.wawapp.client installed)
   - `R8YW40AW58L` — Driver device (com.wawapp.driver installed)
2. Both apps logged in and ready (past auth/PIN gates)
3. Driver app: driver must be online + verified
4. ADB at: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`

## Run

```bash
cd test-runner
node index.js
```

No `npm install` needed — zero dependencies.

## Scenarios

| # | Name | What it tests |
|---|------|---------------|
| S1 | New Order (Driver Background) | FCM → FullScreenNotificationActivity launch |
| S2 | Driver Accept | Accept button → notification cancelled → MainActivity |
| S3 | Client Cancels | Firestore listener auto-dismisses FS activity |
| S4 | Dedup | Same order FCM blocked by native dedup |
| S5 | No Response (TTL) | Activity auto-dismissed after offer expires |

## Results

Written to `test-runner/results/test_results_{timestamp}.md`

## Calibration

Tap coordinates are calculated as percentages of screen resolution.
If buttons are missed, adjust the percentage values in:
- `clientCreateOrder()` — pickup/dropoff/begin/request buttons
- `driverTapAccept()` — accept button position
- `clientTapCancel()` — cancel button position

Use `adb shell getevent -l` to find exact tap coordinates on your device.
