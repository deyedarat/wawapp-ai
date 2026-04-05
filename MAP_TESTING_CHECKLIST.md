# Map Optimization - Testing Checklist

**Date:** 2026-04-04
**Status:** Ready for testing
**Test Environment:** Chrome (recommended), Firefox, Edge

---

## Quick Test Commands

```bash
# Navigate to admin directory
cd apps/wawapp_admin

# Run the app in Chrome
flutter run -d chrome

# Or build and deploy
flutter build web --release
firebase deploy --only hosting:admin
```

---

## Test 1: Live Ops Map - Marker Clustering

**URL:** `http://localhost:[port]/live-ops` or `https://wawapp-952d6.web.app/live-ops`

### Steps

1. ✅ Navigate to Live Ops screen
2. ✅ Verify map loads without errors
3. ✅ Zoom out to level 8-10
4. ✅ **Expected:** Markers cluster into groups with count badges
5. ✅ Click a cluster
6. ✅ **Expected:** Map zooms in smoothly
7. ✅ Zoom in to level 14+
8. ✅ **Expected:** Individual markers visible
9. ✅ Check cluster badge colors:
   - Green clusters = drivers
   - Blue clusters = orders
10. ✅ **Expected:** Counts match number of markers in cluster

### Pass Criteria
- [ ] Clustering works at zoom < 12
- [ ] Clusters show correct count
- [ ] Clicking cluster zooms in
- [ ] Individual markers appear at zoom >= 14
- [ ] No console errors

---

## Test 2: Collapsible Legend

**URL:** Same as Test 1

### Steps

1. ✅ Look at bottom-right corner of map
2. ✅ **Expected:** Small info icon button (legend collapsed)
3. ✅ Click the info icon
4. ✅ **Expected:** Full legend expands with:
   - "دليل الرموز" (Guide) header
   - Driver status colors (green, gray, red)
   - Order markers (pickup, dropoff)
   - Close button (X)
5. ✅ Click X button
6. ✅ **Expected:** Legend collapses back to small icon
7. ✅ Toggle legend 3-4 times
8. ✅ **Expected:** Smooth animation, no flicker

### Pass Criteria
- [ ] Legend starts collapsed
- [ ] Info icon visible and clickable
- [ ] Legend expands showing all items
- [ ] Close button works
- [ ] Smooth transitions

---

## Test 3: Focus Mode (Selection + Dim)

**URL:** Same as Test 1

### Steps

1. ✅ Click any driver marker
2. ✅ **Expected:**
   - Background dims (semi-transparent black overlay)
   - Selected driver marker gets larger (36px)
   - Yellow border around selected marker
   - Stronger glow/shadow
3. ✅ Click a different driver
4. ✅ **Expected:**
   - Previous driver returns to normal
   - New driver highlighted
5. ✅ Click an order marker
6. ✅ **Expected:**
   - Driver deselects
   - Order selected (same highlight style)
7. ✅ Click the dimmed background (not a marker)
8. ✅ **Expected:**
   - Dim overlay disappears
   - All markers return to normal
9. ✅ Select marker, then zoom
10. ✅ **Expected:** Selection persists during zoom

### Pass Criteria
- [ ] Clicking marker dims background
- [ ] Selected marker clearly highlighted
- [ ] Yellow border visible
- [ ] Clicking background clears selection
- [ ] Only one marker selected at a time

---

## Test 4: Viewport Filtering (Performance)

**URL:** Same as Test 1

### Steps

**Setup:** Ensure you have 50+ drivers and orders in Firestore

1. ✅ Zoom out to level 8
2. ✅ Count visible driver markers (not clusters)
3. ✅ **Expected:** Only online drivers visible (~20-30% of total)

4. ✅ Zoom to level 11
5. ✅ **Expected:** More drivers visible (online + active orders)

6. ✅ Zoom to level 14
7. ✅ **Expected:** All drivers visible

**Orders:**

8. ✅ Zoom out to level 10
9. ✅ **Expected:** Only active orders visible

10. ✅ Zoom to level 12
11. ✅ **Expected:** All orders visible

### Performance Check

12. ✅ Zoom in and out rapidly 5 times
13. ✅ **Expected:**
    - No lag or freezing
    - Smooth transitions
    - Markers appear/disappear smoothly

