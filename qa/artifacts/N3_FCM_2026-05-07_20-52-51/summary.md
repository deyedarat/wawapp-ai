# Smoke Test: N3_FCM - Killed-State Real FCM Certification

| Field | Value |
|-------|-------|
| Verdict | **FAIL** |
| Scenario | N3_FCM - Killed-State Real FCM Certification |
| Device | SM-A065F (R83Y20PC4EN) |
| Android | 15 (SDK 35) |
| Start | 2026-05-07_20-52-51 |
| End | 2026-05-07_20-53-38 |
| Duration | 47s |

## Checks

| Check | Result |
|-------|--------|
| App wake | FAIL timeout 25s |
| Fullscreen launch | FAIL |
| Notification tray | PASS |
| Crash detection | PASS |
| Classification | REAL_FCM_WAKE_FAIL |

## Failure Reasons

- App did not wake from killed state within 25s
- Fullscreen activity not launched within 25s

## Artifacts

- device_info.txt
- N3_FCM_logcat.txt
- N3_FCM_pre_fcm.png
- N3_FCM_post_fcm.png
- N3_FCM_notification_dump.txt
- N3_FCM_activity_dump.txt

## FCM Certification Metrics

| Metric | Value |
|--------|-------|
| Execution mode | REAL_FCM |
| Classification | **REAL_FCM_WAKE_FAIL** |
| Delivery latency | 1492ms |
| Wake latency | 0ms |
| Fullscreen latency | 0ms |
| Poll count | 10 |
| Poll interval | 500ms |
| Timeout | 25s |
| FCM message ID | projects/wawapp-952d6/messages/0:1778172786769137%ea809995f9fd7ecd |
| FCM status | REAL_FCM_DELIVERED |

## Latency Thresholds

| Threshold | Value | Status |
|-----------|-------|--------|
| Wake < 3s | 0ms | N/A |
| Fullscreen < 4s | 0ms | N/A |

## Runtime Observability

| Field | Value |
|-------|-------|
| Final State | **FAIL** |
| Last Phase | SUMMARY_EXPORT |

## Phase Timings

| Phase | Duration |
|-------|----------|
| DEVICE_CHECK | 6.5s |
| FORCE_STOP | 3.3s |
| SEND_PAYLOAD | 1.6s |
| WAIT_FOR_ACTIVITY | 26s |
| WAIT_FOR_NOTIFICATION | 2.1s |
| SCREENSHOT_CAPTURE | 3.2s |
| LOGCAT_STOP | 0.6s |
| SUMMARY_EXPORT | 0.1s |
| FCM_AUTH | 2.1s |
| **TOTAL** | **48.5s** |
