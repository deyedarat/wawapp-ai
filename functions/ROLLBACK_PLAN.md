# Dispatch V3 Deployment — Rollback Plan
# Date: 2026-04-16
# Deployment ID: firebase-functions-hash:8f25e6435d50c182abee454aeab9eb9171769796

## Previous Stable Version
- Hash before deploy: check `firebase functions:log` audit entries for prior hash
- The previous version is cached in GCF artifact registry

## Rollback Command (git-based)
```powershell
# 1. Revert to previous commit
git stash   # or git checkout <previous-commit-sha>

# 2. Rebuild
cd functions && npm run build

# 3. Redeploy same 5 functions
npx firebase deploy --only functions:notifyNewOrderV2,functions:processExpiredWaves,functions:acceptOrderV2,functions:rejectOffer,functions:processTripStartFee --project wawapp-952d6
```

## Rollback Triggers (any ONE of these = rollback immediately)
1. Notifications not reaching drivers for >5 minutes after order creation
2. dispatch_queue not being populated for new matching orders
3. ARCHITECTURE VIOLATION errors in Cloud Logging
4. Circuit breaker CRITICAL logs appearing repeatedly
5. processExpiredWaves failing with status != 'ok'
6. Widespread "undefined" Firestore write errors in notifyNewOrderV2 logs
7. acceptOrderV2 returning internal_error for >3 consecutive attempts

## Monitoring Queries (Cloud Logging)
```
# Check for architecture violations
jsonPayload.message =~ "ARCHITECTURE VIOLATION"

# Check for circuit breaker triggers
jsonPayload.tag = "CircuitBreaker"

# Check intake failures
jsonPayload.tag = "DispatchIntake" AND jsonPayload.result = "exception"

# Check notification failures
jsonPayload.metric = "notification_failed"
```

## Functions Deployed
| Function | Trigger | Region |
|----------|---------|--------|
| notifyNewOrderV2 | Firestore onCreate orders/{orderId} | us-central1 |
| processExpiredWaves | Pub/Sub schedule (* * * * *) | us-central1 |
| acceptOrderV2 | HTTPS callable | us-central1 |
| rejectOffer | HTTPS callable | us-central1 |
| processTripStartFee | Firestore onUpdate orders/{orderId} | us-central1 |

## Safe to Delete (if rollback needed)
- dispatch_stuck_orders collection (new, created by circuit breaker)
- No schema changes to existing collections
