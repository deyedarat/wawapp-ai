# Phase B Test Checklist

## Pre-Deployment Tests

### 1. Function Compilation & Deployment
- [ ] `npm run build` succeeds without errors
- [ ] Functions deploy successfully: `firebase deploy --only functions:trackOrderAcceptance,notifyUnassignedOrders`
- [ ] Both functions appear in Firebase Console Functions list
- [ ] `trackOrderAcceptance` has onUpdate trigger configured
- [ ] `notifyUnassignedOrders` scheduler runs every 1 minute

### 2. Acceptance Tracking Logic
- [ ] `acceptedAt` is set when order status changes to 'accepted' with assignedDriverId
- [ ] `acceptedAt` is NOT overwritten if already exists
- [ ] `acceptConfirmSentAt` is set to null when order is accepted
- [ ] Function handles race conditions gracefully
- [ ] No `acceptedAt` set for orders that become accepted without assignedDriverId

### 3. Confirmation Notification Logic
- [ ] Query finds orders: status='accepted', acceptedAt <= 5min ago, acceptConfirmSentAt=null
- [ ] Notifications sent only after exactly 5+ minutes from acceptance
- [ ] `acceptConfirmSentAt` is set after successful notification
- [ ] No duplicate notifications sent (idempotency check)
- [ ] Invalid FCM tokens are handled gracefully

## Integration Tests

### 4. End-to-End Scenarios

#### Scenario A: Normal Acceptance Flow
1. [ ] Client creates order (status: matching)
2. [ ] Driver accepts order (status: accepted, assignedDriverId set)
3. [ ] `trackOrderAcceptance` sets `acceptedAt` timestamp
4. [ ] After 5+ minutes, `notifyUnassignedOrders` sends confirmation
5. [ ] `acceptConfirmSentAt` is set, preventing duplicate notifications

#### Scenario B: Order Status Changes After Acceptance
1. [ ] Driver accepts order (acceptedAt set)
2. [ ] Order moves to 'onRoute' before 5 minutes
3. [ ] No confirmation sent (status != 'accepted')
4. [ ] Order moves back to 'accepted' (edge case)
5. [ ] Confirmation sent if still within rules

#### Scenario C: Driver Changes After Acceptance
1. [ ] Driver A accepts order (acceptedAt set, assignedDriverId = A)
2. [ ] Admin reassigns to Driver B (assignedDriverId = B)
3. [ ] No confirmation sent to Driver A (assignedDriverId changed)
4. [ ] New acceptedAt should be set for Driver B

### 5. Timing Accuracy
- [ ] Confirmations sent at 5:00-5:59 minutes after acceptance (not before 5:00)
- [ ] Function processes orders in reasonable time (<2 minutes execution)
- [ ] Multiple orders accepted simultaneously are handled correctly
- [ ] Timezone handling is correct (Africa/Nouakchott)

### 6. Error Handling
- [ ] Missing acceptedAt field is handled gracefully
- [ ] Invalid assignedDriverId is handled gracefully
- [ ] Driver document not found is handled gracefully
- [ ] FCM token errors don't crash function
- [ ] Firestore transaction failures are logged properly

## Production Monitoring

### 7. Logs & Analytics
- [ ] `[TrackAcceptance]` logs appear for order acceptances
- [ ] `[NotifyAcceptConfirm]` logs appear for confirmation processing
- [ ] Analytics events logged: `order_acceptance_tracked`
- [ ] Error logs include sufficient debugging information
- [ ] Success/failure counts are tracked per execution

### 8. Data Consistency
- [ ] All accepted orders have `acceptedAt` timestamp
- [ ] `acceptConfirmSentAt` is only set after successful notification
- [ ] No orphaned confirmation notifications (driver changed, order cancelled, etc.)
- [ ] Field values are consistent with order status

### 9. Performance Impact
- [ ] Phase A (unassigned orders) still works correctly
- [ ] Combined function execution time is reasonable (<5 minutes)
- [ ] Memory usage stays within 512MB limit
- [ ] No significant increase in Firestore read/write operations

### 10. Notification Delivery
- [ ] Confirmations appear on driver devices
- [ ] Notification channel "acceptance_confirmations" works correctly
- [ ] Arabic text displays correctly
- [ ] Deep linking works (opens driver app to order details)
- [ ] Notification sound and vibration work

## Edge Cases

### 11. Race Conditions
- [ ] Order accepted and immediately cancelled
- [ ] Order accepted by multiple drivers simultaneously
- [ ] Driver goes offline after acceptance but before confirmation
- [ ] Order data changes during confirmation processing
- [ ] Function runs multiple times concurrently

### 12. Data Migration
- [ ] Existing accepted orders without `acceptedAt` are handled gracefully
- [ ] Orders with missing `acceptConfirmSentAt` field work correctly
- [ ] Backward compatibility with existing order structure

## Success Criteria

- [ ] Exactly one confirmation sent per accepted order
- [ ] Confirmations sent 5+ minutes after acceptance
- [ ] No duplicate confirmations
- [ ] Phase A functionality unaffected
- [ ] Function performance acceptable (<5 min execution, <512MB memory)
- [ ] Error rate <5% of executions
- [ ] All accepted orders have proper timestamps