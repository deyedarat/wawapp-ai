# Phase C Test Checklist

## Pre-Deployment Tests

### 1. Function Compilation & Deployment
- [ ] `npm run build` succeeds without errors
- [ ] Functions deploy successfully: `firebase deploy --only functions:processTripStartFee,enforceOrderExclusivity`
- [ ] Both functions appear in Firebase Console Functions list
- [ ] onUpdate and onWrite triggers are configured correctly

### 2. Fee Calculation Logic
- [ ] 10% fee calculated correctly: `Math.round(orderPrice * 0.1)`
- [ ] Rounding works: 155 MRU → 16 MRU, 154 MRU → 15 MRU
- [ ] Zero price orders handled gracefully (0 MRU fee)
- [ ] Large price orders handled correctly (no overflow)

### 3. Idempotency Testing
- [ ] First accepted → onRoute transition deducts fee
- [ ] Second accepted → onRoute transition (retry) does NOT deduct fee
- [ ] Ledger doc `${orderId}_start_fee` prevents double charging
- [ ] Function can run multiple times safely
- [ ] Concurrent executions handled correctly

## Core Functionality Tests

### 4. Sufficient Balance Scenarios
- [ ] Driver has exact fee amount: deduction succeeds
- [ ] Driver has more than fee: deduction succeeds, correct balance
- [ ] Wallet balance updated atomically
- [ ] Ledger transaction created with correct amounts
- [ ] startedAt timestamp set on order
- [ ] Order status remains 'onRoute'

### 5. Insufficient Balance Scenarios
- [ ] Driver has less than fee: deduction blocked
- [ ] Order status reverted to 'accepted'
- [ ] No ledger transaction created
- [ ] No startedAt timestamp set
- [ ] FCM notification sent to driver with required amount
- [ ] Driver can try again after topping up wallet

### 6. Atomic Transaction Testing
- [ ] All operations succeed together or fail together
- [ ] Wallet update and ledger creation are atomic
- [ ] Order status update is consistent with fee deduction
- [ ] No partial states (wallet deducted but no ledger, etc.)
- [ ] Transaction rollback works on any failure

## Integration Tests

### 7. End-to-End Trip Start Flow
1. [ ] Client creates order (status: matching)
2. [ ] Driver accepts order (status: accepted, assignedDriverId set)
3. [ ] Driver starts trip (status: onRoute)
4. [ ] Fee deducted from driver wallet
5. [ ] Ledger transaction created
6. [ ] Order locked with startedAt/lockedAt timestamps

### 8. Insufficient Balance Flow
1. [ ] Driver accepts order with insufficient wallet balance
2. [ ] Driver attempts to start trip (accepted → onRoute)
3. [ ] Status reverted to accepted
4. [ ] Driver receives "insufficient balance" notification
5. [ ] Driver tops up wallet
6. [ ] Driver successfully starts trip on retry

### 9. Order Exclusivity Testing
- [ ] Only assigned driver can transition order to onRoute
- [ ] Other drivers cannot see/accept orders with assignedDriverId set
- [ ] onRoute orders are locked (lockedAt timestamp set)
- [ ] Driver reassignments are logged for audit
- [ ] Multiple drivers cannot accept same order simultaneously

## Edge Cases & Error Handling

### 10. Race Conditions
- [ ] Multiple rapid status changes handled correctly
- [ ] Concurrent fee deduction attempts blocked by idempotency
- [ ] Order status changes during fee processing handled gracefully
- [ ] Driver wallet updates during transaction handled atomically

### 11. Data Consistency
- [ ] Missing driver wallet document handled gracefully
- [ ] Invalid order price values handled (negative, null, etc.)
- [ ] Missing assignedDriverId handled correctly
- [ ] Corrupted wallet balance data handled safely

### 12. Error Recovery
- [ ] Transaction failures revert order status
- [ ] FCM notification failures don't block fee processing
- [ ] Firestore permission errors logged properly
- [ ] Network timeouts handled with retries

## Security & Exclusivity Tests

### 13. Server-Side Guards
- [ ] Driver A cannot transition Driver B's accepted order
- [ ] Orders with lockedAt cannot be modified by other drivers
- [ ] Admin reassignments work but are logged
- [ ] Invalid driver IDs rejected
- [ ] Unauthorized status transitions blocked

### 14. Client-Side Integration
- [ ] Driver app hides orders assigned to other drivers
- [ ] Driver app disables actions for locked orders
- [ ] Wallet balance displayed correctly after fee deduction
- [ ] Transaction history shows trip start fees

## Performance & Monitoring

### 15. Function Performance
- [ ] Fee deduction completes within reasonable time (<10 seconds)
- [ ] Memory usage acceptable for transaction processing
- [ ] No significant impact on other order operations
- [ ] Concurrent order processing works correctly

### 16. Logging & Analytics
- [ ] `[TripStartFee]` logs appear for fee processing
- [ ] `[OrderExclusivity]` logs appear for exclusivity enforcement
- [ ] Analytics events logged: `trip_start_fee_deducted`
- [ ] Error logs include sufficient debugging information
- [ ] Audit logs capture driver reassignments

### 17. Data Integrity
- [ ] Wallet balances remain consistent (existing wallets collection)
- [ ] Transaction records match wallet changes (existing transactions collection)
- [ ] Order timestamps are accurate
- [ ] No orphaned transactions or inconsistent states

## Production Readiness

### 18. Wallet Management
- [ ] Driver wallet creation process works (uses existing wallets collection)
- [ ] Wallet top-up functionality integrated
- [ ] Balance display in driver app accurate
- [ ] Transaction history accessible to drivers (existing transactions collection)

### 19. Notification Delivery
- [ ] Insufficient balance notifications reach drivers
- [ ] Arabic text displays correctly
- [ ] Notification channel "wallet_notifications" works
- [ ] Deep linking to wallet/top-up screen works

### 20. Rollback & Recovery
- [ ] Functions can be disabled if needed
- [ ] Manual wallet adjustments possible for support (existing wallets collection)
- [ ] Transaction records can be audited/reversed if needed (existing transactions collection)
- [ ] Order status can be manually corrected

## Success Criteria

- [ ] 10% fee deducted exactly once per trip start
- [ ] No double charging under any circumstances
- [ ] Insufficient balance properly blocks trip start
- [ ] Order exclusivity enforced server-side
- [ ] Atomic transactions maintain data consistency
- [ ] Error rate <1% of trip starts
- [ ] Function performance <10 seconds per execution