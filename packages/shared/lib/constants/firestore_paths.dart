/// Firestore collection and document paths.
class FirestorePaths {
  FirestorePaths._();

  // Collections
  static const String users = 'users';
  static const String orders = 'orders';
  static const String laundries = 'laundries';
  static const String ratings = 'ratings';
  static const String notifications = 'notifications';

  // Document fields
  static const String fieldCustomerId = 'customerId';
  static const String fieldLaundryId = 'laundryId';
  static const String fieldStatus = 'status';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldPhoneNumber = 'phoneNumber';
  static const String fieldRole = 'role';
  static const String fieldFcmToken = 'fcmToken';
  static const String fieldIsActive = 'isActive';
}
