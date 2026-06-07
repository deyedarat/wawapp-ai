import 'package:flutter/material.dart';

/// Extension methods for common types.

extension StringExtensions on String {
  /// Capitalizes the first letter.
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Checks if the string is a valid number.
  bool get isNumeric => double.tryParse(this) != null;
}

extension DateTimeExtensions on DateTime {
  /// Returns true if the date is today.
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Returns true if the date is in the past.
  bool get isPast => isBefore(DateTime.now());

  /// Returns the start of the day.
  DateTime get startOfDay => DateTime(year, month, day);

  /// Returns the end of the day.
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);

  /// Returns the start of the week (Monday).
  DateTime get startOfWeek {
    final daysFromMonday = weekday - 1;
    return subtract(Duration(days: daysFromMonday)).startOfDay;
  }

  /// Returns the start of the month.
  DateTime get startOfMonth => DateTime(year, month, 1);
}

extension ContextExtensions on BuildContext {
  /// Gets the current theme.
  ThemeData get theme => Theme.of(this);

  /// Gets the text theme.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Gets the color scheme.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Gets the screen size.
  Size get screenSize => MediaQuery.of(this).size;

  /// Gets the screen width.
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Gets the screen height.
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Shows a snackbar.
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
