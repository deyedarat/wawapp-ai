# Phase D Test Checklist

## Pre-Deployment Tests

### 1. Function Compilation & Deployment
- [ ] `npm run build` succeeds without errors
- [ ] Functions deploy successfully: `firebase deploy --only functions:createTopupRequest,approveTopupRequest,rejectTopupRequest,enforceWalletBalance`
- [ ] All functions appear in Firebase Console Functions list
- [ ] Callable functions are accessible via client SDKs

### 2. Top-up Request Creation
- [ ] Driver can create top-up request with valid amount
- [ ] Amount validation: rejects < 1,000 MRU
- [ ] Amount validation: rejects > 100,000 MRU
- [ ] Auth required: unauthenticated requests rejected
- [ ] Driver verification: non-driver users rejected
- [ ] Request created with correct fields and 'pending' status

### 3. Admin Approval Process
- [ ] Admin can approve pending requests
- [ ] Non-admin users cannot approve requests
- [ ] Idempotency: approving already-approved request returns success
- [ ] Wallet balance updated correctly
- [ ] Transaction record created with correct schema
- [ ] Request status updated to 'approved' with timestamps

### 4. Admin Rejection Process
- [ ] Admin can reject pending requests
- [ ] Non-admin users cannot reject requests
- [ ] Request status updated to 'rejected' with notes
- [ ] No wallet changes on rejection
- [ ] No transaction record created on rejection

## Integration Tests

### 5. End-to-End Top-up Flow
1. [ ] Driver creates top-up request (status: pending)
2. [ ] Admin approves request via callable function
3. [ ] Driver wallet balance increases by request amount
4. [ ] Transaction record created in transactions collection
5. [ ] Request status becomes 'approved' with admin details

### 6. Wallet Balance Enforcement
- [ ] Driver with zero balance cannot accept orders
- [ ] Order reverted to 'matching' when driver has insufficient balance
- [ ] Driver receives notification about insufficient balance
- [ ] Driver with positive balance can accept orders normally
- [ ] Balance check happens immediately on order acceptance

### 7. Atomic Transaction Testing
- [ ] Approval process is fully atomic (all succeed or all fail)
- [ ] Wallet update and transaction creation happen together
- [ ] Request status update is consistent with wallet changes
- [ ] No partial states (wallet updated but request still pending, etc.)

## Error Handling & Edge Cases

### 8. Invalid Requests
- [ ] Negative amounts rejected
- [ ] Zero amounts rejected
- [ ] Non-numeric amounts rejected
- [ ] Missing amount parameter rejected
- [ ] Invalid request IDs handled gracefully

### 9. Race Conditions
- [ ] Multiple approval attempts handled idempotently
- [ ] Concurrent request creation by same driver handled
- [ ] Order acceptance during wallet balance changes handled
- [ ] Admin processing same request simultaneously handled

### 10. Missing Data Scenarios
- [ ] Non-existent request ID handled gracefully
- [ ] Missing driver profile handled during request creation
- [ ] Missing wallet document handled during approval
- [ ] Invalid admin tokens rejected properly

## Security & Authorization

### 11. Authentication & Authorization
- [ ] Unauthenticated users cannot create requests
- [ ] Drivers cannot approve their own requests
- [ ] Non-admin users cannot access admin functions
- [ ] Admin token validation works correctly
- [ ] Driver can only read their own requests

### 12. Firestore Rules Testing
- [ ] Drivers can create their own top-up requests
- [ ] Drivers cannot create requests for other drivers
- [ ] Drivers can read their own requests only
- [ ] Drivers cannot update request status directly
- [ ] Admins can read all requests
- [ ] Direct client updates to requests are blocked

## Data Consistency & Integrity

### 13. Wallet Integration
- [ ] Top-up transactions use existing wallet schema
- [ ] Balance calculations are accurate
- [ ] totalCredited field updated correctly
- [ ] Transaction IDs follow `topup_${requestId}` pattern
- [ ] Currency field set to 'MRU' consistently

### 14. Transaction Records
- [ ] All required transaction fields populated
- [ ] balanceBefore and balanceAfter are accurate
- [ ] Metadata includes requestId, adminId, notes
- [ ] Transaction type is 'credit' and source is 'topup'
- [ ] Timestamps are set correctly

### 15. Request Status Management
- [ ] New requests always start as 'pending'
- [ ] Status transitions are valid (pending → approved/rejected)
- [ ] processedAt timestamp set on approval/rejection
- [ ] adminId recorded correctly on processing
- [ ] Notes field updated appropriately

## Performance & Monitoring

### 16. Function Performance
- [ ] Request creation completes within reasonable time (<5 seconds)
- [ ] Approval process completes within reasonable time (<10 seconds)
- [ ] Balance enforcement doesn't significantly delay order acceptance
- [ ] Concurrent requests handled efficiently

### 17. Logging & Analytics
- [ ] `[CreateTopup]` logs appear for request creation
- [ ] `[ApproveTopup]` logs appear for approval processing
- [ ] `[WalletBalance]` logs appear for balance enforcement
- [ ] Analytics events logged correctly
- [ ] Error logs include sufficient debugging information

### 18. Notification Delivery
- [ ] Insufficient balance notifications reach drivers
- [ ] Arabic text displays correctly in notifications
- [ ] Notification channel "wallet_notifications" works
- [ ] Deep linking to wallet/top-up screen works

## Production Readiness

### 19. Admin Interface Integration
- [ ] Admin panel can list pending requests
- [ ] Admin panel can approve/reject requests
- [ ] Admin panel shows request history and status
- [ ] Bulk operations work if implemented

### 20. Driver App Integration
- [ ] Driver app shows current wallet balance
- [ ] Driver app can create top-up requests
- [ ] Driver app shows request status and history
- [ ] Driver app handles insufficient balance gracefully

### 21. Rollback & Recovery
- [ ] Functions can be disabled if needed
- [ ] Manual wallet adjustments possible for support
- [ ] Request status can be manually corrected
- [ ] Transaction records can be audited/reversed if needed

## Success Criteria

- [ ] Drivers can create top-up requests successfully
- [ ] Only admins can approve/reject requests
- [ ] Wallet balances updated atomically and accurately
- [ ] Order acceptance blocked for drivers with zero balance
- [ ] All operations are idempotent and safe to retry
- [ ] Error rate <1% of operations
- [ ] Function performance <10 seconds per operation