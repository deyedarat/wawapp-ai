import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/models/app_config.dart';

/// Service for fetching app configuration from backend
/// Handles maintenance mode, force updates, and version requirements
class ConfigService {
  static const String baseUrl = 'http://77.42.76.36';
  static const String configEndpoint = '/api/public/config';
  static const Duration timeout = Duration(seconds: 10);

  /// Singleton instance
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  /// Cached config to avoid repeated network calls
  AppConfig? _cachedConfig;
  DateTime? _lastFetchTime;
  static const Duration cacheTimeout = Duration(minutes: 5);

  /// Fetch app configuration from backend
  /// Returns cached config if available and not expired
  Future<AppConfig> fetchConfig({bool forceRefresh = false}) async {
    // Return cached config if available and not expired
    if (!forceRefresh &&
        _cachedConfig != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < cacheTimeout) {
      if (kDebugMode) {
        debugPrint('📦 Returning cached config');
      }
      return _cachedConfig!;
    }

    try {
      if (kDebugMode) {
        debugPrint('🌐 Fetching config from $baseUrl$configEndpoint');
      }

      final uri = Uri.parse('$baseUrl$configEndpoint');
      final response = await http.get(uri).timeout(timeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final config = AppConfig.fromJson(jsonData);

        // Cache the config
        _cachedConfig = config;
        _lastFetchTime = DateTime.now();

        if (kDebugMode) {
          debugPrint('✅ Config fetched successfully: $config');
        }

        return config;
      } else {
        throw ConfigException(
          'Failed to fetch config: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Network error fetching config: $e');
      }
      throw ConfigException('Network error: $e');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error fetching config: $e');
      }
      throw ConfigException('Failed to fetch config: $e');
    }
  }

  /// Clear cached config
  void clearCache() {
    _cachedConfig = null;
    _lastFetchTime = null;
    if (kDebugMode) {
      debugPrint('🗑️ Config cache cleared');
    }
  }

  /// Get cached config without making network request
  AppConfig? getCachedConfig() => _cachedConfig;
}

/// Exception thrown when config fetch fails
class ConfigException implements Exception {
  final String message;
  ConfigException(this.message);

  @override
  String toString() => 'ConfigException: $message';
}
