# Amazon Q Prompts: Admin Map Enhancement
## WawApp - OpenStreetMap Enhancement (Free Google Maps Alternative)

**Target File:** `apps/wawapp_admin/lib/features/orders/widgets/map_location_picker.dart`

**Mission:** Add client app map features to admin panel while keeping OpenStreetMap (zero cost).

---

## 🎯 **Overview**

The client app uses Google Maps (paid) but already uses Nominatim (free) for geocoding.
The admin panel uses OpenStreetMap (free) but lacks some UX features.

**Goal:** Bridge the gap by adding missing features to admin map without switching to Google Maps.

---

## 📋 **PROMPT 1: Add GPS "My Location" Button**

### Task
Add a "My Location" button to the admin map that centers on the admin's current GPS position.

### Requirements
1. Add `geolocator` permission check (already in pubspec.yaml via client app)
2. Create a new zoom button styled like existing ones (green background, white icon)
3. Position it below the existing zoom controls
4. On tap:
   - Request location permission if needed
   - Get current GPS position
   - Animate map to that position with zoom level 16
   - Show loading indicator during GPS acquisition
   - Handle errors gracefully (show SnackBar)

### Technical Details
```dart
// Import
import 'package:geolocator/geolocator.dart';

// Add to _MapLocationPickerState
bool _isGettingLocation = false;

// Permission check (reuse from client app pattern)
Future<bool> _checkLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = at Geolocator.requestPermission();
  }
  return permission == LocationPermission.whileInUse ||
         permission == LocationPermission.always;
}

// Get current position
Future<void> _goToMyLocation() async {
  setState(() => _isGettingLocation = true);
  try {
    if (!await _checkLocationPermission()) {
      throw 'Location permission denied';
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
    _mapController.move(LatLng(position.latitude, position.longitude), 16);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحديد الموقع: $e'), backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) setState(() => _isGettingLocation = false);
  }
}
```

### UI Placement
Add to the existing zoom controls stack (line ~460):
```dart
_zoomButton(
  _isGettingLocation ? Icons.hourglass_empty : Icons.gps_fixed,
  'موقعي الحالي',
  _goToMyLocation,
  color: _kGreen,
  iconColor: Colors.white,
),
```

### Testing
- Verify permission dialog appears on first use
- Confirm map animates to GPS position
- Test error handling (GPS disabled, timeout)
- Ensure loading state shows during acquisition

---

## 📋 **PROMPT 2: Make Marker Draggable**

### Task
Convert the selected position marker to a draggable marker (like Google Maps in client app).

### Requirements
1. Make the green location marker draggable
2. Show "جار تحديد العنوان..." while dragging
3. Update address automatically when drag ends
4. Show coordinates in real-time during drag
5. Add visual feedback (shadow/pulse) while dragging

### Technical Details
```dart
// Replace MarkerLayer at line ~354 with DraggableMarker approach

// Add state variable
bool _isDragging = false;

// Create draggable marker helper
Marker _buildDraggableMarker() {
  return Marker(
    point: _selectedPosition!,
    width: 60,
    height: 70,
    alignment: Alignment.topCenter,
    child: GestureDetector(
      onPanStart: (_) {
        setState(() => _isDragging = true);
      },
      onPanUpdate: (details) {
        // Convert screen position to LatLng
        final bounds = _mapController.camera.pixelBounds;
        final point = _mapController.camera.pointToLatLng(details.localPosition);
        setState(() {
          _selectedPosition = point;
          _selectedAddress = 'الإحداثيات: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
        });
      },
      onPanEnd: (_) async {
        setState(() {
          _isDragging = false;
          _isLoadingAddress = true;
          _selectedAddress = 'جار تحديد العنوان...';
        });
        final address = await _getAddressFromLatLng(
          _selectedPosition!.latitude,
          _selectedPosition!.longitude,
        );
        if (mounted) {
          setState(() {
            _selectedAddress = address;
            _isLoadingAddress = false;
          });
        }
      },
      child: AnimatedScale(
        scale: _isDragging ? 1.2 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kGreen,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: _kGreen.withOpacity(_isDragging ? 0.8 : 0.5),
                    blurRadius: _isDragging ? 20 : 12,
                    spreadRadius: _isDragging ? 4 : 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 24),
            ),
            CustomPaint(
              size: const Size(14, 10),
              painter: _MarkerTrianglePainter(_kGreen),
            ),
          ],
        ),
      ),
    ),
  );
}
```

