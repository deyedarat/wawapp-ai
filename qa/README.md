# WawApp Dispatch Reliability Certification Platform
## README & Operations Guide

---

## Architecture

```
qa/
  orchestrator/          # Core engine
    config.js            # All constants: devices, SLAs, paths
    firebase.js          # Admin SDK singleton
    timeline.js          # NDJSON event stream
    device.js            # ADB abstraction layer
    assertions.js        # Deterministic assertion library
    reporter.js          # PASS/FAIL report generator
    utils.js             # sleep, waitFor, runId
    orchestrate.js       # Master runner
  backend/
    backend.js           # All Firebase operations
  scenarios/
    core/                # Happy path + basic failures
    reliability/         # Known failure modes (Phases 4–4.8)
    torture/             # High-stress sequences
  reports/               # Generated per run: <runId>/
  artifacts/             # Screenshots per run
  run_all.ps1            # Full certification
  run_regression_suite.ps1
  run_torture_suite.ps1
```

---

## Quick Start

### Regression suite (daily use)
```powershell
powershell -File qa/run_regression_suite.ps1
```

### Full certification (pre-release)
```powershell
powershell -File qa/run_all.ps1
```

### Single scenario
```powershell
node qa/scenarios/reliability/stale_cache_resurrection.js
```

### Specific suite via orchestrator
```powershell
node qa/orchestrator/orchestrate.js --suite core
node qa/orchestrator/orchestrate.js --suite reliability
node qa/orchestrator/orchestrate.js --suite torture
node qa/orchestrator/orchestrate.js --suite regression  # core + reliability
node qa/orchestrator/orchestrate.js --suite all
```

---

## Device Requirements

| Role   | Device         | ADB Serial     | OS         |
|--------|---------------|----------------|------------|
| Driver | Samsung SM-A065F | R83Y20PC4EN | Android 15 |
| Rider  | (TBD)          | TBD            | Any        |

The rider device slot is reserved in `config.js`. Rider-dependent scenarios
will gracefully skip rider steps until the device is registered.

---

## Scenarios

### Core (7 scenarios)
| Scenario | Invariant Verified |
|---|---|
| `dispatch_accept_success` | Happy path E2E, FCM SLA |
| `dispatch_reject` | Clean dismiss, order not accepted |
| `dispatch_timeout` | Order expiry propagates to UI |
| `client_cancel_before_accept` | Cancellation revokes actionable UI |
| `client_cancel_after_accept` | (stub — extend as needed) |
| `fullscreen_accept_success` | FullScreenNotificationActivity path |
| `flutter_foreground_offer` | Flutter foreground modal path |

### Reliability (7 scenarios)
| Scenario | Bug Found In |
|---|---|
| `stale_cache_resurrection` | Phase 4.8 (765ms cache race) |
| `zombie_fullscreen_protection` | Phase 4.7 (_safeDismiss) |
| `process_kill_during_offer` | Phase 4.8 |
| `duplicate_accept_guard` | Phase 4.7 (double-tap) |
| `startup_rehydration` | Phase 4.8 (cache hydration) |
| `stale_active_trip_recovery` | Phase 4.6 (SharedPrefs suppression) |
| `offline_reconnect` | General connectivity |

### Torture (4 scenarios)
| Scenario | Stress Vector |
|---|---|
| `rapid_sequential_orders` | N orders back-to-back |
| `app_kill_mid_dispatch` | Kill at T1/T2/T3 points |
| `repeated_fcm_burst` | Multiple FCM wave retries |
| `lock_unlock_during_offer` | Lock screen interference |

---

## Output

Each run produces:
```
qa/reports/<runId>/
  timeline.ndjson              # All events with timestamps
  certification_report.md      # Human-readable summary
  certification_report.json    # Machine-readable summary
  <scenario>/
    result.json
    result.md
qa/artifacts/<runId>/
  <scenario>_<label>.png       # Screenshots
```

---

## Operational Invariants

The harness continuously validates all 10 invariants on every run:

1. **Dead offers never resurrect** — `stale_cache_resurrection`, `startup_rehydration`
2. **Fullscreen authority never zombifies** — `zombie_fullscreen_protection`
3. **Duplicate accept is impossible** — `duplicate_accept_guard`
4. **Silent suppression cannot persist** — `stale_active_trip_recovery`
5. **Cache snapshots cannot create false authority** — `stale_cache_resurrection`
6. **Notification authority is singular** — `rapid_sequential_orders`
7. **FCM wake latency within SLA** — `dispatch_accept_success` (15s threshold)
8. **Driver cannot be silently starved** — `stale_active_trip_recovery`
9. **Terminal states revoke actionable UI** — `dispatch_timeout`, `client_cancel_before_accept`
10. **All lifecycle paths terminate cleanly** — `process_kill_during_offer`, `app_kill_mid_dispatch`

---

## SLA Thresholds

| Metric | Threshold |
|--------|-----------|
| Rider commit → FCM received | 15,000ms |
| FCM received → Fullscreen rendered | 3,000ms |
| Driver tap → Firestore accepted | 8,000ms |
| Cache emission → Server reconciliation | 5,000ms |

---

## Known Blind Spots

1. **Rider device not yet connected** — scenarios requiring real rider interaction (`client_cancel_before_accept`, `client_cancel_after_accept`) use backend-only cancellation. Add rider device to `config.js` to enable full dual-device flows.
2. **Wave dispatch timing** — Cloud Functions introduce variable latency. The 30s fullscreen wait window may need tuning per environment.
3. **GPS drift** — If `driver_locations` coordinates drift from config anchor, dispatch selector may not match. Re-run `node qa/backend/backend.js` inject to refresh.
4. **Instrumented build required for FORENSIC_TRACE** — The `stale_cache_resurrection` and `startup_rehydration` logcat assertions require the debug APK with `[FORENSIC_TRACE]` markers in `orders_service.dart`. Release APKs will skip those log assertions (non-fatal).
5. **Lock screen scenarios** — `lock_unlock_during_offer` requires the device to NOT have a PIN/pattern. Configure test device accordingly.

---

## CI Integration Path

```yaml
# github-actions or similar
- name: Run WawApp Regression Suite
  run: |
    adb connect ${{ secrets.DRIVER_DEVICE_IP }}
    powershell -File qa/run_regression_suite.ps1
  env:
    GOOGLE_APPLICATION_CREDENTIALS: ${{ secrets.FIREBASE_SA_JSON }}
```

Replace the ADB serial in `config.js` with an environment variable for CI:
```js
deviceId: process.env.DRIVER_DEVICE_SERIAL || 'R83Y20PC4EN',
```

---

## Reliability Roadmap

| Priority | Work Item |
|---|---|
| P0 | Add `isFromCache` filter to `watchMyOffers` (cache resurrection fix) |
| P0 | Connect rider physical device for full dual-device flows |
| P1 | Add `stale_active_trip_recovery` scenario (Phase 4.6 SharedPrefs regression) |
| P1 | Add `offline_reconnect` scenario |
| P2 | Add `lock_unlock_during_offer` scenario |
| P2 | Add `repeated_fcm_burst` scenario |
| P3 | Replace `monkey` launcher with `am start` for deterministic launch |
| P3 | Parameterize tap coordinates from UIAutomator dynamic detection |
| P3 | Add GitHub Actions workflow YAML |
