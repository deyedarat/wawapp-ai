# WawApp v1 – UX Pilot Journeys

**Document Owner:** UX / Product Designer
**Date:** 2025-12-22
**Status:** PILOT-FOCUSED (No redesigns, operational clarity only)

---

## 1. Client Journey

### Happy Path: App Open → Order Created → Tracked → Completed

**Step 1: Launch & Auth (0-30 seconds)**
```
App opens → Firebase init → Auth check
├─ New user → Login screen
│   ├─ Enter phone (8 digits, auto-formats to +222XXXXXXXX)
│   ├─ Tap "Check Phone" → OTP sent → Enter 6-digit code
│   └─ Create 4-digit PIN → Logged in
└─ Returning user → Login screen
    ├─ Enter phone
    ├─ Enter 4-digit PIN
    └─ Auto-redirect to home
```

**Friction Point:** New users see 3 screens before reaching home (phone → OTP → PIN). Returning users must type phone + PIN every time (no biometric, no "remember me").

---

**Step 2: Create Order (30-90 seconds)**
```
Home screen loads
├─ Map displays (300px height, centered on Nouakchott)
├─ Pickup field: Tap search icon → Autocomplete sheet → Select location
├─ Dropoff field: Tap search icon → Autocomplete sheet → Select location
├─ (Optional) Select shipment type from 6 categories
├─ Map updates with green (pickup) + red (dropoff) markers
└─ Tap "Begin Shipment" → Navigate to Quote screen
```

**Quote screen displays:**
- Large price (MRU)
- Distance (km, haversine calculation)
- Estimated time (minutes)
- Price breakdown (base + distance + multiplier)
- "Request Now" button

**Tap "Request Now":**
- Order created in Firestore (status: "assigning")
- Navigate to Track screen
- Client sees loading state: "Finding driver..."

**Friction Points:**
1. **Location input confusion:** Three ways to set location (text field, search icon, map tap) with no onboarding. Users may not discover "My Location" quick button or saved locations.
2. **Silent map failure:** If Google Maps API key invalid or quota exceeded, map shows blank grey box. No error message, no fallback.
3. **Autocomplete dependency:** If Places API fails, no search results. User stuck with manual map panning only.
4. **Pickup vs dropoff mode:** Toggle between "selecting pickup" or "dropoff" is not visually obvious. User may tap map and wonder why wrong marker moved.

---

**Step 3: Wait for Driver Assignment (0-5 minutes target)**
```
Track screen active
├─ Firestore listener on order document
├─ Client sees: "Finding nearby driver..."
├─ Status polling every few seconds
└─ When status changes to "accepted":
    └─ Auto-navigate to Driver Found screen
```

**Driver Found screen shows:**
- Success message: "Order accepted!"
- Driver card: name, phone (if available), vehicle type
- Map with driver location (blue marker) + pickup (green marker)
- ETA: "5-10 minutes"
- "Track Driver" button → Full tracking screen

**Friction Points:**
1. **Indefinite waiting:** No timeout UI. If no driver accepts in 10 minutes, client sees infinite spinner. Must manually close app or wait for admin cancellation.
2. **No driver availability indicator:** Client doesn't know if 0 drivers are online vs 20 drivers are busy. Creates anxiety during wait.
3. **Silent status transitions:** If order stuck in "assigning" due to backend error, client sees no feedback. No "Taking longer than usual..." message.
4. **Auto-navigation assumption:** Client expects immediate notification when driver accepts. If Firestore listener drops (network flicker), client misses transition and stays on stale "Finding driver" screen.

---

**Step 4: Track Delivery (Variable, 10-30 minutes typical)**
```
Public Track screen (/track/{orderId})
├─ Shows driver location on map (updates every few seconds)
├─ Shows order status timeline:
│   ├─ Created ✓
│   ├─ Assigned ✓
│   ├─ On Route → (in progress indicator)
│   └─ Completed (pending)
└─ Map centers on driver + pickup/dropoff markers
```

**When driver taps "Complete Order":**
- Status → "completed"
- Client screen auto-navigates to Trip Completed screen
- Shows success + rating prompt (1-5 stars + optional comment)

