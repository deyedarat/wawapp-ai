# Smoke Test: SPAM - Notification Spam / Dedup Stress

| Field | Value |
|-------|-------|
| Verdict | **FAIL** |
| Scenario | SPAM - Notification Spam / Dedup Stress |
| Device | SM-A065F (R83Y20PC4EN) |
| Android | 15 (SDK 35) |
| Start | 2026-05-06_22-39-17 |
| End | 2026-05-06_22-39-46 |
| Duration | 29s |

## Checks

| Check | Result |
|-------|--------|
| App not crashed | FAIL |
| No duplicate full-screen | PASS count=0 |
| Dedup (tray count) | PASS 1/5 |
| Dedup log evidence | WARN none found |
| No crash in logcat | PASS |

## Failure Reasons

- App crashed during burst

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
| 1 | stress_223927_dup | 500 | 22:39:28.405 |
| 2 | stress_223927_dup | 500 | 22:39:29.974 |
| 3 | stress_223927_dup | 500 | 22:39:31.520 |
| 4 | stress_223927_dup | 500 | 22:39:33.098 |
| 5 | stress_223927_dup | 500 | 22:39:34.691 |

## Post-Burst Metrics

| Metric | Value |
|--------|-------|
| Notifications in tray | 1 |
| Full-screen activities | 0 |
| Crash traces | 0 |
| Dedup log hits | 0 |

## Runtime Observability

| Field | Value |
|-------|-------|
| Final State | **FAIL** |
| Last Phase | SUMMARY_EXPORT |

## Phase Timings

| Phase | Duration |
|-------|----------|
| DEVICE_CHECK | 6.4s |
| SEND_PAYLOAD | 7.4s |
| WAIT_FOR_NOTIFICATION | 5s |
| SCREENSHOT_CAPTURE | 5.4s |
| LOGCAT_STOP | 1.6s |
| SUMMARY_EXPORT | 0s |
| **TOTAL** | **31.7s** |
