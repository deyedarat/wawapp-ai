# WawApp v1 – Product Scope (LOCKED)

**Document Owner:** Product Manager / Release Owner
**Date:** 2025-12-22
**Status:** LOCKED FOR RELEASE

---

## 1. Product Definition

WawApp v1 is a **pilot-stage on-demand delivery platform** for Nouakchott, Mauritania, connecting clients who need urgent deliveries with drivers who fulfill them. It supports real-time order matching, GPS tracking, and admin oversight. This is a **small-scale operational pilot** designed to validate core logistics workflows and unit economics with limited users (target: 20-50 drivers, 100-200 clients).

---

## 2. Primary Users

### Client (Order Placer)
- **Who:** Individuals or small businesses needing same-day local delivery in Nouakchott
- **Core Job:** Create delivery request → Track driver → Confirm delivery
- **Access:** Mobile app (Android)

### Driver (Order Fulfiller)
- **Who:** Independent drivers with motorcycles or light vehicles
- **Core Job:** Go online → Accept nearby orders → Complete delivery → Track earnings
- **Access:** Mobile app (Android)

### Admin (Platform Operator)
- **Who:** WawApp operations team (2-3 people)
- **Core Job:** Monitor live operations → Resolve stuck orders → Track platform health
- **Access:** Web dashboard (desktop browser)

---

## 3. MUST HAVE (Non-Negotiable)

If ANY of these are missing or broken, **DO NOT SHIP**.

### 3.1 Client App
1. **Phone + PIN Authentication** – Login with Mauritania phone number and 4-digit PIN
2. **Order Creation with Pricing** – Select pickup/dropoff → See instant quote → Confirm order
3. **Real-time Order Tracking** – See driver location on map and order status updates

### 3.2 Driver App
4. **Nearby Orders Discovery** – See orders within 8km when online → Accept order
5. **Active Order Management** – Navigate to pickup → Mark on-route → Complete delivery
6. **Earnings Dashboard** – View daily, weekly, and lifetime earnings by completed orders

### 3.3 Admin App
7. **Live Operations Dashboard** – Real-time map of online drivers + active orders + ability to reassign stuck orders

---

## 4. SHOULD HAVE (Nice to Have, Can Ship Without)

These features are functional but NOT required for pilot success:

- **Client order history** (single-order tracking sufficient for pilot)
- **Driver order history** (earnings dashboard covers core need)
- **Admin financial reports** (manual export acceptable for pilot)
- **Admin driver/client management screens** (operational visibility sufficient)
- **Saved locations** (client can re-type addresses)
- **Push notifications** (polling/refresh acceptable for pilot scale)

---

## 5. WON'T HAVE (Explicitly Excluded from v1)

Even if partially implemented in the codebase, these are **OUT OF SCOPE** for v1:

### Excluded Features
- **CSV export** (admin) → Manual data export only
- **Wallet/payout flows** (driver) → Manual cash settlement between operator and drivers
- **Multi-city support** → Nouakchott only, hardcoded city center
- **Driver onboarding verification** → Admin manually approves drivers offline before app access
- **Client payment integration** → Cash on delivery only, no digital payments
- **Order scheduling** → Immediate orders only, no future booking
- **Order cancellation by client** → Admin handles cancellations manually if needed
- **Driver ratings/reviews** → No feedback system in v1
- **Promotional codes / discounts** → Fixed pricing only
- **Multi-stop orders** → Single pickup → single dropoff only
- **Order reassignment by driver** → Once accepted, driver must complete or contact admin
- **Offline mode** → Internet connection required at all times

### Technical Exclusions
- **iOS apps** → Android only for pilot
- **Internationalization** → Arabic UI labels hardcoded, no language switching
- **Advanced analytics dashboards** → Crashlytics + basic Firebase Analytics only
- **Performance monitoring** → Crashlytics crash reports sufficient
- **A/B testing** → No experimentation framework in v1

---

## 6. Success Criteria (Day 7 Post-Launch)

Measure success by **operational viability**, not vanity metrics.

### Must Achieve (GO Signal for v2)
1. **Order Completion Rate ≥ 70%** – Of all orders created, at least 70% reach "completed" status (excludes admin cancellations due to no drivers available)
2. **Driver Utilization ≥ 30%** – At least 30% of online drivers complete ≥1 order per day
3. **Zero Critical Crashes** – Crashlytics reports zero crashes that block order creation, acceptance, or completion flows

### Should Achieve (Health Indicators)
4. **Average Order-to-Assignment Time ≤ 5 minutes** – Time from order creation to driver acceptance
5. **Admin Intervention Rate ≤ 20%** – Less than 20% of orders require manual admin reassignment or cancellation

---

## 7. What We Will Monitor at Launch

Tie to **existing instrumentation only** (no new features):

### Firebase Crashlytics (All Apps)
- Crash-free rate by app (target: 99%+)
- Top 5 crash types by volume
- Crashes in auth, order creation, order acceptance, tracking flows

### Firebase Analytics (Client + Driver Apps)
- **order_created** event count (client)
- **order_accepted** event count (driver)
- **order_completed** event count (driver)
- User type classification (client vs driver)
- Screen view distribution

### Firestore Real-time Queries (Admin Dashboard)
- Online drivers count (live)
- Active orders count by status (assigning, accepted, on_route)
- Completed orders today
- Cancelled orders today

### Manual Daily Export (Admin)
- Orders CSV: order_id, client_id, driver_id, status, created_at, completed_at, fare, distance
- Drivers CSV: driver_id, online_status, total_earnings, completed_orders_count
- Calculate metrics in Google Sheets for first 7 days

---

## 8. Launch Readiness Gate

Before announcing pilot to users, verify:

- [ ] All 7 MUST HAVE features tested end-to-end on real Android devices
- [ ] Staging Go/No-Go checklist passed (Gates A, B, C, D, E)
- [ ] Firebase projects configured: staging + production
- [ ] Google Maps API key valid and billed
- [ ] Firestore security rules deployed and tested
- [ ] Crashlytics initialized in all 3 apps
- [ ] Admin login credentials created for ops team
- [ ] 10 test drivers onboarded with working credentials
- [ ] 10 test clients onboarded with working credentials
- [ ] Manual test run: Create order (client) → Accept (driver) → Complete → Verify earnings

---

## 9. Scope Lock Enforcement

**This document is the single source of truth for v1.**

- Any feature request → Defer to v2 (no exceptions)
- Any bug blocking MUST HAVE features → Fix immediately
- Any bug in SHOULD HAVE features → Document and defer
- Any bug in WON'T HAVE features → Ignore

**Sign-off Authority:** Product Manager only. No scope changes without written approval.

---

**End of PRODUCT_SCOPE_V1.md**
