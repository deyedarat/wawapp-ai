# WawApp - تطبيق المغسلة 🧺

A complete laundry management system for Mauritania, built with Flutter and Firebase. The system consists of two mobile applications: one for laundry shop owners/staff and one for customers.

## 📱 Applications

### 1. Laundry Owner App (تطبيق المغسلة)
For laundry shop staff to manage orders, customers, and track revenue.

**Features:**
- Phone + OTP authentication
- Dashboard with order statistics (pending, ready, delivered today)
- Create new orders (select customer, add items, set price, set ETA)
- Update order status: Received → Washing → Ready → Delivered
- Customer management with order history
- Daily/weekly revenue summary
- Arabic/French bilingual interface with RTL support

### 2. Customer App (تطبيق الزبون)
For customers to track their laundry orders and receive notifications.

**Features:**
- Phone + OTP registration and login
- View active orders with real-time status tracking
- Order history with details
- Push notifications on status changes
- Rate service after delivery
- Arabic/French bilingual interface with RTL support

## 🏗️ Architecture

```
wawapp-ai/
├── apps/
│   ├── laundry_app/          # Laundry owner/staff app
│   └── customer_app/         # Customer app
├── packages/
│   └── shared/               # Shared code (models, services, widgets)
├── firebase/
│   ├── functions/            # Cloud Functions (TypeScript)
│   ├── firestore/            # Security rules & indexes
│   ├── firebase.json         # Firebase configuration
│   └── .firebaserc           # Firebase project config
├── melos.yaml                # Monorepo management
└── README.md
```

### Shared Package
The `packages/shared` package contains:
- **Models**: UserModel, OrderModel, OrderItemModel, RatingModel
- **Services**: AuthService, FirestoreService, NotificationService, MessagingService
- **Widgets**: StatusBadge, PhoneInputField, LoadingWidget, ErrorWidget
- **Localization**: Arabic/French translations
- **Utils**: Validators, Formatters, Extensions
- **Constants**: App constants, Firestore paths

## 🛠️ Technical Stack

| Component | Technology |
|-----------|-----------|
| Frontend | Flutter (latest stable) |
| Authentication | Firebase Auth (Phone OTP) |
| Database | Cloud Firestore |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Backend Logic | Cloud Functions (TypeScript) |
| State Management | Provider |
| Monorepo | Melos |

## 🚀 Setup Instructions

### Prerequisites

