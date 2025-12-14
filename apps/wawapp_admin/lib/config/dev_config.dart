/**
 * Development Configuration
 * 
 * ⚠️ WARNING: This configuration BYPASSES admin authentication checks
 * ⚠️ DO NOT USE IN PRODUCTION
 * 
 * Features:
 * - Relaxed authentication (any authenticated user can access admin panel)
 * - Debug logging enabled
 * - Dev tools visible
 * - Local development optimizations
 */

import 'app_config.dart';

class DevConfig implements AppConfig {
  @override
  String get environment => 'dev';
  
  @override
  bool get useStrictAuth => false;  // ⚠️ DANGER: Allows dev auth bypass
  
  @override
  bool get enableDebugLogging => true;
  
  @override
  bool get showDevTools => true;
  
  @override
  String get firebaseProjectId => 'wawapp-dev-952d6';  // Dev project (if exists)
  
  @override
  String? get apiBaseUrl => 'http://localhost:5001';  // Local emulator
}
