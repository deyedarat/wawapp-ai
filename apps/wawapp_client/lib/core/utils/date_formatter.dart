import 'package:intl/intl.dart';

/// Utility class for formatting dates in the WawApp client
class DateFormatter {
  DateFormatter._(); // Private constructor to prevent instantiation

  /// Format order creation date for UI display
  /// Returns formatted date or fallback if null
  static String formatOrderCreated(DateTime? dateTime) {
    if (dateTime == null) return 'غير محدد';
    return DateFormat('yyyy-MM-dd HH:mm', 'ar').format(dateTime);
  }

  /// Format order completion date for UI display
  /// Returns formatted date or fallback if null
  static String formatOrderCompleted(DateTime? dateTime) {
    if (dateTime == null) return 'لم يكتمل بعد';
    return DateFormat('yyyy-MM-dd HH:mm', 'ar').format(dateTime);
  }

  /// Format date with relative time (e.g., "منذ ساعتين")
  /// Returns relative time string or absolute date if too old
  static String formatRelative(DateTime? dateTime) {
    if (dateTime == null) return 'غير محدد';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inHours < 1) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inDays < 1) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return DateFormat('yyyy-MM-dd', 'ar').format(dateTime);
    }
  }
}
