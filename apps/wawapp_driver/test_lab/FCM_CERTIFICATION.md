# FCM Notification Certification Pipeline

Production-grade notification validation on Firebase Test Lab physical devices.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Firebase Test Lab (Samsung A15, Android 14, API 34)            │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  NotificationE2ETest (Instrumentation)                   │   │
│  │  1. Launch app                                           │   │
│  │  2. Fetch real FCM token                                 │   │
│  │  3. Log: FCM_TOKEN=xxx                                   │   │
│  │  4. Wait 180s for external push                          │   │
│  │  5. Poll SharedPreferences for delivery marker           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ▲                                      │
│                          │ FCM Push                             │
└──────────────────────────┼──────────────────────────────────────┘
                           │
┌──────────────────────────┼──────────────────────────────────────┐
│  fcm-certification.ps1   │  (Local machine)                     │
│  1. Read token from logs │                                      │
│  2. OAuth2 via SA JSON   │                                      │
│  3. Send FCM v1 API push ┘                                      │
│  4. Measure latency                                             │
│  5. Print PASS/FAIL                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Log Markers

| Marker | Source | Meaning |
|--------|--------|---------|
| `WAWAPP_TEST` | All | Test tag for filtering |
| `FCM_TOKEN=` | NotificationE2ETest | Token for push injection |
| `WAITING_FOR_PUSH` | NotificationE2ETest | Ready for external push |
| `PUSH_RECEIVED` | MyFirebaseMessagingService + Test | FCM message arrived |
| `NOTIFICATION_POSTED` | NotificationHelper | System notification created |
| `FULLSCREEN_LAUNCHED` | FullScreenNotificationActivity | Full-screen UI opened |
| `ALARM_SCHEDULED` | NotificationHelper | Sound repeats scheduled |
| `ALARM_FIRED` | SoundRepeatReceiver | AlarmManager repeat fired |

## Execution Flow

### Option A: Two-Phase (Recommended for CI)

**Phase 1: Run test, extract token**
```powershell
cd apps\wawapp_driver\test_lab
.\run-testlab-fcm.ps1 -ProjectId "your-firebase-project" -Build $true
```

**Phase 2: Send pushes with extracted token**
```powershell
.\fcm-certification.ps1 `
  -Token (Get-Content .\extracted_fcm_token.txt) `
  -ServiceAccountJson "path\to\service-account.json" `
  -ProjectId "your-firebase-project" `
  -Scenario all
```

### Option B: Single Command (Auto-push)
```powershell
.\run-testlab-fcm.ps1 `
  -ProjectId "your-firebase-project" `
  -Build $true `
  -SendPush `
  -ServiceAccountJson "path\to\service-account.json"
```

### Option C: Manual gcloud + Push

**Build APKs:**
```powershell
cd apps\wawapp_driver\android
.\gradlew.bat assembleDebug assembleDebugAndroidTest
```

**Run on Test Lab:**
```bash
gcloud firebase test android run \
  --type instrumentation \
  --app app/build/outputs/apk/debug/app-debug.apk \
  --test app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
  --device model=a15,version=34,locale=en,orientation=portrait \
  --timeout 5m \
  --no-auto-google-login \
  --project your-firebase-project
```

**Extract token from output:**
```powershell
# From Test Lab console output or downloaded logcat:
Select-String "FCM_TOKEN=" testlab_logcat.txt | ForEach-Object { $_.Line -match "FCM_TOKEN=(.+)" | Out-Null; $Matches[1] }
```

**Send push:**
```powershell
.\fcm-certification.ps1 -Token "extracted_token" -ServiceAccountJson "sa.json" -ProjectId "proj" -Scenario wave_offer
```

## Test Scenarios

### wave_offer
- Triggers: `MyFirebaseMessagingService.onMessageReceived`
- Routes to: `handleCriticalNotification` → `NotificationHelper.showFullScreenNotification`
- Launches: `FullScreenNotificationActivity`
- Schedules: 7 AlarmManager sound repeats
- Validates: Full notification pipeline end-to-end

### fullscreen (new_order)
- Same as wave_offer but with `notificationType=new_order`
- Validates: Wake lock, keyguard dismiss, screen-on behavior

### qa_test
- Triggers: `onMessageReceived` → certification marker write
- Does NOT route to any notification display (unknown type)
- Validates: Raw FCM delivery without notification side effects

### dedup
- Sends same orderId+round twice with 3s gap
- First: should display notification
- Second: should be dropped by `isOfferAlreadySeen()`
- Validates: SharedPreferences dedup logic

## Service Account Setup

1. Go to Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Save as `service-account.json` (DO NOT commit)
4. Ensure the SA has `Firebase Cloud Messaging API` role

## What Gets Validated

| Component | Validation |
|-----------|-----------|
| FCM Token | Real token from Firebase on physical device |
| FCM Delivery | Google servers accept and deliver push |
| MyFirebaseMessagingService | `onMessageReceived` fires, logs PUSH_RECEIVED |
| Dedup Logic | Second identical push is dropped |
| NotificationHelper | Notification posted with correct channel |
| FullScreenNotificationActivity | Activity launches over lock screen |
| AlarmManager | Sound repeats scheduled and fire |
| Android 14 | USE_FULL_SCREEN_INTENT permission check |
| Wake Behavior | WakeLock + setTurnScreenOn |
| Notification Channels | Correct importance, sound, bypassDnd |

