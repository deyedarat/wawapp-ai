# Smoke Test: N3 - Killed-State Notification

| Field | Value |
|-------|-------|
| Verdict | **FAIL** |
| Scenario | N3 - Killed-State Notification |
| Device | SM-A065F (R83Y20PC4EN) |
| Android | 15 (SDK 35) |
| Start | 2026-05-07_20-48-21 |
| End | 2026-05-07_20-49-00 |
| Duration | 39s |

## Checks

| Check | Result |
|-------|--------|
| Full-screen activity | FAIL |
| Notification in tray | PASS |
| App process woken | FAIL |

## Failure Reasons

- Full-screen activity not visible
- App not started after FCM

## Artifacts

- device_info.txt
- N3_logcat.txt
- N3_pre_fcm.png
- N3_post_fcm.png
- N3_notification_dump.txt
- N3_activity_dump.txt

## Runtime Observability

| Field | Value |
|-------|-------|
| Final State | **FAIL** |
| Last Phase | SUMMARY_EXPORT |

## Phase Timings

| Phase | Duration |
|-------|----------|
| DEVICE_CHECK | 6.5s |
| FORCE_STOP | 3.4s |
| SEND_PAYLOAD | 1.1s |
| WAIT_FOR_ACTIVITY | 20.1s |
| WAIT_FOR_NOTIFICATION | 2.1s |
| SCREENSHOT_CAPTURE | 3.1s |
| LOGCAT_STOP | 1.6s |
| SUMMARY_EXPORT | 0.1s |
| **TOTAL** | **41.3s** |