**Friction Points:**
1. **Driver location lag:** Location updates depend on driver's GPS signal and Firestore write latency. Client may see 10-30 second delays in marker position. No "Last updated X seconds ago" indicator.
2. **No ETA recalculation:** Initial "5-10 minutes" estimate never updates based on actual driver movement or traffic.
3. **Status ambiguity:** "On Route" status used for both:
   - Driver traveling to pickup
   - Driver traveling from pickup to dropoff
   Client cannot distinguish progress.
4. **Completion surprise:** No "Driver is arriving" or "Driver completed pickup" intermediate notifications. Client suddenly sees "Trip completed" screen.

---

### Alternate Paths & Edge Cases

**Path A: Order Cancelled by Admin**
- Status changes to "cancelled"
- Client sees... nothing (no auto-navigation, no dialog)
- Must manually refresh or restart app to discover cancellation

**Path B: Client Kills App During Tracking**
- On relaunch: Auth gate → Home screen
- "Current Shipment" card shows "No active shipments" (always, even if order active)
- No way to return to tracking screen unless client saved public tracking URL

**Path C: Network Loss During Order Creation**
- "Request Now" button tapped but Firestore write fails
- Shows... nothing (no retry, no error message)
- Client thinks order created but it's not in backend
- Tapping button again creates duplicate order

---

## 2. Driver Journey

### Happy Path: Go Online → See Orders → Accept → Deliver → View Earnings

**Step 1: Launch & Auth (Same as Client)**
```
App opens → Auth check
├─ New driver → Phone → OTP → Create PIN → Home
└─ Returning driver → Phone + PIN → Home
```

**Step 2: Go Online (5-15 seconds)**
```
Driver Home screen
├─ Large online/offline toggle switch (grey when offline)
├─ Status message: "Go online to receive orders" (Arabic)
└─ Tap toggle to go online:
    ├─ Profile completeness check:
    │   ├─ Required: name, vehicleType, vehiclePlate, city
    │   └─ If incomplete → Dialog: "Complete your profile" → Redirect /profile/edit
    ├─ Location prerequisite check:
    │   ├─ GPS enabled?
    │   ├─ Location permission granted?
    │   └─ If fails → Error dialog
    └─ If all pass:
        ├─ Firestore: Set driver online status = true
        ├─ LocationService.startTracking() → Get first GPS fix
        ├─ Snackbar: "You are now online"
        └─ Toggle turns green
```

**Friction Points:**
1. **Profile gate confusion:** If profile incomplete, driver tapped "go online" but gets redirected to profile edit. No explanation WHY they can't go online (no checklist shown).
2. **GPS prerequisite checked once:** If driver goes online successfully but GPS drops mid-shift (battery saver, tunnel, etc.), no warning shown. Driver thinks they're online but backend can't match them to orders.
3. **No feedback loop:** Driver goes online but doesn't know if system is working. No "X orders nearby" or "Waiting for orders..." message. Silent success creates doubt.

---

**Step 3: Discover Nearby Orders (0-5 minutes wait)**
```
From Home screen → Tap "Nearby Orders" quick action → Nearby screen

Nearby screen:
├─ Gets driver's current GPS position
├─ Firestore query:
│   ├─ status = "matching"
│   ├─ distance ≤ 8km (calculated using haversine)
│   └─ assignedDriverId = null
└─ Displays list of order cards:
    ├─ Order ID (last 6 chars)
    ├─ Distance: X.X km (from driver position)
    ├─ Price: X MRU (green, bold)
    ├─ Pickup address (truncated)
    ├─ Dropoff address (truncated)
    └─ "Accept Order" button
```

**Friction Points:**
1. **Empty state ambiguity:** If list shows "No nearby orders", driver doesn't know WHY:
   - Am I actually online? (check not visible here)
   - Are there zero orders in system?
   - Are all orders >8km away?
   - Is Firestore composite index missing? (silent failure)
2. **Race condition on accept:** If 2 drivers tap "Accept Order" simultaneously, first write wins. Loser sees snackbar "Order already taken" but list doesn't auto-refresh. Driver must manually go back and return to refresh.
3. **No order age indicator:** Driver can't tell if order has been waiting 10 seconds or 10 minutes. Stale orders look identical to fresh ones.
4. **Distance recalculation on every render:** If driver moves while viewing list, distances recalculate constantly. Creates visual jitter in list.

