# Map Optimization Prompts for Amazon Q

## Overview
These prompts will transform the admin map from cluttered to clean and professional.

---

## PROMPT 1: Add Marker Clustering Library

**Task:** Add the flutter_map_marker_cluster package for marker clustering.

**Actions:**
1. Add to `apps/wawapp_admin/pubspec.yaml` dependencies:
   ```yaml
   flutter_map_marker_cluster: ^1.3.6
   ```

2. Run:
   ```bash
   cd apps/wawapp_admin
   flutter pub get
   ```

**Success Criteria:**
- Package successfully added
- No dependency conflicts
- `flutter pub get` completes without errors

---

## PROMPT 2: Implement Marker Clustering in LiveMap

**File:** `apps/wawapp_admin/lib/features/live_ops/widgets/live_map.dart`

**Task:** Replace individual MarkerLayer widgets with clustered versions to reduce visual clutter.

**Changes:**

1. **Add import at top:**
   ```dart
   import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
   ```

2. **Replace the driver MarkerLayer (around line 178-190) with:**
   ```dart
   MarkerClusterLayerWidget(
     options: MarkerClusterLayerOptions(
       maxClusterRadius: 80,
       size: const Size(50, 50),
       fitBoundsOptions: const FitBoundsOptions(
         padding: EdgeInsets.all(50),
       ),
       markers: widget.drivers.map((driver) => Marker(
         point: driver.location,
         width: 48,
         height: 48,
         child: GestureDetector(
           onTap: () => widget.onDriverTap?.call(driver),
           child: driver.isOnline && !driver.isBlocked
               ? _buildOnlineDriverMarker(driver)
               : _buildDriverMarkerCore(driver),
         ),
       )).toList(),
       builder: (context, markers) {
         return Container(
           decoration: BoxDecoration(
             color: AdminAppColors.primaryLight.withOpacity(0.9),
             shape: BoxShape.circle,
             border: Border.all(color: Colors.white, width: 2),
           ),
           child: Center(
             child: Text(
               '${markers.length}',
               style: const TextStyle(
                 color: Colors.white,
                 fontWeight: FontWeight.bold,
                 fontSize: 14,
               ),
             ),
           ),
         );
       },
     ),
   ),
   ```

3. **Replace order pickup MarkerLayer (around line 167-177) with:**
   ```dart
   MarkerClusterLayerWidget(
     options: MarkerClusterLayerOptions(
       maxClusterRadius: 60,
       size: const Size(45, 45),
       markers: widget.orders.map((order) => Marker(
         point: order.pickupLocation,
         width: 34,
         height: 34,
         child: GestureDetector(
           onTap: () => widget.onOrderTap?.call(order),
           child: _buildPickupMarker(order),
         ),
       )).toList(),
       builder: (context, markers) {
         return Container(
           decoration: BoxDecoration(
             color: Colors.blue.withOpacity(0.9),
             shape: BoxShape.circle,
             border: Border.all(color: Colors.white, width: 2),
           ),
           child: Center(
             child: Text(
               '${markers.length}',
               style: const TextStyle(
                 color: Colors.white,
                 fontWeight: FontWeight.bold,
                 fontSize: 12,
               ),
             ),
           ),
         );
       },
     ),
   ),
   ```

**Success Criteria:**
- Markers cluster at lower zoom levels
- Clicking clusters zooms in
- Individual markers appear at higher zoom
- No runtime errors

---

## PROMPT 3: Reduce Polygon Opacity in MapLocationPicker

**File:** `apps/wawapp_admin/lib/features/orders/widgets/map_location_picker.dart`

**Task:** Make district polygons less visually dominant.

**Changes:**

1. **Update PolygonLayer (around line 536-544):**
   ```dart
   if (_showDistricts)
     PolygonLayer(
       polygons: _districts.map((d) => Polygon(
         points: d.coords,
         color: d.color.withOpacity(0.08),  // CHANGED from 0.25 to 0.08
         borderColor: d.color.withOpacity(0.5),  // ADD: subtle border
         borderStrokeWidth: 1.5,  // CHANGED from 2 to 1.5
         isFilled: true,
       )).toList(),
     ),
   ```

