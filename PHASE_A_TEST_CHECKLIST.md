# Phase A Test Checklist

## Pre-Deployment Tests

### 1. Function Compilation & Deployment
- [ ] `npm run build` succeeds without errors
- [ ] Function deploys successfully: `firebase deploy --only functions:notifyUnassignedOrders`
- [ ] Function appears in Firebase Console Functions list
- [ ] Cloud Scheduler job is created automatically

### 2. Basic Function Logic
- [ ] Function triggers every 1 minute (check Cloud Scheduler)
- [ ] Function processes unassigned orders (status: requested/assigning/matching, assignedDriverId: null)
- [ ] Function skips assigned orders (assignedDriverId != null)
- [ ] Function skips completed/cancelled/expired orders
- [ ] Function handles empty result set gracefully

### 3. Driver Eligibility
- [ ] Only online drivers (`isOnline: true`) receive notifications
- [ ] Only drivers within 10km radius receive notifications
- [ ] Only drivers with valid FCM tokens receive notifications
- [ ] Drivers with stale locations (>5 minutes) are excluded
- [ ] Drivers with inaccurate locations (>100m accuracy) are excluded

### 4. Notification Limits
- [ ] Driver receives max 10 notifications per order
- [ ] 11th notification is blocked with "notification_limit_reached" error
- [ ] Notification count is tracked in `driver_order_notifications` collection
- [ ] Count increments correctly after each successful notification

### 5. Deduplication & Idempotency
- [ ] Function can be run multiple times without duplicate notifications
- [ ] Notification count tracking prevents over-notification
- [ ] Invalid FCM tokens are removed from driver profiles
- [ ] Function handles Firestore race conditions gracefully

## Integration Tests

### 6. End-to-End Scenarios

#### Scenario A: New Unassigned Order
1. [ ] Client creates order (status: matching, assignedDriverId: null)
2. [ ] `notifyNewOrder` function sends initial notifications
3. [ ] After 1 minute, `notifyUnassignedOrders` sends reminder notifications
4. [ ] Driver accepts order (assignedDriverId set)
5. [ ] Next `notifyUnassignedOrders` run skips this order

#### Scenario B: Order Expiration
1. [ ] Order remains unassigned for 10 minutes
2. [ ] `expireStaleOrders` changes status to "expired"
3. [ ] Next `notifyUnassignedOrders` run skips expired order

#### Scenario C: Notification Limit Reached
1. [ ] Order remains unassigned for 10+ minutes
2. [ ] Driver receives exactly 10 notifications
3. [ ] 11th notification attempt is blocked
4. [ ] Other eligible drivers still receive notifications

### 7. Error Handling
- [ ] Invalid FCM tokens are handled gracefully
- [ ] Missing pickup coordinates are logged and skipped
- [ ] Firestore permission errors don't crash function
- [ ] Network timeouts are handled with retries
- [ ] Function completes within 5-minute timeout

### 8. Performance & Scalability
- [ ] Function processes 100 orders within timeout
- [ ] Parallel notification sending works correctly
- [ ] Memory usage stays within 512MB limit
- [ ] Function execution time is reasonable (<2 minutes typical)

## Production Monitoring

### 9. Logs & Analytics
- [ ] Function execution logs appear in Cloud Functions console
- [ ] Analytics events are logged: `unassigned_orders_notification_batch`
- [ ] Error logs include sufficient debugging information
- [ ] Success/failure counts are tracked per execution

### 10. Firestore Impact
- [ ] `driver_order_notifications` collection grows as expected
- [ ] No unexpected read/write spikes in other collections
- [ ] Firestore rules allow function access to required collections
- [ ] TTL policy (if implemented) cleans up old tracking documents

### 11. FCM Delivery
- [ ] Notifications appear on driver devices
- [ ] Notification channel "unassigned_orders" works correctly
- [ ] Deep linking works (opens driver app to nearby orders)
- [ ] Notification sound and vibration work
- [ ] Arabic text displays correctly

## Rollback Plan

### 12. Emergency Procedures
- [ ] Function can be disabled via Firebase Console
- [ ] Cloud Scheduler job can be paused
- [ ] Previous function version can be restored
- [ ] `driver_order_notifications` collection can be cleared if needed

## Success Criteria

- [ ] Function runs reliably every minute
- [ ] Drivers receive timely notifications for unassigned orders
- [ ] No driver receives more than 10 notifications per order
- [ ] No duplicate notifications are sent
- [ ] Function performance is acceptable (<2 min execution, <512MB memory)
- [ ] Error rate is <5% of executions