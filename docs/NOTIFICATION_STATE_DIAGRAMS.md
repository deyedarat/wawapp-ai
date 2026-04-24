# WawApp Notification System — State Diagrams

## 1. Order Lifecycle & Dispatch Waves

```mermaid
stateDiagram-v2
    direction TB

    [*] --> ClientCreatesOrder

    state "Order Created" as ClientCreatesOrder
    state "matching" as Matching
    state "accepted" as Accepted
    state "onRoute" as OnRoute
    state "completed" as Completed
    state "expired" as Expired
    state "cancelledByClient" as CancelledClient
    state "cancelledByDriver" as CancelledDriver

    ClientCreatesOrder --> Matching : notifyNewOrderV2\n(Firestore onCreate)

    state "Dispatch Engine" as DispatchEngine {
        state "dispatch_queue" as Queue
        state "Wave 1" as W1
        state "Wave 2" as W2
        state "Wave 3" as W3
        state "Wave 4+" as W4

        Queue --> W1 : enqueueOrder()\n1 driver, 3km, 45s
        W1 --> W2 : Cloud Task fires\nafter 45s TTL
        W2 --> W3 : Cloud Task fires\nafter 45s TTL
        W3 --> W4 : Cloud Task fires\nafter 45s TTL
        W4 --> W4 : Repeat every 60s\n5 drivers, 15km

        state "Per Wave" as PerWave {
            [*] --> FindDrivers
            FindDrivers --> SendOffers : eligibleDrivers > 0
            FindDrivers --> WaitExpiry : no drivers found
            SendOffers --> FCM_Send
            FCM_Send --> OfferSent : success
            FCM_Send --> TokenInvalid : invalid/expired token
            TokenInvalid --> RemoveToken : delete fcmToken\nfrom drivers/
            WaitExpiry --> [*]
            OfferSent --> [*]
        }
    }

    Matching --> DispatchEngine
    DispatchEngine --> Matching : waves continue

    Matching --> Accepted : driver accepts offer\n(acceptOrderV2)
    Matching --> Expired : expireStaleOrders\n(8 min timeout)
    Matching --> CancelledClient : client cancels

    Accepted --> OnRoute : driver starts trip\n(processTripStartFee)
    Accepted --> CancelledDriver : driver cancels\n(handleDriverCancellation)
    Accepted --> CancelledClient : client cancels

    OnRoute --> Completed : driver ends trip
    OnRoute --> CancelledClient : client cancels

    Expired --> [*]
    CancelledClient --> [*]
    CancelledDriver --> Matching : order returns\nto matching
    Completed --> [*]
```

## 2. FCM Delivery Pipeline (New Order)

```mermaid
stateDiagram-v2
    direction TB

    state "Cloud Function\nsendOfferNotification()" as CF
    state "FCM Server" as FCM

    [*] --> CF : dispatch engine\ntriggers wave

    CF --> ValidatePayload
    ValidatePayload --> BuildMessage : ✅ normalized
    ValidatePayload --> ArchViolation : ❌ raw order fields\ndetected

    BuildMessage --> FCM : data-only payload\n(no notification block)

    FCM --> DeviceOnline : device reachable
    FCM --> DeviceOffline : device unreachable
    FCM --> InvalidToken : token expired/invalid

    InvalidToken --> CleanupToken : delete fcmToken\nfrom drivers/{id}
    CleanupToken --> [*] : {success: false}

    DeviceOffline --> [*] : FCM queues\n(TTL = wave TTL)

    DeviceOnline --> NativeHandler : MyFirebaseMessaging\nService.kt

    state "App State Check" as AppStateCheck {
        NativeHandler --> ForegroundCheck
        ForegroundCheck --> IsForeground : ProcessLifecycleOwner\n.isAtLeast(STARTED)
        ForegroundCheck --> IsBackground
    }

    state "Foreground Path" as FGPath {
        IsForeground --> CancelSystemNotif : cancel orderId.hashCode()
        CancelSystemNotif --> FcmForegroundBridge : EventChannel\nto Flutter
        FcmForegroundBridge --> FlutterDedup
    }

    state "Background Path" as BGPath {
        IsBackground --> VerifyOrder : Firestore read\nisOrderStillMatching()
        VerifyOrder --> OrderStale : status ≠ matching
        VerifyOrder --> OrderValid : status = matching
        OrderStale --> DropNotif : notification dropped
        OrderValid --> NativeNotification
        NativeNotification --> CallStyleNotif : Android 12+\nCallStyle
        NativeNotification --> LegacyFullScreen : Android < 12
        CallStyleNotif --> FullScreenActivity : startActivity()\nFullScreenNotification\nActivity
        LegacyFullScreen --> FullScreenActivity
        FullScreenActivity --> SoundRepeats : schedule 3x\nvia Handler +\nAlarmManager
    }

    ArchViolation --> [*] : throw Error
    DropNotif --> [*]
```