## Troubleshooting

### Token not appearing in logs
- Ensure `google-services.json` is valid for the Firebase project
- Check that Firebase is initialized (app must fully launch)
- Verify network connectivity on Test Lab device

### Push not received
- Verify token is fresh (tokens expire if app is reinstalled)
- Check FCM v1 API response for errors
- Ensure `data` payload (not `notification` block) is used
- Verify `android.priority = "high"` in payload

### FullScreenNotificationActivity not launching
- Check `USE_FULL_SCREEN_INTENT` permission in logcat
- On Android 14+, this permission may be revoked by default
- Verify `SYSTEM_ALERT_WINDOW` for unlocked-screen launches
- Check `canDrawOverlays()` in logcat

### Dedup not working
- Dedup uses `offerId` as primary key, falls back to `orderId_round`
- TTL is 60 minutes — ensure test sends within window
- Check `fcm_dedup` SharedPreferences in logcat

### AlarmManager not firing
- Android 12+ requires `SCHEDULE_EXACT_ALARM` permission
- Check logcat for "Exact alarm permission not granted"
- Test Lab devices may have battery optimization enabled

### Build failures
- Ensure `assembleDebugAndroidTest` succeeds locally first
- Check that `GrantPermissionRule` resolves (needs `rules:1.6.1`)
- Verify no ProGuard issues (test APK uses debug build)

---

## Agentic Orchestration Contract

This pipeline is designed for future integration with autonomous QA agents.

### Structured Event Protocol

All components emit machine-parseable NDJSON on logcat tag `WAWAPP_EVENT`:

```json
{"event":"TOKEN_ACQUIRED","ts":1719000000000,"phase":"phase_1","data":{"token":"abc...","length":163}}
{"event":"AWAITING_STIMULUS","ts":1719000001000,"phase":"phase_3","data":{"stimulus_type":"fcm_push","timeout_seconds":180,"token":"abc...","ready":true}}
{"event":"PUSH_PROCESSED","ts":1719000005000,"phase":"runtime","data":{"type":"wave_offer","orderId":"cert_order_123","sentTime":1719000004000,"foreground":true}}
```

### Agent Integration Modes

| Agent Type | Integration Point |
|-----------|-------------------|
| Antigravity | Stream `adb logcat -s WAWAPP_EVENT:*`, react to `AWAITING_STIMULUS` |
| MCP Runtime | Call `fcm-certification.ps1 -OutputFormat json`, parse NDJSON stdout |
| Appium | Launch instrumentation, poll logcat for events, inject pushes |
| Replay Framework | Correlate via `RunId` across device + orchestration events |

### JSON Output Mode

```powershell
# Agent-consumable NDJSON output (no colors, no human text)
.\fcm-certification.ps1 -Token $t -ServiceAccountJson sa.json -ProjectId proj -OutputFormat json

# With file persistence for post-hoc analysis
.\fcm-certification.ps1 -Token $t -ServiceAccountJson sa.json -ProjectId proj -OutputFormat json -OutputFile results.ndjson

# With correlation ID for multi-step workflows
.\fcm-certification.ps1 -Token $t -ServiceAccountJson sa.json -ProjectId proj -OutputFormat json -RunId "workflow_abc123"
```

### Scenario Manifest

Machine-readable scenario definitions live in `test_lab/scenarios/fcm_certification.yaml`.
Agents can parse this to:
- Discover available test scenarios
- Generate correct FCM payloads
- Understand expected device-side events
- Validate postconditions
- Compose multi-scenario workflows

### Event Flow for Agents

```
┌─────────────────────────────────────────────────────────────────┐
│  Device (logcat -s WAWAPP_EVENT)                                │
│                                                                 │
│  SCENARIO_START ──→ TOKEN_ACQUIRED ──→ AWAITING_STIMULUS        │
│                                              │                  │
│                                              │ (agent sends     │
│                                              │  push here)      │
│                                              ▼                  │
│  PUSH_PROCESSED ──→ NOTIFICATION_POSTED ──→ FULLSCREEN_LAUNCHED │
│                                              │                  │
│  STIMULUS_RECEIVED ──→ ASSERTION_RESULT ──→ SCENARIO_END        │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  Orchestration Script (stdout, json mode)                       │
│                                                                 │
│  ORCHESTRATION_START ──→ PUSH_SENT ──→ PUSH_ACCEPTED            │
│                                              │                  │
│  ASSERTION_RESULT ──→ ORCHESTRATION_END (exit 0 or 1)           │
└─────────────────────────────────────────────────────────────────┘
```

### File Artifacts for Agents

| Artifact | Path | Purpose |
|----------|------|--------|
| FCM Token | `files/fcm_token.txt` | Push injection target |
| Event Log | `files/certification_events.ndjson` | Full event history |
| Orchestration Log | `-OutputFile results.ndjson` | Script-side events |

### Exit Codes

| Code | Meaning | Agent Action |
|------|---------|-------------|
| 0 | All checks passed | Continue workflow |
| 1 | One or more failures | Retry or escalate |

### Extending with New Scenarios

1. Add scenario definition to `scenarios/fcm_certification.yaml`
2. Add payload generator function in `fcm-certification.ps1`
3. Add to `$Scenario` ValidateSet
4. Device-side events are automatic (existing markers cover all paths)
