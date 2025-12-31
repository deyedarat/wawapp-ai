import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart' as core;

/// Mock data for Firebase Test Lab Mode
class TestLabMockData {
  static const String mockDriverId = 'testlab_driver_001';
  static const String mockDriverPhone = '+222123456789';

  /// Mock Firebase User for Test Lab
  static User get mockUser => _MockUser();

  /// Mock Driver Profile for Test Lab
  static core.DriverProfile get mockDriverProfile => core.DriverProfile(
        id: mockDriverId,
        name: 'أحمد محمد',
        phone: mockDriverPhone,
        photoUrl: null,
        vehicleType: 'سيدان',
        vehiclePlate: 'ABC-123',
        vehicleColor: 'أبيض',
        city: 'نواكشوط',
        region: 'تفرغ زينة',
        isVerified: true,
        isOnline: true,
        rating: 4.7,
        totalTrips: 156,
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        updatedAt: DateTime.now(),
      );

  /// Mock Firestore Document for driver profile
  static DocumentSnapshot<Map<String, dynamic>> get mockDriverDoc =>
      _MockDocumentSnapshot();

  /// Mock completed orders for earnings
  static List<core.Order> get mockCompletedOrders => [
        core.Order(
          id: 'order_001',
          ownerId: 'client_001',
          distanceKm: 5.2,
          price: 1500,
          pickupAddress: 'السوق المركزي، نواكشوط',
          dropoffAddress: 'جامعة نواكشوط العصرية',
          pickup: const core.LocationPoint(
              lat: 18.0735, lng: -15.9582, label: 'السوق المركزي'),
          dropoff: const core.LocationPoint(
              lat: 18.1012, lng: -15.9456, label: 'جامعة نواكشوط'),
          status: 'completed',
          driverId: mockDriverId,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          completedAt:
              DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
          driverRating: 5,
        ),
        core.Order(
          id: 'order_002',
          ownerId: 'client_002',
          distanceKm: 3.1,
          price: 900,
          pickupAddress: 'مطار نواكشوط الدولي',
          dropoffAddress: 'فندق الموريتاني',
          pickup: const core.LocationPoint(
              lat: 18.0969, lng: -15.9497, label: 'المطار'),
          dropoff: const core.LocationPoint(
              lat: 18.0866, lng: -15.9560, label: 'فندل الموريتاني'),
          status: 'completed',
          driverId: mockDriverId,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          completedAt:
              DateTime.now().subtract(const Duration(days: 1, hours: -1)),
          driverRating: 4,
        ),
      ];

  /// Mock nearby orders for map screen
  static List<core.Order> get mockNearbyOrders => [
        core.Order(
          id: 'nearby_001',
          ownerId: 'client_003',
          distanceKm: 2.8,
          price: 800,
          pickupAddress: 'مستشفى الشيخ زايد',
          dropoffAddress: 'السوق الكبير',
          pickup: const core.LocationPoint(
              lat: 18.0845, lng: -15.9523, label: 'مستشفى الشيخ زايد'),
          dropoff: const core.LocationPoint(
              lat: 18.0735, lng: -15.9582, label: 'السوق الكبير'),
          status: 'matching',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        core.Order(
          id: 'nearby_002',
          ownerId: 'client_004',
          distanceKm: 4.1,
          price: 1200,
          pickupAddress: 'جامعة نواكشوط',
          dropoffAddress: 'مركز التسوق',
          pickup: const core.LocationPoint(
              lat: 18.1012, lng: -15.9456, label: 'جامعة نواكشوط'),
          dropoff: const core.LocationPoint(
              lat: 18.0923, lng: -15.9634, label: 'مركز التسوق'),
          status: 'matching',
          createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      ];
}

/// Mock Firebase User implementation
class _MockUser implements User {
  @override
  String get uid => TestLabMockData.mockDriverId;

  @override
  String? get phoneNumber => TestLabMockData.mockDriverPhone;

  @override
  String? get displayName => 'Test Lab Driver';

  @override
  String? get email => null;

  @override
  bool get emailVerified => false;

  @override
  bool get isAnonymous => false;

  @override
  UserMetadata get metadata => throw UnimplementedError();

  @override
  List<UserInfo> get providerData => [];

  @override
  String? get refreshToken => null;

  @override
  String? get tenantId => null;

  @override
  String? get photoURL => null;

  @override
  MultiFactor get multiFactor => throw UnimplementedError();

  @override
  Future<UserCredential> linkWithProvider(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> reauthenticateWithProvider(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<void> delete() => throw UnimplementedError();

  @override
  Future<String> getIdToken([bool forceRefresh = false]) =>
      throw UnimplementedError();

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> linkWithCredential(AuthCredential credential) =>
      throw UnimplementedError();

  @override
  Future<ConfirmationResult> linkWithPhoneNumber(String phoneNumber,
          [RecaptchaVerifier? verifier]) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> linkWithPopup(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<void> linkWithRedirect(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> reauthenticateWithCredential(
          AuthCredential credential) =>
      throw UnimplementedError();

  @override
  Future<UserCredential> reauthenticateWithPopup(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<void> reauthenticateWithRedirect(AuthProvider provider) =>
      throw UnimplementedError();

  @override
  Future<void> reload() => throw UnimplementedError();

  @override
  Future<void> sendEmailVerification(
          [ActionCodeSettings? actionCodeSettings]) =>
      throw UnimplementedError();

  @override
  Future<User> unlink(String providerId) => throw UnimplementedError();

  @override
  Future<void> updateDisplayName(String? displayName) =>
      throw UnimplementedError();

  @override
  Future<void> updateEmail(String newEmail) => throw UnimplementedError();

  @override
  Future<void> updatePassword(String newPassword) => throw UnimplementedError();

  @override
  Future<void> updatePhoneNumber(PhoneAuthCredential phoneCredential) =>
      throw UnimplementedError();

  @override
  Future<void> updatePhotoURL(String? photoURL) => throw UnimplementedError();

  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) =>
      throw UnimplementedError();

  @override
  Future<void> verifyBeforeUpdateEmail(String newEmail,
          [ActionCodeSettings? actionCodeSettings]) =>
      throw UnimplementedError();
}

/// Mock Firestore DocumentSnapshot implementation
class _MockDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  String get id => TestLabMockData.mockDriverId;

  @override
  bool get exists => true;

  @override
  Map<String, dynamic>? data() => TestLabMockData.mockDriverProfile.toJson();

  @override
  DocumentReference<Map<String, dynamic>> get reference =>
      throw UnimplementedError();

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  dynamic get(Object field) => data()?[field];

  @override
  dynamic operator [](Object field) => get(field);
}