## 3. Flutter Foreground Dedup Pipeline

```mermaid
stateDiagram-v2
    direction TB

    state "Incoming Message" as Incoming
    state "handleIncomingOffer()" as Central

    [*] --> Incoming

    Incoming --> Central : FcmForegroundBridge\nOR onMessage

    state "Dedup Pipeline" as Dedup {
        Central --> ExtractOfferKey : offerId or\norderId_round

        ExtractOfferKey --> PruneExpired : TTL sweep\n(10 min window)

        PruneExpired --> ReplayCheck : SharedPreferences\nlast_handled_offer_id
        ReplayCheck --> BlockReplay : ⛔ same as last\npersisted offer
        ReplayCheck --> MemoryCheck : ✅ not replayed

        MemoryCheck --> BlockDuplicate : ⛔ offerId in\n_seenOfferIds
        MemoryCheck --> RaceLock : ✅ not seen

        RaceLock --> BlockRace : ⛔ Completer active\nfor this offerId
        RaceLock --> AcquireLock : ✅ no race

        AcquireLock --> MarkSeen : _seenOfferIds[id] = now\npersist to SharedPrefs
        MarkSeen --> ProcessInner
    }

    BlockReplay --> [*] : logged: replay_blocked
    BlockDuplicate --> [*] : logged: dedup_blocked
    BlockRace --> [*] : logged: race_blocked

    state "Inner Handler" as Inner {
        ProcessInner --> PersistentDedup : messageId check\nvia NotificationDedupService
        PersistentDedup --> BlockPersistent : ⛔ already processed
        PersistentDedup --> ResolveType : ✅ new message

        ResolveType --> IsTripReminder : trip_start_reminder
        ResolveType --> IsFullScreen : new_order /\nwave_offer
        ResolveType --> IsTimeoutExpired : timeout_expired
        ResolveType --> IsOther : other types

        IsTripReminder --> CheckAccepted : Firestore read\n_isOrderStillAccepted()
        CheckAccepted --> DropStale : ❌ not accepted
        CheckAccepted --> ShowReminder : ✅ still accepted
        ShowReminder --> NavigateReminder : go('/trip-start-reminder')

        IsFullScreen --> CheckStale : _isStaleNotification()
        CheckStale --> DropStaleOrder : ⛔ recently processed
        CheckStale --> CheckBusy : ✅ not stale

        CheckBusy --> DropBusy : ⛔ driver on\nactive trip
        CheckBusy --> CheckRejected : ✅ not busy

        CheckRejected --> DropRejected : ⛔ driver rejected\nthis order
        CheckRejected --> CheckGuard : ✅ not rejected

        CheckGuard --> DropGuard : ⛔ another full-screen\nalready active
        CheckGuard --> ShowFullScreen : ✅ all checks pass

        ShowFullScreen --> NavigateFS : go('/full-screen-notification')

        IsTimeoutExpired --> CancelLocal : cancel local notif
        CancelLocal --> GoNearby : go('/nearby')

        IsOther --> ShowHeadsUp : local notification\n(heads-up)
    }

    BlockPersistent --> [*]
    DropStale --> [*]
    DropStaleOrder --> [*]
    DropBusy --> [*]
    DropRejected --> [*]
    DropGuard --> [*]
    NavigateReminder --> [*]
    NavigateFS --> [*]
    GoNearby --> [*]
    ShowHeadsUp --> [*]
```

## 4. Trip Start Reminder (monitorAcceptedOrders)

