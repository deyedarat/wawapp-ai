📋 PROJECT_STATE_REPORT
WawApp Multi-App Flutter Ecosystem
Date: 2025-11-22
Supervisor: Claude Code
Branch: driver-auth-stable-work
🎯 EXECUTIVE SUMMARY
Overall Health: 7.5/10
Production Readiness: 65%
Technical Debt: MEDIUM
Architecture Compliance: ✅ EXCELLENT (100% Riverpod, GoRouter)
✅ WHAT IS WORKING
Client App (wawapp_client)
Authentication: Phone + OTP + PIN (95% complete)
Order Creation & Tracking: Real-time Firestore streaming
Maps & Geolocation: Google Maps, district layers, autocomplete
Profile Management: Full CRUD with saved locations
FCM Notifications: Push notifications + deep linking
Analytics: Firebase Analytics integrated
Driver App (wawapp_driver)
Authentication: Phone + OTP + PIN (95% complete)
Order Discovery: Geohash-based nearby orders
Order Management: Accept/reject, status transitions
Location Tracking: Real-time driver position to Firestore
Earnings Dashboard: Daily/weekly/monthly aggregations
History: Completed orders with details
Backend (Firebase)
Cloud Functions: 4 functions (expire orders, ratings, notifications) - EXCELLENT per audit
Security Rules: Comprehensive, properly scoped - EXCELLENT
Firestore Indexes: Optimized for geo-queries
🔴 WHAT IS BROKEN
Critical Issues
Order Model Inconsistency 🔴 CRITICAL
Client and Driver have DIFFERENT Order models
Files: apps/wawapp_client/lib/features/track/models/order.dart vs apps/wawapp_driver/lib/models/order.dart
Impact: Data integrity risk, potential bugs in order lifecycle
Priority: FIX IMMEDIATELY
Code Duplication 🔴 HIGH
phone_pin_auth.dart duplicated (Client: 3277 bytes, Driver: 4954 bytes - DIFFERENT)
fcm_service.dart duplicated (Client: 12KB, Driver: 10KB - DIFFERENT)
notification_service.dart, analytics_service.dart duplicated
Impact: Maintenance nightmare, bugs in one app not in the other
Priority: FIX IMMEDIATELY
Disabled Repository Tests 🔴 CRITICAL
File: apps/wawapp_client/test/repository/orders_repository_test.dart
Reason: fake_cloud_firestore compatibility issues
Impact: No test coverage for critical OrdersRepository
Priority: HIGH
Missing Firestore Migration ⚠️ HIGH
TODO in apps/wawapp_driver/lib/services/orders_service.dart:49
Schema fields assignedDriverId + indexes not verified
Impact: Query failures possible
Priority: HIGH
⚠️ WHAT IS MISSING
Production Blockers
Payment Integration 🚫 BLOCKER
No Stripe/PayPal/payment gateway
Client wallet screen missing
Driver wallet is 10% stub
Impact: CANNOT GO TO PRODUCTION
Estimated effort: 40 hours
Driver Navigation 🚫 BLOCKER
No map view in driver app
No turn-by-turn navigation to pickup/dropoff
Folder exists but empty: apps/wawapp_driver/lib/features/map/
Impact: Driver cannot navigate efficiently
Estimated effort: 16 hours
Biometric Authentication ⚠️ MEDIUM
No fingerprint/Face ID
Only PIN login (shoulder-surfing risk)
Estimated effort: 8 hours
🏗️ ARCHITECTURE CONSISTENCY
✅ COMPLIANT Areas
State Management: 100% Riverpod (StateNotifierProvider, StreamProvider, FutureProvider)
Navigation: 100% GoRouter (no manual Navigator.push)
Firebase: Consistent integration patterns
Folder Structure: Clean feature-based organization
❌ NON-COMPLIANT Areas
Code Sharing: Services duplicated instead of using packages/
State Patterns: 17 files still use setState (should be pure Riverpod)
Nested Directory: features/features/profile/ (redundant nesting)
🎯 HIGH-RISK AREAS
Authentication Flow 🔴
Different implementations in Client vs Driver
PIN storage (verify hashing)
No biometric fallback
Order Status Transitions 🔴
State machine: matching → accepted → onRoute → completed
Race conditions (multiple drivers accepting same order)
Different Order models = potential bugs
Real-time Tracking 🟡
High Firestore write costs
Location privacy (covered by security rules)
Payment Processing 🚫
NOT IMPLEMENTED (blocker)
📊 CODE QUALITY METRICS
Total Dart Files: 156
Test Coverage: ~15% (LOW)
Disabled Tests: Critical OrdersRepository tests
Debug Logs: 353 occurrences (no production logging)
setState Usage: 17 files (should refactor to Riverpod)
TODO Comments: 2 in production code
🔢 PRIORITY RANKING
🔴 CRITICAL (Fix Now)
Unify Order model → packages/core_shared/
Extract duplicated auth logic → packages/auth_shared/
Extract duplicated FCM service → packages/core_shared/
Fix Firestore schema migration (assignedDriverId)
🟠 HIGH (Next Sprint)
Re-enable OrdersRepository tests
Implement payment integration (Stripe)
Add driver map + navigation
Biometric authentication
🟡 MEDIUM (Future Sprints)
Refactor setState → pure Riverpod (17 files)
Increase test coverage to 60%
Production logging service
Fix nested features/features/ directory
Update Todos

