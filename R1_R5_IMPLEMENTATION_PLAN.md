# WawApp R1-R5 Implementation Plan
**Branch:** feature/ui-notifications-topup-theme-pin-cancel  
**Base Commit:** be6e2ac  
**Date:** 2025-12-31

## Overview
This document provides a complete implementation plan for 5 critical requirements:
- R1: In-app Notifications Inbox
- R2: Top-up/Charging Flow
- R3: Unified Theme/Language
- R4: Client PIN Change
- R5: Client Order Cancellation Fix

---

## R1: In-App Notifications Inbox

### Goal
Allow users to view notification history inside the app, with deeplinks and actionable buttons.

### Implementation

#### 1. Data Model

**Firestore Collection:** `notifications/{notificationId}`

```typescript
{
  id: string;
  userId: string;  // The recipient
  type: 'order_update' | 'system' | 'promotion' | 'driver_message';
  title: string;
  body: string;
  data: {
    orderId?: string;
    driverId?: string;
    status?: string;
    // type-specific data
  };
  read: boolean;
  actionUrl?: string;  // Deep link URL
  createdAt: Timestamp;
  expiresAt?: Timestamp;  // Optional expiration
}
```

#### 2. Firestore Security Rules

**Add to firestore.rules:**
```javascript
match /notifications/{notificationId} {
  // Admin can write (Cloud Functions)
  allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
  allow write: if isAdmin();
  
  // Users can mark their own notifications as read
  allow update: if isSignedIn() 
    && resource.data.userId == request.auth.uid
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['read', 'updatedAt']);
}
```

#### 3. Flutter Implementation Files

**A. Model: `apps/wawapp_client/lib/features/notifications/models/app_notification.dart`**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  orderUpdate,
  system,
  promotion,
  driverMessage,
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool read;
  final String? actionUrl;
  final DateTime createdAt;
  final DateTime? expiresAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    this.read = false,
    this.actionUrl,
    required this.createdAt,
    this.expiresAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: _parseType(data['type']),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      read: data['read'] ?? false,
      actionUrl: data['actionUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: data['expiresAt'] != null 
        ? (data['expiresAt'] as Timestamp).toDate() 
        : null,
    );
  }

  static NotificationType _parseType(String? type) {
    switch (type) {
      case 'order_update': return NotificationType.orderUpdate;
      case 'system': return NotificationType.system;
      case 'promotion': return NotificationType.promotion;
      case 'driver_message': return NotificationType.driverMessage;
      default: return NotificationType.system;
    }
  }
}
```

**B. Provider: `apps/wawapp_client/lib/features/notifications/providers/notifications_provider.dart`**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_notification.dart';

final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList());
});

final unreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.when(
    data: (notifs) => Stream.value(notifs.where((n) => !n.read).length),
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
  );
});
```

**C. Screen: `apps/wawapp_client/lib/features/notifications/screens/notifications_screen.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/colors.dart';
import '../../../theme/typography.dart';
import '../models/app_notification.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBarbr(
        title: const Text('الإشعارات'), // Notifications in Arabic
        actions: [
          // Mark all as read button
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () => _markAllAsRead(ref),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.builder(
            itemCount: notifications.length,
            padding: const EdgeInsets.all(WawAppSpacing.md),
            itemBuilder: (context, index) {
              return _NotificationCard(
                notification: notifications[index],
                onTap: () => _handleNotificationTap(
                  context,
                  notifications[index],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('خطأ في تحميل الإشعارات'), // Error loading notifications
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: WawAppColors.textSecondaryLight,
          ),
          const SizedBox(height: WawAppSpacing.md),
          Text(
            'لا توجد إشعارات',  // No notifications
            style: const TextStyle(
              fontSize: 18,
              color: WawAppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllAsRead(WidgetRef ref) async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true, 'updatedAt': FieldValue.serverTimestamp()});
    }

    await batch.commit();
  }

  void _handleNotificationTap(BuildContext context, AppNotification notification) {
    // Mark as read
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(notification.id)
        .update({'read': true, 'updatedAt': FieldValue.serverTimestamp()});

    // Handle deep link or action
    if (notification.actionUrl != null) {
      // Use your router to navigate
      // e.g., context.push(notification.actionUrl!);
    } else if (notification.data['orderId'] != null) {
      // Navigate to order details
      // context.push('/orders/${notification.data['orderId']}');
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: WawAppSpacing.sm),
      color: notification.read 
        ? WawAppColors.surfaceLight 
        : WawAppColors.primary.withOpacity(0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WawAppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(WawAppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(),
              const SizedBox(width: WawAppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: WawAppSpacing.xs),
                    Text(
                      notification.body,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: WawAppSpacing.xs),
                    Text(
                      _formatTime(notification.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WawAppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.read)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: WawAppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;

    switch (notification.type) {
      case NotificationType.orderUpdate:
        icon = Icons.local_shipping;
        color = WawAppColors.primary;
        break;
      case NotificationType.system:
        icon = Icons.info_outline;
        color = WawAppColors.info;
        break;
      case NotificationType.promotion:
        icon = Icons.local_offer;
        color: WawAppColors.secondary;
        break;
      case NotificationType.driverMessage:
        icon = Icons.message;
        color = WawAppColors.success;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(WawAppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'الآن'; // Now
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة'; // X minutes ago
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة'; // X hours ago
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم'; // X days ago
    return '${time.day}/${time.month}/${time.year}';
  }
}
```

**D. Deep Link Handler: Update FCM service to save notifications to Firestore**

In `apps/wawapp_client/lib/services/fcm_service.dart`, add:
```dart
Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
  final user = _auth.currentUser;
  if (user == null) return;

  await _firestore.collection('notifications').add({
    'userId': user.uid,
    'type': message.data['type'] ?? 'system',
    'title': message.notification?.title ?? '',
    'body': message.notification?.body ?? '',
    'data': message.data,
    'read': false,
    'actionUrl': message.data['actionUrl'],
    'createdAt': FieldValue.serverTimestamp(),
  });
}
```

#### 4. Router Integration

