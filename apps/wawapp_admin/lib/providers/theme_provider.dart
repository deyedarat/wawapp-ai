/// Theme Provider
/// Manages light/dark theme state for the admin panel with localStorage persistence
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theme mode state notifier with persistence
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _storageKey = 'wawapp_admin_theme_mode';

  ThemeModeNotifier() : super(_loadSavedTheme());

  /// Load saved theme from localStorage
  static ThemeMode _loadSavedTheme() {
    try {
      final saved = html.window.localStorage[_storageKey];
      if (saved == 'dark') return ThemeMode.dark;
      if (saved == 'light') return ThemeMode.light;
    } catch (_) {}
    return ThemeMode.light;
  }

  /// Save theme preference to localStorage
  void _saveTheme(ThemeMode mode) {
    try {
      html.window.localStorage[_storageKey] = mode == ThemeMode.dark ? 'dark' : 'light';
    } catch (_) {}
  }

  void toggle() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveTheme(state);
  }

  void setLight() {
    state = ThemeMode.light;
    _saveTheme(state);
  }

  void setDark() {
    state = ThemeMode.dark;
    _saveTheme(state);
  }
}

/// Provider for theme mode
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
