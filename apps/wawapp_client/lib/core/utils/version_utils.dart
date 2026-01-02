/// Utilities for version comparison and validation
class VersionUtils {
  /// Compare two semantic version strings (e.g., "1.0.5" vs "1.0.0")
  /// Returns:
  ///   -1 if version1 < version2
  ///    0 if version1 == version2
  ///    1 if version1 > version2
  static int compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.tryParse).toList();
    final v2Parts = version2.split('.').map(int.tryParse).toList();

    // Ensure both versions have at least 3 parts (major.minor.patch)
    while (v1Parts.length < 3) {
      v1Parts.add(0);
    }
    while (v2Parts.length < 3) {
      v2Parts.add(0);
    }

    // Compare each part
    for (int i = 0; i < 3; i++) {
      final v1Part = v1Parts[i] ?? 0;
      final v2Part = v2Parts[i] ?? 0;

      if (v1Part < v2Part) return -1;
      if (v1Part > v2Part) return 1;
    }

    return 0; // Versions are equal
  }

  /// Check if current version is less than minimum required version
  /// Returns true if update is required
  static bool isUpdateRequired(String currentVersion, String minVersion) {
    return compareVersions(currentVersion, minVersion) < 0;
  }

  /// Validate version string format (major.minor.patch)
  static bool isValidVersion(String version) {
    final parts = version.split('.');
    if (parts.length < 2 || parts.length > 4) return false;

    for (final part in parts) {
      if (int.tryParse(part) == null) return false;
    }

    return true;
  }

  /// Extract version number from pubspec version (e.g., "1.0.5+10" -> "1.0.5")
  static String extractVersion(String pubspecVersion) {
    return pubspecVersion.split('+').first;
  }
}