### Pass Criteria
- [ ] Fewer markers at low zoom
- [ ] More markers at high zoom
- [ ] Filtering happens smoothly
- [ ] No performance lag
- [ ] No "setState after dispose" errors in console

---

## Test 5: Polygon Opacity (Location Picker)

**URL:** `http://localhost:[port]/orders/create`

### Steps

1. ✅ Navigate to Orders → Create Order
2. ✅ Click "Pickup Location" or "Dropoff Location" field
3. ✅ **Expected:** Map location picker opens
4. ✅ Observe district polygons (colored areas)
5. ✅ **Expected:**
   - Polygons are barely visible (~0.08 opacity)
   - Roads underneath are clearly readable
   - Street names visible
   - District labels readable but not dominant
6. ✅ Toggle district visibility (icon in top-right)
7. ✅ **Expected:** Polygons show/hide

### Visual Comparison

**Before (old version):** Heavy colored fills obscuring map
**After (current):** Subtle tints, map details clear

### Pass Criteria
- [ ] Polygons barely visible but identifiable
- [ ] Roads and labels clearly visible
- [ ] Map is primary visual element
- [ ] No excessive colors blocking view

---

## Test 6: Compact Search Bar

**URL:** Same as Test 5 (location picker)

### Steps

1. ✅ Look at the search bar at top of map
2. ✅ **Expected:**
   - Noticeably smaller than before
   - Still easy to click and type
   - Search icon on the left (prefix)
   - Compact padding and font
3. ✅ Type "مطعم" (restaurant) in search
4. ✅ **Expected:**
   - Autocomplete dropdown appears
   - Results display correctly
   - Search works perfectly
5. ✅ Measure visual space
6. ✅ **Expected:** More map visible compared to before

### Visual Check

- Border radius: 20px (slightly rounded)
- Font size: 12px (readable but compact)
- Padding: Reduced but comfortable

### Pass Criteria
- [ ] Search bar is noticeably smaller
- [ ] Still easy to use
- [ ] Search functionality works
- [ ] More map visible

---

## Test 7: Hover Effects (Web/Desktop Only)

**URL:** Live Ops map

### Steps

**Prerequisites:** Use Chrome, Firefox, or Edge on desktop (not mobile)