2. **Update district label styling (around line 552-569):**
   ```dart
   if (_showDistricts)
     MarkerLayer(
       markers: _districts.map((d) => Marker(
         point: d.center,
         width: 120,
         height: 36,
         child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
           decoration: BoxDecoration(
             color: Colors.white.withOpacity(0.75),  // CHANGED: lighter background
             borderRadius: BorderRadius.circular(6),
             border: Border.all(color: d.color.withOpacity(0.6), width: 1),
           ),
           child: Text(
             '${d.nameAr}\n${d.nameFr}',
             textAlign: TextAlign.center,
             style: TextStyle(
               fontSize: 9,
               fontWeight: FontWeight.bold,
               color: d.color.withOpacity(0.9),  // CHANGED: use district color
               height: 1.2,
             ),
           ),
         ),
       )).toList(),
     ),
   ```

**Success Criteria:**
- Polygons are barely visible but still identifiable
- Map roads and labels remain clearly visible
- District names are readable but not dominant

---

## PROMPT 4: Add Collapsible Legend

**File:** `apps/wawapp_admin/lib/features/live_ops/widgets/live_map.dart`

**Task:** Make the legend collapsible to reduce UI clutter.

**Changes:**

1. **Add state variable in _LiveMapState class (around line 46):**
   ```dart
   bool _legendExpanded = false;
   ```

2. **Replace the legend Positioned widget (around line 215-219) with:**
   ```dart
   Positioned(
     bottom: 12,
     right: 12,
     child: _buildCollapsibleLegend(context),
   ),
   ```

3. **Replace the _buildLegend method (around line 399-428) with:**
   ```dart
   Widget _buildCollapsibleLegend(BuildContext context) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.end,
       mainAxisSize: MainAxisSize.min,
       children: [
         // Collapsed state - just toggle button
         if (!_legendExpanded)
           Material(
             color: Colors.white.withOpacity(0.9),
             borderRadius: BorderRadius.circular(8),
             elevation: 3,
             child: IconButton(
               icon: const Icon(Icons.info_outline, size: 20),
               tooltip: 'إظهار دليل الرموز',
               onPressed: () => setState(() => _legendExpanded = true),
             ),
           ),

         // Expanded state - full legend
         if (_legendExpanded)
           Material(
             color: Colors.white.withOpacity(0.95),
             borderRadius: BorderRadius.circular(10),
             elevation: 3,
             child: Container(
               constraints: const BoxConstraints(maxWidth: 200),
               padding: const EdgeInsets.all(12),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text(
                         'دليل الرموز',
                         style: Theme.of(context).textTheme.labelSmall?.copyWith(
                           fontWeight: FontWeight.bold,
                           color: Colors.grey[700],
                         ),
                       ),
                       IconButton(
                         icon: const Icon(Icons.close, size: 18),
                         padding: EdgeInsets.zero,
                         constraints: const BoxConstraints(),
                         onPressed: () => setState(() => _legendExpanded = false),
                       ),
                     ],
                   ),
                   const SizedBox(height: 6),
                   _legendRow(color: const Color(0xFF00704A), icon: Icons.directions_car, label: 'سائق متصل'),
                   _legendRow(color: const Color(0xFF6C757D), icon: Icons.directions_car, label: 'سائق غير متصل'),
                   _legendRow(color: const Color(0xFFC1272D), icon: Icons.directions_car, label: 'سائق محظور'),
                   const Divider(height: 10),
                   _legendRow(color: Colors.blue, icon: Icons.place, label: 'نقطة الاستلام'),
                   _legendRow(color: Colors.orange, icon: Icons.flag, label: 'نقطة التسليم'),
                 ],
               ),
             ),
           ),
       ],
     );
   }
   ```

**Success Criteria:**
- Legend starts collapsed showing only an info icon
- Clicking expands to show full legend
- Close button collapses it again
- Smooth transitions

---

## PROMPT 5: Add Focus Mode for Selection

**File:** `apps/wawapp_admin/lib/features/live_ops/widgets/live_map.dart`

**Task:** Dim UI when selecting a marker to improve focus.

**Changes:**

1. **Add state variables in _LiveMapState (around line 46):**
   ```dart
   String? _selectedDriverId;
   String? _selectedOrderId;
   ```

2. **Update onDriverTap wrapper in driver MarkerLayer builder:**
   ```dart
   onTap: () {
     setState(() {
       _selectedDriverId = driver.id;
       _selectedOrderId = null;
     });
     widget.onDriverTap?.call(driver);
   },
   ```

3. **Update onOrderTap wrapper in order MarkerLayer builder:**
   ```dart
   onTap: () {
     setState(() {
       _selectedOrderId = order.id;
       _selectedDriverId = null;
     });
     widget.onOrderTap?.call(order);
   },
   ```

