import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateState {
  final bool mustUpdate;
  final bool softUpdate;
  final String? downloadUrl;
  final String? latestVersion;
  final String? message;

  const AppUpdateState({
    this.mustUpdate = false,
    this.softUpdate = false,
    this.downloadUrl,
    this.latestVersion,
    this.message,
  });
}

final forceUpdateProvider = FutureProvider<AppUpdateState>((ref) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('driver_app')
        .get();

    if (!doc.exists) return const AppUpdateState();

    final data = doc.data()!;
    final minVersion = data['minVersion'] as String? ?? '0.0.0';
    final latestVersion = data['latestVersion'] as String? ?? '0.0.0';
    final downloadUrl = data['downloadUrl'] as String?;
    final forceUpdate = data['forceUpdate'] as bool? ?? false;
    final message = data['updateMessage'] as String?;

    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;

    if (kDebugMode) {
      debugPrint('[ForceUpdate] current=$currentVersion min=$minVersion '
          'latest=$latestVersion forceUpdate=$forceUpdate');
    }

    final isBelowMin = _compareVersions(currentVersion, minVersion) < 0;
    final isBelowLatest = _compareVersions(currentVersion, latestVersion) < 0;

    if (isBelowMin || (forceUpdate && isBelowLatest)) {
      return AppUpdateState(
        mustUpdate: true,
        downloadUrl: downloadUrl,
        latestVersion: latestVersion,
        message: message,
      );
    }

    if (isBelowLatest) {
      return AppUpdateState(
        softUpdate: true,
        downloadUrl: downloadUrl,
        latestVersion: latestVersion,
        message: message,
      );
    }

    return const AppUpdateState();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[ForceUpdate] Error: $e');
    }
    return const AppUpdateState();
  }
});

int _compareVersions(String a, String b) {
  final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  for (int i = 0; i < 3; i++) {
    final va = i < partsA.length ? partsA[i] : 0;
    final vb = i < partsB.length ? partsB[i] : 0;
    if (va < vb) return -1;
    if (va > vb) return 1;
  }
  return 0;
}
