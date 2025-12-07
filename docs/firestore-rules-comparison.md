# Firestore Security Rules Comparison

**Date**: 2025-11-30  
**Status**: Audit for deployment decision

## Files

- `firestore.rules` (121 lines) - **CURRENTLY DEPLOYED**
- `firestore.rules.new` (96 lines) - **NOT DEPLOYED**

## Key Differences

### Changes in .new file:

1. **Simplified users collection update rules**:
   - Removed complex conditional checks for `totalTrips` and `averageRating`
   - Replaced with simpler blanket prohibition using `hasAny(['totalTrips', 'averageRating'])`

2. **Simplified savedLocations rules**:
   - Removed detailed validation rules for lat/lng bounds and label requirements
   - Replaced nested subcollection rules with simpler path-based rules
   - Changed from `match /users/{uid}/savedLocations/{locationId}` nested to `match /users/{userId}/savedLocations/{locationId}` direct

3. **Simplified drivers collection update rules**:
   - Removed complex conditional checks for admin-only fields
   - Replaced with simpler blanket prohibition using `hasAny(['isVerified', 'rating', 'totalTrips'])`
   - Removed `ratedOrders` field protection

## Security Impact Analysis

### Stricter Rules (Good):
- **Admin field protection**: Both versions prevent modification of admin-only fields, but .new version is more explicit
- **PIN security**: Both versions maintain PIN hash/salt protection equally

### Relaxed Rules (Review Required):
- **⚠️ CRITICAL: Saved locations validation removed**: 
  - Current rules validate lat/lng bounds (-90 to 90, -180 to 180) and require label
  - New rules allow ANY data to be written to savedLocations
  - **SECURITY RISK**: Could allow invalid coordinates or malicious data

### Removed Rules (High Risk):
- **⚠️ HIGH RISK: Coordinate validation**: 
  - Removed lat/lng bounds checking for saved locations
  - Could allow invalid coordinates that break map functionality
- **⚠️ MEDIUM RISK: Label validation**: 
  - Removed requirement for savedLocations to have a label field
  - Could cause UI crashes if label is missing
- **⚠️ LOW RISK: ratedOrders field protection**: 
  - Removed from drivers collection protection
  - Less critical but could affect rating calculations

## Recommendation

**🚨 DO NOT DEPLOY AUTOMATICALLY 🚨**

**CRITICAL ISSUES FOUND:**
1. **Saved locations validation completely removed** - HIGH SECURITY RISK
2. **Coordinate bounds checking removed** - FUNCTIONALITY RISK
3. **Required field validation removed** - STABILITY RISK

## Deployment Checklist

Before deploying firestore.rules.new:
- [ ] **REQUIRED**: Add back coordinate validation for savedLocations
- [ ] **REQUIRED**: Add back label field requirement for savedLocations  
- [ ] **RECOMMENDED**: Add back ratedOrders field protection for drivers
- [ ] Review diff with security team
- [ ] Test with Firebase Emulator Suite
- [ ] Verify no breaking changes to client/driver apps
- [ ] Backup current rules: `cp firestore.rules firestore.rules.backup`
- [ ] Deploy: `firebase deploy --only firestore:rules`
- [ ] Monitor Cloud Functions logs for permission errors
- [ ] Rollback plan: `cp firestore.rules.backup firestore.rules && firebase deploy --only firestore:rules`

## Recommended Hybrid Approach

Keep the simplified admin field protection from .new but restore validation:

```javascript
match /users/{userId}/savedLocations/{locationId} {
  allow read, delete: if isSignedIn() && request.auth.uid == userId;
  
  allow create, update: if isSignedIn() 
                    && request.auth.uid == userId
                    && request.resource.data.lat is number
                    && request.resource.data.lat >= -90
                    && request.resource.data.lat <= 90
                    && request.resource.data.lng is number
                    && request.resource.data.lng >= -180
                    && request.resource.data.lng <= 180
                    && request.resource.data.label is string
                    && request.resource.data.label.size() > 0;
}
```

## Next Steps

1. **IMMEDIATE**: Human architect must review this comparison
2. **DECISION REQUIRED**: Deploy .new OR keep current OR create hybrid version
3. **BEFORE DEPLOYMENT**: Fix validation issues identified above
4. Delete unused file after decision

**⚠️ SECURITY TEAM APPROVAL REQUIRED BEFORE ANY DEPLOYMENT ⚠️**