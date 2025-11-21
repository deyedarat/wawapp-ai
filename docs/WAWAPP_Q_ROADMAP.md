WawApp – Handoff Roadmap for Amazon Q (Next Batches)
Date: 2025-11-20
Completed: Batches 1-5 (Build fixes, Firestore indexes, Driver location, Online/offline status, Order expiration)
Current State: Production-ready Flutter monorepo with Cloud Functions deployed
Architecture: Flutter + Riverpod + Firebase (Firestore, Auth, FCM)
BATCH 6: Client-Side Order Cancellation
Goal: Allow clients to cancel orders they created before driver completes pickup. Files to Modify:
packages/core_shared/lib/src/order_status.dart - Verify cancelledByClient transitions
apps/wawapp_client/lib/services/orders_service.dart - Add cancelOrder() method
apps/wawapp_client/lib/features/track/track_order_screen.dart - Add "Cancel Order" button
firestore.rules - Verify client can update own orders to cancelledByClient
Steps:
Verify OrderStatus.matching/assigning/accepted can transition to cancelledByClient (lines 137-150)
Add Future<void> cancelOrder(String orderId) method in client orders service (Firestore transaction)
Add cancellation button in track screen UI (visible only when status.canClientCancel returns true)
Show confirmation dialog before cancellation
Test: Create order → cancel → verify status = cancelledByClient in Firestore
Constraints:
Use OrderStatus.cancelledByClient enum (NOT generic cancelled)
Use Firestore transaction for atomic update
Check canClientCancel getter before showing button
No cancellation after driver starts trip (onRoute status)
BATCH 7: Driver Cancellation & Trip Completion Polish
Goal: Add driver cancellation + basic trip completion with rating. Files to Modify:
apps/wawapp_driver/lib/features/active/active_order_screen.dart - Add cancel button
apps/wawapp_driver/lib/services/orders_service.dart - Add cancelOrder() method
apps/wawapp_client/lib/features/track/trip_completed_screen.dart - Create basic completion screen
apps/wawapp_client/lib/services/orders_service.dart - Add rateDriver(orderId, rating) method
firestore.rules - Update to allow rating field writes by order owner
Steps:
Driver cancel: Add cancel button in active_order_screen.dart (visible when canDriverCancel)
Driver service: Add cancelOrder() using OrderStatus.cancelledByDriver
Client completion: Create trip_completed_screen.dart showing order summary + 5-star rating widget
Rating service: Add rateDriver() method (update orders/{id}.driverRating field)
Test both flows end-to-end
Constraints:
Driver can cancel only during accepted or onRoute (check canDriverCancel)
Rating stored in orders/{orderId}.driverRating (number 1-5)
Completion screen shown when client receives status == 'completed' in real-time listener
Use transaction for cancel to prevent race conditions
BATCH 8: Error Handling & User-Friendly Error Screens
Goal: Replace generic error dialogs with proper error screens and retry logic. Files to Create:
packages/core_shared/lib/src/app_error.dart - Define error types enum
apps/wawapp_client/lib/widgets/error_screen.dart - Reusable error screen widget
apps/wawapp_driver/lib/widgets/error_screen.dart - Driver version
Files to Modify:
apps/wawapp_client/lib/services/orders_service.dart - Wrap Firestore errors
apps/wawapp_driver/lib/services/orders_service.dart - Wrap Firestore errors
All screens showing CircularProgressIndicator - Add error state handling
Steps:
Create AppError enum: networkError, permissionDenied, notFound, timeout, unknown
Create ErrorScreen widget with: icon, Arabic message, retry button
Update all StreamProvider and FutureProvider to catch errors and map to AppError
Replace CircularProgressIndicator with AsyncValue.when() pattern (loading/error/data)
Test: Disable network → verify error screen → enable → retry → verify recovery
Constraints:
All error messages in Arabic
Use AsyncValue.when() from Riverpod (NOT manual try-catch in widgets)
Retry button should re-trigger provider refresh
Don't break existing functionality - add error handling incrementally
BATCH 9 (Optional): FCM Push Notifications
Goal: Send notifications for key order events. Files to Modify:
functions/src/notifyOrderEvents.ts - New Cloud Function (Firestore trigger)
apps/wawapp_client/lib/services/fcm_service.dart - Handle notification taps
apps/wawapp_driver/lib/services/fcm_service.dart - Handle notification taps
Steps:
Create Firestore-triggered Cloud Function on orders/{id} updates
Send FCM when: order accepted, driver arrived, order completed, order expired
Update client FCM service to navigate to track screen on tap
Update driver FCM service to navigate to active order screen on tap
Test: Create order → verify client receives "Driver accepted" notification
Constraints:
Use Firebase Admin SDK messaging.send() (NOT legacy FCM API)
Store FCM tokens in users/{uid}.fcmToken field
Only send if token exists and user online
Include orderId in notification data payload for navigation
BATCH 10 (Optional): Analytics & Monitoring
Goal: Add Firebase Analytics for key metrics. Files to Modify:
apps/wawapp_client/lib/services/analytics_service.dart - Already exists, expand events
apps/wawapp_driver/lib/services/analytics_service.dart - Already exists, expand events
functions/src/expireStaleOrders.ts - Add Analytics event for expirations
Steps:
Log event: order_created (client), order_accepted (driver), order_completed (both)
Log event: order_expired in Cloud Function
Set user properties: user_type (client/driver), total_orders (lifetime count)
Add crash reporting via Firebase Crashlytics (already configured)
Create BigQuery export for advanced analytics (optional)
Constraints:
Use existing AnalyticsService singleton instances
Event names must follow Firebase Analytics naming conventions (lowercase, underscores)
Don't log PII (phone numbers, addresses) - only aggregated metrics
Test in debug mode with firebase analytics:debug before deploying
Architecture Reminders
State Management: Riverpod only (no BLoC, Provider, GetX)
Firestore Writes: Always use transactions for critical updates (order status changes)
OrderStatus: Use enum values from packages/core_shared/lib/src/order_status.dart
Security: Cloud Functions bypass rules; client apps must respect firestore.rules
Navigation: GoRouter (avoid Navigator.push)
Localization: Arabic messages required for all user-facing text Critical Files:
State machine: packages/core_shared/lib/src/order_status.dart
Security rules: firestore.rules
Firestore indexes: firestore.indexes.json
Cloud Functions: functions/src/
Testing Requirements
Before marking any batch complete:
Run flutter analyze on both apps (0 errors required)
Test happy path manually on real devices
Test error cases (network off, permissions denied)
Verify Firestore security rules prevent unauthorized access
Check Cloud Function logs for errors (if applicable)
Handoff Notes: All batches 1-5 are production-ready. BATCH 6 is highest priority for user experience. Follow plan-first methodology: read files → propose changes → get user approval → implement. Ask user for clarification on any ambiguous requirements.