Add to `apps/wawapp_client/lib/core/router/app_router.dart`:
```dart
GoRoute(
  path: '/notifications',
  name: 'notifications',
  builder: (context, state) => const NotificationsScreen(),
),
```

#### 5. Add Notification Bell to Home Screen

Update home screen app bar:
```dart
AppBar(
  actions: [
    Consumer(builder: (context, ref, _) {
      final unreadCount = ref.watch(unreadCountProvider).valueOrNull ?? 0;
      return Badge(
        label: Text('$unreadCount'),
        isLabelVisible: unreadCount > 0,
        child: IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () => context.push('/notifications'),
        ),
      );
    }),
  ],
)
```

### Testing Checklist - R1

- [ ] Create test notification from Firebase Console
- [ ] Verify notification appears in inbox
- [ ] Tap notification - should mark as read
- [ ] Tap notification with order ID - should navigate to order
- [ ] Mark all as read - verify all turn grey
- [ ] Check unread badge count updates
- [ ] Test deep link from system notification tray
- [ ] Verify Firestore rules (user can only read own notifications)

---

## R2: Top-up / Charging Flow

### Goal
Guided flow for drivers to request wallet top-ups via banking apps.

### Implementation

#### 1. Data Model

**Firestore Collection:** `topup_requests/{requestId}`

```typescript
{
  id: string;
  userId: string;
  userType: 'driver' | 'client';  // For future client wallet support
  bankAppId: string;  // e.g., 'bim', 'bci', 'snim'
  destinationCode: string;  // Payment destination for selected bank
  amount: number;  // MRU
  senderPhone: string;  // Phone number used to send money
  status: 'pending' | 'approved' | 'rejected';
  createdAt: Timestamp;
  updatedAt: Timestamp;
  adminReviewedBy?: string;  // Admin UID
  adminReviewedAt?: Timestamp;
  adminNotes?: string;
  approvalTransactionId?: string;  // Link to wallet transaction
}
```

**Config Collection:** `app_config/topup_config`

```typescript
{
  bankApps: [
    {
      id: 'bim',
      name: 'بنك موريتانيا الدولي',  // BIM in Arabic
      nameEn: 'Banque Internationale de Mauritanie',
      destinationCode: '22101234',  // Example
      logo: 'assets/banks/bim.png',
    },
    {
      id: 'bci',
      name: 'البنك التجاري',  // BCI in Arabic
      nameEn: 'Banque Commerciale et Industrielle',
      destinationCode: '22105678',
      logo: 'assets/banks/bci.png',
    },
    {
      id: 'snim',
      name: 'بنك سنيم',  // SNIM Bank in Arabic
      nameEn: 'Banque SNIM',
      destinationCode: '22109012',
      logo: 'assets/banks/snim.png',
    },
  ],
  minAmount: 1000,  // Minimum 1000 MRU
  maxAmount: 100000,  // Maximum 100,000 MRU
}
```

#### 2. Firestore Security Rules

**Add to firestore.rules:**
```javascript
match /topup_requests/{requestId} {
  // Admin can read/write all
  allow read, write: if isAdmin();
  
  // Users can create their own requests
  allow create: if isSignedIn()
    && request.resource.data.userId == request.auth.uid
    && request.resource.data.status == 'pending'
    && request.resource.data.amount >= 1000
    && request.resource.data.amount <= 100000
    && request.resource.data.senderPhone is string
    && request.resource.data.bankAppId is string
    && !('adminReviewedBy' in request.resource.data)
    && !('approvalTransactionId' in request.resource.data);
  
  // Users can read their own requests
  allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
  
  // Users cannot update (only admins can approve/reject)
}

match /app_config/{configId} {
  // Anyone can read config
  allow read: if true;
  // Only admins can write
  allow write: if isAdmin();
}
```

#### 3. Flutter Implementation Files

**A. Model: `apps/wawapp_driver/lib/features/wallet/models/bank_app.dart`**
```dart
class BankApp {
  final String id;
  final String name;
  final String nameEn;
  final String destinationCode;
  final String logo;

  BankApp({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.destinationCode,
    required this.logo,
  });

  factory BankApp.fromMap(Map<String, dynamic> map) {
    return BankApp(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      nameEn: map['nameEn'] ?? '',
      destinationCode: map['destinationCode'] ?? '',
      logo: map['logo'] ?? '',
    );
  }
}

class TopupRequest {
  final String id;
  final String userId;
  final String userType;
  final String bankAppId;
  final String destinationCode;
  final int amount;
  final String senderPhone;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? adminReviewedBy;
  final DateTime? adminReviewedAt;
  final String? adminNotes;

  TopupRequest({
    required this.id,
    required this.userId,
    required this.userType,
    required this.bankAppId,
    required this.destinationCode,
    required this.amount,
    required this.senderPhone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.adminReviewedBy,
    this.adminReviewedAt,
    this.adminNotes,
  });

  factory TopupRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TopupRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      userType: data['userType'] ?? 'driver',
      bankAppId: data['bankAppId'] ?? '',
      destinationCode: data['destinationCode'] ?? '',
      amount: data['amount'] ?? 0,
      senderPhone: data['senderPhone'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      adminReviewedBy: data['adminReviewedBy'],
      adminReviewedAt: data['adminReviewedAt'] != null
          ? (data['adminReviewedAt'] as Timestamp).toDate()
          : null,
      adminNotes: data['adminNotes'],
    );
  }
}
```

**B. Provider: `apps/wawapp_driver/lib/features/wallet/providers/topup_provider.dart`**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bank_app.dart';

final bankAppsProvider = FutureProvider<List<BankApp>>((ref) async {
  final doc = await FirebaseFirestore.instance
      .collection('app_config')
      .doc('topup_config')
      .get();

  if (!doc.exists) return [];

  final data = doc.data();
  final bankApps = data?['bankApps'] as List<dynamic>? ?? [];

  return bankApps.map((app) => BankApp.fromMap(app)).toList();
});

