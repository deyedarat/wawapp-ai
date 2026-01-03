import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/models/app_config.dart';

/// Service for fetching app configuration from backend
/// Handles maintenance mode, force updates, and version requirements
class ConfigService {
  /// Production config URL (HTTPS domain)
  /// Can be overridden via --dart-define=WAWAPP_CONFIG_URL=https://your-domain.com
  static const String _defaultConfigUrl = 'https://config.wawappmr.com/api/public/config';
  
  /// Get config URL from environment or use default
  static String get configUrl => 
      const String.fromEnvironment('WAWAPP_CONFIG_URL', defaultValue: _defaultConfigUrl);
  
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
        debugPrint('🌐 Fetching config from $configUrl');
      }

      final uri = Uri.parse(configUrl);
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
