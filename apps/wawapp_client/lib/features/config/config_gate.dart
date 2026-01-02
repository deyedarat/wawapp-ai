import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/config_provider.dart';
import '../../core/utils/version_utils.dart';
import 'maintenance_screen.dart';
import 'update_required_screen.dart';

/// Widget that checks app configuration before showing child
/// Handles maintenance mode, force updates, and version checks
class ConfigGate extends ConsumerWidget {
  final Widget child;

  const ConfigGate({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      data: (config) {
        // Check maintenance mode first (highest priority)
        if (config.maintenance) {
          return MaintenanceScreen(
            message: config.message,
            supportWhatsApp: config.supportWhatsApp,
          );
        }

        // Check for force update
        if (config.forceUpdate) {
          return FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final currentVersion =
                    VersionUtils.extractVersion(snapshot.data!.version);
                return UpdateRequiredScreen(
                  currentVersion: currentVersion,
                  requiredVersion: config.minClientVersion,
                  message: config.message,
                  isForced: true,
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          );
        }

        // Check version requirement
        return FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final currentVersion =
                  VersionUtils.extractVersion(snapshot.data!.version);
              final needsUpdate = VersionUtils.isUpdateRequired(
                currentVersion,
                config.minClientVersion,
              );

              if (needsUpdate) {
                return UpdateRequiredScreen(
                  currentVersion: currentVersion,
                  requiredVersion: config.minClientVersion,
                  message: config.message,
                  isForced: true,
                );
              }
            }

            // All checks passed, show the app
            return child;
          },
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0B1220),
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      ),
      error: (error, stack) {
        // If config fetch fails, allow app to continue
        // This prevents network issues from blocking the app
        debugPrint('⚠️ Config fetch failed: $error');
        debugPrint('   Allowing app to continue...');
        return child;
      },
    );
  }
}
