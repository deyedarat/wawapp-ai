# WawApp Admin Panel

لوحة إدارة واو أب - Web-based administration dashboard for WawApp platform

## Overview

The WawApp Admin Panel is a modern, web-first Flutter application designed to manage the WawApp platform's operations, including orders, drivers, and clients. Built with the Manus Visual Identity (Mauritania flag colors), it provides a beautiful and consistent user experience.

## Features

### ✅ Implemented

1. **Dashboard Screen**
   - Real-time statistics (active drivers, ongoing orders, completed orders, cancelled orders)
   - Recent activity feed
   - Quick action cards
   - Beautiful Manus-branded UI

2. **Orders Management**
   - Comprehensive orders table with filtering
   - Filter by status (assigning/accepted/on-route/completed/cancelled)
   - View order details
   - Cancel orders functionality (UI ready)
   - Export orders (UI ready)

3. **Drivers Management**
   - Drivers table with status indicators
   - Filter by status (all/online/offline/blocked)
   - View driver profiles
   - Block/unblock drivers (UI ready)
   - Operator identification (Mauritel/Chinguitel/Mattel)
   - Rating and trip statistics

4. **Clients Management**
   - Clients table with verification status
   - View client profiles
   - Toggle verification status (UI ready)
   - Order history tracking
   - Export clients (UI ready)

5. **Settings Screen**
   - General settings (language, theme, notifications)
   - App settings (pricing, coverage areas, working hours)
   - System settings (backup, security, about)

### 🎨 Design System

**Manus Visual Identity**:
- Primary Green: `#00704A` (Mauritania flag)
- Golden Yellow: `#F5A623` (Mauritania flag)
- Accent Red: `#C1272D` (Mauritania flag)
- Light Background: `#F8F9FA`
- Dark Background: `#0A1612`

**Typography**:
- Primary Font: Inter (Bold for headings, Medium for UI)
- Secondary Font: DM Sans (Regular for body text)

**Components**:
- Responsive sidebar navigation
- Top app bar with search
- Stat cards
- Status badges
- Data tables with actions
- Modal dialogs

### 🌍 Internationalization & RTL

- Full Arabic language support
- RTL (Right-to-Left) layout
- Consistent spacing and alignment for RTL
- Support for future French localization

## Architecture

### Project Structure

```
lib/
├── core/
│   ├── router/
│   │   └── admin_app_router.dart        # GoRouter configuration
│   ├── theme/
│   │   ├── colors.dart                  # Manus color palette
│   │   ├── typography.dart              # Text styles
│   │   └── app_theme.dart               # Material theme
│   └── widgets/
│       ├── admin_scaffold.dart          # Main layout wrapper
│       ├── admin_sidebar.dart           # Sidebar navigation
│       ├── stat_card.dart               # Statistics cards
│       └── status_badge.dart            # Status indicators
├── features/
│   ├── dashboard/
│   │   └── dashboard_screen.dart        # Dashboard screen
│   ├── orders/
│   │   └── orders_screen.dart           # Orders management
│   ├── drivers/
│   │   └── drivers_screen.dart          # Drivers management
│   ├── clients/
│   │   └── clients_screen.dart          # Clients management
│   └── settings/
│       └── settings_screen.dart         # Settings screen
├── app.dart                             # App widget
└── main.dart                            # Entry point
```

### Dependencies

- `flutter_riverpod` - State management
- `go_router` - Declarative routing
- `firebase_core`, `firebase_auth`, `cloud_firestore` - Firebase integration (ready)
- `core_shared`, `auth_shared` - Shared packages from monorepo

## Running the Admin Panel

### Development Mode

```bash
# Navigate to admin app directory
cd apps/wawapp_admin

# Get dependencies
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# Or run on web server
flutter run -d web-server --web-port 8080
```

### Production Build

```bash
# Build web app
flutter build web

# Output will be in build/web/
```

## Integration Points (Ready for Implementation)

The UI is fully implemented and ready for backend integration:

### Orders
- Connect to Firestore `orders` collection
- Implement real-time streaming
- Hook up cancel order action
- Implement export functionality

### Drivers
- Connect to Firestore `drivers` collection
- Watch online status updates
- Implement block/unblock actions
- Add driver form

### Clients
- Connect to Firestore `clients` collection
- Implement verification toggle
- Track order history
- Export client data

### Dashboard
- Calculate real-time statistics from Firestore
- Implement activity feed streaming
- Add charting library for visualizations

## Firebase Integration

The app is ready for Firebase integration. To enable:

1. Add `firebase_options.dart` configuration
2. Uncomment Firebase initialization in `main.dart`
3. Create Firestore security rules
4. Deploy Firestore indexes

## Next Steps

### Phase 1: Backend Integration
- [ ] Connect to Firebase Firestore
- [ ] Implement real-time data streaming
- [ ] Add authentication for admin users
- [ ] Implement action handlers (cancel, block, verify)

### Phase 2: Enhanced Features
- [ ] Add data export (CSV, PDF)
- [ ] Implement search functionality
- [ ] Add date range filters
- [ ] Create detailed analytics charts
- [ ] Add notifications system

### Phase 3: Advanced Features
- [ ] Real-time order tracking on map
- [ ] Driver performance analytics
- [ ] Revenue reports
- [ ] System health monitoring
- [ ] Audit logs

## Testing

Currently implemented:
- ✅ UI smoke tests (manual)
- ✅ RTL layout verification
- ✅ Theme consistency
- ✅ Responsive design

To add:
- [ ] Unit tests for business logic
- [ ] Widget tests for components
- [ ] Integration tests for flows

## Contributing

Follow the existing code patterns:
1. Use Manus colors from `AdminAppColors`
2. Use spacing constants from `AdminSpacing`
3. Follow RTL-aware layouts with `EdgeInsetsDirectional`
4. Keep Arabic labels consistent
5. Maintain separation between UI and business logic

## License

WawApp proprietary software. All rights reserved.

## Support

For issues or questions about the admin panel, contact the development team.
