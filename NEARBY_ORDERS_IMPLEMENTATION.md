# Nearby Orders Implementation

## Overview
This implementation unifies the order document schema across Client and Driver apps, tightens Firestore security rules, and adds composite indexing for optimal performance.

## Order Schema (Unified)
```typescript
{
  ownerId: string,           // uid of client creating order
  status: "matching",        // current status
  pickup: {
    lat: number,            // -90 to 90
    lng: number,            // -180 to 180  
    label: string           // human-readable address
  },
  dropoff: {
    lat: number,            // -90 to 90
    lng: number,            // -180 to 180
    label: string           // human-readable address
  },
  distanceKm: number,       // 0 <= distanceKm < 100
  price: int,               // >= 0
  createdAt: serverTimestamp
}
```

## Client App Changes
- **OrdersRepository**: Updated to create orders with unified schema
- **QuoteScreen**: Uses repository for order creation with proper error handling
- **Authentication**: Automatically includes ownerId from Firebase Auth

## Driver App Changes  
- **Order Model**: Unified with LocationPoint structure for pickup/dropoff
- **LocationService**: GPS positioning with permission handling
- **OrdersService**: 8km radius filtering with distance-based sorting
- **NearbyScreen**: Real-time display of nearby orders with labels
- **Logging**: Structured logs for debugging: `[nearby_stream] start/empty/error/item`

## Security Rules
- Strict field validation with type checking
- Geographic coordinate validation
- Price and distance range validation  
- Authenticated access only
- Owner-based creation restrictions

## Performance Optimization
- **Composite Index**: `status ASC, createdAt DESC` for fast matching queries
- **Client-side filtering**: 8km radius calculated locally to reduce bandwidth
- **Distance sorting**: Orders sorted by proximity to driver

## Deployment Notes
1. Deploy Firestore rules: `firebase deploy --only firestore:rules`
2. Deploy indexes: `firebase deploy --only firestore:indexes`
3. If App Check is enabled, ensure proper configuration for both apps

## Follow-up TODOs
- [ ] Consider geospatial indexing for production scale (GeoHash/Geofirestore)
- [ ] Add order status transitions (matching → accepted → enRoute → delivered)
- [ ] Implement driver assignment logic
- [ ] Add real-time order tracking with telemetry