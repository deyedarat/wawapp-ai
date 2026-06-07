import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

/// Formatting utilities for display purposes.
class Formatters {
  Formatters._();

  /// Formats a price with currency.
  static String formatPrice(double price, {String locale = 'ar'}) {
    final formatted = NumberFormat('#,##0', locale).format(price);
    if (locale == 'ar') {
      return '$formatted ${AppConstants.currencySymbol}';
    }
    return '$formatted ${AppConstants.currencySymbolFr}';
  }

  /// Formats a date for display.
  static String formatDate(DateTime date, {String locale = 'ar'}) {
    if (locale == 'ar') {
      return DateFormat('yyyy/MM/dd', 'ar').format(date);
    }
    return DateFormat('dd/MM/yyyy', 'fr').format(date);
  }

  /// Formats a time for display.
  static String formatTime(DateTime date, {String locale = 'ar'}) {
    return DateFormat('HH:mm', locale).format(date);
  }

  /// Formats a date and time for display.
  static String formatDateTime(DateTime date, {String locale = 'ar'}) {
    return '${formatDate(date, locale: locale)} ${formatTime(date, locale: locale)}';
  }

  /// Formats a relative time (e.g., "2 hours ago").
  static String formatRelativeTime(DateTime date, {String locale = 'ar'}) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return locale == 'ar' ? 'الآن' : 'Maintenant';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return locale == 'ar'
          ? 'منذ $minutes دقيقة'
          : 'Il y a $minutes min';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return locale == 'ar'
          ? 'منذ $hours ساعة'
          : 'Il y a $hours h';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return locale == 'ar'
          ? 'منذ $days يوم'
          : 'Il y a $days jour${days > 1 ? 's' : ''}';
    } else {
      return formatDate(date, locale: locale);
    }
  }

  /// Formats a phone number for display.
  static String formatPhoneDisplay(String phone) {
    if (phone.startsWith('+222') && phone.length == 12) {
      final number = phone.substring(4);
      return '+222 ${number.substring(0, 2)} ${number.substring(2, 4)} ${number.substring(4, 6)} ${number.substring(6)}';
    }
    return phone;
  }

  /// Formats an order number for display.
  static String formatOrderNumber(String orderId) {
    if (orderId.length > 6) {
      return '#${orderId.substring(0, 6).toUpperCase()}';
    }
    return '#${orderId.toUpperCase()}';
  }
}
