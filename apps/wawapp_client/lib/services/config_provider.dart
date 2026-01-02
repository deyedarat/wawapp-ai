import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/app_config.dart';
import 'config_service.dart';

/// Provider for ConfigService singleton
final configServiceProvider = Provider<ConfigService>((ref) {
  return ConfigService();
});

/// Provider for fetching and caching app configuration
/// This is a FutureProvider that automatically handles loading states
final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  final configService = ref.watch(configServiceProvider);
  return await configService.fetchConfig();
});

/// Provider for getting cached config synchronously (may be null)
final cachedConfigProvider = Provider<AppConfig?>((ref) {
  final configService = ref.watch(configServiceProvider);
  return configService.getCachedConfig();
});