---

**Step 4: Accept Order & Navigate (Immediate)**
```
Tap "Accept Order" button
├─ ordersService.acceptOrder(orderId) called
├─ If success:
│   ├─ Order status → "accepted"
│   ├─ assignedDriverId → driver's ID
│   ├─ Auto-navigate to /active-order screen
│   └─ LocationService.startTracking() (if not already active)
└─ If fails:
    └─ Snackbar: "Order already taken"
```

**Active Order screen shows:**
- Order ID (last 6 chars)
- Pickup address (full)
- Dropoff address (full)
- Distance (km)
- Price (MRU, green)
- Current status badge (Arabic)
- **"Start Trip" button** (if status = "accepted")
- **"Complete Order" button** (if status = "on_route")
- **"Cancel Order" button** (always visible)

**Friction Points:**
1. **Navigation to pickup not integrated:** Driver sees pickup address as text but no "Open in Google Maps" or in-app turn-by-turn navigation. Must manually copy address and paste into separate maps app.
2. **Status transition manual:** Driver must remember to tap "Start Trip" after arriving at pickup, then "Complete Order" after dropoff. No automatic detection (geofence arrival).
3. **Cancel too easy:** "Cancel Order" button always visible with no warning badge. Driver may tap accidentally. Confirmation dialog exists but single tap from disaster.
4. **No pickup confirmation:** No explicit "I've picked up the package" button. Status goes directly from "accepted" to "on_route" to "completed". If driver taps "Start Trip" before actually picking up package, client tracking becomes misleading.

---

**Step 5: Complete Delivery & View Earnings (30 seconds)**
```
Driver arrives at dropoff → Taps "Complete Order"
├─ Confirmation dialog: "Mark order as completed?"
├─ If confirmed:
│   ├─ Order status → "completed"
│   ├─ Earnings added to driver's total
│   └─ Auto-navigate back to Home screen
└─ Driver now sees updated status: Still online, ready for next order
```

**View Earnings:**
```
From Home → Tap "Earnings" quick action → Earnings screen

Earnings screen (3 tabs):
├─ Daily: Today's trips + total MRU
├─ Weekly: This week's trips + total MRU
└─ Total: All-time trips + total MRU

Each trip card shows:
├─ Date/time
├─ From → To (addresses truncated >30 chars)
├─ Distance
└─ Price earned (green, bold)
```

**Friction Points:**
1. **Earnings update lag:** After completing order, driver must manually navigate to Earnings tab to see new total. No immediate "You earned X MRU!" confirmation on completion screen.
2. **No running total visible:** While online and accepting orders, driver can't see "Today so far: X MRU from Y trips" without leaving Home screen.
3. **Cash settlement unclear:** Earnings shown in MRU but no indication of when/how driver gets paid. No "Payout" button, no "Request withdrawal" flow. Driver must contact admin offline.

---

### Alternate Paths & Edge Cases

**Path A: Driver Goes Offline Mid-Delivery**
- Driver toggles offline switch while order active
- System allows it (no prevention)
- Order remains assigned to driver
- Client still sees driver as assigned but location stops updating
- No warning to driver: "You have an active order"

**Path B: Driver Profile Incomplete After Going Online**
- Profile completeness checked only at "go online" tap
- If driver edits profile and removes required field (e.g., deletes vehicle plate), can stay online
- System doesn't re-validate until next login

**Path C: Order Cancelled by Admin While Driver En Route**
- Status changes to "cancelled"
- Driver still on Active Order screen
- Screen shows... stale data (no auto-refresh, no dialog)
- Driver completes delivery, taps "Complete Order" → Fails with generic error
- No explanation of cancellation

**Path D: Multiple Drivers Accept Same Order (Race Condition)**
- Firestore transaction prevents double-assignment
- But UI doesn't reflect race: Loser driver sees brief loading spinner, then snackbar "Already taken"
- No auto-return to Nearby screen; driver must tap back manually

---

## 3. Admin Journey

### Happy Path: Monitor Live Operations → Intervene on Stuck Order