Conduct comprehensive codebase exploration and analysis

Create PROJECT_STATE_REPORT with findings

Generate JOB_QUEUE with prioritized tasks

Prepare first task for Amazon Q
📝 JOB_QUEUE
Small, Incremental Tasks for Amazon Q
Each task: 10-20 minutes | Minimal diffs | No structural changes
🔴 CRITICAL TRACK (Order Model Unification)
Task 1: Create Unified Order Model in Shared Package ✋ READY
Estimated Time: 15 min
Files to Create: packages/core_shared/lib/src/order.dart
Files to Read:
apps/wawapp_client/lib/features/track/models/order.dart
apps/wawapp_driver/lib/models/order.dart
Action: Merge both Order models into single source of truth, include ALL fields from both versions
Dependencies: None
Risk: LOW (new file creation)
Task 2: Export Unified Order Model from core_shared ✋ READY
Estimated Time: 5 min
Files to Edit: packages/core_shared/lib/core_shared.dart
Action: Add export 'src/order.dart';
Dependencies: Task 1 completed
Risk: LOW
Task 3: Update Client Order Imports to Use Shared Model ⏸️ BLOCKED
Estimated Time: 10 min
Files to Edit:
apps/wawapp_client/lib/features/track/data/orders_repository.dart
apps/wawapp_client/lib/features/track/providers/order_tracking_provider.dart
apps/wawapp_client/lib/features/track/models/order.dart (DELETE)
Action: Replace all import '../models/order.dart' with import 'package:core_shared/core_shared.dart'
Dependencies: Task 1, Task 2 completed
Risk: MEDIUM (verify no breaking changes)
Task 4: Update Driver Order Imports to Use Shared Model ⏸️ BLOCKED
Estimated Time: 10 min
Files to Edit:
apps/wawapp_driver/lib/services/orders_service.dart
apps/wawapp_driver/lib/features/nearby/providers/nearby_orders_provider.dart
apps/wawapp_driver/lib/models/order.dart (DELETE)
Action: Replace all import '../models/order.dart' with import 'package:core_shared/core_shared.dart'
Dependencies: Task 1, Task 2 completed
Risk: MEDIUM (verify no breaking changes)
Task 5: Run Flutter Analyze (Client) - Verify Order Model Migration ⏸️ BLOCKED
Estimated Time: 5 min
Command: flutter analyze in apps/wawapp_client/
Expected: No new errors related to Order model
Dependencies: Task 3 completed
Risk: LOW (verification only)
Task 6: Run Flutter Analyze (Driver) - Verify Order Model Migration ⏸️ BLOCKED
Estimated Time: 5 min
Command: flutter analyze in apps/wawapp_driver/
Expected: No new errors related to Order model
Dependencies: Task 4 completed
Risk: LOW (verification only)
🔴 CRITICAL TRACK (Auth Service Deduplication)
Task 7: Compare phone_pin_auth.dart Implementations ✋ READY
Estimated Time: 10 min
Files to Read:
apps/wawapp_client/lib/services/phone_pin_auth.dart
apps/wawapp_driver/lib/services/phone_pin_auth.dart
Action: Create a detailed diff report showing differences between the two implementations
Output: Text report listing differences
Dependencies: None
Risk: LOW (read-only analysis)
Task 8: Extract Unified phone_pin_auth.dart to auth_shared Package ⏸️ BLOCKED
Estimated Time: 15 min
Files to Create: packages/auth_shared/lib/src/phone_pin_auth.dart
Action: Merge both implementations, preserving ALL functionality from both versions
Dependencies: Task 7 completed (understand differences first)
Risk: MEDIUM (critical auth code)
Task 9: Update Client to Use Shared phone_pin_auth ⏸️ BLOCKED
Estimated Time: 10 min
Files to Edit:
apps/wawapp_client/lib/features/auth/providers/auth_service_provider.dart
apps/wawapp_client/lib/services/phone_pin_auth.dart (DELETE)
Action: Import from package:auth_shared/auth_shared.dart
Dependencies: Task 8 completed
Risk: HIGH (auth flow critical)
Task 10: Update Driver to Use Shared phone_pin_auth ⏸️ BLOCKED
Estimated Time: 10 min
Files to Edit:
apps/wawapp_driver/lib/features/auth/providers/auth_service_provider.dart
apps/wawapp_driver/lib/services/phone_pin_auth.dart (DELETE)
Action: Import from package:auth_shared/auth_shared.dart
Dependencies: Task 8 completed
Risk: HIGH (auth flow critical)
Task 11: Test Client Auth Flow After Migration ⏸️ BLOCKED
Estimated Time: 15 min
Manual Test Steps:
Run client app
Enter phone number
Verify OTP screen appears
Enter OTP
Create/enter PIN
Verify home screen loads
Dependencies: Task 9 completed
Risk: MEDIUM (integration test)
Task 12: Test Driver Auth Flow After Migration ⏸️ BLOCKED
Estimated Time: 15 min
Manual Test Steps:
Run driver app
Enter phone number
Verify OTP screen appears
Enter OTP
Create/enter PIN
Verify driver home screen loads
Dependencies: Task 10 completed
Risk: MEDIUM (integration test)
🔴 CRITICAL TRACK (FCM Service Deduplication)
Task 13: Compare fcm_service.dart Implementations ✋ READY
Estimated Time: 10 min
Files to Read:
apps/wawapp_client/lib/services/fcm_service.dart (12KB)
apps/wawapp_driver/lib/services/fcm_service.dart (10KB)
Action: Create detailed diff report showing differences
Dependencies: None
Risk: LOW (read-only analysis)
Task 14: Extract Unified fcm_service.dart to core_shared ⏸️ BLOCKED
Estimated Time: 20 min
Files to Create: packages/core_shared/lib/src/fcm_service.dart
Action: Merge both implementations, preserve client-specific and driver-specific logic via parameters
Dependencies: Task 13 completed
Risk: MEDIUM (notifications critical)
Task 15: Update Client to Use Shared fcm_service ⏸️ BLOCKED
Estimated Time: 10 min
Files to Edit:
Client files importing FCM service
apps/wawapp_client/lib/services/fcm_service.dart (DELETE)
Action: Import from package:core_shared/core_shared.dart
Dependencies: Task 14 completed
Risk: MEDIUM (verify notifications still work)
Task 16: Update Driver to Use Shared fcm_service ⏸️ BLOCKED
Estimated Time: 10 min
Files to Edit:
Driver files importing FCM service
apps/wawapp_driver/lib/services/fcm_service.dart (DELETE)
Action: Import from package:core_shared/core_shared.dart
Dependencies: Task 14 completed
Risk: MEDIUM (verify notifications still work)
🟠 HIGH PRIORITY TRACK (Firestore Schema Migration)
Task 17: Verify assignedDriverId Field in Firestore ✋ READY
Estimated Time: 10 min
Action: Check existing orders in Firestore to confirm assignedDriverId field exists
Files to Read: apps/wawapp_driver/lib/services/orders_service.dart:49
Dependencies: None
Risk: LOW (read-only verification)
Task 18: Add Firestore Index for assignedDriverId Query ⏸️ BLOCKED
Estimated Time: 10 min
Files to Edit: firestore.indexes.json
Action: Add composite index: assignedDriverId (ASC) + createdAt (DESC)
Dependencies: Task 17 completed (verify field exists)
Risk: LOW (index creation)
Task 19: Deploy Firestore Indexes ⏸️ BLOCKED
Estimated Time: 5 min
Command: firebase deploy --only firestore:indexes
Dependencies: Task 18 completed
Risk: LOW (idempotent operation)
Task 20: Remove TODO Comment in orders_service.dart ⏸️ BLOCKED
Estimated Time: 2 min
Files to Edit: apps/wawapp_driver/lib/services/orders_service.dart:49
Action: Delete the TODO comment after verification complete
Dependencies: Task 17, 18, 19 completed
Risk: LOW (comment removal)
🟠 HIGH PRIORITY TRACK (Test Coverage)
Task 21: Investigate fake_cloud_firestore Compatibility ✋ READY
Estimated Time: 15 min
Files to Read: apps/wawapp_client/test/repository/orders_repository_test.dart
Action: Research if fake_cloud_firestore has been updated or if Firebase Emulator is better option
Output: Recommendation report
Dependencies: None
Risk: LOW (research only)
Task 22: Choose Testing Strategy for OrdersRepository ⏸️ BLOCKED
Estimated Time: 5 min
Options:
A) Upgrade fake_cloud_firestore to compatible version
B) Use Firebase Emulator for integration tests
Action: Make decision based on Task 21 findings
Dependencies: Task 21 completed
Risk: LOW (decision making)
Task 23: Implement Chosen Testing Strategy ⏸️ BLOCKED
Estimated Time: 20 min
Files to Edit: apps/wawapp_client/test/repository/orders_repository_test.dart
Action: Update test file based on Task 22 decision
Dependencies: Task 22 completed
Risk: MEDIUM (tests must pass)
🟡 MEDIUM PRIORITY TRACK (Architecture Cleanup)
Task 24: Fix Nested features/features/ Directory ✋ READY
Estimated Time: 10 min
Files to Move: apps/wawapp_client/lib/features/features/profile/* → apps/wawapp_client/lib/features/profile/
Action: Move files to correct location, update imports
Dependencies: None
Risk: LOW (straightforward refactor)
Task 25: Identify setState Usage in Client App ✋ READY
Estimated Time: 10 min
Command: grep -r "setState" apps/wawapp_client/lib/ (use Grep tool)
Action: Generate list of files using setState
Output: List of file paths with line numbers
Dependencies: None
Risk: LOW (read-only search)
Task 26: Identify setState Usage in Driver App ✋ READY
Estimated Time: 10 min
Command: grep -r "setState" apps/wawapp_driver/lib/ (use Grep tool)
Action: Generate list of files using setState
Output: List of file paths with line numbers
Dependencies: None
Risk: LOW (read-only search)
Task 27: Refactor First Client File to Pure Riverpod ⏸️ BLOCKED
Estimated Time: 15 min
Action: Pick simplest file from Task 25 list, convert StatefulWidget + setState to Riverpod StateNotifier
Dependencies: Task 25 completed
Risk: MEDIUM (behavior must remain identical)
Task 28: Refactor First Driver File to Pure Riverpod ⏸️ BLOCKED
Estimated Time: 15 min
Action: Pick simplest file from Task 26 list, convert StatefulWidget + setState to Riverpod StateNotifier
Dependencies: Task 26 completed
Risk: MEDIUM (behavior must remain identical)
📊 QUEUE SUMMARY
Total Tasks: 28
Ready to Start: 9 tasks
Blocked: 19 tasks (waiting on dependencies) Tracks:
🔴 Order Model Unification: 6 tasks
🔴 Auth Service Deduplication: 6 tasks
🔴 FCM Service Deduplication: 4 tasks
🟠 Firestore Schema Migration: 4 tasks
🟠 Test Coverage: 3 tasks
🟡 Architecture Cleanup: 5 tasks
Critical Path: Tasks 1 → 2 → 3 → 4 → 5 → 6 (Order Model)
Update Todos

Conduct comprehensive codebase exploration and analysis

Create PROJECT_STATE_REPORT with findings

Generate JOB_QUEUE with prioritized tasks

Prepare first task for Amazon Q 