```mermaid
stateDiagram-v2
    direction TB

    state "Cloud Scheduler\nevery 1 minute" as Scheduler
    state "monitorAcceptedOrders()" as Monitor

    [*] --> Scheduler
    Scheduler --> Monitor

    Monitor --> QueryAccepted : orders where\nstatus = 'accepted'\nlimit 50

    QueryAccepted --> NoOrders : empty
    QueryAccepted --> ProcessBatch : found orders

    NoOrders --> [*] : log: no orders

    state "Per Order" as PerOrder {
        ProcessBatch --> CheckAcceptedAt
        CheckAcceptedAt --> SkipNoTimestamp : ❌ missing acceptedAt
        CheckAcceptedAt --> CalcElapsed : ✅ has acceptedAt

        CalcElapsed --> SkipTooEarly : < 3 min elapsed
        CalcElapsed --> CheckIdempotent : ≥ 3 min elapsed

        CheckIdempotent --> SkipRecent : lastReminderSentAt\n< 3 min ago
        CheckIdempotent --> DetermineLevel : ✅ ready to send

        state "Escalation" as Escalation {
            DetermineLevel --> Normal : 0–6 min\n"هل وصلت للعميل؟"
            DetermineLevel --> Warning : 6–15 min\n"⚠️ تأخير"
            DetermineLevel --> Critical : 15+ min\n"🚨 تحذير نهائي"
        }

        Normal --> SendFCM
        Warning --> SendFCM
        Critical --> SendFCM
        Critical --> NotifyAdmin : writeAdminNotification()\n(once per order)
        Critical --> LogViolation : drivers/{id}/violations\n(idempotent)

        SendFCM --> ReadToken : drivers/{id}.fcmToken
        ReadToken --> NoToken : ❌ missing
        ReadToken --> SendMessage : ✅ has token

        SendMessage --> FCMSuccess : ✅ delivered
        SendMessage --> FCMFail : ❌ error

        FCMSuccess --> UpdateOrder : lastReminderSentAt\nreminderCount++
        FCMFail --> HandleTokenError : invalid token?\ndelete fcmToken
    }

    SkipNoTimestamp --> [*]
    SkipTooEarly --> [*]
    SkipRecent --> [*]
    NoToken --> [*]
    HandleTokenError --> [*]
    UpdateOrder --> [*]
    NotifyAdmin --> [*]
```

## 5. Trip Reminder Delivery (Foreground vs Background)

```mermaid
stateDiagram-v2
    direction TB

    state "FCM: trip_start_reminder" as FCMMsg

    [*] --> FCMMsg

    FCMMsg --> NativeHandler : MyFirebaseMessagingService

    NativeHandler --> FGCheck : isAppInForeground()

    state "FOREGROUND" as FG {
        FGCheck --> FGBridge : ✅ foreground
        FGBridge --> FlutterHandler : FcmForegroundBridge\n→ handleIncomingOffer()
        FlutterHandler --> FlutterDedup : dedup pipeline
        FlutterDedup --> FirestoreCheck : _isOrderStillAccepted()\nSource.server
        FirestoreCheck --> DropCancelled : ❌ order cancelled/\ncompleted/expired
        FirestoreCheck --> ShowFlutterUI : ✅ still accepted
        ShowFlutterUI --> TripReminderScreen : go('/trip-start-reminder')\nAmber full-screen\nFlutter widget
    }

    state "BACKGROUND / KILLED" as BG {
        FGCheck --> BGHandler : ❌ background
        BGHandler --> VerifyAccepted : isOrderStillAccepted()\nFirestore read on Thread
        VerifyAccepted --> DropStale : ❌ not accepted
        VerifyAccepted --> ShowNative : ✅ accepted

        ShowNative --> NativeNotif : NotificationHelper\n.showFullScreenNotification()\nchannel: trip_reminders_v9
        NativeNotif --> SoundRepeats : 3x sound via\nHandler + AlarmManager

        ShowNative --> LaunchActivity : TripReminderActivity\n(amber native UI)
        LaunchActivity --> VerifyAgain : verifyOrderStatus()\nFirestore check on open
        VerifyAgain --> AutoClose : ❌ order no longer\naccepted → finish()
        VerifyAgain --> ShowTimer : ✅ show elapsed\ntimer + buttons
    }

    state "User Actions" as Actions {
        ShowTimer --> StartTrip : "بدأت الرحلة"\n→ MainActivity\naction=start_trip
        ShowTimer --> NotYet : "لم أصل بعد"\n→ finish()
        TripReminderScreen --> FlutterStartTrip : "بدأت الرحلة"\n→ transition(onRoute)
        TripReminderScreen --> FlutterDismiss : "لم أصل بعد"\n→ go('/active-order')
    }

    DropCancelled --> [*]
    DropStale --> [*]
    AutoClose --> [*]
    StartTrip --> [*]
    NotYet --> [*]
    FlutterStartTrip --> [*]
    FlutterDismiss --> [*]
```