### Alternative Approach (flutter_map DragMarkers plugin)
If gestures conflict, use the official plugin:
```yaml
# Add to pubspec.yaml
dependencies:
  flutter_map_dragmarker: ^1.0.0
```

```dart
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';

// Replace MarkerLayer with DragMarkers
DragMarkers(
  markers: [
    DragMarker(
      point: _selectedPosition!,
      width: 60,
      height: 70,
      onDragEnd: (details, point) async {
        setState(() {
          _selectedPosition = point;
          _isLoadingAddress = true;
        });
        final address = await _getAddressFromLatLng(point.latitude, point.longitude);
        if (mounted) {
          setState(() {
            _selectedAddress = address;
            _isLoadingAddress = false;
          });
        }
      },
      builder: (context, point, isDragging) {
        return AnimatedScale(
          scale: isDragging ? 1.2 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: _buildMarkerWidget(),
        );
      },
    ),
  ],
)
```

### Testing
- Drag marker smoothly across map
- Verify address updates after drag ends
- Confirm visual feedback (scale/shadow) works
- Test on touch and mouse devices

---

## 📋 **PROMPT 3: Add Nominatim Autocomplete Search**

### Task
Enhance search bar with real-time autocomplete using Nominatim Search API (free).

### Requirements
1. Keep existing local search for districts/POIs
2. Add Nominatim API search for addresses
3. Show suggestions dropdown (max 5 results)
4. Prioritize local results over API results
5. Handle Arabic and French queries
6. Add debouncing (500ms) to reduce API calls

### Technical Details
```dart
// Add dependencies
import 'dart:async';

// Add state variables
List<_SearchResult> _searchResults = [];
Timer? _searchDebounce;
bool _isSearching = false;

class _SearchResult {
  final String displayName;
  final LatLng position;
  final String type; // 'district', 'poi', 'nominatim'

  const _SearchResult(this.displayName, this.position, this.type);
}

// Nominatim search function
Future<List<_SearchResult>> _searchNominatim(String query) async {
  try {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?'
      'q=$query&'
      'format=json&'
      'limit=5&'
      'countrycodes=mr&' // Mauritania only
      'accept-language=ar&'
      'bounded=1&'
      'viewbox=-16.05,18.15,-15.85,18.00', // Nouakchott bbox
    );
    final response = await http.get(url, headers: {'User-Agent': 'WawApp-Admin/1.0'});

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => _SearchResult(
        item['display_name'] as String,
        LatLng(
          double.parse(item['lat'] as String),
          double.parse(item['lon'] as String),
        ),
        'nominatim',
      )).toList();
    }
  } catch (e) {
    debugPrint('Nominatim search error: $e');
  }
  return [];
}

// Combined search (local + API)
Future<void> _performSearch(String query) async {
  if (query.isEmpty) {
    setState(() => _searchResults = []);
    return;
  }

  setState(() => _isSearching = true);
  final results = <_SearchResult>[];
  final q = query.toLowerCase();

  // 1. Search districts
  for (final d in _districts) {
    if (d.nameAr.contains(query) || d.nameFr.toLowerCase().contains(q)) {
      results.add(_SearchResult('مقاطعة ${d.nameAr}', d.center, 'district'));
    }
  }

  // 2. Search POIs
  for (final p in _pois) {
    if (p.nameAr.contains(query) || p.nameFr.toLowerCase().contains(q)) {
      results.add(_SearchResult('${p.icon} ${p.nameAr}', p.position, 'poi'));
    }
  }

  // 3. Search Nominatim (if no local results or query is address-like)
  if (results.length < 3) {
    final nominatimResults = await _searchNominatim(query);
    results.addAll(nominatimResults);
  }

  setState(() {
    _searchResults = results;
    _isSearching = false;
  });
}

// Update TextField onChanged
TextField(
  controller: _searchController,
  decoration: InputDecoration(
    hintText: '🔍 ابحث عن حي، مكان، أو عنوان...',
    suffixIcon: _isSearching
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : IconButton(
            icon: const Icon(Icons.search, color: _kGreen),
            onPressed: () => _performSearch(_searchController.text),
          ),
  ),
  onChanged: (value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(value);
    });
  },
)

// Add results dropdown below search bar
if (_searchResults.isNotEmpty)
  Positioned(
    top: 56,
    left: 60,
    right: 60,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
      ),
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final result = _searchResults[index];
          return ListTile(
            dense: true,
            leading: Icon(
              result.type == 'district' ? Icons.map :
              result.type == 'poi' ? Icons.place :
              Icons.location_on,
              color: _kGreen,
              size: 20,
            ),
            title: Text(result.displayName, style: const TextStyle(fontSize: 12)),
            onTap: () {
              _mapController.move(result.position, 16);
              _onMapTap(TapPosition(null, null), result.position);
              setState(() => _searchResults = []);
              _searchController.clear();
            },
          );
        },
      ),
    ),
  ),
```

