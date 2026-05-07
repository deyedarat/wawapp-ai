# Production Readiness Test Matrix

## Status Legend
| Symbol | Meaning |
|--------|---------|
| ✅ | Passing |
| ❌ | Failing |
| ⏳ | Not tested |
| 🔄 | Flaky |

---

## Auth Flow

| # | Scenario | Priority | Status | Notes |
|---|----------|----------|--------|-------|
| A1 | OTP login (happy path) | P0 | ⏳ | Phone → OTP → PIN → Home |
| A2 | Retry OTP (timeout/resend) | P0 | ⏳ | Timer expiry → resend → verify |

---

## Notifications

| # | Scenario | Priority | Status | Notes |
|---|----------|----------|--------|-------|
| N1 | Foreground notification | P0 | ⏳ | App open, FCM data msg → heads-up |
| N2 | Duplicate notification | P1 | ⏳ | Same orderId twice → single display |
| N3 | Killed-state notification | P0 | ⏳ | App force-stopped → FCM → full-screen intent |

---

## Matching & Orders

| # | Scenario | Priority | Status | Notes |
|---|----------|----------|--------|-------|
| M1 | Driver stale filtering | P0 | ⏳ | Stale location (>5min) → excluded from matching |
| M2 | Recovery boost | P1 | ⏳ | After expiry → re-match with expanded radius |
| M3 | Accept order flow | P0 | ⏳ | Driver sees order → accepts → status transitions |

---

## Location & GPS

| # | Scenario | Priority | Status | Notes |
|---|----------|----------|--------|-------|
| L1 | GPS weak accuracy | P1 | ⏳ | Accuracy >50m → warning state, not used for matching |

---

## Gate Criteria

Production deploy requires:
- All P0 scenarios: ✅
- All P1 scenarios: ✅ or 🔄 with documented workaround
- Zero ❌ on any priority level
- Artifacts collected for each test run in `qa/artifacts/`