4. **Add overlay after the FlutterMap widget (around line 199):**
   ```dart
   // Dim overlay when something is selected
   if (_selectedDriverId != null || _selectedOrderId != null)
     Positioned.fill(
       child: GestureDetector(
         onTap: () => setState(() {
           _selectedDriverId = null;
           _selectedOrderId = null;
         }),
         child: Container(
           color: Colors.black.withOpacity(0.3),
         ),
       ),
     ),
   ```

5. **Update _buildDriverMarkerCore to highlight selected (around line 277):**
   ```dart
   Widget _buildDriverMarkerCore(LiveDriverMarker driver) {
     final color = _parseColor(driver.statusColor);
     final isSelected = _selectedDriverId == driver.id;

     return Stack(
       alignment: Alignment.center,
       children: [
         Container(
           width: isSelected ? 36 : 30,  // Larger when selected
           height: isSelected ? 36 : 30,
           decoration: BoxDecoration(
             shape: BoxShape.circle,
             color: color,
             border: Border.all(
               color: isSelected ? Colors.yellow : Colors.white,
               width: isSelected ? 3.5 : 2.5,
             ),
             boxShadow: [
               BoxShadow(
                 color: color.withOpacity(isSelected ? 0.8 : 0.5),
                 blurRadius: isSelected ? 12 : 6,
                 spreadRadius: isSelected ? 3 : 1,
                 offset: const Offset(0, 2),
               ),
             ],
           ),
           child: Icon(
             Icons.directions_car,
             size: isSelected ? 20 : 16,
             color: Colors.white,
           ),
         ),
         // ... rest of the widget
       ],
     );
   }
   ```

**Success Criteria:**
- Clicking a marker dims the background
- Selected marker is highlighted
- Clicking background clears selection
- Smooth visual feedback

---

## PROMPT 6: Optimize Marker Rendering with Zoom-Based Filtering

**File:** `apps/wawapp_admin/lib/features/live_ops/widgets/live_map.dart`

**Task:** Only render markers visible at current zoom level to improve performance.

**Changes:**

1. **Add state variable for current zoom:**
   ```dart
   double _currentZoom = _defaultZoom;
   ```

2. **Add listener to map controller in initState:**
   ```dart
   @override
   void initState() {
     super.initState();
     _pulseController = AnimationController(/* ... */);
     _pulseAnimation = Tween<double>(/* ... */);

     // ADD: Listen to map movement
     _mapController.mapEventStream.listen((event) {
       if (event is MapEventMove || event is MapEventRotate) {
         setState(() => _currentZoom = _mapController.camera.zoom);
       }
     });

     WidgetsBinding.instance.addPostFrameCallback((_) => _fitMarkers());
   }
   ```

3. **Add method to filter markers by zoom:**
   ```dart
   List<LiveDriverMarker> _getVisibleDrivers() {
     if (_currentZoom < 10) {
       // At low zoom, only show online drivers
       return widget.drivers.where((d) => d.isOnline && !d.isBlocked).toList();
     } else if (_currentZoom < 12) {
       // At medium zoom, show online + drivers with active orders
       return widget.drivers.where((d) =>
         (d.isOnline && !d.isBlocked) || d.activeOrderId != null
       ).toList();
     }
     // At high zoom, show all
     return widget.drivers;
   }

   List<LiveOrderMarker> _getVisibleOrders() {
     if (_currentZoom < 11) {
       // At low zoom, only show active orders
       return widget.orders.where((o) => o.isActive).toList();
     }
     // At higher zoom, show all
     return widget.orders;
   }
   ```

4. **Update MarkerClusterLayerWidget to use filtered lists:**
   ```dart
   markers: _getVisibleDrivers().map((driver) => /* ... */).toList(),
   ```
   ```dart
   markers: _getVisibleOrders().map((order) => /* ... */).toList(),
   ```

**Success Criteria:**
- Fewer markers visible at lower zoom levels
- All markers appear when zooming in
- Smooth performance even with 100+ markers
- No jank during zoom

---

## PROMPT 7: Improve Search Bar Styling

**File:** `apps/wawapp_admin/lib/features/orders/widgets/map_location_picker.dart`

**Task:** Make search bar more compact and less dominant.

**Changes:**