1. **Flutter SDK** (latest stable): [Install Flutter](https://docs.flutter.dev/get-started/install)
2. **Node.js** (v18+): [Install Node.js](https://nodejs.org/)
3. **Firebase CLI**: `npm install -g firebase-tools`
4. **Melos**: `dart pub global activate melos`
5. **A Firebase project** with Blaze plan (for Cloud Functions)

### Step 1: Clone the Repository

```bash
git clone https://github.com/deyedarat/wawapp-ai.git
cd wawapp-ai
git checkout feature/laundry-app
```

### Step 2: Firebase Setup

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable **Authentication** → Phone provider
3. Enable **Cloud Firestore**
4. Enable **Cloud Messaging**

#### Configure Firebase for Flutter

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure for laundry app
cd apps/laundry_app
flutterfire configure --project=YOUR_PROJECT_ID

# Configure for customer app
cd ../customer_app
flutterfire configure --project=YOUR_PROJECT_ID
```

This will generate the `firebase_options.dart` file for each app.

#### Update Firebase Project ID

Edit `firebase/.firebaserc` and replace `your-firebase-project-id` with your actual project ID.

### Step 3: Deploy Cloud Functions

```bash
cd firebase/functions
npm install
npm run build

cd ..
firebase deploy --only functions
```

### Step 4: Deploy Firestore Rules & Indexes

```bash
cd firebase
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

### Step 5: Install Dependencies

```bash
# From the root directory
melos bootstrap

# Or manually:
cd packages/shared && flutter pub get
cd ../../apps/laundry_app && flutter pub get
cd ../customer_app && flutter pub get
```

### Step 6: Run the Apps

```bash
# Run laundry app
cd apps/laundry_app
flutter run

# Run customer app (in another terminal)
cd apps/customer_app
flutter run
```

## 📋 Core Flow

```
1. Customer registers (phone + name)
2. Customer brings clothes to laundry
3. Staff creates order:
   - Selects customer (by phone)
   - Lists items (3 shirts, 2 pants, etc.)
   - Sets estimated completion time
   - Sets price
4. Customer receives notification: "تم استلام ملابسك"
5. Staff marks order as "washing"
6. Staff marks order as "ready"
7. Customer receives notification: "ملابسك جاهزة!"
8. Customer picks up clothes
9. Staff marks as "delivered"
10. Customer rates the service
```

## 🔐 Firestore Security Rules

The security rules enforce:
- Users can only read/write their own profiles
- Laundry staff can read customer profiles and manage orders
- Customers can only read their own orders
- Customers can only rate delivered orders
- Notifications are read-only for users (created by Cloud Functions)
- Orders cannot be deleted (only cancelled)

## 🌐 Localization

The app supports:
- **Arabic (العربية)** - Primary language, RTL layout
- **French (Français)** - Secondary language, LTR layout

Users can switch languages from the Settings screen.

### Mauritanian Phone Format
The app is configured for Mauritanian phone numbers:
- Country code: +222
- Format: XX XX XX XX (8 digits)

## 📊 Firestore Data Model

### Users Collection (`/users/{userId}`)
```json
{
  "uid": "string",
  "phoneNumber": "+222XXXXXXXX",
  "name": "string",
  "role": "customer | laundryOwner | staff",
  "fcmToken": "string",
  "isActive": true,
  "preferredLanguage": "ar | fr",
  "createdAt": "timestamp",
  "lastLoginAt": "timestamp"
}
```

### Orders Collection (`/orders/{orderId}`)
```json
{
  "customerId": "string",
  "customerName": "string",
  "customerPhone": "+222XXXXXXXX",
  "laundryId": "string",
  "items": [
    {
      "type": "shirt | pants | thobe | blanket | ...",
      "quantity": 3,
      "pricePerItem": 500,
      "notes": "optional"
    }
  ],
  "status": "received | washing | ready | delivered | cancelled",
  "totalPrice": 5000,
  "discount": 0,
  "estimatedCompletionTime": "timestamp",
  "createdAt": "timestamp",
  "completedAt": "timestamp | null",
  "deliveredAt": "timestamp | null",
  "notes": "optional string",
  "rating": "1-5 | null",
  "ratingComment": "optional string"
}
```

### Ratings Collection (`/ratings/{ratingId}`)
```json
{
  "orderId": "string",
  "customerId": "string",
  "laundryId": "string",
  "rating": 1-5,
  "comment": "optional string",
  "createdAt": "timestamp"
}
```

## 🔔 Cloud Functions

| Function | Trigger | Purpose |
|----------|---------|---------|
| `onOrderCreated` | Firestore onCreate | Notify customer of new order |
| `onOrderUpdated` | Firestore onUpdate | Notify customer of status change |
| `onRatingCreated` | Firestore onCreate | Notify laundry of new rating |
| `checkOverdueOrders` | Scheduled (hourly) | Alert staff about overdue orders |
| `cleanupInactiveTokens` | Scheduled (daily) | Remove stale FCM tokens |

## 🧪 Testing with Firebase Emulators

```bash
cd firebase
firebase emulators:start
```

This starts local emulators for Auth, Firestore, and Functions at:
- Auth: http://localhost:9099
- Firestore: http://localhost:8080
- Functions: http://localhost:5001
- Emulator UI: http://localhost:4000

To connect your Flutter apps to emulators, uncomment the emulator configuration in the service files.

## 📦 Item Types (أنواع القطع)

| Arabic | French | English |
|--------|--------|---------|
| قميص | Chemise | Shirt |
| بنطلون | Pantalon | Pants |
| دراعة | Daraa | Thobe/Daraa |
| ملحفة | Melhfa | Melhfa |
| بطانية | Couverture | Blanket |
| ملاءة | Drap | Sheet |
| ستارة | Rideau | Curtain |
| جاكيت | Veste | Jacket |
| فستان | Robe | Dress |
| أخرى | Autre | Other |

## 🔄 Order Statuses

| Status | Arabic | French | Description |
|--------|--------|--------|-------------|
| received | تم الاستلام | Reçu | Order created, clothes received |
| washing | قيد الغسيل | En lavage | Clothes being washed |
| ready | جاهز | Prêt | Ready for pickup |
| delivered | تم التسليم | Livré | Customer picked up |
| cancelled | ملغي | Annulé | Order cancelled |

## 💰 Currency

The app uses **Mauritanian Ouguiya (MRU)** as the currency:
- Symbol: أوقية / MRU
- Example: 500 أوقية

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is proprietary software. All rights reserved.

## 📞 Support

For support, please contact the development team.