### Testing
- Type "مستشفى" → should show POIs + Nominatim results
- Type "تفرغ زينة" → should show district first
- Verify debouncing (API called after 500ms pause)
- Test Arabic and French queries

---

## 📋 **PROMPT 4: Add Saved Locations Feature**

### Task
Allow admins to save frequently used locations for quick access.

### Requirements
1. Add "Save Location" button in bottom info card
2. Store saved locations in Firestore (per admin user)
3. Show saved locations list in a bottom sheet
4. Add floating action button to open saved locations
5. Maximum 10 saved locations per admin
6. Each location has: name (editable), address, coordinates, timestamp

### Technical Details
```dart
// Firestore structure
// collection: 'admin_saved_locations'
// document: '{adminUid}'
// fields:
//   - locations: List<Map<String, dynamic>>
//     - name: String
//     - address: String
//     - latitude: double
//     - longitude: double
//     - savedAt: Timestamp

// Add dependency check (should already exist)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// State variables
List<Map<String, dynamic>> _savedLocations = [];

// Load saved locations on init
@override
void initState() {
  super.initState();
  _loadSavedLocations();
}

Future<void> _loadSavedLocations() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('admin_saved_locations')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data()?['locations'] != null) {
      setState(() {
        _savedLocations = List<Map<String, dynamic>>.from(doc.data()!['locations']);
      });
    }
  } catch (e) {
    debugPrint('Error loading saved locations: $e');
  }
}

// Save current location
Future<void> _saveCurrentLocation() async {
  if (_selectedPosition == null) return;

  // Ask for location name
  final nameController = TextEditingController(text: 'موقع ${_savedLocations.length + 1}');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('حفظ الموقع'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(
          labelText: 'اسم الموقع',
          hintText: 'مثال: مكتب المبيعات',
        ),
        textDirection: TextDirection.rtl,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: _kGreen),
          child: const Text('حفظ'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'User not authenticated';

    final newLocation = {
      'name': nameController.text.trim(),
      'address': _selectedAddress,
      'latitude': _selectedPosition!.latitude,
      'longitude': _selectedPosition!.longitude,
      'savedAt': FieldValue.serverTimestamp(),
    };

    final updatedLocations = [..._savedLocations, newLocation];
    if (updatedLocations.length > 10) {
      updatedLocations.removeAt(0); // Remove oldest
    }

    await FirebaseFirestore.instance
        .collection('admin_saved_locations')
        .doc(user.uid)
        .set({'locations': updatedLocations}, SetOptions(merge: true));

    setState(() => _savedLocations = updatedLocations);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الموقع بنجاح'), backgroundColor: _kGreen),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حفظ الموقع: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// Show saved locations bottom sheet
void _showSavedLocations() {
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'المواقع المحفوظة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const Divider(),
          if (_savedLocations.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'لا توجد مواقع محفوظة',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _savedLocations.length,
                itemBuilder: (context, index) {
                  final loc = _savedLocations[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: _kGreen,
                      child: Icon(Icons.bookmark, color: Colors.white, size: 20),
                    ),
                    title: Text(loc['name'] as String),
                    subtitle: Text(
                      loc['address'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteSavedLocation(index),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      final position = LatLng(loc['latitude'], loc['longitude']);
                      _mapController.move(position, 16);
                      _onMapTap(TapPosition(null, null), position);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}

// Delete saved location
Future<void> _deleteSavedLocation(int index) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final updatedLocations = List<Map<String, dynamic>>.from(_savedLocations);
    updatedLocations.removeAt(index);

    await FirebaseFirestore.instance
        .collection('admin_saved_locations')
        .doc(user.uid)
        .set({'locations': updatedLocations}, SetOptions(merge: true));

    setState(() => _savedLocations = updatedLocations);
    Navigator.pop(context); // Close bottom sheet
    _showSavedLocations(); // Reopen with updated list
  } catch (e) {
    debugPrint('Error deleting location: $e');
  }
}
```

