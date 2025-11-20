# BATCH 10: Analytics & Monitoring - Test Plan

## Overview
This document outlines the manual testing procedures for verifying Firebase Analytics integration in WawApp client and driver applications.

## Prerequisites
- Both apps built and running on test devices
- Firebase Analytics enabled in Firebase Console
- Debug logging enabled (kDebugMode = true)
- Access to Firebase Console Analytics DebugView

## Test Cases

### Test A: Order Creation Analytics (Client App)
**Objective**: Verify `order_created` event is logged when client creates an order

**Steps**:
1. Open WawApp Client app
2. Navigate to home screen
3. Select pickup and dropoff locations
4. Tap "احسب السعر" (Calculate Price)
5. On quote screen, tap "اطلب الآن" (Request Now)
6. Check debug console logs

**Expected Result**:
- Console log: `[Analytics] order_created: {order_id}`
- Event appears in Firebase Analytics DebugView within 1-2 minutes

**Pass Criteria**: ✅ Event logged with valid order_id parameter

---

### Test B: Client Order Cancellation Analytics
**Objective**: Verify `order_cancelled_by_client` event is logged

**Steps**:
1. Create an order (follow Test A)
2. Navigate to tracking screen
3. Tap "إلغاء الطلب" (Cancel Order) button
4. Confirm cancellation in dialog
5. Check debug console logs

**Expected Result**:
- Console log: `[Analytics] order_cancelled_by_client: {order_id}`
- Event appears in Firebase Analytics DebugView

**Pass Criteria**: ✅ Event logged after successful cancellation

---

### Test C: Driver Order Acceptance Analytics
**Objective**: Verify `order_accepted_by_driver` event is logged

**Steps**:
1. Open WawApp Driver app
2. Ensure driver is online and location enabled
3. Navigate to "الطلبات القريبة" (Nearby Orders)
4. Wait for an order to appear (or create one from client)
5. Tap "قبول" (Accept) button
6. Check debug console logs

**Expected Result**:
- Console log: `[Analytics] order_accepted_by_driver: {order_id}`
- Event appears in Firebase Analytics DebugView

**Pass Criteria**: ✅ Event logged after successful acceptance

---

### Test D: Driver Order Completion Analytics
**Objective**: Verify `order_completed_by_driver` event is logged

**Steps**:
1. Driver has an active order (status: accepted or onRoute)
2. Navigate to "الطلب النشط" (Active Order)
3. If status is accepted, tap "بدء الرحلة" (Start Trip)
4. Tap "إكمال الطلب" (Complete Order)
5. Check debug console logs

**Expected Result**:
- Console log: `[Analytics] order_completed_by_driver: {order_id}`
- Event appears in Firebase Analytics DebugView

**Pass Criteria**: ✅ Event logged after successful completion

---

### Test E: Driver Order Cancellation Analytics
**Objective**: Verify `order_cancelled_by_driver` event is logged

**Steps**:
1. Driver has an active order
2. Navigate to "الطلب النشط" (Active Order)
3. Tap "إلغاء الطلب" (Cancel Order) button
4. Confirm cancellation with "نعم" (Yes)
5. Check debug console logs

**Expected Result**:
- Console log: `[Analytics] order_cancelled_by_driver: {order_id}`
- Event appears in Firebase Analytics DebugView

**Pass Criteria**: ✅ Event logged after successful cancellation

---

### Test F: Trip Completed View Analytics (Client App)
**Objective**: Verify `order_completed_viewed` event is logged

**Steps**:
1. Complete an order from driver side (Test D)
2. Client app should auto-navigate to trip completed screen
3. Check debug console logs immediately upon screen load

**Expected Result**:
- Console log: `[Analytics] order_completed_viewed: {order_id}`
- Event logged only once per screen visit
- Event appears in Firebase Analytics DebugView

**Pass Criteria**: ✅ Event logged once when screen first loads

---

### Test G: Driver Rating Analytics (Client App)
**Objective**: Verify `driver_rated` event is logged with rating value

**Steps**:
1. On trip completed screen (from Test F)
2. Tap on star rating (e.g., 4 stars)
3. Tap "إرسال التقييم" (Submit Rating)
4. Check debug console logs

**Expected Result**:
- Console log: `[Analytics] driver_rated: {order_id}, rating: {1-5}`
- Event appears in Firebase Analytics DebugView with rating parameter

**Pass Criteria**: ✅ Event logged with correct order_id and rating (1-5)

---

### Test H: Order Expiration Analytics (Cloud Functions)
**Objective**: Verify `order_expired` logs in Cloud Functions

**Steps**:
1. Create an order from client app
2. Do NOT accept it from driver side
3. Wait 10+ minutes for expiration function to run
4. Check Cloud Functions logs in Firebase Console

**Expected Result**:
- Log entry: `[Analytics] order_expired` with order_id, owner_id, created_at
- Log entry: `[Analytics] order_expired_batch` with count
- Order status in Firestore changes to 'expired'

**Pass Criteria**: ✅ Analytics logs present in Cloud Functions console

---

### Test I: User Type Property (Both Apps)
**Objective**: Verify user_type property is set correctly

**Steps**:
1. Open client app → check logs for: `[Analytics] user_type set to client`
2. Open driver app → check logs for: `[Analytics] user_type set to driver`
3. In Firebase Console → Analytics → User Properties
4. Verify user_type property exists with values 'client' and 'driver'

**Expected Result**:
- Console logs show user_type being set on app start
- Firebase Console shows user_type property

**Pass Criteria**: ✅ Property set correctly for both apps

---

## Regression Testing

### Verify No Breaking Changes
- ✅ Order creation flow works normally
- ✅ Order cancellation (client & driver) works normally
- ✅ Order completion flow works normally
- ✅ Trip completed screen displays correctly
- ✅ Driver rating submission works normally
- ✅ Order expiration function runs without errors

### Performance Check
- ✅ No noticeable lag when analytics events fire
- ✅ App startup time not significantly impacted
- ✅ Analytics errors don't crash the app

---

## Firebase Console Verification

### Analytics DebugView
1. Open Firebase Console → Analytics → DebugView
2. Select test device
3. Verify events appear in real-time during testing
4. Check event parameters are correct

### Analytics Events Dashboard
1. Wait 24 hours for data aggregation
2. Open Firebase Console → Analytics → Events
3. Verify custom events appear:
   - order_created
   - order_cancelled_by_client
   - order_cancelled_by_driver
   - order_accepted_by_driver
   - order_completed_by_driver
   - order_completed_viewed
   - driver_rated

### User Properties
1. Open Firebase Console → Analytics → User Properties
2. Verify 'user_type' property exists
3. Check distribution between 'client' and 'driver' values

---

## Troubleshooting

### Events Not Appearing
- Verify Firebase Analytics is enabled in Firebase Console
- Check app is in debug mode (kDebugMode = true)
- Ensure device is registered in DebugView
- Wait 1-2 minutes for events to propagate

### Console Logs Missing
- Verify imports are correct
- Check AnalyticsService.instance is being called
- Ensure try-catch blocks aren't silently failing

### Cloud Functions Logs Missing
- Check function is deployed: `firebase deploy --only functions`
- Verify function is running: Check Cloud Scheduler
- Check function logs: Firebase Console → Functions → Logs

---

## Sign-Off

**Tester Name**: _________________  
**Date**: _________________  
**Test Results**: ☐ Pass ☐ Fail  
**Notes**: _________________

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-XX  
**Author**: WawApp Development Team