**Step 1: Login & Dashboard (10 seconds)**
```
Admin app opens → Login screen (email + password)
├─ Enter credentials
├─ Tap "Sign in"
└─ Navigate to Dashboard (/)

Dashboard shows (4-column grid):
├─ Online Drivers: X drivers (X% online) [tap → /drivers]
├─ Active Orders: X (in transit) [tap → /orders]
├─ Completed Today: X [tap → /orders filtered]
└─ Cancelled Today: X [tap → /orders filtered]

Quick Actions:
├─ Add Driver (TODO)
├─ Add Client (TODO)
└─ Settings → /settings
```

**Friction Points:**
1. **No real-time auto-refresh:** Stats update only when admin manually refreshes page or navigates away and back.
2. **"Add Driver" placeholder:** Buttons exist but do nothing. Admin expects to onboard drivers via UI but must do it offline (or via Firestore console).

---

**Step 2: Open Live Operations Dashboard (Immediate)**
```
From sidebar → Tap "Live Ops" → Live Ops screen (/live-ops)

Screen layout:
├─ Top bar: "Live" indicator (green dot) + current time (HH:mm:ss)
├─ Left panel: Filter panel (collapsible)
├─ Statistics bar:
│   ├─ Online Drivers: X
│   ├─ Active Orders: X
│   ├─ Unassigned Orders: X
│   ├─ Anomalies: X (orders stuck >10 min)
│   └─ Avg Assignment Time: X.X min
├─ Anomaly alert box (red, if anomalies exist):
│   ├─ "Alert: Stuck Orders"
│   ├─ "X orders stuck in 'assigning' state for >10 minutes"
│   └─ "View Details" button → Dialog with list
└─ Interactive map:
    ├─ Blue markers: Online drivers (with location)
    ├─ Red markers: Active orders (pickup locations)
    └─ Click marker → Info panel (bottom-left overlay)
```

**Friction Points:**
1. **Real-time update frequency unclear:** Map updates via Firestore stream but no visible "Last updated X seconds ago" timestamp on markers. Admin doesn't know if data is stale.
2. **Anomaly threshold hardcoded:** 10-minute stuck threshold not configurable. Admin can't adjust for peak hours or test scenarios.
3. **Filter panel interaction:** Toggling filters sometimes doesn't trigger map re-render. Admin must close and reopen Live Ops to force refresh.

---

**Step 3: Identify Stuck Order (Visual Scan)**
```
Admin sees anomaly alert: "3 orders stuck in 'assigning' state"
├─ Click "View Details" → Dialog lists:
│   ├─ Order ID (first 8 chars)
│   ├─ Time stuck (minutes)
│   ├─ Pickup address
│   └─ Price
├─ Admin clicks order ID → Navigate to order details
└─ OR admin clicks red order marker on map → Info panel opens:
    ├─ Order ID
    ├─ Status (badge with warning icon if stuck)
    ├─ Pickup address, dropoff address
    ├─ Price, distance
    ├─ Order age: "Created 12 minutes ago"
    └─ Warning badge: "Stuck in 'assigning' for >10 min"
```

**Friction Points:**
1. **No automatic suggested action:** Admin sees order stuck but no "Suggested actions" list. Must decide manually: cancel order, reassign to driver, or wait longer.
2. **Cannot see why stuck:** No indication of root cause (e.g., "No drivers within 8km", "All drivers offline", "Firestore index missing").

---

**Step 4: Intervene → Reassign or Cancel Order**
```
Option A: Cancel Order
├─ From order details dialog → Click "X" icon (cancel button)
├─ Confirmation dialog: "Cancel this order?" + optional reason text field
├─ Tap "Confirm" → adminOrdersService.cancelOrder(orderId, reason)
├─ Order status → "cancelled"
├─ Snackbar: "Order cancelled successfully"
└─ Map updates: Red marker disappears

Option B: Reassign Order (Expected but not found in UI)
├─ Admin expects "Reassign" button in order details
├─ Should show list of online drivers within reasonable distance
├─ Admin selects driver → Order assigned manually
└─ **MISSING IN CURRENT IMPLEMENTATION**
```