### UI Changes

**1. Add FAB for saved locations:**
```dart
floatingActionButton: FloatingActionButton(
  onPressed: _showSavedLocations,
  backgroundColor: _kGreen,
  child: Badge(
    label: Text('${_savedLocations.length}'),
    isLabelVisible: _savedLocations.isNotEmpty,
    child: const Icon(Icons.bookmarks, color: Colors.white),
  ),
),
```

**2. Add "Save" button in bottom info card (after "تأكيد الموقع"):**
```dart
if (_selectedPosition != null) ...[
  const SizedBox(height: 12),
  OutlinedButton.icon(
    onPressed: _saveCurrentLocation,
    icon: const Icon(Icons.bookmark_add),
    label: const Text('حفظ هذا الموقع'),
    style: OutlinedButton.styleFrom(
      foregroundColor: _kGreen,
      side: const BorderSide(color: _kGreen),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
  ),
],
```

### Firestore Security Rules
Add to `firestore.rules`:
```javascript
match /admin_saved_locations/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

### Testing
- Save a location → verify name dialog
- Open saved locations → confirm list appears
- Tap saved location → map should navigate
- Delete location → confirm removal
- Test 10-location limit (oldest removed)
- Verify Firestore persistence across sessions

---

## 📋 **PROMPT 5: UI/UX Polish**

### Task
Add final touches to improve user experience.

### Requirements
1. Add long-press gesture as alternative to tap (better for precise selection)
2. Show coordinate tooltip while marker is being dragged
3. Add "Recent Locations" (last 5 selected, session-only)
4. Improve loading states with skeleton screens
5. Add haptic feedback on marker selection (mobile)

### Technical Details

**1. Long-press gesture:**
```dart
MapOptions(
  // ... existing options
  onLongPress: (tapPosition, point) {
    _onMapTap(tapPosition, point);
    HapticFeedback.mediumImpact(); // Requires import 'package:flutter/services.dart';
  },
)
```

**2. Coordinate tooltip during drag:**
```dart
// Add overlay when dragging
if (_isDragging && _selectedPosition != null)
  Positioned(
    top: 100,
    left: 0,
    right: 0,
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${_selectedPosition!.latitude.toStringAsFixed(5)}, ${_selectedPosition!.longitude.toStringAsFixed(5)}',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
        ),
      ),
    ),
  ),
```

**3. Recent locations (session-only):**
```dart
// State variable
final List<LocationData> _recentLocations = [];

// Update in _onMapTap
void _onMapTap(TapPosition tapPosition, LatLng position) async {
  // ... existing code

  // Add to recent (after address is resolved)
  final locationData = LocationData(
    address: address,
    latitude: position.latitude,
    longitude: position.longitude,
  );
  setState(() {
    _recentLocations.insert(0, locationData);
    if (_recentLocations.length > 5) {
      _recentLocations.removeLast();
    }
  });
}

// Add chip row above bottom card
if (_recentLocations.isNotEmpty)
  Positioned(
    bottom: 200,
    left: 8,
    right: 8,
    child: SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recentLocations.length,
        itemBuilder: (context, index) {
          final loc = _recentLocations[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.history, size: 16),
              label: Text(
                loc.address.length > 30
                    ? '${loc.address.substring(0, 27)}...'
                    : loc.address,
                style: const TextStyle(fontSize: 11),
              ),
              onPressed: () {
                _mapController.move(LatLng(loc.latitude, loc.longitude), 16);
                setState(() {
                  _selectedPosition = LatLng(loc.latitude, loc.longitude);
                  _selectedAddress = loc.address;
                });
              },
            ),
          );
        },
      ),
    ),
  ),
```

**4. Skeleton loader for address:**
```dart
// Install shimmer package (optional)
// dependencies:
//   shimmer: ^3.0.0

