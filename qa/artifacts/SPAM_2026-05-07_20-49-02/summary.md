# Smoke Test: SPAM - Notification Spam / Dedup Stress

| Field | Value |
|-------|-------|
| Verdict | **PASS** |
| Scenario | SPAM - Notification Spam / Dedup Stress |
| Device | SM-A065F (R83Y20PC4EN) |
| Android | 15 (SDK 35) |
| Start | 2026-05-07_20-49-02 |
| End | 2026-05-07_20-49-37 |
| Duration | 35s |

## Checks

| Check | Result |
|-------|--------|
| App warmed | PASS PID:5359 |
| Crash detection | PASS |
| Process liveness | PASS PID:5359 |
| Fullscreen stacking | PASS count=0 |
| Notification dedup | PASS 0/5 |
| Dedup log evidence | WARN none found |

## Failure Reasons

None

## Artifacts

- device_info.txt
- SPAM_pre_notification_dump.txt
- SPAM_pre_burst.png
- SPAM_logcat.txt
- SPAM_post_burst.png
- SPAM_post_notification_dump.txt
- SPAM_activity_dump.txt

## Burst Configuration

| Parameter | Value |
|-----------|-------|
| Mode | duplicate |
| Count | 5 |
| Interval | 500ms |
| Reboot between | False |
| Max expected notifications | 1 |

## Burst Log

| # | OrderId | Price | Sent At |
|---|---------|-------|---------|
| 1 | stress_204918_dup | 500 | 20:49:19.271 |
| 2 | stress_204918_dup | 500 | 20:49:20.878 |
| 3 | stress_204918_dup | 500 | 20:49:22.462 |
| 4 | stress_204918_dup | 500 | 20:49:24.019 |
| 5 | stress_204918_dup | 500 | 20:49:25.575 |

## Post-Burst Metrics

| Metric | Value |
|--------|-------|
| App warmed | True PID:5359 |
| App alive after burst | YES PID:5359 |
| Crash traces in logcat | 0 |
| Notifications in tray | 0 |
| Full-screen activities | 0 |
| Dedup log hits | 0 |

## Runtime Observability

| Field | Value |
|-------|-------|
| Final State | **PASS** |
| Last Phase | SUMMARY_EXPORT |

## Phase Timings

| Phase | Duration |
|-------|----------|
| DEVICE_CHECK | 6.3s |
| SEND_PAYLOAD | 7.4s |
| WAIT_FOR_NOTIFICATION | 5s |
| SCREENSHOT_CAPTURE | 5.3s |
| LOGCAT_STOP | 1.6s |
| SUMMARY_EXPORT | 0s |
| APP_WARM | 5.7s |
| **TOTAL** | **36.9s** |
