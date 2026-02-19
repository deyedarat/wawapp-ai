import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global search provider for admin panel
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Search controller provider
final searchControllerProvider = Provider<TextEditingController>((ref) {
  final controller = TextEditingController();

  // Update search query when text changes
  controller.addListener(() {
    ref.read(searchQueryProvider.notifier).state = controller.text;
  });

  return controller;
});

/// Search helper functions
class SearchHelper {
  /// Check if a string contains the search query (case-insensitive)
  static bool matches(String text, String query) {
    if (query.isEmpty) return true;
    return text.toLowerCase().contains(query.toLowerCase());
  }

  /// Check if any of the strings contain the search query
  static bool matchesAny(List<String> texts, String query) {
    if (query.isEmpty) return true;
    return texts.any((text) => matches(text, query));
  }
}
