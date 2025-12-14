/**
 * Application Configuration Base Class
 * Defines environment-specific configuration for WawApp Admin Panel
 * 
 * Security: Controls authentication mode, logging, and feature flags
 */

import 'dev_config.dart';
import 'staging_config.dart';
import 'prod_config.dart';

/// Application configuration base class
abstract class AppConfig {
  /// Environment name (dev, staging, prod)
  String get environment;
  
  /// Whether to use strict admin authentication
  /// - true: Enforce isAdmin custom claim check (PRODUCTION)
  /// - false: Allow dev auth bypass (DEVELOPMENT ONLY)
  bool get useStrictAuth;
  
  /// Whether to enable debug logging
  bool get enableDebugLogging;
  
  /// Whether to show dev tools
  bool get showDevTools;
  
  /// Firebase project ID
  String get firebaseProjectId;
  
  /// API base URL (if applicable)
  String? get apiBaseUrl;
  
  /// Whether this is a production environment
  bool get isProduction => environment == 'prod';
  
  /// Whether this is a development environment
  bool get isDevelopment => environment == 'dev';
  
  /// Whether this is a staging environment
  bool get isStaging => environment == 'staging';
}

/// Factory to get current config based on environment
class AppConfigFactory {
  static AppConfig? _instance;
  
  /// Get current configuration instance
  static AppConfig get current {
    if (_instance == null) {
      _instance = _createConfig();
    }
    return _instance!;
  }
  
  /// Create configuration based on ENVIRONMENT dart-define
  static AppConfig _createConfig() {
    const environment = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'prod',  // SAFE DEFAULT: Always default to production
    );
    
    switch (environment.toLowerCase()) {
      case 'dev':
      case 'development':
        return DevConfig();
      case 'staging':
      case 'stage':
        return StagingConfig();
      case 'prod':
      case 'production':
      default:
        // Default to production for safety
        return ProdConfig();
    }
  }
  
  /// Reset instance (for testing)
  static void reset() {
    _instance = null;
  }
}
