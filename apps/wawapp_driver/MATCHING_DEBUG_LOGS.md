# Matching Orders Debug Logs Implementation

## Overview
Added comprehensive debug logging with `[Matching]` prefix to track the entire flow of nearby/matching orders for drivers.

## Files Modified

### 1. `lib/services/orders_service.dart`
**getNearbyOrders()**
- Logs driver position when stream is created
- Logs query intent (status filter, distance constraint)
- Logs snapshot size when received
- For each order document:
  - Logs orderId, status, createdAt, pickup coordinates
  - Logs calculated distance from driver
  - Logs whether order is within range (✓) or too far (✗)
- Logs final sorted list of matching orders

**getDriverActiveOrders()**
- Logs driver ID and query intent
- Logs snapshot size
- For each active order:
  - Logs orderId, status, createdAt, price
- Logs final list of active orders

### 2. `lib/features/nearby/nearby_screen.dart`
- Logs when location initialization starts
- Logs obtained driver location coordinates
- Logs location errors
- Logs when subscribing to nearby orders stream
- Logs when waiting for stream data
- Logs stream errors
- Logs number of orders being displayed

### 3. `lib/features/active/active_order_screen.dart`
- Logs when screen is built
- Logs driver authentication status
- Logs when subscribing to active orders stream
- Logs when waiting for stream data
- Logs number of active orders received

### 4. `lib/features/home/driver_home_screen.dart`
- Logs when home screen is built
- Logs driver online status
- Logs driver ID
- Logs when driver toggles online status
- Logs when navigating to nearby orders screen

## Log Format Examples

```
[Matching] DriverHomeScreen: Building home screen
[Matching] DriverHomeScreen: Driver online status: true
[Matching] DriverHomeScreen: Driver ID: abc123xyz
[Matching] DriverHomeScreen: Navigating to nearby orders screen
[Matching] NearbyScreen: Initializing location
[Matching] NearbyScreen: Location obtained: lat=18.0735, lng=-15.9582
[Matching] NearbyScreen: Subscribing to nearby orders stream
[Matching] getNearbyOrders called
[Matching] Driver position: lat=18.0735, lng=-15.9582
[Matching] Query intent: status=assigning, maxDistance=8.0km
[Matching] Snapshot received: 3 documents
[Matching] Order order123: status=assigning, createdAt=2024-01-15, pickup=(18.0800,-15.9600), distance=1.23km, price=500
[Matching] ✓ Order order123 within range (1.2km)
[Matching] Order order456: status=assigning, createdAt=2024-01-15, pickup=(18.2000,-16.0000), distance=15.45km, price=800
[Matching] ✗ Order order456 too far (15.5km)
[Matching] Final result: 1 matching orders
[Matching] #1: order123 (1.2km, 500MRU)
[Matching] NearbyScreen: Displaying 1 orders
```

## Safety Features
- All logs wrapped in `if (kDebugMode)` checks
- Safe null access for all Firestore fields
- Error handling with try-catch blocks
- No crashes on missing fields

## Testing
To see the logs in action:
1. Build and run the driver app in debug mode
2. Navigate to the home screen
3. Toggle online status
4. Navigate to "Nearby Orders" screen
5. Check the console for `[Matching]` logs

## Benefits
- Complete visibility into the matching algorithm
- Easy debugging of distance calculations
- Track query performance and results
- Identify issues with order filtering
- Monitor driver location accuracy