**Friction Points:**
1. **Reassignment not implemented:** Despite being core admin function, no "Reassign to driver" UI exists. Admin can cancel order but can't fix assignment issue. Must contact driver manually (phone call) or wait for auto-matching.
2. **Cancel reason optional:** Admin can cancel order with no reason logged. Makes post-mortem analysis difficult (why was order cancelled?).
3. **No bulk actions:** If 3 orders stuck, admin must cancel them one by one. No "Cancel all stuck orders" option.
4. **No driver intervention:** Admin can see driver is online but stuck (e.g., not moving for 20 minutes). No "Notify driver" or "Force offline" action available.

---

**Step 5: Monitor Resolution**
```
After intervention:
├─ Admin stays on Live Ops screen
├─ Statistics bar updates (anomalies count decreases)
├─ Map updates (cancelled order marker removed)
└─ Admin continues monitoring
```

**Friction Points:**
1. **No audit log visible:** Admin cancelled order but no record shown in UI. Must check Firestore directly to verify action logged correctly.
2. **No notification to client:** When admin cancels order, client sees... nothing (no auto-navigation, no dialog). Client stuck on "Finding driver" screen indefinitely.

---

### Alternate Paths

**Path A: Navigate to Orders Management Screen**
```
From sidebar → Tap "Orders" → Orders screen (/orders)

Orders table shows:
├─ Filter chips: All, Assigning, Accepted, On Route, Completed, Cancelled
├─ Columns: Order ID, Client, Driver, Status, Pickup, Dropoff, Price, Date, Actions
└─ Actions per row:
    ├─ Eye icon → Order details dialog
    └─ X icon → Cancel order (if not completed/cancelled)
```

**Path B: View Driver/Client Lists**
```
From sidebar → Tap "Drivers" → Drivers screen (/drivers)
├─ Lists all drivers with status, rating, trips
└─ Click driver → Driver details (TODO: add driver intervention actions)

From sidebar → Tap "Clients" → Clients screen (/clients)
├─ Lists all clients
└─ Click client → Client details
```

---

## 4. Top 5 UX Friction Risks (Ranked by Pilot Impact)

### #1 – Indefinite Client Waiting (CRITICAL)
**Where:** Client app, Track screen, "Finding driver..." spinner
**Impact:** If no drivers online or all drivers >8km away, client waits indefinitely with no feedback. No timeout message, no "Cancel order" button, no "No drivers available" warning.
**Risk:** Client frustration → app force-close → negative word-of-mouth → pilot failure
**Mitigation:** Accept this for pilot. Monitor "average assignment time" metric. If >80% of orders stuck >5 minutes, manually contact clients via phone to explain.

---

### #2 – Driver Location Failure (HIGH)
**Where:** Driver app, going online prerequisite check (GPS + permission)
**Impact:** Check only runs ONCE when driver taps "go online". If GPS drops mid-shift (battery saver mode, underground parking, tunnel), driver appears online but cannot be matched to orders (no location data). Driver thinks system broken.
**Risk:** Driver churn, missed orders, low order completion rate
**Mitigation:** Accept for pilot. Train drivers in onboarding: "Keep GPS enabled, disable battery saver for WawApp". Monitor "online drivers with no location data" in Firestore manually.

---

### #3 – Admin Cannot Reassign Orders (HIGH)
**Where:** Admin app, Live Ops screen, order details dialog
**Impact:** When order stuck in "assigning", admin can only cancel (destructive). Cannot manually assign to specific driver. Must rely on automatic matching or tell driver to refresh app.
**Risk:** Operational inefficiency, high cancellation rate, poor unit economics
**Mitigation:** Accept for pilot. Admin team (2-3 people) will use phone calls to coordinate: "Driver Ali, please check your Nearby Orders screen. You should see order #abc123."

---

### #4 – Silent Google Maps API Failures (MEDIUM)
**Where:** Client app, Home screen, map component (300px height)
**Impact:** If Google Maps API key invalid, quota exceeded, or network error, map shows blank grey box. No error message, no fallback UI. Client can still create order using text input but cannot see pickup/dropoff markers. Creates distrust.
**Risk:** Client abandonment, perception of broken app
**Mitigation:** Pre-launch verification: Ensure Maps API key valid + billing enabled + sufficient quota for pilot scale (estimate: 100 orders/day × 3 map loads/order = 300 API calls/day). Monitor Firebase Crashlytics for Maps errors. If >10% of clients see map errors, pause pilot and fix.