1. ✅ Hover mouse over a driver marker (don't click)
2. ✅ **Expected:**
   - Marker smoothly scales up to 1.15x
   - Animation duration: 150ms
   - Easing: smooth (easeOut curve)
3. ✅ Move mouse away
4. ✅ **Expected:**
   - Marker scales back to 1.0x
   - Same smooth animation
5. ✅ Hover over an order marker
6. ✅ **Expected:** Same hover effect
7. ✅ Hover over a cluster badge
8. ✅ **Expected:** Hover effect on cluster too
9. ✅ Rapidly move mouse over multiple markers
10. ✅ **Expected:**
    - Each marker responds independently
    - No lag or stuttering
    - Smooth animations

**Mobile Test:**

11. ✅ Open on mobile device or mobile emulator
12. ✅ **Expected:** No hover effects (MouseRegion is no-op on touch)
13. ✅ Tap markers
14. ✅ **Expected:** Tap/click still works normally

### Pass Criteria
- [ ] Markers scale on hover (desktop)
- [ ] Smooth 150ms animation
- [ ] Scales back when leaving
- [ ] No performance issues
- [ ] No hover on mobile (expected)

---

## Test 8: Edge Cases

### Empty State

1. ✅ Clear all drivers and orders from Firestore (or use filters)
2. ✅ Navigate to Live Ops
3. ✅ **Expected:**
   - Map shows
   - Message: "لا يوجد سائقون أو طلبات نشطة حالياً"
   - No errors in console

### Single Marker

4. ✅ Add exactly 1 driver to Firestore
5. ✅ Reload Live Ops
6. ✅ **Expected:**
   - Map centers on the driver
   - No cluster (single marker)
   - Marker is clearly visible

### 100+ Markers

7. ✅ Add 100+ drivers and orders
8. ✅ Load Live Ops
9. ✅ **Expected:**
   - Initial load < 2 seconds
   - Smooth performance
   - Clustering working well
   - No lag when zooming

### Rapid Interactions

10. ✅ Click markers rapidly
11. ✅ Zoom in/out rapidly
12. ✅ Toggle legend rapidly
13. ✅ **Expected:**
    - No crashes
    - No console errors
    - UI remains responsive

### Offline/Network Issues

14. ✅ Disable network (DevTools → Network → Offline)
15. ✅ **Expected:**
    - Map tiles from cache still work
    - Graceful degradation
    - No crash

### Pass Criteria
- [ ] Empty state handled gracefully
- [ ] Single marker centers correctly
- [ ] 100+ markers perform well
- [ ] No crashes with rapid interactions
- [ ] Offline mode handled

---

## Test 9: Cross-Browser Compatibility

### Chrome

1. ✅ Run all tests above in Chrome
2. ✅ **Expected:** All features work

### Firefox

3. ✅ Open in Firefox
4. ✅ Run Tests 1-7
5. ✅ **Expected:** All features work identically

### Edge

6. ✅ Open in Edge
7. ✅ Run Tests 1-7
8. ✅ **Expected:** All features work identically

### Mobile Safari (Optional)

9. ✅ Open on iPhone/iPad
10. ✅ **Expected:**
    - Map loads
    - Clustering works
    - No hover effects (expected)
    - Touch interactions work

### Pass Criteria
- [ ] Chrome: All features work
- [ ] Firefox: All features work
- [ ] Edge: All features work
- [ ] Mobile: Core features work (no hover)

---

## Test 10: Console & Network Checks

### Console Errors

1. ✅ Open DevTools → Console
2. ✅ Run all tests
3. ✅ **Expected:**
   - No red errors
   - No "setState after dispose" warnings
   - Deprecation warnings acceptable (pre-existing)

### Network Performance

4. ✅ Open DevTools → Network
5. ✅ Load Live Ops
6. ✅ Check for:
   - Map tiles loading correctly
   - No 404 errors
   - Reasonable bundle size

### Memory Leaks

7. ✅ Open DevTools → Performance → Memory
8. ✅ Take heap snapshot
9. ✅ Navigate to Live Ops, zoom around, select markers
10. ✅ Take another heap snapshot
11. ✅ **Expected:** No significant memory growth

### Pass Criteria
- [ ] Zero red errors in console
- [ ] Map tiles load successfully
- [ ] No memory leaks detected

---

## Final Verification

### Overall Quality Check

Run through this quick checklist:

- [ ] Map loads without errors
- [ ] Markers cluster at low zoom
- [ ] Legend toggles open/closed
- [ ] Selection highlights markers
- [ ] Background dims when selected
- [ ] Polygons are subtle
- [ ] Search bar is compact
- [ ] Hover effects work (desktop)
- [ ] Performance is smooth
- [ ] No console errors
- [ ] All browsers work

### If Any Test Fails

1. Note the specific test number
2. Check console for errors
3. Try in incognito/private mode
4. Clear cache and retry
5. Check [MAP_OPTIMIZATION_SUPERVISION.md](MAP_OPTIMIZATION_SUPERVISION.md) troubleshooting section

---

## Acceptance Criteria

To mark this optimization as **COMPLETE**, all these must be true:

✅ All 10 tests above pass
✅ Zero red errors in console
✅ Performance is smooth with 100+ markers
✅ Works in Chrome, Firefox, Edge
✅ Map is visually cleaner than before
✅ No breaking changes to existing features

---

## Test Sign-Off

**Tested by:** __________________
**Date:** __________________
**Browser:** __________________
**Result:** ✅ Pass / ❌ Fail

**Notes:**
_________________________________
_________________________________
_________________________________

---

## Quick Reference: Expected Behaviors

| Feature | Trigger | Expected Result |
|---------|---------|-----------------|
| Clustering | Zoom out to < 12 | Markers group into clusters with count badges |
| Legend | Click info icon | Expands to show full legend |
| Focus Mode | Click marker | Background dims, marker highlighted |
| Hover | Mouse over marker (desktop) | Marker scales to 1.15x |
| Polygons | Open location picker | Barely visible (~0.08 opacity) |
| Search | Type in search bar | Autocomplete works, compact size |
| Viewport Filter | Zoom to 8 | Only online drivers visible |

---

**End of Testing Checklist**

Estimated testing time: 30-45 minutes
Recommended: Test in Chrome first, then other browsers
