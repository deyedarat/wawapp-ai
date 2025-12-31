/**
 * Production Configuration
 * 
 * ✅ SECURE: Enforces strict authentication and security measures
 * 
 * Features:
 * - STRICT authentication (isAdmin custom claim REQUIRED)
 * - No debug logging (clean production logs)
 * - No dev tools
 * - Production Firebase project
 * - Maximum security and performance
 */

import 'app_config.dart';

class ProdConfig implements AppConfig {
  @override
  String get environment => 'prod';
  
  @override
  bool get useStrictAuth => true;  // ✅ ENFORCE strict admin authentication
  
  @override
  bool get enableDebugLogging => false;  // Clean production logs
  
  @override
  bool get showDevTools => false;  // Hide dev tools
  
  @override
  String get firebaseProjectId => 'wawapp-952d6';  // Production project
  
  @override
  String? get apiBaseUrl => null;  // Use default Firebase Functions
}