## 6. Order Status Change Notifications (notifyOrderEvents)

```mermaid
stateDiagram-v2
    direction TB

    state "Firestore Trigger\norders/{orderId}\nonUpdate" as Trigger

    [*] --> Trigger

    Trigger --> CheckStatusChange : before.status\n≠ after.status?
    CheckStatusChange --> NoChange : same status → exit
    CheckStatusChange --> GetConfig : status changed

    state "Notification Config" as Config {
        GetConfig --> DriverAccepted : matching → accepted\n"تم قبول طلبك"\n→ client
        GetConfig --> DriverOnRoute : accepted → onRoute\n"السائق في الطريق"\n→ client
        GetConfig --> TripCompleted : onRoute → completed\n"اكتملت الرحلة"\n→ client
        GetConfig --> OrderExpired : matching → expired\n"انتهت مهلة الطلب"\n→ client
        GetConfig --> CancelledByClient : accepted → cancelledByClient\n"ألغى العميل الرحلة"\n→ driver
        GetConfig --> NoConfig : no matching config\n→ exit
    }

    state "Send Notification" as Send {
        DriverAccepted --> IdempotencyCheck
        DriverOnRoute --> IdempotencyCheck
        TripCompleted --> IdempotencyCheck
        OrderExpired --> IdempotencyCheck
        CancelledByClient --> IdempotencyCheck

        IdempotencyCheck --> AlreadySent : ✅ notification_log\ndoc exists → skip
        IdempotencyCheck --> FetchToken : ❌ not sent yet

        FetchToken --> FromUsers : client notifications\n→ users/{ownerId}
        FetchToken --> FromDrivers : driver notifications\n→ drivers/{driverId}

        FromUsers --> NoToken : ❌ no fcmToken
        FromDrivers --> NoToken
        FromUsers --> SendFCM : ✅ has token
        FromDrivers --> SendFCM

        SendFCM --> Success : ✅ message sent
        SendFCM --> InvalidToken : ❌ token invalid
        SendFCM --> OtherError : ❌ FCM error

        Success --> LogSent : write notification_log\n(idempotency)
        InvalidToken --> DeleteToken : remove fcmToken\nfrom user doc
    }

    NoChange --> [*]
    NoConfig --> [*]
    AlreadySent --> [*]
    NoToken --> [*]
    LogSent --> [*]
    DeleteToken --> [*]
    OtherError --> [*]
```

## 7. Expiration & Cleanup

```mermaid
stateDiagram-v2
    direction TB

    state "Cloud Scheduler\nevery 2 minutes" as Scheduler
    state "expireStaleOrders()" as Expire

    [*] --> Scheduler
    Scheduler --> Expire

    Expire --> QueryStale : orders where\nstatus = matching\nassignedDriverId = null\ncreatedAt < now - 8min

    QueryStale --> NoStale : empty → exit
    QueryStale --> BatchExpire : found stale orders

    BatchExpire --> UpdateStatus : status → 'expired'\nexpiredAt → now

    UpdateStatus --> NotifyClient : FCM to client\n"لا يوجد سائق متاح"
    UpdateStatus --> AdminNotif : writeAdminNotification()\n"طلب منتهي الصلاحية"

    NotifyClient --> ClientHasToken : ✅ send FCM
    NotifyClient --> ClientNoToken : ❌ no token → skip

    state "Dispatch Cleanup" as Cleanup {
        note left of Cleanup
            processExpiredWavesForOrder()
            checks order status before
            each wave. If not 'matching',
            removes from dispatch_queue.
        end note
    }

    NoStale --> [*]
    ClientHasToken --> [*]
    ClientNoToken --> [*]
    AdminNotif --> [*]
```

