# WawApp Admin Panel - Live Operations (Phase 3)

## Overview

The **Live Operations** screen is a real-time command center for monitoring and managing the WawApp platform. It provides administrators with a live map view of drivers and active orders, along with analytics and anomaly detection to surface operational issues.

**Location**: `apps/wawapp_admin/lib/features/live_ops/`

---

## Features

### 1. Real-Time Map Display

- **Map Technology**: OpenStreetMap tiles via `flutter_map` (web-compatible)
- **Default Center**: Nouakchott, Mauritania (18.0735, -15.9582)
- **Auto-centering**: Map automatically centers on active markers

#### Driver Markers
- **Online Drivers**: Green circular markers with truck icon
- **Offline Drivers**: Gray circular markers
- **Blocked Drivers**: Red circular markers
- **Active Order Indicator**: Small yellow dot on marker if driver has active order

#### Order Markers
- **Pickup Location**: Colored circular marker with pin icon (color based on status)
- **Dropoff Location**: Colored circular marker with flag icon (semi-transparent)
- **Connection Line**: Dotted line connecting pickup to dropoff
- **Anomaly Indicator**: Small red dot on pickup marker if order is stuck

**Status Colors**:
- `assigning`: Golden Yellow (#F5A623)
- `accepted`: Blue (#0D6EFD)
- `on_route`: Green (#00704A)
- `completed`: Success Green (#28A745)
- `cancelled*`: Red (#C1272D)

### 2. Real-Time Data Streaming

#### Drivers Collection
**Query**: `drivers` collection
**Fields Used**:
- `location`: GeoPoint or `{lat, lng}` map
- `name`: Driver display name
- `phone`: Driver phone number
- `isOnline`: Boolean
- `isBlocked`: Boolean
- `operator`: "Mauritel" | "Chinguitel" | "Mattel"
- `activeOrderId`: Optional reference to active order
- `rating`: Double (0.0 - 5.0)
- `totalTrips`: Integer

**Filters Applied**:
- Driver status (all/online/offline/blocked)
- Operator filter
- Limit: 200 drivers maximum

#### Orders Collection
**Query**: `orders` collection
**Fields Used**:
- `pickup`: GeoPoint or `{lat, lng}` map
- `dropoff`: GeoPoint or `{lat, lng}` map
- `pickupAddress`: String
- `dropoffAddress`: String
- `status`: String
- `ownerId`: Client ID
- `assignedDriverId`/`driverId`: Optional driver ID
- `createdAt`: Timestamp
- `assignedAt`: Optional timestamp
- `price`: Optional double
- `distanceKm`: Optional double

**Filters Applied**:
- Order status (all/assigning/accepted/on_route/completed/cancelled)
- Time window (now/last hour/today/all)
- Anomaly flag
- Limit: 100 orders maximum

### 3. Filters & Controls

Located in collapsible side panel (320px width).

**Driver Filters**:
- Status: All / Online Only / Offline Only / Blocked Only
- Operator: All / Mauritel / Chinguitel / Mattel

**Order Filters**:
- Status: All / Assigning / Accepted / On Route / Completed / Cancelled
- Time Window:
  - **Now** (active orders only) - default
  - **Last Hour** (created in last 60 minutes)
  - **Today** (created today)
  - **All** (no time filter)

**Anomaly Filter**:
- Toggle: Show anomalies only
- Definition: Orders in `assigning` status for more than threshold

**Reset Button**: Appears when filters are not at default values

### 4. Live Analytics Dashboard

Top statistics bar displays:

1. **Online Drivers**
   - Count of drivers with `isOnline=true` AND `isBlocked=false`
   - Icon: drive_eta
   - Color: Green

2. **Active Orders**
   - Count of orders in `assigning`, `accepted`, or `on_route` status
   - Icon: local_shipping
   - Color: Blue

3. **Unassigned Orders**
   - Count of active orders with no `assignedDriverId`
   - Icon: pending
   - Color: Golden Yellow

4. **Anomalous Orders**
   - Count of orders stuck in `assigning` for > threshold
   - Icon: warning
   - Color: Red

5. **Average Assignment Time** (optional)
   - Average minutes from `createdAt` to `assignedAt`
   - Icon: timer
   - Color: Info Blue
   - Only shown when data is available

### 5. Anomaly Detection

**Definition**: Orders are considered anomalous if:
- Status is `assigning`
- Age (time since creation) > 10 minutes

**Threshold**: Configurable constant (default: 10 minutes)
- Location: `LiveOrderMarker.isAnomalous(thresholdMinutes: 10)`

**Alerts**:
- Red banner appears when anomalies exist
- Shows count and description
- "View Details" button opens dialog with list
- Each anomalous order shows:
  - Order ID (short hash)
  - Pickup/dropoff addresses
  - Age in minutes

**Visual Indicators**:
- Small red dot on pickup marker
- Red highlight in order info panel

### 6. Interactive Info Panels

**Driver Info Panel** (on marker click):
- Name
- Phone
- Operator (localized: موريتل/شنقيتل/ماتل)
- Status (متصل/غير متصل/محظور)
- Rating (⭐)
- Total trips
- Active order ID (if any)

**Order Info Panel** (on marker click):
- Order ID (short hash)
- Status (localized)
- Pickup address
- Dropoff address
- Price (MRU)
- Distance (km)
- Age (minutes)
- Warning badge if anomalous

**Panel Behavior**:
- Appears at bottom of map
- Semi-transparent overlay
- Close button (X)
- Max width: 500px

### 7. UI/UX Features

**Responsive Layout**:
- Large screens: Filter panel + map side-by-side
- Small screens: Filter panel collapses (toggle button)

**RTL Support**:
- Full right-to-left layout for Arabic
- Proper alignment of all UI elements
- Mirror-safe icons and components

**Manus Branding**:
- Colors from Admin theme (Mauritania flag palette)
- Typography: Inter/DM Sans
- Consistent spacing and radii
- Material 3 components

**Performance Optimizations**:
- Query limits (200 drivers, 100 orders)
- Client-side filtering for some operations
- Efficient marker rendering
- Auto-centering only on data changes

---

## Architecture

### File Structure
```
lib/features/live_ops/
├── models/
│   ├── live_driver_marker.dart      # Driver marker model
│   ├── live_order_marker.dart       # Order marker model
│   └── live_ops_filters.dart        # Filter enums and state
├── providers/
│   └── live_ops_providers.dart      # Riverpod providers
├── widgets/
│   ├── live_map.dart                # Map widget
│   └── filter_panel.dart            # Filter sidebar
└── live_ops_screen.dart             # Main screen
```

### Data Flow
```
Firestore (orders, drivers)
    ↓
Riverpod Providers (real-time streams)
    ↓
LiveOpsScreen (aggregates & computes)
    ↓
LiveMap Widget (renders markers)
```

### State Management
- **Filter State**: `liveOpsFiltersProvider` (StateProvider)
- **Drivers Stream**: `liveDriversStreamProvider` (StreamProvider)
- **Orders Stream**: `liveOrdersStreamProvider` (StreamProvider)
- **Statistics**: `liveOpsStatsProvider` (Provider, derived)
- **Anomalies**: `anomalousOrdersProvider` (Provider, derived)

---

## Configuration

### Thresholds & Constants

**Anomaly Threshold**:
```dart
// In LiveOrderMarker.isAnomalous()
thresholdMinutes: 10  // Default
```

**Query Limits**:
```dart
// In live_ops_providers.dart
drivers limit: 200
orders limit: 100
```

**Map Defaults**:
```dart
// In live_map.dart
defaultCenter: LatLng(18.0735, -15.9582)  // Nouakchott
defaultZoom: 12.0
minZoom: 5.0
maxZoom: 18.0
```

**Marker Sizes**:
```dart
driver marker: 40x40 (outer), 28x28 (inner)
order pickup: 32x32
order dropoff: 32x32
anomaly indicator: 10x10
active order indicator: 12x12
```

---

## Firestore Requirements

### Required Fields

**drivers collection**:
```
- location: GeoPoint or {lat: number, lng: number}
- name: string
- phone: string
- isOnline: boolean
- isBlocked: boolean
- operator: string (optional)
- activeOrderId: string (optional)
- rating: number (optional)
- totalTrips: number (optional)
```

**orders collection**:
```
- pickup: GeoPoint or {lat: number, lng: number}
- dropoff: GeoPoint or {lat: number, lng: number}
- pickupAddress: string
- dropoffAddress: string
- status: string
- ownerId: string
- assignedDriverId: string (optional)
- driverId: string (optional)
- createdAt: Timestamp
- assignedAt: Timestamp (optional)
- price: number (optional)
- distanceKm: number (optional)
```

### Recommended Indexes

**For driver queries**:
```
Collection: drivers
Fields: [isOnline ASC, createdAt DESC]
```

**For order queries**:
```
Collection: orders
Fields: [status ASC, createdAt DESC]
```

**For time-windowed order queries**:
```
Collection: orders
Fields: [createdAt DESC]
```

Deploy indexes:
```bash
firebase deploy --only firestore:indexes
```

---

## Future Enhancements

### Performance
- [ ] Marker clustering for large datasets
- [ ] Virtual scrolling for anomaly lists
- [ ] Server-side aggregation via Cloud Function
- [ ] WebSocket for even lower latency

### Features
- [ ] Driver track history (breadcrumbs)
- [ ] Order assignment from map
- [ ] Click-to-call driver/client
- [ ] Export map view as image
- [ ] Heatmap overlay for order density
- [ ] Traffic layer integration
- [ ] Driver ETA predictions

### Analytics
- [ ] Average speed per driver
- [ ] Order completion rate by area
- [ ] Peak hours visualization
- [ ] Driver utilization metrics
- [ ] Customer satisfaction correlation

### Alerts
- [ ] Push notifications for anomalies
- [ ] Configurable alert rules
- [ ] Email/SMS alerts
- [ ] Alert history and trends

---

## Troubleshooting

### Map Not Loading
- **Issue**: Blank map or no tiles
- **Solution**: 
  - Check internet connection
  - Verify OpenStreetMap tile server is accessible
  - Check browser console for CORS errors
  - Consider using cached tiles or alternative tile provider

### No Markers Appearing
- **Issue**: Empty map with no drivers/orders
- **Solution**:
  - Verify Firestore has data in `drivers` and `orders` collections
  - Check that documents have `location` field with valid coordinates
  - Verify Firestore rules allow admin read access
  - Check browser console for query errors

### Filters Not Working
- **Issue**: Filters don't update data
- **Solution**:
  - Check Riverpod provider dependencies
  - Verify filter state is updating
  - Check Firestore indexes are deployed
  - Look for query errors in console

### Performance Issues
- **Issue**: Slow rendering or lag
- **Solution**:
  - Reduce query limits in providers
  - Enable marker clustering (future feature)
  - Check network tab for excessive requests
  - Profile Flutter app with DevTools

---

## Testing

### Manual Testing Checklist
- [ ] Map loads and displays correctly
- [ ] Driver markers appear with correct colors
- [ ] Order markers appear with pickup/dropoff
- [ ] Filters update data in real-time
- [ ] Stats bar shows correct counts
- [ ] Anomaly alert appears when applicable
- [ ] Info panels open on marker click
- [ ] Panel closes on X button
- [ ] Filter panel toggles correctly
- [ ] Reset filters button works
- [ ] RTL layout displays correctly
- [ ] Responsive layout works on different screen sizes

### Data Scenarios
1. **No data**: Empty state message
2. **Only drivers**: Driver markers only
3. **Only orders**: Order markers only
4. **Mixed data**: Both drivers and orders
5. **Anomalous orders**: Alert banner appears
6. **Blocked drivers**: Red markers
7. **All filters**: Combinations work correctly

---

## Monitoring

### Key Metrics
- **Real-time metrics** (displayed in UI):
  - Online drivers count
  - Active orders count
  - Unassigned orders count
  - Anomalous orders count
  - Average assignment time

### Operational Alerts
- Orders stuck > 10 minutes in `assigning`
- No online drivers available
- Spike in unassigned orders
- High cancellation rate

### Performance Monitoring
- Query execution time
- Map render time
- Provider update frequency
- Memory usage

---

## Dependencies

### Flutter Packages
```yaml
flutter_map: ^6.1.0        # Map widget
latlong2: ^0.9.0           # Coordinate handling
flutter_riverpod: ^2.4.9   # State management
go_router: ^12.1.3         # Routing
intl: ^0.20.2              # Date formatting
```

### Backend
- Firebase Firestore (real-time database)
- Firestore Security Rules (admin access)

---

## Deployment

### Before Deployment
1. Update Firestore indexes:
   ```bash
   firebase deploy --only firestore:indexes
   ```

2. Verify security rules allow admin access to `drivers` and `orders`

3. Test with production data (use staging environment first)

### Production Considerations
- **Scalability**: Monitor query costs as data grows
- **Rate Limiting**: Consider Cloud Functions aggregation for large datasets
- **Caching**: Implement caching for stats if needed
- **Monitoring**: Set up alerts for anomalies via Cloud Functions

---

**Version**: 1.0.0  
**Date**: December 9, 2025  
**Status**: ✅ Complete
