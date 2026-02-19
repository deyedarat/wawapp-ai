import 'package:google_maps_flutter/google_maps_flutter.dart';

class AddressUtils {
  /// Prefixes that indicate a geocoding failure — not valid address strings.
  static const _errorPrefixes = [
    'تعذّر',
    'جار تحديد',
    'موقع غير محدد',
  ];

  /// Returns a human-readable address string.
  /// Rejects geocoding error strings and falls back to coordinates.
  static String friendly({
    String? userInput,
    String? plusCode,
    LatLng? latLng,
  }) {
    final trimmed = userInput?.trim() ?? '';
    final isValidInput = trimmed.isNotEmpty &&
        !_errorPrefixes.any((p) => trimmed.startsWith(p));

    if (isValidInput) return trimmed;
    if (plusCode != null && plusCode.trim().isNotEmpty) {
      return plusCode.trim();
    }
    if (latLng != null) {
      String d(double v) => v.toStringAsFixed(5);
      return '(${d(latLng.latitude)}, ${d(latLng.longitude)})';
    }
    return 'عنوان غير معروف';
  }
}