---

### #5 – Order Race Condition (MEDIUM)
**Where:** Driver app, Nearby screen, "Accept Order" button
**Impact:** If 2 drivers tap "Accept Order" on same order simultaneously (within ~1 second), Firestore transaction ensures only 1 write succeeds. Loser driver sees snackbar "Order already taken" but order list doesn't auto-refresh. Driver must manually go back and return to see updated list. Repeated failures frustrate driver.
**Risk:** Driver confusion, perception of unfair order distribution
**Mitigation:** Accept for pilot. Train drivers: "If you see 'Order already taken', go back and return to refresh list. Orders are assigned to fastest driver." Monitor "average order acceptance attempts per driver" (if >2 attempts/order, indicates high contention → need more drivers).

---

## 5. UX Rules for v1 Pilot (DO NOT CHANGE)

### Rule #1: No Redesigns
**Rationale:** Pilot goal is operational validation, not UX optimization. Any visual redesign (colors, typography, layouts) risks introducing new bugs. Existing UI is functional enough for 20-50 drivers and 100-200 clients.
**Forbidden:** Changing button styles, adding animations, modifying map marker icons, rewriting screen layouts.

---

### Rule #2: No New Flows
**Rationale:** Adding features (e.g., "Cancel order" for client, "Request payout" for driver) increases scope and delays launch. Accept manual workarounds for pilot.
**Forbidden:** Adding client order cancellation, driver payout requests, admin bulk actions, push notification settings, in-app chat.

---

### Rule #3: No Optimizations
**Rationale:** Performance issues (e.g., distance recalculation jitter, map re-renders) are acceptable at pilot scale. Optimizing now wastes time.
**Forbidden:** Debouncing location updates, caching Firestore queries, lazy-loading images, refactoring providers for efficiency.

---

### Rule #4: No Error Message Improvements
**Rationale:** Silent failures and generic error messages are technical debt but not pilot blockers. Focus on monitoring (Crashlytics) to detect issues, not preventing every edge case.
**Forbidden:** Adding custom error screens, retry mechanisms, detailed error toasts, offline mode handling.

---

### Rule #5: Accept Manual Admin Coordination
**Rationale:** Admin team is small (2-3 people) and willing to use phone calls to resolve stuck orders. Building full admin intervention UI (reassign orders, notify drivers, force offline) is v2 work.
**Forbidden:** Building admin "Reassign order" UI, "Notify driver" push button, "Force driver offline" action, "Bulk cancel orders" tool.

---

## 6. Operational Workarounds (Pilot-Specific)

### Workaround #1: Client Indefinite Waiting
**Problem:** No timeout UI when no drivers available.
**Pilot Solution:** Admin monitors Live Ops dashboard every 5-10 minutes. If order stuck >10 minutes, admin calls client via phone: "Sorry, no drivers available right now. We'll cancel your order and call you back when drivers online."

---

### Workaround #2: Driver GPS Loss
**Problem:** GPS drops mid-shift, driver appears online but unmatchable.
**Pilot Solution:** Admin sees driver marker not moving on Live Ops map. Admin calls driver: "Please check GPS enabled and restart WawApp."

---

### Workaround #3: Admin Cannot Reassign Orders
**Problem:** Order stuck, admin wants to manually assign to specific driver.
**Pilot Solution:** Admin calls driver directly: "Please open WawApp, go to Nearby Orders, you should see order #abc123. Accept it."

---

### Workaround #4: No Client Order History
**Problem:** Client completed order 2 days ago, wants to see address again.
**Pilot Solution:** Client calls admin, admin looks up order in Orders Management screen, reads address over phone.

---

### Workaround #5: Driver Cash Settlement
**Problem:** Driver completed 10 orders, wants to get paid, but no "Request payout" button.
**Pilot Solution:** End of week, admin exports order history CSV, calculates driver earnings manually, transfers cash/mobile money offline.

---

**End of UX_PILOT_JOURNEYS.md**
