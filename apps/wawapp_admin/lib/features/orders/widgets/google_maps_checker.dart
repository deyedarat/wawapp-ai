import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Checks if Google Maps JavaScript API is FULLY loaded and functional.
bool get isGoogleMapsAvailable {
  if (!kIsWeb) return true;
  try {
    final google = _googleGlobal;
    if (google == null || google.isUndefinedOrNull) return false;
    final maps = google.getProperty('maps'.toJS);
    if (maps == null || maps.isUndefinedOrNull) return false;
    final mapConstructor = (maps as JSObject).getProperty('Map'.toJS);
    if (mapConstructor == null || mapConstructor.isUndefinedOrNull) return false;
    return true;
  } catch (e) {
    return false;
  }
}

@JS('google')
external JSObject? get _googleGlobal;

@JS('location.reload')
external void _jsReload();

void reloadPage() {
  if (kIsWeb) {
    _jsReload();
  }
}

/// Wraps a GoogleMap widget and catches platform errors gracefully.
class SafeGoogleMap extends StatefulWidget {
  final GoogleMap googleMap;

  const SafeGoogleMap({super.key, required this.googleMap});

  @override
  State<SafeGoogleMap> createState() => _SafeGoogleMapState();
}

class _SafeGoogleMapState extends State<SafeGoogleMap> {
  bool _hasError = false;
  final _originalErrorBuilder = ErrorWidget.builder;

  @override
  void initState() {
    super.initState();
    // Override error widget builder to catch maps platform errors
    ErrorWidget.builder = (FlutterErrorDetails details) {
      final message = details.exception.toString();
      if (message.contains('TargetPlatform') ||
          message.contains('maps plugin') ||
          message.contains('not yet supported')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasError) {
            setState(() => _hasError = true);
          }
        });
        return const GoogleMapsBlockedWidget(title: '');
      }
      return _originalErrorBuilder(details);
    };
  }

  @override
  void dispose() {
    ErrorWidget.builder = _originalErrorBuilder;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || !isGoogleMapsAvailable) {
      return const GoogleMapsBlockedWidget(title: '');
    }
    return widget.googleMap;
  }
}

/// Widget displayed when Google Maps fails to load
class GoogleMapsBlockedWidget extends StatelessWidget {
  final String title;

  const GoogleMapsBlockedWidget({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
              child: Icon(Icons.map_outlined, size: 64, color: Colors.orange.shade700),
            ),
            const SizedBox(height: 24),
            Text(
              'تعذّر تحميل الخريطة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'يبدو أن مانع الإعلانات في المتصفح يحظر خدمة Google Maps.\n'
              'لحل المشكلة، جرّب أحد الخيارات التالية:',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSuggestion(Icons.block, 'عطّل مانع الإعلانات لهذا الموقع'),
                  const SizedBox(height: 10),
                  _buildSuggestion(Icons.open_in_browser, 'استخدم متصفح Chrome أو Edge'),
                  const SizedBox(height: 10),
                  _buildSuggestion(Icons.refresh, 'أعد تحميل الصفحة بعد التعطيل'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => reloadPage(),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة تحميل الصفحة'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSuggestion(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.orange.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