// Or use simple animated container
Widget _buildAddressShimmer() {
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.3, end: 1.0),
    duration: const Duration(milliseconds: 800),
    builder: (context, value, child) {
      return Opacity(
        opacity: value,
        child: Container(
          height: 16,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    },
    onEnd: () {
      // Rebuild to restart animation
      if (_isLoadingAddress) {
        setState(() {});
      }
    },
  );
}

// Use in bottom card
child: _isLoadingAddress
    ? _buildAddressShimmer()
    : Text(_selectedAddress, ...),
```

### Testing
- Long-press map → should select location
- Drag marker → tooltip shows coordinates
- Select multiple locations → recent chips appear
- Tap recent chip → map navigates
- Verify haptic feedback on mobile devices

---

## 🚀 **EXECUTION PLAN FOR AMAZON Q**

### Sequential Order (Execute one at a time)

1. **Phase 1:** GPS My Location Button (PROMPT 1)
   - Low risk, independent feature
   - Test before moving to Phase 2

2. **Phase 2:** Draggable Marker (PROMPT 2)
   - Medium risk, modifies core interaction
   - Test thoroughly before Phase 3

3. **Phase 3:** Nominatim Autocomplete (PROMPT 3)
   - Low risk, enhances existing search
   - Can run in parallel with Phase 4

4. **Phase 4:** Saved Locations (PROMPT 4)
   - Medium risk, requires Firestore setup
   - Verify security rules before deployment

5. **Phase 5:** UI/UX Polish (PROMPT 5)
   - Low risk, visual enhancements only
   - Can be done incrementally

### Verification Checklist (After Each Phase)

```bash
# 1. Analyze code
flutter analyze apps/wawapp_admin

# 2. Format code
flutter format apps/wawapp_admin/lib/features/orders/widgets/map_location_picker.dart

# 3. Build (check for compile errors)
flutter build apk --debug --target-platform android-arm64

# 4. Manual testing on device/emulator
# - Test new feature
# - Verify existing features still work
# - Check for console errors
```

---

## ⚠️ **CRITICAL NOTES FOR AMAZON Q**

### DO NOT:
- ❌ Switch to Google Maps (stay with OpenStreetMap)
- ❌ Remove existing features (districts, POIs, legend)
- ❌ Change file structure or create new files
- ❌ Add external packages without checking pubspec.yaml first
- ❌ Modify Firestore security rules without human approval

### DO:
- ✅ Preserve existing code style and patterns
- ✅ Add comprehensive error handling
- ✅ Test each feature independently
- ✅ Use Arabic RTL text direction where appropriate
- ✅ Follow Flutter best practices (dispose controllers, handle mounted state)
- ✅ Add comments in English for complex logic

### Dependencies Already Available:
```yaml
# These are already in pubspec.yaml (verify before using)
- geolocator (from client app)
- cloud_firestore
- firebase_auth
- http
- flutter_map
- latlong2
```

### If New Dependency Needed:
1. Check if alternative exists using current dependencies
2. If absolutely required, add to `apps/wawapp_admin/pubspec.yaml`
3. Run `flutter pub get` before continuing
4. Document the addition in git commit

---

## 📝 **SUCCESS CRITERIA**

### Admin Map Should Have:
1. ✅ GPS "My Location" button (like client app)
2. ✅ Draggable marker (like Google Maps)
3. ✅ Real address search via Nominatim (free)
4. ✅ Saved locations with Firestore persistence
5. ✅ Recent locations quick access
6. ✅ All existing features preserved (districts, POIs, legend)
7. ✅ Zero new costs (still 100% free)

### Performance Benchmarks:
- GPS acquisition: < 5 seconds
- Address resolution: < 3 seconds
- Marker drag: 60 FPS smooth
- Search autocomplete: < 1 second

### Code Quality:
- Zero `flutter analyze` warnings
- All `await` statements have error handling
- All controllers properly disposed
- No hardcoded strings (use Arabic variables)
- Consistent with existing codebase style

---

## 🎯 **FINAL NOTE**

This enhancement brings admin map to feature parity with client app **without** incurring Google Maps costs.

**Estimated cost savings:** $500-1500/month

**Total implementation time:** 4-6 hours (across 5 prompts)

**Zero API costs:** OpenStreetMap + Nominatim are completely free

---

**Ready for execution by Amazon Q Developer.**

**Date:** 2026-04-03
**Project:** WawApp
**Target:** Admin Panel Map Enhancement (OpenStreetMap)