1. **Update search bar container (around line 687-720):**
   ```dart
   Container(
     decoration: BoxDecoration(
       color: Colors.white,
       borderRadius: BorderRadius.circular(20),  // CHANGED from 24
       boxShadow: [
         BoxShadow(
           color: Colors.black.withOpacity(0.15),  // CHANGED from 0.2
           blurRadius: 6,  // CHANGED from 8
           offset: const Offset(0, 2),
         )
       ],
     ),
     child: TextField(
       controller: _searchController,
       decoration: InputDecoration(
         hintText: 'ابحث عن موقع...',  // SHORTER text
         hintStyle: const TextStyle(fontSize: 12),  // CHANGED from 13
         contentPadding: const EdgeInsets.symmetric(
           horizontal: 14,  // CHANGED from 16
           vertical: 10,    // CHANGED from 12
         ),
         border: InputBorder.none,
         prefixIcon: const Icon(Icons.search, size: 20, color: _kGreen),  // ADD
         suffixIcon: _isSearching
             ? const Padding(
                 padding: EdgeInsets.all(10),  // CHANGED from 12
                 child: SizedBox(
                   width: 18,  // CHANGED from 20
                   height: 18,
                   child: CircularProgressIndicator(strokeWidth: 2),
                 ),
               )
             : null,
       ),
       textDirection: TextDirection.rtl,
       style: const TextStyle(fontSize: 12),  // CHANGED from 13
       onChanged: (value) {/* ... */},
       onSubmitted: _performSearch,
     ),
   ),
   ```

**Success Criteria:**
- Search bar is visibly smaller
- Still perfectly usable
- More map visible
- Clean professional look

---

## PROMPT 8: Add Smooth Marker Hover Effect

**File:** `apps/wawapp_admin/lib/features/live_ops/widgets/live_map.dart`

**Task:** Add scale animation on marker hover for better interactivity.

**Changes:**

1. **Wrap marker child with MouseRegion and AnimatedScale:**
   ```dart
   child: _HoverScaleMarker(
     child: driver.isOnline && !driver.isBlocked
         ? _buildOnlineDriverMarker(driver)
         : _buildDriverMarkerCore(driver),
   ),
   ```

2. **Add new stateful widget at bottom of file:**
   ```dart
   class _HoverScaleMarker extends StatefulWidget {
     final Widget child;

     const _HoverScaleMarker({required this.child});

     @override
     State<_HoverScaleMarker> createState() => _HoverScaleMarkerState();
   }

   class _HoverScaleMarkerState extends State<_HoverScaleMarker> {
     bool _isHovering = false;

     @override
     Widget build(BuildContext context) {
       return MouseRegion(
         onEnter: (_) => setState(() => _isHovering = true),
         onExit: (_) => setState(() => _isHovering = false),
         child: AnimatedScale(
           scale: _isHovering ? 1.15 : 1.0,
           duration: const Duration(milliseconds: 150),
           curve: Curves.easeOut,
           child: widget.child,
         ),
       );
     }
   }
   ```

**Success Criteria:**
- Markers scale up smoothly on hover
- Scale down when mouse leaves
- No performance issues
- Works on web and desktop

---

## Testing Checklist

After implementing all prompts, verify:

- [ ] Markers cluster properly at zoom levels < 12
- [ ] Clusters show correct count
- [ ] Clicking cluster zooms in smoothly
- [ ] Polygons are subtle and don't hide map details
- [ ] Legend toggles open/closed
- [ ] Selected markers are clearly highlighted
- [ ] Background dims when marker selected
- [ ] Search bar is compact but usable
- [ ] Markers scale on hover (web/desktop)
- [ ] Performance is smooth with 100+ markers
- [ ] No console errors or warnings
- [ ] Map is visually cleaner than before

---

## Performance Verification

Run these tests:

```bash
cd apps/wawapp_admin
flutter analyze
flutter build web --release
```

Expected results:
- Zero new warnings
- Build completes successfully
- Bundle size increase < 100KB (due to clustering library)

---

## Rollback Plan

If issues occur:

1. **Marker clustering issues:**
   - Remove `flutter_map_marker_cluster` import
   - Restore original `MarkerLayer` widgets from git history

2. **Performance degradation:**
   - Disable zoom-based filtering (PROMPT 6)
   - Increase clustering radius

3. **Visual issues:**
   - Revert polygon opacity to 0.15 (middle ground)
   - Keep legend always visible

---

## Estimated Impact

**Before:**
- Cluttered map with overlapping markers
- Heavy polygons hiding map details
- Always-visible legend taking space
- No visual hierarchy

**After:**
- Clean clustered markers
- Subtle polygons preserving map readability
- Collapsible legend
- Clear focus states
- Smooth animations
- Professional appearance

**Development time:** ~3-4 hours
**Prompts:** 8 sequential prompts
**Risk level:** Low (all changes are additive/visual)