## 8. Full System Overview

```mermaid
flowchart TB
    subgraph Client["Client App"]
        CO[Create Order]
        CC[Cancel Order]
        CR[Receive Notifications]
    end

    subgraph Firebase["Firebase Backend"]
        subgraph Dispatch["Dispatch Engine"]
            NNO[notifyNewOrderV2<br/>onCreate trigger]
            DE[dispatch engine<br/>enqueue → waves]
            PEW[processExpiredWaves<br/>fallback scheduler]
            HWE[handleWaveExpiration<br/>Cloud Tasks]
        end

        subgraph Monitors["Scheduled Monitors"]
            ESO[expireStaleOrders<br/>every 2 min]
            MAO[monitorAcceptedOrders<br/>every 1 min]
        end

        subgraph Events["Event Triggers"]
            NOE[notifyOrderEvents<br/>onUpdate trigger]
            PTF[processTripStartFee<br/>onUpdate trigger]
            HDC[handleDriverCancellation<br/>callable]
        end
    end

    subgraph Driver["Driver App"]
        subgraph Native["Kotlin Native Layer"]
            MFMS[MyFirebaseMessaging<br/>Service]
            NH[NotificationHelper<br/>CallStyle + Sound]
            FSNA[FullScreenNotification<br/>Activity]
            TRA[TripReminderActivity<br/>Amber UI]
        end

        subgraph Flutter["Flutter Layer"]
            NS[NotificationService<br/>Dedup Pipeline]
            FSS[FullScreenNotification<br/>Screen]
            TSRS[TripStartReminder<br/>Screen]
            AOS[ActiveOrder<br/>Screen]
        end
    end

    CO -->|Firestore write| NNO
    NNO -->|enqueueOrder| DE
    DE -->|FCM data-only| MFMS

    MFMS -->|background| NH
    MFMS -->|foreground| NS
    NH --> FSNA
    NH --> TRA
    NS --> FSS
    NS --> TSRS

    HWE -->|per-order task| DE
    PEW -->|fallback scan| DE

    ESO -->|expire matching| NOE
    MAO -->|trip_start_reminder| MFMS

    NOE -->|status change FCM| CR
    NOE -->|cancellation FCM| MFMS

    CC -->|status update| NOE
    HDC -->|return to matching| DE

    PTF -->|accepted→onRoute| AOS

    style FSNA fill:#1B5E20,color:#fff
    style TRA fill:#F59E0B,color:#fff
    style FSS fill:#1B5E20,color:#fff
    style TSRS fill:#F59E0B,color:#fff
    style ESO fill:#E53935,color:#fff
    style MAO fill:#F59E0B,color:#fff
```

---

## Legend

| Color | Meaning |
|-------|---------|
| 🟢 Green (#1B5E20) | New order full-screen (accept/reject) |
| 🟠 Amber (#F59E0B) | Trip start reminder (warning) |
| 🔴 Red (#E53935) | Expiration / cancellation |

## Key Failure Paths

| Failure | Guard | Recovery |
|---------|-------|----------|
| FCM token invalid/expired | Catch `messaging/invalid-registration-token` | Delete token from Firestore |
| Order cancelled during wave | `isOrderStillMatching()` check before notification | Drop notification silently |
| Trip reminder after cancellation | `_isOrderStillAccepted()` (Flutter) + `verifyOrderStatus()` (Kotlin) | Auto-close / don't navigate |
| Duplicate FCM delivery | 5-layer dedup: offerId TTL → replay → memory → race lock → persistent | Block at first matching layer |
| Wave stuck in 'sending' | `waveStatus` guard + fallback scheduler | Next scheduler run resets to 'idle' |
| Cloud Task fails to fire | `processExpiredWaves` runs every 2 min as fallback | Catches orphaned waves |
| Driver on active trip | `_isDriverOnActiveTrip()` Firestore check | Skip new order notification |
| Circuit breaker tripped | 3 consecutive failures per order / 10 global in 1 min | Move to `dispatch_stuck_orders` / pause 30s |
