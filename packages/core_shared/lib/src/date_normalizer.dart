import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Safely normalize Firestore Timestamp to DateTime
DateTime? normalizeTimestamp(Timestamp? timestamp) {
  if (timestamp == null) return null;
  try {
    return timestamp.toDate();
  } catch (e) {
    return null;
  }
}

/// Format DateTime for MRU display (Arabic-friendly)
String formatDateForMRU(DateTime dateTime) {
  final formatter = DateFormat('dd/MM/yyyy HH:mm');
  return formatter.format(dateTime);
}

/// Safely convert DateTime to local with null safety
DateTime? toLocalWithSafety(DateTime? dateTime) {
  if (dateTime == null) return null;
  try {
    return dateTime.toLocal();
  } catch (e) {
    return dateTime;
  }
}

/// Group orders by date categories
enum DateCategory {
  today,
  yesterday,
  thisWeek,
  older,
}

/// Get date category for grouping
DateCategory getDateCategory(DateTime? dateTime) {
  if (dateTime == null) return DateCategory.older;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekStart = today.subtract(Duration(days: now.weekday - 1));

  if (dateTime.isAfter(today)) {
    return DateCategory.today;
  } else if (dateTime.isAfter(yesterday)) {
    return DateCategory.yesterday;
  } else if (dateTime.isAfter(weekStart)) {
    return DateCategory.thisWeek;
  } else {
    return DateCategory.older;
  }
}

/// Get Arabic label for date category
String getDateCategoryLabel(DateCategory category) {
  switch (category) {
    case DateCategory.today:
      return 'اليوم';
    case DateCategory.yesterday:
      return 'أمس';
    case DateCategory.thisWeek:
      return 'هذا الأسبوع';
    case DateCategory.older:
      return 'سابقاً';
  }
}
