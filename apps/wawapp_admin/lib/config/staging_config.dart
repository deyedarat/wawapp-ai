/**
 * Staging Configuration
 * 
 * Pre-production environment for testing with production-like settings
 * 
 * Features:
 * - STRICT authentication (same as production)
 * - Debug logging enabled (for troubleshooting)
 * - Dev tools visible (for testing)
 * - Test/staging data
 */

import 'app_config.dart';

class StagingConfig implements AppConfig {
  @override
  String get environment => 'staging';
  
  @override
  bool get useStrictAuth => true;  // ✅ Strict auth like production
  
  @override
  bool get enableDebugLogging => true;  // But keep logging for debugging
  
  @override
  bool get showDevTools => true;  // And dev tools for testing
  
  @override
  String get firebaseProjectId => 'wawapp-staging-952d6';  // Staging project (if exists)
  
  @override
  String? get apiBaseUrl => null;  // Use default Firebase Functions
}