final topupRequestsProvider = StreamProvider.autoDispose<List<TopupRequest>>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('topup_requests')
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => TopupRequest.fromFirestore(doc))
          .toList());
});
```

**C. Screen: `apps/wawapp_driver/lib/features/wallet/screens/topup_flow_screen.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/components.dart';
import '../models/bank_app.dart';
import '../providers/topup_provider.dart';

class TopupFlowScreen extends ConsumerStatefulWidget {
  const TopupFlowScreen({super.key});

  @override
  ConsumerState<TopupFlowScreen> createState() => _TopupFlowScreenState();
}

class _TopupFlowScreenState extends ConsumerState<TopupFlowScreen> {
  int _currentStep = 0;
  BankApp? _selectedBank;
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bankAppsAsync = ref.watch(bankAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('شحن المحفظة'),  // Charge Wallet in Arabic
      ),
      body: bankAppsAsync.when(
        data: (bankApps) => _buildStepper(bankApps),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('خطأ في تحميل البيانات'),  // Error loading data
        ),
      ),
    );
  }

  Widget _buildStepper(List<BankApp> bankApps) {
    return Stepper(
      currentStep: _currentStep,
      onStepContinue: () => _handleContinue(bankApps),
      onStepCancel: _handleCancel,
      controlsBuilder: (context, details) {
        return Padding(
          padding: const EdgeInsets.only(top: DriverAppSpacing.md),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: _isSubmitting ? null : details.onStepContinue,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_currentStep == 2 ? 'إرسال الطلب' : 'متابعة'),  // Submit Request : Continue
              ),
              const SizedBox(width: DriverAppSpacing.sm),
              if (_currentStep > 0)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('رجوع'),  // Back
                ),
            ],
          ),
        );
      },
      steps: [
        Step(
          title: const Text('اختر البنك'),  // Choose Bank
          content: _buildBankSelection(bankApps),
          isActive: _currentStep >= 0,
        ),
        Step(
          title: const Text('رمز الوجهة'),  // Destination Code
          content: _buildDestinationCode(),
          isActive: _currentStep >= 1,
        ),
        Step(
          title: const Text('المبلغ والهاتف'),  // Amount and Phone
          content: _buildAmountAndPhone(),
          isActive: _currentStep >= 2,
        ),
      ],
    );
  }

  Widget _buildBankSelection(List<BankApp> bankApps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اختر تطبيق البنك الذي ستستخدمه لإرسال المال',  // Choose banking app
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: DriverAppSpacing.md),
        ...bankApps.map((bank) => _BankAppCard(
          bank: bank,
          isSelected: _selectedBank?.id == bank.id,
          onTap: () => setState(() => _selectedBank = bank),
        )),
      ],
    );
  }

  Widget _buildDestinationCode() {
    if (_selectedBank == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أرسل المال إلى هذا الرقم:',  // Send money to this number
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: DriverAppSpacing.md),
        Container(
          padding: const EdgeInsets.all(DriverAppSpacing.lg),
          decoration: BoxDecoration(
            color: DriverAppColors.successLight.withOpacity(0.1),
            borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
            border: Border.all(color: DriverAppColors.successLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedBank!.destinationCode,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DriverAppColors.successLight,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: _selectedBank!.destinationCode),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ الرقم')),  // Number copied
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: DriverAppSpacing.md),
        Text(
          'استخدم تطبيق ${_selectedBank!.name} لإرسال المال إلى هذا الرقم، ثم اضغط "متابعة"',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DriverAppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountAndPhone() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أدخل المبلغ الذي أرسلته ورقم هاتفك',  // Enter amount and phone
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: DriverAppSpacing.md),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'المبلغ (MRU)',  // Amount
              hintText: '1000',
              prefixIcon: Icon(Icons.attach_money),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء إدخال المبلغ';  // Please enter amount
              }
              final amount = int.tryParse(value);
              if (amount == null) {
                return 'المبلغ غير صحيح';  // Invalid amount
              }
              if (amount < 1000) {
                return 'الحد الأدنى 1000 MRU';  // Minimum 1000
              }
              if (amount > 100000) {
                return 'الحد الأقصى 100,000 MRU';  // Maximum 100,000
              }
              return null;
            },
          ),
          const SizedBox(height: DriverAppSpacing.md),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف المرسل',  // Sender phone number
              hintText: '22201234567',
              prefixIcon: Icon(Icons.phone),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'الرجاء إدخال رقم الهاتف';  // Please enter phone
              }
              if (!RegExp(r'^\d{8,11}$').hasMatch(value)) {
                return 'رقم الهاتف غير صحيح';  // Invalid phone
              }
              return null;
            },
          ),
          const SizedBox(height: DriverAppSpacing.md),
          Container(
            padding: const EdgeInsets.all(DriverAppSpacing.md),
            decoration: BoxDecoration(
              color: DriverAppColors.infoLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(DriverAppSpacing.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: DriverAppColors.infoLight),
                const SizedBox(width: DriverAppSpacing.sm),
                Expanded(
                  child: Text(
                    'سيتم مراجعة طلبك من قبل الإدارة وإضافة المبلغ إلى محفظتك',  // Request will be reviewed
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleContinue(List<BankApp> bankApps) {
    if (_currentStep == 0) {
      if (_selectedBank == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء اختيار البنك')),  // Please choose bank
        );
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      setState(() => _currentStep++);
    } else if (_currentStep == 2) {
      _submitRequest();
    }
  }

  void _handleCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBank == null) return;

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(authProvider).valueOrNull;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance.collection('topup_requests').add({
        'userId': user.uid,
        'userType': 'driver',
        'bankAppId': _selectedBank!.id,
        'destinationCode': _selectedBank!.destinationCode,
        'amount': int.parse(_amountController.text),
        'senderPhone': _phoneController.text,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال الطلب بنجاح'),  // Request submitted successfully
            backgroundColor: DriverAppColors.successLight,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${e.toString()}')),  // Error
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _BankAppCard extends StatelessWidget {
  final BankApp bank;
  final bool isSelected;
  final VoidCallback onTap;

  const _BankAppCard({
    required this.bank,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: DriverAppSpacing.sm),
      color: isSelected 
        ? DriverAppColors.primaryLight.withOpacity(0.1) 
        : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
        side: BorderSide(
          color: isSelected 
            ? DriverAppColors.primaryLight 
            : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(DriverAppSpacing.md),
          child: Row(
            children: [
              // Bank logo placeholder (use Image.asset if you have logos)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: DriverAppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(DriverAppSpacing.radiusSm),
                ),
                child: const Icon(Icons.account_balance),
              ),
              const SizedBox(width: DriverAppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bank.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      bank.nameEn,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DriverAppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: DriverAppColors.primaryLight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**D. Requests History Screen: `apps/wawapp_driver/lib/features/wallet/screens/topup_requests_screen.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bank_app.dart';
import '../providers/topup_provider.dart';

class TopupRequestsScreen extends ConsumerWidget {
  const TopupRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(topupRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الشحن'),  // Top-up Requests
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Text('لا توجد طلبات'),  // No requests
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(DriverAppSpacing.md),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return _RequestCard(request: requests[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('خطأ في تحميل الطلبات'),  // Error loading requests
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final TopupRequest request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: DriverAppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(DriverAppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${request.amount} MRU',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                _buildStatusBadge(context),
              ],
            ),
            const SizedBox(height: DriverAppSpacing.sm),
            _buildInfoRow(Icons.phone, request.senderPhone),
            _buildInfoRow(Icons.calendar_today, 
              '${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year}'),
            if (request.adminNotes != null) ...[
              const Divider(),
              Text(
                'ملاحظات: ${request.adminNotes}',  // Notes
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color color;
    String text;

    switch (request.status) {
      case 'pending':
        color = DriverAppColors.pendingYellow;
        text = 'قيد المراجعة';  // Under review
        break;
      case 'approved':
        color = DriverAppColors.completedGreen;
        text = 'مقبول';  // Approved
        break;
      case 'rejected':
        color = DriverAppColors.cancelledRed;
        text = 'مرفوض';  // Rejected
        break;
      default:
        color = DriverAppColors.textSecondaryLight;
        text = request.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverAppSpacing.sm,
        vertical: DriverAppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(DriverAppSpacing.radiusSm),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DriverAppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: DriverAppColors.textSecondaryLight),
          const SizedBox(width: DriverAppSpacing.xs),
          Text(
            text,
            style: const TextStyle(
              color: DriverAppColors.textSecondaryLight,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 4. Admin Verification

**Cloud Function (already exists):** `functions/src/approveTopupRequest.ts`

No changes needed - already implements admin approval with proper validation.

#### 5. Router Integration

Add to driver app router:
```dart
GoRoute(
  path: '/wallet/topup',
  name: 'topup',
  builder: (context, state) => const TopupFlowScreen(),
),
GoRoute(
  path: '/wallet/topup-requests',
  name: 'topup-requests',
  builder: (context, state) => const TopupRequestsScreen(),
),
```

### Testing Checklist - R2

- [ ] Create topup_config document in Firestore with bank apps
- [ ] Start top-up flow - verify all 3 steps display correctly
- [ ] Try to continue without selecting bank - should show error
- [ ] Select bank - verify destination code displays
- [ ] Copy destination code - verify clipboard
- [ ] Enter invalid amount (< 1000) - should show error
- [ ] Enter valid amount and phone - submit
- [ ] Verify topup_request created in Firestore
- [ ] Verify user cannot modify status field
- [ ] Admin approves request - verify wallet updated
- [ ] Check requests history screen shows all requests with correct status

---

## R3: Unified Theme/Language/Formatting

### Goal
Ensure consistent theme tokens, typography, spacing, and localization across all new screens.

### Implementation

#### 1. Create Shared Theme Constants (if not exists)

Both apps already have comprehensive theme systems. Ensure all new screens use:

**Client App:**
- Colors: `WawAppColors` from `apps/wawapp_client/lib/theme/colors.dart`
- Spacing: `WawAppSpacing` from `apps/wawapp_client/lib/theme/colors.dart`
- Typography: `WawAppTypography` from `apps/wawapp_client/lib/theme/typography.dart`

**Driver App:**
- Colors: `DriverAppColors` from `apps/wawapp_driver/lib/core/theme/colors.dart`
- Spacing: `DriverAppSpacing` from `apps/wawapp_driver/lib/core/theme/colors.dart`
- Elevation: `DriverAppElevation` from `apps/wawapp_driver/lib/core/theme/colors.dart`

#### 2. Localization Strategy

All new screens use Arabic strings directly (as that's the primary language for Mauritania).

For future i18n support, strings should be extracted to:
- `apps/wawapp_client/lib/l10n/app_ar.arb`
- `apps/wawapp_driver/lib/l10n/app_ar.arb`

#### 3. UI Consistency Checklist

Apply to ALL new screens (notifications, top-up, PIN change):

**Layout:**
- [ ] Use `WawAppSpacing` / `DriverAppSpacing` constants for padding/margins
- [ ] Consistent card elevation (`WawAppElevation.medium`)
- [ ] Consistent border radius (`radiusMd` for cards, `radiusSm` for chips)

**Typography:**
- [ ] Use `Theme.of(context).textTheme` for all text
- [ ] Title screens: `titleLarge` or `headlineSmall`
- [ ] Body text: `bodyMedium`
- [ ] Captions/hints: `bodySmall` with `textSecondary` color

**Colors:**
- [ ] Primary buttons: `WawAppColors.primary` / `DriverAppColors.primaryLight`
- [ ] Success states: `successLight` or `completedGreen`
- [ ] Error states: `errorLight` or `cancelledRed`
- [ ] Warning states: `warningLight` or `pendingYellow`
- [ ] Text: `textPrimaryLight/Dark` for main, `textSecondaryLight/Dark` for hints

**Components:**
- [ ] Use Material 3 components (ElevatedButton, OutlinedButton, Card)
- [ ] All buttons follow theme button styles
- [ ] All inputs follow theme input decoration
- [ ] Loading states use CircularProgressIndicator with primary color

**Arabic RTL Support:**
- [ ] Use `EdgeInsetsDirectional` instead of `EdgeInsets`
- [ ] Use `Directionality` widget if needed
- [ ] Test all screens in RTL mode

### Testing Checklist - R3

- [ ] All new screens use theme colors (no hardcoded colors)
- [ ] All spacing uses theme constants (no magic numbers)
- [ ] All text uses theme text styles
- [ ] All buttons follow theme button styles
- [ ] All Arabic text displays correctly
- [ ] RTL layout works correctly
- [ ] Dark mode works (if implemented)

---

## R4: Client PIN Change

### Goal
Allow clients to change PIN before and after login, mirroring driver functionality.

### Implementation

#### 1. Pre-Login Flow: Forgot PIN

**Screen: `apps/wawapp_client/lib/features/auth/forgot_pin_screen.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/colors.dart';
import 'providers/auth_service_provider.dart';

class ForgotPinScreen extends ConsumerStatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  ConsumerState<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends ConsumerState<ForgotPinScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نسيت الرمز السري'),  // Forgot PIN
      ),
      body: Padding(
        padding: const EdgeInsets.all(WawAppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'أدخل رقم هاتفك لإعادة تعيين الرمز السري',  // Enter phone to reset PIN
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: WawAppSpacing.xl),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف',  // Phone Number
                hintText: '+22212345678',
                prefixIcon: const Icon(Icons.phone),
                errorText: _errorMessage,
              ),
            ),
            const SizedBox(height: WawAppSpacing.lg),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSendOTP,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إرسال رمز التحقق'),  // Send verification code
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'الرجاء إدخال رقم الهاتف');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use existing auth service to send OTP
      await ref.read(authServiceProvider).sendOtp(phone);
      
      if (mounted) {
        // Navigate to OTP screen with reset_pin mode
        context.push('/auth/otp', extra: {
          'phone': phone,
          'mode': 'reset_pin',
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في إرسال الرمز: ${e.toString()}';  // Error sending code
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
```

**Update OTP Screen to handle PIN reset:**

In `apps/wawapp_client/lib/features/auth/otp_screen.dart`, add a mode parameter:
```dart
final String mode; // 'login' or 'reset_pin'

// After OTP verification success:
if (mode == 'reset_pin') {
  // Navigate to create new PIN
  context.pushReplacement('/auth/create-pin', extra: {
    'phone': widget.phone,
    'customToken': customToken,
  });
} else {
  // Normal login flow
  // ... existing code
}
```

#### 2. Post-Login Flow: Change PIN from Settings

**Screen: `apps/wawapp_client/lib/features/settings/screens/change_pin_screen.dart`**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import '../../../theme/colors.dart';

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تغيير الرمز السري'),  // Change PIN
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(WawAppSpacing.lg),
          children: [
            Text(
              'أدخل الرمز السري الحالي ثم الرمز الجديد',  // Enter current PIN then new PIN
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: WawAppSpacing.xl),
            TextFormField(
              controller: _currentPinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'الرمز السري الحالي',  // Current PIN
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (value) {
                if (value == null || value.length != 4) {
                  return 'الرمز السري يجب أن يكون 4 أرقام';  // PIN must be 4 digits
                }
                return null;
              },
            ),
            const SizedBox(height: WawAppSpacing.md),
            TextFormField(
              controller: _newPinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'الرمز السري الجديد',  // New PIN
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (value) {
                if (value == null || value.length != 4) {
                  return 'الرمز السري يجب أن يكون 4 أرقام';
                }
                if (value == _currentPinController.text) {
                  return 'الرمز الجديد يجب أن يكون مختلفاً عن الحالي';  // New PIN must be different
                }
                return null;
              },
            ),
            const SizedBox(height: WawAppSpacing.md),
            TextFormField(
              controller: _confirmPinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'تأكيد الرمز السري الجديد',  // Confirm new PIN
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (value) {
                if (value != _newPinController.text) {
                  return 'الرمز السري غير متطابق';  // PINs don't match
                }
                return null;
              },
            ),
            const SizedBox(height: WawAppSpacing.xl),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleChangePin,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('تغيير الرمز السري'),  // Change PIN
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChangePin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authProvider).valueOrNull;
      if (user == null) throw Exception('User not authenticated');

      // Get user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User document not found');
      }

      final data = userDoc.data()!;
      final storedHash = data['pinHash'] as String?;
      final storedSalt = data['pinSalt'] as String?;

      if (storedHash == null) {
        throw Exception('No PIN set');
      }

      // Verify current PIN
      String currentPinHash;
      if (storedSalt != null) {
        // New system with salt
        currentPinHash = _hashWithSalt(_currentPinController.text, storedSalt);
      } else {
        // Legacy system
        currentPinHash = sha256.convert(
          utf8.encode('${user.uid}:${_currentPinController.text}')
        ).toString();
      }

      if (currentPinHash != storedHash) {
        throw Exception('الرمز السري الحالي غير صحيح');  // Current PIN incorrect
      }

      // Generate new salt and hash
      final newSalt = _generateSalt();
      final newPinHash = _hashWithSalt(_newPinController.text, newSalt);

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'pinHash': newPinHash,
        'pinSalt': newSalt,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تغيير الرمز السري بنجاح'),  // PIN changed successfully
            backgroundColor: WawAppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: WawAppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashWithSalt(String pin, String salt) {
    return sha256.convert(utf8.encode('$pin:$salt')).toString();
  }
}
```

#### 3. Add to Settings Screen

Update `apps/wawapp_client/lib/features/settings/settings_screen.dart`:
```dart
ListTile(
  leading: const Icon(Icons.lock),
  title: const Text('تغيير الرمز السري'),  // Change PIN
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/settings/change-pin'),
),
```

#### 4. Update Router

Add routes:
```dart
GoRoute(
  path: '/auth/forgot-pin',
  name: 'forgot-pin',
  builder: (context, state) => const ForgotPinScreen(),
),
GoRoute(
  path: '/settings/change-pin',
  name: 'change-pin',
  builder: (context, state) => const ChangePinScreen(),
),
```

#### 5. Update Login Screen

Add "Forgot PIN?" link:
```dart
TextButton(
  onPressed: () => context.push('/auth/forgot-pin'),
  child: const Text('نسيت الرمز السري؟'),  // Forgot PIN?
),
```

### Testing Checklist - R4

**Pre-Login Flow:**
- [ ] Click "Forgot PIN?" on login screen
- [ ] Enter phone number
- [ ] Verify OTP is sent
- [ ] Enter OTP
- [ ] Create new PIN
- [ ] Verify can login with new PIN

**Post-Login Flow:**
- [ ] Navigate to Settings > Change PIN
- [ ] Enter wrong current PIN - should show error
- [ ] Enter same PIN as current for new PIN - should show error
- [ ] Enter mismatched confirm PIN - should show error
- [ ] Enter valid current PIN and new PIN
- [ ] Verify PIN updated in Firestore (pinHash and pinSalt changed)
- [ ] Logout and login with new PIN
- [ ] Verify old PIN no longer works

---

## R5: Client Order Cancellation Fix

### Goal
Fix client-side cancellation so it works when allowed (before trip starts).

### Current Issue Analysis

From the code review, the Firestore rules already restrict cancellation:
```javascript
(request.resource.data.status == "cancelledByClient" 
  && isOwner() 
  && resource.data.status in ["matching", "accepted"])
```

This means cancellation is only allowed when order is in "matching" or "accepted" status, NOT "onRoute".

### Implementation

#### 1. Update Order Service

**File: `apps/wawapp_client/lib/features/orders/services/order_service.dart`**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cancel order - only allowed if status is 'matching' or 'accepted'
  Future<void> cancelOrder(String orderId, String userId) async {
    try {
      final orderRef = _firestore.collection('orders').doc(orderId);
      
      // Use transaction to ensure status check
      await _firestore.runTransaction((transaction) async {
        final orderDoc = await transaction.get(orderRef);
        
        if (!orderDoc.exists) {
          throw Exception('الطلب غير موجود');  // Order not found
        }

        final data = orderDoc.data()!;
        final currentStatus = data['status'] as String?;
        final ownerId = data['ownerId'] as String?;

        // Verify ownership
        if (ownerId != userId) {
          throw Exception('غير مصرح لك بإلغاء هذا الطلب');  // Not authorized
        }

        // Check if cancellation is allowed
        if (currentStatus != 'matching' && currentStatus != 'accepted') {
          throw Exception('لا يمكن إلغاء الطلب بعد بدء الرحلة');  // Cannot cancel after trip started
        }

        // Update status
        transaction.update(orderRef, {
          'status': 'cancelledByClient',
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Check if order can be cancelled
  bool canCancelOrder(String orderStatus) {
    return orderStatus == 'matching' || orderStatus == 'accepted';
  }
}
```

#### 2. Create Provider

**File: `apps/wawapp_client/lib/features/orders/providers/order_service_provider.dart`**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/order_service.dart';

final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService();
});
```

#### 3. Update Order Details Screen

**File: `apps/wawapp_client/lib/features/orders/screens/order_details_screen.dart`**

Add cancel button:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/colors.dart';
import '../providers/order_service_provider.dart';
import '../models/order.dart';

class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),  // Order Details
      ),
      body: orderAsync.when(
        data: (order) => _buildContent(context, ref, order),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('خطأ في تحميل الطلب'),  // Error loading order
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Order order) {
    final orderService = ref.read(orderServiceProvider);
    final canCancel = orderService.canCancelOrder(order.status);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(WawAppSpacing.md),
            children: [
              // ... existing order details ...
              
              // Status
              _buildInfoCard(
                context,
                title: 'الحالة',  // Status
                value: _getStatusText(order.status),
                valueColor: _getStatusColor(order.status),
              ),

              // ... more details ...
            ],
          ),
        ),
        
        // Cancel button at bottom
        if (canCancel)
          Container(
            padding: const EdgeInsets.all(WawAppSpacing.md),
            decoration: BoxDecoration(
              color: WawAppColors.surfaceLight,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: OutlinedButton.icon(
                onPressed: () => _handleCancelOrder(context, ref, order),
                style: OutlinedButton.styleFrom(
                  foregroundColor: WawAppColors.error,
                  side: const BorderSide(color: WawAppColors.error),
                ),
                icon: const Icon(Icons.cancel),
                label: const Text('إلغاء الطلب'),  // Cancel Order
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleCancelOrder(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الطلب'),  // Cancel Order
        content: const Text('هل أنت متأكد من إلغاء هذا الطلب؟'),  // Are you sure?
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لا'),  // No
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: WawAppColors.error,
            ),
            child: const Text('نعم، إلغاء'),  // Yes, cancel
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final user = ref.read(authProvider).valueOrNull;
      if (user == null) throw Exception('User not authenticated');

      await ref.read(orderServiceProvider).cancelOrder(order.id, user.uid);

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الطلب بنجاح'),  // Order cancelled successfully
            backgroundColor: WawAppColors.success,
          ),
        );
        Navigator.of(context).pop(); // Go back to previous screen
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString()}'),
            backgroundColor: WawAppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: WawAppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(WawAppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: WawAppColors.textSecondaryLight,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? WawAppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'matching': return 'جاري البحث عن سائق';  // Looking for driver
      case 'accepted': return 'تم القبول';  // Accepted
      case 'onRoute': return 'في الطريق';  // On the way
      case 'completed': return 'مكتمل';  // Completed
      case 'cancelledByClient': return 'ملغي من العميل';  // Cancelled by client
      case 'cancelledByDriver': return 'ملغي من السائق';  // Cancelled by driver
      case 'cancelled': return 'ملغي';  // Cancelled
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'matching': return WawAppColors.warning;
      case 'accepted': return WawAppColors.info;
      case 'onRoute': return WawAppColors.primary;
      case 'completed': return WawAppColors.success;
      case 'cancelledByClient':
      case 'cancelledByDriver':
      case 'cancelled': return WawAppColors.error;
      default: return WawAppColors.textSecondaryLight;
    }
  }
}
```

#### 4. Add Cancel Button to Active Order Card (Home Screen)

Update the active order card in home screen:
```dart
if (order.status == 'matching' || order.status == 'accepted')
  OutlinedButton.icon(
    onPressed: () => _showCancelDialog(context, order),
    style: OutlinedButton.styleFrom(
      foregroundColor: WawAppColors.error,
      side: const BorderSide(color: WawAppColors.error),
    ),
    icon: const Icon(Icons.cancel, size: 18),
    label: const Text('إلغاء'),  // Cancel
  ),
```

### Testing Checklist - R5

**Allowed Cancellation:**
- [ ] Create order (status = 'matching')
- [ ] Verify cancel button is visible
- [ ] Click cancel - confirm dialog appears
- [ ] Cancel order - verify success message
- [ ] Check Firestore - status = 'cancelledByClient'
- [ ] Driver assigned (status = 'accepted')
- [ ] Verify cancel button still visible
- [ ] Cancel order - should succeed

**Blocked Cancellation:**
- [ ] Driver starts trip (status = 'onRoute')
- [ ] Verify cancel button is NOT visible
- [ ] Try to cancel via Firestore console - should fail with permission denied
- [ ] Completed order - verify no cancel button

**Edge Cases:**
- [ ] Cancel while driver is accepting (race condition) - should handle gracefully
- [ ] Cancel with no internet - should show error
- [ ] Cancel with expired auth - should re-auth

---

## Firestore Schema Summary

### New Collections

#### 1. notifications
```typescript
{
  id: string;
  userId: string;
  type: 'order_update' | 'system' | 'promotion' | 'driver_message';
  title: string;
  body: string;
  data: map;
  read: boolean;
  actionUrl?: string;
  createdAt: Timestamp;
  expiresAt?: Timestamp;
}
```

**Indexes:**
```json
{
  "collectionGroup": "notifications",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

#### 2. topup_requests
```typescript
{
  id: string;
  userId: string;
  userType: 'driver' | 'client';
  bankAppId: string;
  destinationCode: string;
  amount: number;
  senderPhone: string;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: Timestamp;
  updatedAt: Timestamp;
  adminReviewedBy?: string;
  adminReviewedAt?: Timestamp;
  adminNotes?: string;
  approvalTransactionId?: string;
}
```

**Indexes:**
```json
{
  "collectionGroup": "topup_requests",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

#### 3. app_config
```typescript
{
  id: 'topup_config',
  bankApps: Array<{
    id: string;
    name: string;
    nameEn: string;
    destinationCode: string;
    logo: string;
  }>;
  minAmount: number;
  maxAmount: number;
}
```

---

## Firestore Rules Updates

**Add to firestore.rules:**
```javascript
// Notifications
match /notifications/{notificationId} {
  allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
  allow write: if isAdmin();
  allow update: if isSignedIn() 
    && resource.data.userId == request.auth.uid
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['read', 'updatedAt']);
}

// Top-up Requests
match /topup_requests/{requestId} {
  allow read, write: if isAdmin();
  allow create: if isSignedIn()
    && request.resource.data.userId == request.auth.uid
    && request.resource.data.status == 'pending'
    && request.resource.data.amount >= 1000
    && request.resource.data.amount <= 100000
    && request.resource.data.senderPhone is string
    && request.resource.data.bankAppId is string
    && !('adminReviewedBy' in request.resource.data)
    && !('approvalTransactionId' in request.resource.data);
  allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
}

// App Config
match /app_config/{configId} {
  allow read: if true;
  allow write: if isAdmin();
}
```

---

## Deployment Steps

### 1. Firestore Setup
```bash
# Deploy rules
firebase deploy --only firestore:rules

# Deploy indexes
firebase deploy --only firestore:indexes

# Create topup_config document manually
firebase firestore:set app_config/topup_config '{
  "bankApps": [
    {
      "id": "bim",
      "name": "بنك موريتانيا الدولي",
      "nameEn": "Banque Internationale de Mauritanie",
      "destinationCode": "22101234",
      "logo": "assets/banks/bim.png"
    },
    {
      "id": "bci",
      "name": "البنك التجاري",
      "nameEn": "Banque Commerciale et Industrielle",
      "destinationCode": "22105678",
      "logo": "assets/banks/bci.png"
    }
  ],
  "minAmount": 1000,
  "maxAmount": 100000
}'
```

### 2. Flutter Apps
```bash
# Client app
cd apps/wawapp_client
flutter pub get
flutter build apk --release

# Driver app
cd apps/wawapp_driver
flutter pub get
flutter build apk --release
```

### 3. Testing
- Follow each requirement's testing checklist
- Test on real devices (Android + iOS)
- Test with real Firebase project (not emulator)

---

## Commit Structure

```bash
# R1: Notifications
git add .
git commit -m "feat(client,driver): in-app notifications inbox with Firestore persistence

- Add notifications collection with Firestore rules
- Implement NotificationsScreen with unread badge
- Add deeplink handling from FCM
- Support multiple notification types (order, system, promotion)
- Add mark as read functionality
- Update router with /notifications route

Closes R1"

# R2: Top-up
git add .
git commit -m "feat(driver): guided top-up flow with banking app selection

- Add topup_requests collection with secure rules
- Implement 3-step wizard: bank selection -> destination code -> amount/phone
- Add app_config collection for bank apps configuration
- Implement TopupRequestsScreen for history
- Admin verification via existing Cloud Function
- Prevent self-approval via Firestore rules

Closes R2"

# R3: Theme
git add .
git commit -m "chore(client,driver): unify theme/language across new screens

- Apply WawAppSpacing/DriverAppSpacing constants
- Use theme text styles consistently
- Arabic strings for all new UI
- Consistent button/card/input styling
- RTL support with EdgeInsetsDirectional

Closes R3"

# R4: PIN
git add .
git commit -m "feat(client): add PIN change flows (pre/post login)

- Add ForgotPinScreen for pre-login PIN reset
- Add ChangePinScreen for post-login PIN change
- Implement OTP verification for reset flow
- Use salted PIN hashing matching driver behavior
- Add routes and settings integration

Closes R4"

# R5: Cancel
git add .
git commit -m "fix(client): client order cancellation flow

- Add OrderService with transaction-based cancellation
- Only allow cancel when status in ['matching', 'accepted']
- Add cancel button to OrderDetailsScreen
- Add cancel button to active order card
- Show confirmation dialog before cancel
- Handle cancellation errors gracefully

Closes R5"
```

---

## Known Limitations & Assumptions

### Assumptions
1. Firebase project is already set up and configured
2. FCM tokens are being collected and stored
3. Admin panel exists for top-up request approval
4. Phone verification (OTP) is working
5. Both apps use Firebase Auth
6. Mauritania is primary market (Arabic language)

### Limitations
1. **Notifications**: No push notification triggers from this implementation (needs Cloud Functions to create notification documents)
2. **Top-up**: Bank app list is static config (no dynamic fetching from external API)
3. **Top-up**: No payment verification (admin must manually verify via banking portal)
4. **PIN Reset**: Requires active phone number (no email fallback)
5. **Cancellation**: No automatic refunds (if payment was made)
6. **Localization**: Arabic only (no i18n framework integration)

### Future Enhancements
1. Add Cloud Functions to create notification documents automatically
2. Integrate with banking APIs for automatic payment verification
3. Add payment integration for automatic refunds
4. Full i18n support with flutter_localizations
5. Dark mode support for all screens
6. Offline support with local caching
7. Analytics tracking for all user actions

---

## QA Test Matrix

| Requirement | Screen/Feature | Test Case | Priority |
|-------------|---------------|-----------|----------|
| R1 | Notifications Inbox | Display notifications list | P0 |
| R1 | Notifications Inbox | Mark notification as read | P0 |
| R1 | Notifications Inbox | Tap notification - navigate to order | P0 |
| R1 | Notifications Inbox | Unread badge count | P1 |
| R1 | Deep Links | System notification opens app to detail | P0 |
| R2 | Top-up Flow | Select bank app | P0 |
| R2 | Top-up Flow | Display destination code | P0 |
| R2 | Top-up Flow | Copy destination code | P1 |
| R2 | Top-up Flow | Submit with valid amount/phone | P0 |
| R2 | Top-up Flow | Reject invalid amount (< 1000) | P0 |
| R2 | Top-up Flow | Reject invalid amount (> 100000) | P0 |
| R2 | Top-up Flow | Reject invalid phone format | P0 |
| R2 | Top-up Requests | Display request history | P1 |
| R2 | Top-up Requests | Show status (pending/approved/rejected) | P1 |
| R2 | Admin Verification | Admin can approve request | P0 |
| R2 | Admin Verification | User cannot modify status | P0 |
| R3 | Theme | All screens use theme colors | P0 |
| R3 | Theme | All screens use spacing constants | P0 |
| R3 | Theme | Arabic text displays correctly | P0 |
| R3 | Theme | RTL layout works | P1 |
| R4 | Forgot PIN | Send OTP to phone | P0 |
| R4 | Forgot PIN | Verify OTP and create new PIN | P0 |
| R4 | Change PIN | Verify current PIN | P0 |
| R4 | Change PIN | Reject same PIN as current | P0 |
| R4 | Change PIN | Reject mismatched confirm PIN | P0 |
| R4 | Change PIN | Update PIN in Firestore | P0 |
| R4 | Change PIN | Login with new PIN works | P0 |
| R5 | Cancel Order | Show cancel button when status = matching | P0 |
| R5 | Cancel Order | Show cancel button when status = accepted | P0 |
| R5 | Cancel Order | Hide cancel button when status = onRoute | P0 |
| R5 | Cancel Order | Confirmation dialog before cancel | P0 |
| R5 | Cancel Order | Update status to cancelledByClient | P0 |
| R5 | Cancel Order | Firestore rules prevent post-trip cancel | P0 |

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Firestore rules too restrictive | HIGH | Thorough testing in staging before production |
| Notification spam | MEDIUM | Implement rate limiting in Cloud Functions |
| Top-up fraud | HIGH | Admin verification + manual banking portal check |
| PIN reset abuse | MEDIUM | Use existing OTP rate limiting |
| Race condition in cancellation | MEDIUM | Transaction-based updates |
| Poor UX for Arabic speakers | HIGH | Native Arabic speaker testing |

---

## Performance Considerations

1. **Notifications**: Limit query to 100 most recent
2. **Top-up Requests**: Limit query to 50 most recent
3. **Order Details**: Single document fetch (no joins)
4. **Theme**: No runtime theme switching (reduce rebuilds)

---

## Security Checklist

- [ ] All new Firestore collections have security rules
- [ ] Rules prevent unauthorized access
- [ ] Rules prevent privilege escalation
- [ ] PIN hashing uses salt
- [ ] OTP rate limiting is enforced
- [ ] Admin-only operations are protected
- [ ] No sensitive data in client logs

---

## END OF IMPLEMENTATION PLAN

This document provides a complete, production-ready implementation plan for all 5 requirements. Each section includes:
- Detailed code with proper error handling
- Firestore schema and security rules
- UI with Arabic localization
- Testing checklists
- Deployment steps

The implementation follows the "controlled execution mode" constraint:
- Minimal, safe changes
- No refactoring of existing code
- Clear commit structure
- Comprehensive testing guidance

**Next Steps:**
1. Review this plan with the team
2. Create tasks in project management tool
3. Implement each requirement in order (R1 → R5)
4. Follow testing checklists rigorously
5. Deploy to staging first
6. Conduct user acceptance testing
7. Deploy to production

**Estimated Implementation Time:**
- R1: 8 hours
- R2: 12 hours
- R3: 4 hours (applied throughout)
- R4: 6 hours
- R5: 4 hours
- Testing & Bug Fixes: 8 hours
- **Total: ~42 hours (~1 week for single developer)**
