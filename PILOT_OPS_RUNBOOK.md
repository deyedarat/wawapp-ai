# WawApp v1 – Pilot Operations Runbook

**Document Owner:** Ops / SRE / Support Lead
**Date:** 2025-12-22
**Status:** OPERATIONAL MANUAL (Day 1-7 pilot)

---

## 0. Quick Reference Card

**Emergency Contacts:**
- Product Manager: [PHONE] [EMAIL]
- Admin Lead: [PHONE] [EMAIL]
- Growth Lead: [PHONE] [EMAIL]
- On-Call Ops: [PHONE] [EMAIL]

**Critical Links:**
- Firebase Console: https://console.firebase.google.com/project/wawapp-staging
- Admin Dashboard: [URL]
- Crashlytics: [Firebase Console → Crashlytics]
- Analytics: [Firebase Console → Analytics]
- Google Sheets (Metrics): [URL]
- Driver WhatsApp Group: [URL]
- Client Support Line: [PHONE]

**Daily Checklist (Every 9:00 AM):**
- [ ] Check North Star (completion rate ≥70%?)
- [ ] Check DAU (client growing? driver stable?)
- [ ] Check Crashlytics (crash-free ≥95%?)
- [ ] Check Kill Signals (any K1-K7 triggered?)
- [ ] Update Daily Metrics Log (Google Sheet)
- [ ] Review admin interventions from last 24h
- [ ] Post standup summary to admin Slack/WhatsApp

---

## 1. Incident Types & Response Procedures

### CRITICAL INCIDENTS (Immediate Response Required)

---

### **Incident K1: Order Completion Rate < 50% for 2 Consecutive Days**

**Severity:** 🔴 CRITICAL – Marketplace fundamentally broken

**Detection:**
- **Automated:** Daily metrics calculation in Google Sheets (formula: `=COUNTIF(D:D,"completed")/COUNTA(C:C)` where D=status, C=order_id)
- **Manual:** Admin dashboard shows "Completed Today" significantly lower than "Orders Created"
- **Threshold:** If completion rate <50% on Day N, mark as WARNING. If still <50% on Day N+1, trigger K1.

**Immediate Actions (Within 30 Minutes):**

**Step 1: Verify Data (5 minutes)**
```bash
# Admin opens Firebase Console → Firestore → orders collection
# Filter: createdAt >= [today - 2 days]
# Count: status = "completed" vs total orders
# Confirm: Is completion rate actually <50%?
```

**Step 2: Diagnose Root Cause (10 minutes)**

Check admin dashboard Live Ops screen:
- **Supply problem?** Online drivers count = 0 or very low (<5)?
  - Likely cause: Drivers quit, GPS issues, app crashes
- **Demand problem?** Active orders count = 0?
  - Likely cause: No clients creating orders
- **Matching problem?** Unassigned orders count high (>10 stuck in "assigning")?
  - Likely cause: No drivers within 8km, Firestore index missing, backend error
- **Execution problem?** Many orders stuck in "accepted" or "on_route" (not completing)?
  - Likely cause: Driver GPS loss, driver abandoning orders, navigation issues

**Step 3: Immediate Mitigation (15 minutes)**

Based on diagnosis:

**If supply problem (no drivers online):**
```
Action: Call top 5 most active drivers
Script: "Hi [Driver Name], this is WawApp operations. We noticed
you haven't been online today. Is everything OK with the app?
Can you go online now? We have clients waiting for deliveries."

Goal: Get at least 3 drivers online within 30 minutes.
```

**If matching problem (orders stuck in "assigning"):**
```
Action: Admin manually cancels stuck orders + calls clients
1. Admin dashboard → Orders → Filter "Assigning" → Sort by oldest
2. For each order stuck >15 minutes:
   - Click cancel button → Enter reason: "No drivers available"
   - Call client immediately (see template in Section 3)
```

**If execution problem (drivers not completing orders):**
```
Action: Call assigned drivers
1. Admin dashboard → Live Ops → Click driver markers not moving
2. Call driver:
   "Hi [Driver], you have order #[ID] assigned. Are you having
   issues? Do you need help with navigation or GPS?"
3. If driver unresponsive (no answer after 2 calls):
   - Admin cancels order + calls client
   - Mark driver as "problematic" in notes
```

**Step 4: Escalate to Product Manager (Immediate)**

Send Slack/WhatsApp message:
```
🔴 CRITICAL: K1 Triggered - Completion Rate <50% for 2 Days

Day [N-1]: X/Y orders completed (Z%)
Day [N]: X/Y orders completed (Z%)

Root cause: [Supply/Demand/Matching/Execution problem]
Immediate action taken: [What you did in Step 3]
Current status: [X drivers online, Y active orders, Z stuck orders]

Decision needed: PAUSE pilot or continue with mitigation?
Call scheduled: [Time] - [Meeting link]
```

**Decision Owner:** Product Manager (must respond within 1 hour)

**Decision Options:**
- **Continue with intensive monitoring:** If root cause fixable quickly (e.g., called drivers, they're going online now)
- **PAUSE pilot:** If root cause unfixable in <24 hours (see Section 2 for pause procedure)

**Evidence to Collect:**
- Firestore export: All orders from last 48 hours (CSV)
- Firebase Crashlytics: Screenshots of crash-free rate (client + driver apps)
- Admin dashboard: Screenshot of Live Ops screen
- Driver call log: Who was called, what they said
- Google Sheets: Daily metrics log (last 3 days)

**Post-Incident:**
- Document in "PILOT_INCIDENT_LOG.md" (create if not exists)
- Update decision playbook with learnings

---

### **Incident K2: Zero Completed Orders for 24 Hours**

**Severity:** 🔴 CRITICAL – Complete marketplace failure

**Detection:**
- **Automated:** Google Sheets formula: `=COUNTIF(D:D,"completed")` where D=status filtered by date=today
- **Manual:** Admin dashboard "Completed Today" = 0 for entire day
- **Threshold:** If by 6:00 PM local time, completed orders = 0, trigger K2.

**Immediate Actions (Within 30 Minutes):**

**Step 1: Verify System Status (5 minutes)**
```
Check Firebase Console:
- [ ] Firebase Authentication: Any service outages? (Status Dashboard)
- [ ] Firestore: Can admin read/write data? (Try adding test document)
- [ ] Crashlytics: Are apps reporting data? (Check "Last active" timestamp)
- [ ] Analytics: Are events being logged? (Check Real-time view)

Check Admin Dashboard:
- [ ] Dashboard loads? (If not → backend down)
- [ ] Stats show zeros or error? (If error → Firestore connection issue)
```

**Step 2: Check Client & Driver Presence (10 minutes)**

```
Firebase Analytics → Real-time view:
- Client app: Any active users? (session_start events in last 1 hour)
- Driver app: Any active users?

Firestore → drivers collection:
- Query: online = true
- Count: How many drivers currently online?

Firestore → orders collection:
- Query: createdAt >= today
- Count: Were ANY orders created today?
```

**Diagnosis Matrix:**

| Condition | Likely Cause | Action |
|-----------|--------------|--------|
| No client app sessions + No orders created | All clients abandoned app | PAUSE pilot (fatal) |
| No driver app sessions + Zero drivers online | All drivers quit | PAUSE pilot (fatal) |
| Orders created but all stuck in "assigning" | Driver supply shortage OR backend matching failure | Call drivers urgently |
| No orders created but clients active | Critical bug in order creation flow | Check Crashlytics → PAUSE pilot |
| Backend errors (Firestore/Auth down) | Firebase service outage | Wait for Firebase resolution + inform users |

**Step 3: Emergency Response (15 minutes)**

**If backend issue (Firebase outage):**
```
1. Check Firebase Status Page: https://status.firebase.google.com/
2. If confirmed outage:
   - Post message to driver WhatsApp group (see Section 3 templates)
   - Send SMS to all clients (if SMS system available)
   - Wait for resolution, monitor every 30 minutes
3. If NOT outage → Check Firestore security rules (may have accidentally blocked all writes)
```

**If critical bug (app crashes on order creation):**
```
1. Firebase Crashlytics → Client app → Sort by "Crash rate" descending
2. Identify crash affecting >10% users
3. Screenshot crash stack trace
4. Immediately PAUSE pilot (see Section 2)
5. Emergency bug fix required (escalate to dev team)
```

**If client/driver abandonment:**
```
1. Call sample of 5 clients + 5 drivers
2. Ask: "Why haven't you used WawApp today?"
3. Document reasons
4. Escalate to Product Manager
5. Decision: PAUSE pilot for pivot
```

**Step 4: Escalate to Product Manager (Immediate)**

Send emergency alert:
```
🚨 EMERGENCY: K2 Triggered - Zero Orders Completed in 24 Hours

System Status:
- Firebase: [UP/DOWN]
- Client DAU today: [X users]
- Driver DAU today: [X users]
- Orders created today: [X]
- Orders completed today: 0

Root cause: [Diagnosis from Step 2]
Action taken: [What you did in Step 3]

RECOMMENDATION: PAUSE PILOT IMMEDIATELY
Emergency call: [Start immediately - conference line]
```

**Decision Owner:** Product Manager + Founder/CEO (joint decision)

**Decision Options:**
- **PAUSE pilot immediately:** Default action (99% of scenarios)
- **Wait for Firebase resolution:** Only if confirmed Firebase outage + ETA <2 hours

**Evidence to Collect:**
- Full Firestore export (all collections: orders, drivers, clients)
- Crashlytics full report (all crashes in last 24 hours)
- Firebase Analytics export (all events in last 24 hours)
- Screenshots: Admin dashboard, Firebase Console status pages
- User call logs: Transcribe reasons for non-usage

---

### **Incident K3: Crash-Free Rate < 95% in Any App**

**Severity:** 🔴 CRITICAL – Apps unusable for significant user percentage

**Detection:**
- **Automated:** Firebase Crashlytics → Dashboard → "Crash-free users" metric
- **Manual:** Check daily at 9:00 AM + 6:00 PM
- **Threshold:** If crash-free users <95% (i.e., ≥5% of users experiencing crashes), trigger K3.

**Immediate Actions (Within 30 Minutes):**

**Step 1: Identify Crash Type (5 minutes)**

```
Firebase Crashlytics → [Client or Driver app] → Issues tab

Sort by: "Impacted users" descending

Top crash shows:
- Issue title: [e.g., "NullPointerException in OrderService"]
- Impacted users: [e.g., "15 users (8%)"]
- Events: [e.g., "42 crashes"]
- First seen: [Date/time]
- Latest event: [Date/time]

Click crash → Stack trace tab
```

**Step 2: Classify Severity (5 minutes)**

| Crash Location | Impact | Action Priority |
|----------------|--------|-----------------|
| Auth flow (login, OTP, PIN) | **FATAL** – Users cannot login | PAUSE pilot immediately |
| Order creation (quote screen, submit button) | **FATAL** – Clients cannot order | PAUSE pilot immediately |
| Order acceptance (driver nearby screen) | **FATAL** – Drivers cannot accept | PAUSE pilot immediately |
| Tracking screen | **HIGH** – Tracking broken, but order flows work | Fix ASAP, may continue pilot |
| Profile/Settings screen | **MEDIUM** – Non-critical feature | Log for v2, continue pilot |
| Analytics logging | **LOW** – User-facing flow unaffected | Ignore for pilot |

**Step 3: Immediate Mitigation (10 minutes)**

**If FATAL crash (auth/order creation/acceptance):**
```
1. PAUSE pilot immediately (see Section 2)
2. Screenshot crash stack trace
3. Send to dev team with subject: "🚨 CRITICAL CRASH - PILOT PAUSED"
4. Inform users (see Section 3 communication templates)
5. Wait for hotfix (target: <24 hours)
```

**If HIGH crash (tracking screen):**
```
1. Document crash details (stack trace, reproduction steps if known)
2. Continue pilot BUT:
   - Add note to daily standup: "Known issue: tracking may crash"
   - Train admin team: If client calls saying "app crashed while tracking",
     provide public tracking link as workaround:
     https://wawapp.com/track/[ORDER_ID]
3. Send to dev team with subject: "HIGH PRIORITY - Fix needed before Day 7"
```

**If MEDIUM/LOW crash:**
```
1. Log in "PILOT_KNOWN_ISSUES.md"
2. Continue pilot (no action needed)
3. Include in weekly review for v2 prioritization
```

**Step 4: Root Cause Investigation (10 minutes)**

Check Crashlytics tabs:
- **Logs tab:** What was user doing before crash? (if available)
- **Keys tab:** Custom keys logged (e.g., orderId, userId)
- **State tab:** Device info (Android version, RAM, network)

Common patterns:
- Crash on **specific Android version** (e.g., Android 11 only) → OS compatibility issue
- Crash on **low-end devices** (e.g., <2GB RAM) → Memory issue
- Crash on **poor network** (e.g., mobile data, not WiFi) → Timeout/retry issue
- Crash on **specific user action** (e.g., tapping button rapidly) → Race condition

**Step 5: Escalate to Product Manager + Dev Lead**

```
🔴 CRITICAL: K3 Triggered - Crash Rate >5%

App: [Client / Driver / Admin]
Crash title: [From Crashlytics]
Impacted users: [X users (Y%)]
Crash location: [Auth / Order Creation / Tracking / etc.]

Severity: [FATAL / HIGH / MEDIUM / LOW]
Action taken: [Paused pilot / Continuing with workaround / Logged for v2]

Stack trace: [Paste first 20 lines or attach screenshot]
Reproduction steps: [If known]

Dev team: Hotfix needed? ETA?
Decision: [PAUSE / CONTINUE / CONDITIONAL]
```

**Decision Owner:** Product Manager + Dev Lead (joint decision)

**Decision Options:**
- **PAUSE + Hotfix:** If FATAL crash (default for auth/order flows)
- **Continue with workaround:** If HIGH crash with manual mitigation available
- **Continue + Log for v2:** If MEDIUM/LOW crash

**Evidence to Collect:**
- Crashlytics full report (export to file if possible)
- Screenshots: Crash details, stack trace, affected devices
- User reports: If any users called/messaged about the crash
- Reproduction video: If crash reproducible, record screen capture

---

### WARNING INCIDENTS (24-Hour Investigation Period)

---

### **Incident K4: Driver Utilization < 20% for 3 Consecutive Days**

**Severity:** 🟡 WARNING – Driver churn risk, economics broken

**Detection:**
- **Manual:** Daily metrics Google Sheet
- Formula: `=(Drivers with ≥1 completed order today / Drivers online today) × 100%`
- **Threshold:** If <20% for Day N, Day N+1, Day N+2 → Trigger K4 on Day N+2 evening

**Immediate Actions (Within 24 Hours):**

**Step 1: Verify Data (1 hour)**

```
Firestore export:
1. drivers collection → Filter: onlineAt >= [Day N] → Export CSV
2. orders collection → Filter: status = "completed" AND completedAt >= [Day N] → Export CSV
3. Cross-reference: How many unique driver IDs appear in completed orders vs online drivers?

Example:
- Day N: 20 drivers online, 3 drivers completed orders → 15% utilization
- Day N+1: 18 drivers online, 4 drivers completed orders → 22% utilization (FALSE ALARM)
- Day N+2: 15 drivers online, 2 drivers completed orders → 13% utilization

Confirm: Is utilization consistently <20%?
```

**Step 2: Diagnose Root Cause (2 hours)**

**Hypothesis A: Not enough orders (demand shortage)**
```
Check:
- Client DAU trend (decreasing?)
- Orders created per day (decreasing?)
- Client funnel: Are clients opening app but not ordering?

If TRUE:
  Root cause = Demand shortage
  Action = Client acquisition (see Step 3A)
```

**Hypothesis B: Orders going to few "power drivers"**
```
Check:
- In completed orders CSV, count orders per driver
- Are 80% of orders completed by 20% of drivers?

If TRUE:
  Root cause = Geographic concentration (orders in one area, most drivers elsewhere)
  Action = Rebalance driver recruitment (see Step 3B)
```

**Hypothesis C: Drivers going online but immediately offline (giving up)**
```
Check:
- In drivers CSV, calculate: avg time between "went online" and "went offline"
- If <30 minutes → Drivers trying but quitting quickly

If TRUE:
  Root cause = Poor driver experience (not seeing orders, GPS issues)
  Action = Driver interviews (see Step 3C)
```

**Step 3: Mitigation Actions (Based on Root Cause)**

**Action 3A: Demand Shortage → Client Acquisition Push**
```
Timeline: 48 hours
Owner: Growth Lead

Tasks:
1. Social media push:
   - Post "Special offer: First 5 deliveries this week" (if budget allows incentive)
   - Share in local Facebook groups, WhatsApp groups
   - Target audience: Small businesses, busy professionals

2. Flyer distribution:
   - Print 100 flyers with QR code to download app
   - Distribute in high-traffic areas (markets, cafes, offices)
   - Staff: Admin team members (2 hours each)

3. Referral incentive (manual):
   - Call top 10 most active clients
   - Offer: "Invite 3 friends, get 1 free delivery"
   - Track referrals manually in Google Sheet

Target: Increase client DAU by 30% within 48 hours
Measure: Client DAU Day N+4 vs Day N+2
```

**Action 3B: Geographic Rebalancing → Driver Recruitment**
```
Timeline: 72 hours
Owner: Ops Lead

Tasks:
1. Identify underserved areas:
   - Export all completed orders CSV
   - Map pickup locations (use Google My Maps or manual plotting)
   - Find areas with high order density but no nearby drivers

2. Recruit drivers in those areas:
   - Visit driver waiting spots in underserved areas (e.g., taxi stands, moto-taxi hubs)
   - Pitch WawApp: "Earn money with deliveries in [Area Name]"
   - On-the-spot onboarding (create account, verify profile, test order)

Target: Onboard 5-10 new drivers in underserved areas
Measure: Driver utilization Day N+5 (should increase to >25%)
```

**Action 3C: Driver Experience Issues → Interviews + Training**
```
Timeline: 24 hours
Owner: Ops Lead

Tasks:
1. Call 10 drivers (mix of active + inactive):
   Script:
   "Hi [Driver], this is WawApp ops. We noticed you went online
   recently but didn't complete orders. Can you tell me why?
   - Did you see any orders in the Nearby Orders screen?
   - Did you have issues with GPS or app crashes?
   - Were the orders too far away or pricing too low?"

2. Document responses in "DRIVER_FEEDBACK.md"

3. Common issues → Immediate fixes:
   - "I didn't see any orders" → Check Firestore composite index (matching query may be failing)
   - "GPS not working" → Send step-by-step GPS troubleshooting guide via WhatsApp
   - "Orders too far" → Review 8km radius, consider increasing to 12km
   - "Pricing too low" → Escalate to Product Manager (pricing adjustment decision)

4. Send training video/guide:
   - WhatsApp message to driver group: "How to use WawApp driver app"
   - Cover: Going online, finding nearby orders, accepting orders, using GPS

Target: 80% of interviewed drivers go back online within 24 hours
Measure: Driver online count Day N+3
```

**Step 4: Report to Product Manager (End of Day N+2)**

```
🟡 WARNING: K4 Triggered - Driver Utilization <20% for 3 Days

Day N: [X/Y drivers utilized = Z%]
Day N+1: [X/Y drivers utilized = Z%]
Day N+2: [X/Y drivers utilized = Z%]

Root cause analysis: [Demand shortage / Geographic / Driver experience]
Mitigation launched: [Action 3A / 3B / 3C]
Owner: [Name]
Timeline: [48-72 hours]
Target metric: [Specific improvement expected]

Next check: Day N+4 morning standup
Decision: Continue pilot with intensive monitoring
```

**Decision Owner:** Ops Lead (can act independently, report to PM)

**Evidence to Collect:**
- Drivers CSV export (online timestamps)
- Orders CSV export (completed orders by driver)
- Driver call logs (interview responses)
- Screenshots: Admin dashboard utilization trend

---

### **Incident K5: Average Assignment Time > 10 Minutes (Median) for 2+ Days**

**Severity:** 🟡 WARNING – Client experience unacceptable

**Detection:**
- **Manual:** Daily metrics Google Sheet
- Calculation: For each order, `assignment_time = acceptedAt - createdAt` (minutes), then `MEDIAN(assignment_time)`
- **Threshold:** If median >10 minutes for Day N and Day N+1 → Trigger K5 on Day N+1 evening

**Immediate Actions (Within 24 Hours):**

**Step 1: Identify Stuck Orders (1 hour)**

```
Firestore export:
1. orders collection → Filter: status = "assigning" (stuck orders)
2. For each stuck order:
   - Order ID
   - Created timestamp
   - Pickup location
   - Time stuck (current time - created)

Sort by: Time stuck descending

Admin dashboard → Live Ops:
- Check "Unassigned Orders" count
- Check "Anomalies" (orders stuck >10 min)
```

**Step 2: Root Cause Analysis (1 hour)**

**Check A: Are there enough online drivers?**
```
Firestore → drivers collection → Count: online = true

Benchmark:
- <5 drivers online → CRITICAL supply shortage
- 5-10 drivers online → MODERATE supply shortage
- >10 drivers online → Supply OK, matching issue

If <5 drivers:
  Root cause = Supply shortage
  Action = Emergency driver recruitment (call all registered drivers)
```

**Check B: Are drivers too far from orders?**
```
Manual check:
1. Admin dashboard → Live Ops → Map view
2. Look at blue markers (online drivers) vs red markers (unassigned orders)
3. Visually assess: Are drivers within 8km of orders?

If drivers clustered in one area, orders in another:
  Root cause = Geographic mismatch
  Action = Call drivers, ask them to relocate to order-dense areas
```

**Check C: Is Firestore composite index working?**
```
Check Firebase Console → Firestore → Indexes:
- Required index for driver matching query:
  Collection: orders
  Fields: status (Ascending), location (Geohash - if using), createdAt (Ascending)

If index status = "Building" or "Error":
  Root cause = Backend matching failure
  Action = Wait for index build OR disable geolocation matching temporarily
```

**Step 3: Immediate Mitigation**

**Mitigation A: Emergency Driver Calls (Supply Shortage)**
```
Timeline: 2 hours
Owner: Admin team (all hands)

Tasks:
1. Export driver list (phone numbers)
2. Call ALL registered drivers (even inactive):
   Script:
   "Hi [Driver], WawApp ops here. We have many clients waiting
   for deliveries right now. Can you go online immediately?
   Guaranteed orders for the next 2 hours."

3. Offer temporary incentive (if approved by PM):
   "Bonus: Complete 3 orders in next 2 hours, earn extra 50 MRU."

Target: Get 10+ drivers online within 1 hour
```

**Mitigation B: Manual Order Assignment (Geographic Mismatch)**
```
Timeline: Continuous (admin intensive)
Owner: Admin team lead

Process:
1. Admin dashboard → Live Ops → Identify stuck order
2. Look at map: Find nearest online driver (even if >8km)
3. Call driver:
   "Hi [Driver], can you accept order #[ID]? Pickup at [Address].
   I'll send you the details. Please check your Nearby Orders screen now."
4. If driver agrees, guide them:
   "Open app → Nearby Orders → You should see it. Tap Accept."
5. If driver doesn't see order (Firestore index issue):
   "Don't worry, I'll assign it manually."
   → Admin uses Firestore Console → orders → [order_id] →
     Edit field: assignedDriverId = [driver_id], status = "accepted"

Repeat for all stuck orders.
```

**Mitigation C: Reduce Matching Radius (Temporary)**
```
Timeline: 1 hour (code change + deploy)
Owner: Dev team (emergency)

Change:
- In driver app NearbyScreen, increase radius from 8km → 15km
- Deploy hotfix to driver app (via Firebase App Distribution or Play Store)

Risk: Drivers may see orders too far away, leading to long pickup times
Monitoring: Track actual pickup distances, revert if >15km orders appearing
```

**Step 4: Report to Product Manager**

```
🟡 WARNING: K5 Triggered - Assignment Time >10 min for 2 Days

Day N: Median assignment time [X] minutes
Day N+1: Median assignment time [X] minutes

Stuck orders right now: [X orders in "assigning" status]
Online drivers right now: [X drivers]

Root cause: [Supply shortage / Geographic mismatch / Index issue]
Mitigation: [A / B / C - describe action taken]
Owner: [Name]
Status: [In progress / Completed]

Next check: Day N+2 morning (expect improvement to <10 min)
Decision: Continue pilot with manual coordination
```

**Decision Owner:** Ops Lead (can act, must inform PM)

**Evidence to Collect:**
- Orders CSV (all orders with assignment times)
- Screenshots: Live Ops map (driver vs order positions)
- Firebase Console: Firestore indexes status
- Driver call log: Who was called, response

---

### **Incident K6: Client DAU Drops > 50% (Day 1 → Day 7)**

**Severity:** 🟡 WARNING – Client retention catastrophic

**Detection:**
- **Manual:** Compare Firebase Analytics DAU Day 1 vs Day 7
- Formula: `(Day_7_DAU - Day_1_DAU) / Day_1_DAU × 100%`
- **Threshold:** If drop >50% (e.g., 30 clients Day 1 → <15 clients Day 7) → Trigger K6

**Immediate Actions (Within 24 Hours):**

**Step 1: Validate Data (30 minutes)**

```
Firebase Analytics → Dashboards → Active Users:
- Filter: user_type = 'client'
- Date range: Day 1 (launch day) vs Day 7

Confirm:
- Day 1 DAU: [X users]
- Day 7 DAU: [Y users]
- Drop: [(Y-X)/X] = [Z%]

Check for data anomalies:
- Is Day 7 a weekend? (Lower usage expected)
- Was there a Firebase outage on Day 7? (Check status page)
- Are we counting test users? (Exclude test UIDs)
```

**Step 2: User Interview Campaign (4 hours)**

```
Owner: Ops + Growth leads
Timeline: Complete within 24 hours

Sample selection:
1. Export client list from Firestore (clients collection)
2. Segment:
   - Active users (used app Day 6-7): 5 users
   - Churned users (used app Day 1-2, not since): 10 users
   - Never ordered (opened app but never created order): 5 users

Interview script:
For CHURNED users:
"Hi [Name], this is WawApp team. You tried our delivery app on
[Date] but haven't used it since. Can I ask why?
- Was the app confusing or hard to use?
- Was the pricing too high?
- Did you have a bad experience with a delivery?
- Are you using a competitor instead?"

For NEVER ORDERED:
"Hi [Name], you downloaded WawApp but didn't order. What stopped you?
- Did you have trouble setting pickup/dropoff locations?
- Did the pricing seem unclear or too expensive?
- Did the app crash or show errors?"

Document responses in "CLIENT_CHURN_FEEDBACK.md"
```

**Step 3: Root Cause Categorization (1 hour)**

After interviews, classify feedback:

**Category A: UX Friction (app too hard to use)**
```
Symptoms:
- "I couldn't figure out how to set my location"
- "The map was confusing"
- "I didn't understand the pricing"

Action:
- Create 1-page "How to Use WawApp" guide with screenshots
- Send via WhatsApp to all clients
- Offer "Assisted order" service: "Call us, we'll create the order for you"
```

**Category B: Pricing Objection (too expensive)**
```
Symptoms:
- "100 MRU is too much for short distances"
- "Competitor charges 80 MRU for same route"
- "I can take a taxi for less"

Action:
- Price comparison analysis (competitors vs WawApp)
- Escalate to Product Manager: Pricing adjustment needed?
- Temporary promo: "50% off next order" (if approved)
```

**Category C: Bad Experience (service quality)**
```
Symptoms:
- "Driver took 30 minutes to arrive"
- "Driver couldn't find my location"
- "My package was damaged"

Action:
- Driver training: Navigation, GPS usage, handling packages
- Implement "satisfaction callback": Call client after delivery to ensure OK
- Offer compensation for bad experiences (free delivery coupon)
```

**Category D: Competitor Preference (market loss)**
```
Symptoms:
- "I'm using [Competitor] now, they're faster/cheaper/better"
- "My friends all use [Competitor]"

Action:
- Competitive analysis: What does competitor do better?
- Decision: Can we match their offering in pilot? Or accept niche position?
- Escalate to Product Manager: Pivot strategy?
```

**Step 4: Retention Campaign (48 hours)**

```
Owner: Growth Lead
Timeline: Launch within 48 hours

Campaign elements:
1. Re-engagement SMS/WhatsApp:
   "Hi [Name], we miss you! Get 30% off your next WawApp delivery.
   Valid for 48 hours. Download: [link]"

2. Personalized outreach:
   - For clients who had 1 successful order:
     "Hi [Name], you ordered from [Address] on [Date]. Need another delivery?"
   - For clients who never ordered:
     "Hi [Name], first delivery free! Let us show you how easy it is."

3. Referral bonus:
   - Active clients: "Invite a friend, both get 20% off next order"

Target: Reactivate 30% of churned users within 48 hours
Measure: Client DAU Day 9 vs Day 7
```

**Step 5: Report to Product Manager**

```
🟡 WARNING: K6 Triggered - Client DAU Dropped >50%

Day 1 DAU: [X clients]
Day 7 DAU: [Y clients]
Drop: [Z%]

User interviews completed: [N users]
Churn reasons (top 3):
1. [Category A/B/C/D - % of responses]
2. [Category A/B/C/D - % of responses]
3. [Category A/B/C/D - % of responses]

Retention campaign launched:
- [Campaign element 1]
- [Campaign element 2]
- [Campaign element 3]

Target: Reactivate [N] clients by Day 9
Next check: Day 9 morning standup

Decision: [Continue pilot / Conditional / Recommend pause]
```

**Decision Owner:** Growth Lead + Product Manager (joint)

**Evidence to Collect:**
- Firebase Analytics DAU trend (screenshot)
- Client interview transcripts (CLIENT_CHURN_FEEDBACK.md)
- Competitor pricing comparison (spreadsheet)
- Retention campaign messages (copies of SMS/WhatsApp sent)

---

### **Incident K7: Driver DAU Drops > 50% (Day 1 → Day 7)**

**Severity:** 🟡 WARNING – Driver churn catastrophic

**Detection:**
- **Manual:** Compare Firebase Analytics DAU Day 1 vs Day 7
- Filter: user_type = 'driver'
- **Threshold:** If drop >50% → Trigger K7

**Immediate Actions (Within 24 Hours):**

**Step 1: Validate + Segment Drivers (1 hour)**

```
Firestore export:
1. drivers collection → All documents
2. Segment by activity:
   - Active: Went online Day 6-7
   - Churned: Went online Day 1-3, not since
   - Never worked: Registered but never went online OR went online but never completed order

Calculate earnings per driver (from orders collection):
- Group by assignedDriverId
- Sum price field
- Sort descending

Identify:
- Top earners (>500 MRU in 7 days) - Why are they still active?
- Zero earners (0 MRU) - Why did they quit without trying?
- Low earners (1-2 orders, <200 MRU) - Why did they try once and quit?
```

**Step 2: Driver Interview Campaign (4 hours)**

```
Owner: Ops Lead
Timeline: Complete within 24 hours

Sample:
- Active drivers (still going online): 3 interviews
- Churned drivers (quit): 10 interviews
- Zero-earner drivers: 5 interviews

Script for CHURNED:
"Hi [Driver Name], this is WawApp ops. We noticed you haven't been
online since [Date]. Can you tell me why you stopped?
- Not enough orders?
- Earnings too low?
- App issues (GPS, crashes, navigation)?
- Prefer working with competitor platform?
- Personal reasons (busy, vehicle issues)?"

Script for ACTIVE (to understand what works):
"Hi [Driver Name], thank you for staying active with WawApp!
What do you like about the platform?
What could we improve to help you earn more?"

Document in "DRIVER_CHURN_FEEDBACK.md"
```

**Step 3: Root Cause Categorization**

**Category A: Low Earnings (not enough orders)**
```
Symptoms:
- "I went online for 2 hours, got zero orders"
- "I completed 1 order in 3 days, not worth my time"
- "Too many drivers, not enough work"

Action:
- Reduce driver count (stop new driver onboarding temporarily)
- OR increase client acquisition (marketing push)
- OR offer guaranteed minimum: "Next 5 drivers to go online get guaranteed 3 orders"
```

**Category B: App Issues (UX/GPS problems)**
```
Symptoms:
- "GPS never works, I can't see nearby orders"
- "App crashes when I try to accept orders"
- "I don't understand how to use the app"

Action:
- GPS troubleshooting guide (WhatsApp distribution)
- Check Crashlytics for driver app crashes
- 1-on-1 training session (in-person or video call)
```

**Category C: Competitor Preference**
```
Symptoms:
- "I drive for [Competitor], they pay better"
- "Competitor has more orders"

Action:
- Competitive pricing analysis
- Decision: Can we match competitor rates? (escalate to PM)
- Highlight WawApp advantages: "Lower commission, faster payments"
```

**Category D: Personal/External Reasons**
```
Symptoms:
- "My motorcycle broke down"
- "I got a full-time job"
- "Family issues"

Action:
- Accept churn (unavoidable)
- Offer: "When you're ready to return, call us, we'll reactivate you"
```

**Step 4: Driver Retention Campaign**

```
Timeline: 48 hours
Owner: Ops Lead

Elements:
1. Earnings boost incentive:
   "Complete 5 orders this week, earn 100 MRU bonus"
   (Manual tracking via Firestore, payment via mobile money)

2. Re-onboarding session:
   - In-person or video call
   - Walk through app: Going online, seeing orders, navigation
   - Answer questions
   - Test order together

3. Driver community building:
   - Create WhatsApp group for active drivers
   - Share daily tips: "Best times to go online", "High-demand areas"
   - Peer support: Experienced drivers help new ones

4. Personal check-in:
   - Call each churned driver individually
   - "We value you. What can we do to bring you back?"

Target: Reactivate 40% of churned drivers by Day 9
Measure: Driver DAU Day 9 vs Day 7
```

**Step 5: Report to Product Manager**

```
🟡 WARNING: K7 Triggered - Driver DAU Dropped >50%

Day 1 DAU: [X drivers]
Day 7 DAU: [Y drivers]
Drop: [Z%]

Driver segments:
- Active (still online): [X drivers, avg earnings Y MRU]
- Churned (quit): [X drivers, avg earnings Y MRU before quitting]
- Never worked: [X drivers]

Churn reasons (top 3):
1. [Low earnings - % of interviews]
2. [App issues - % of interviews]
3. [Competitor / Personal - % of interviews]

Retention campaign launched:
- Earnings boost incentive
- Re-onboarding sessions scheduled: [N drivers]
- WhatsApp community created

Target: Reactivate [N] drivers by Day 9
Next check: Day 9 morning

Decision: [Continue pilot / Recommend pause if churn root cause = fundamental economics]
```

**Decision Owner:** Ops Lead + Product Manager

**Evidence to Collect:**
- Driver earnings analysis (CSV with driver_id, total_earned, orders_completed)
- Driver interview transcripts
- Competitor analysis (what they offer vs WawApp)
- Retention campaign materials (WhatsApp messages, incentive details)

---

## 2. Pilot Pause Procedure

**When to Execute:** Triggered by K1, K2, K3 (critical incidents) OR Product Manager decision

**Timeline:** Complete within 2 hours of pause decision

**Owner:** Ops Lead (executes), Product Manager (authorizes)

---

### **Phase 1: Immediate Service Shutdown (30 minutes)**

**Step 1: Stop New Orders (10 minutes)**

```
Option A: Backend flag (if available):
- Firebase Console → Firestore → Create document:
  Collection: system_config
  Document ID: pilot_status
  Field: enabled = false

- Client app checks this flag before allowing "Request Now" button
- If enabled=false, show: "Service temporarily unavailable. We'll be back soon."

Option B: Manual coordination (if no backend flag):
- Admin team posts in client WhatsApp groups:
  "⚠️ WawApp service paused for maintenance.
  Please do not create new orders for next 2 hours.
  We'll notify when service resumes."

- Admin monitors Firestore for new orders being created
- If new order appears → Admin calls client immediately to cancel + apologize
```

**Step 2: Set All Drivers Offline (10 minutes)**

```
Firestore Console → drivers collection:
1. Batch update all documents:
   - Field: online = false
   - Field: pausedByAdmin = true (for tracking)
   - Field: pausedAt = [current timestamp]

2. OR if manual:
   - Export driver phone numbers
   - Send WhatsApp message (see Section 3 template)
   - Call drivers who don't respond within 5 minutes

Verification:
- Admin dashboard → Live Ops → Map should show zero blue markers (no online drivers)
```

**Step 3: Handle Active Orders (10 minutes)**

```
Firestore → orders collection → Query:
- status IN ["assigning", "accepted", "on_route"]

For each active order:
1. If status = "assigning" (no driver assigned yet):
   - Admin cancels order
   - Call client (see Section 3 communication template)

2. If status = "accepted" or "on_route" (driver en route):
   - Call driver: "Please complete this delivery, then go offline.
     No new orders after this one."
   - Let driver finish current delivery
   - DO NOT cancel (would hurt client experience)
   - Monitor until status = "completed"

Timeline: Wait up to 30 minutes for in-progress deliveries to complete
If any order not completed after 30 min → Escalate to driver (call again)
```

---

### **Phase 2: User Communication (30 minutes)**

**Step 1: Notify All Clients (15 minutes)**

```
Method: WhatsApp broadcast + SMS (if available)

Message: (See Section 3 for full template)
"Dear WawApp user, we are temporarily pausing service for technical
improvements. We apologize for any inconvenience. We will notify you
when service resumes. Thank you for your patience."

Delivery:
- WhatsApp: Broadcast to all client phone numbers
- SMS: Send via SMS gateway (if configured)
- In-app: Update banner in client app (if dynamic content enabled)

Track:
- Mark timestamp of notification sent
- Log in PILOT_INCIDENT_LOG.md
```

**Step 2: Notify All Drivers (15 minutes)**

```
Method: WhatsApp group + individual messages

Message: (See Section 3 for template)
"WawApp drivers: Service is paused for 24-48 hours for system improvements.
Please do not go online. We will notify you when to resume.
Your earnings are safe and will be paid as scheduled."

Delivery:
- Post in driver WhatsApp group
- Send individual message to each driver (if group not sufficient)
- Call top 10 most active drivers personally (to ensure they understand)

Response handling:
- Monitor WhatsApp for driver questions
- Common Q: "When will service resume?"
  A: "We'll notify you within 48 hours. Thank you for your patience."
- Common Q: "Will I still get paid?"
  A: "Yes, all earnings earned before pause will be paid on schedule."
```

---

### **Phase 3: Internal Coordination (30 minutes)**

**Step 1: Admin Team Brief (10 minutes)**

```
Emergency call or Slack message to all admin team members:

Subject: 🚨 PILOT PAUSED - All Hands Briefing

Summary:
- Pilot paused at [Time]
- Reason: [K1/K2/K3 triggered - brief description]
- All drivers set offline
- Active orders: [X orders in progress, expected completion by [Time]]
- Users notified: [Y clients, Z drivers]

Next steps:
- Evidence collection (Phase 4)
- Root cause analysis (within 24 hours)
- Decision meeting: [Scheduled time - within 48 hours]

Admin responsibilities until resume:
- Monitor Firestore for any new orders (should be zero)
- Answer client/driver calls (use templates in Section 3)
- Update Daily Metrics Log (mark Day X as "PAUSED")

Stand down: Do NOT create new orders or reactivate drivers without PM approval
```

**Step 2: Stakeholder Notification (10 minutes)**

```
Email to:
- Product Manager
- Founder/CEO
- Dev team lead
- Any investors or board members (if applicable)

Subject: WawApp Pilot PAUSED - Emergency Update

Body:
Dear [Name],

The WawApp v1 pilot has been paused as of [Time] due to [Incident Type].

Incident: [K1/K2/K3/etc. - brief summary]
Impact: [X clients affected, Y drivers affected]
Root cause: [Preliminary diagnosis]

Actions taken:
- All new orders stopped
- All drivers set offline
- Active deliveries completed
- Users notified

Next steps:
- Evidence collection (complete by [Time])
- Root cause analysis (complete by [Time + 24h])
- Decision meeting: [Date/Time] - [Meeting link]

Status: PAUSED (not shut down)
Resume ETA: [24-72 hours / TBD]

I will provide updates every 12 hours until resolution.

Regards,
[Ops Lead Name]
```

**Step 3: Public Communication (10 minutes - if needed)**

```
IF pilot is public-facing (social media, website):

Post on:
- WawApp Facebook page
- WawApp Twitter/X
- Website banner

Message:
"WawApp service is temporarily unavailable for system improvements.
We apologize for the inconvenience and will be back soon.
Follow us for updates."

DO NOT:
- Over-explain the technical issue
- Promise specific resume date (unless certain)
- Blame users or drivers

Keep tone: Professional, apologetic, confident in resolution
```

---

### **Phase 4: Evidence Collection (30 minutes)**

**Step 1: Firestore Exports**

```
Firebase Console → Firestore:

Export collections (as JSON or CSV):
1. orders (all documents, all fields)
2. drivers (all documents, all fields)
3. clients (all documents, all fields)
4. system_logs (if exists)

Save to:
- Google Drive folder: "WawApp_Pilot_Pause_[Date]"
- Local backup (encrypted USB drive or secure laptop folder)

File naming:
- orders_export_[YYYY-MM-DD_HH-MM].csv
- drivers_export_[YYYY-MM-DD_HH-MM].csv
- clients_export_[YYYY-MM-DD_HH-MM].csv
```

**Step 2: Crashlytics Reports**

```
Firebase Console → Crashlytics:

For each app (client, driver, admin):
1. Issues tab → Export:
   - Top 10 crashes by impacted users
   - Stack traces
   - Device info

2. Dashboard → Screenshot:
   - Crash-free users % (last 7 days)
   - Total crashes (last 7 days)

Save to: Same Google Drive folder
```

**Step 3: Analytics Exports**

```
Firebase Analytics:

1. Events tab → Export:
   - order_created count (last 7 days)
   - order_accepted_by_driver count
   - order_completed_by_driver count
   - driver_went_online count
   - session_start count (segmented by user_type)

2. Audience tab → Screenshot:
   - DAU trend (last 7 days, client vs driver)
   - User retention cohort (Day 1 cohort)

Save to: Same Google Drive folder
```

**Step 4: Admin Dashboard Snapshots**

```
Admin Dashboard → Take screenshots:
1. Dashboard home (stats summary)
2. Live Ops map (final state before pause)
3. Orders table (filter: last 24 hours)
4. Drivers table (showing online/offline status)

Annotate screenshots:
- Timestamp
- Key metrics visible
- Any anomalies (highlight in red)

Save to: Google Drive folder
```

**Step 5: Daily Metrics Log**

```
Google Sheets → Daily Metrics Log:

Fill in Day X (pause day) row:
- Client DAU: [from Analytics]
- Driver DAU: [from Analytics]
- Orders Created: [from Firestore]
- Orders Completed: [from Firestore]
- Completion Rate: [calculated]
- Assignment Time: [calculated from order timestamps]
- Driver Utilization: [calculated]
- Kill Signals: [List which ones triggered]
- Notes: "PILOT PAUSED - [Incident type] - [Time]"

Export Google Sheet as PDF:
- Save to Google Drive folder
```

---

### **Phase 5: Pilot Pause Checklist Verification**

**Before declaring pause complete, verify:**

- [ ] No new orders being created (Firestore check)
- [ ] All drivers marked offline (Firestore + Admin dashboard check)
- [ ] Active deliveries completed (or escalated if stuck)
- [ ] Clients notified (WhatsApp/SMS sent, logged)
- [ ] Drivers notified (WhatsApp group + individual messages sent)
- [ ] Admin team briefed (Slack/call completed)
- [ ] Stakeholders notified (email sent)
- [ ] Evidence collected (all exports + screenshots saved to Google Drive)
- [ ] Daily Metrics Log updated (pause marked)
- [ ] PILOT_INCIDENT_LOG.md updated (incident documented)
- [ ] Decision meeting scheduled (within 48 hours, calendar invite sent)

**Pause Status:** COMPLETE at [Time]

**Next action:** Root cause analysis (24-hour deadline)

---

## 3. Communication Templates

### 3.1 Client Messages

**Template C1: Order Cancelled Due to Pause**

```
Channel: Phone call (required for all cancelled orders)

Script:
"Hello [Client Name], this is [Your Name] from WawApp calling about
order #[Order ID].

I'm sorry to inform you that we had to cancel your delivery order
because we are temporarily pausing our service for technical improvements.

I sincerely apologize for the inconvenience. We will notify you by
WhatsApp when service resumes, likely within 24-48 hours.

[IF CLIENT ASKS: What about my urgent delivery?]
I understand this is urgent. Let me help you find an alternative.
[Suggest competitor service or taxi if appropriate]

Thank you for your patience and understanding."

After call:
- Log in Google Sheet: Client name, order ID, call time, client reaction
- If client very upset → Escalate to PM (may need compensation offer)
```

**Template C2: Pause Notification (WhatsApp/SMS)**

```
Channel: WhatsApp broadcast + SMS

Message:
"Dear WawApp customer,

We are temporarily pausing our delivery service for system improvements.

If you have an active order, your driver will complete it. For any
urgent needs, please contact us at [Support Phone].

We will notify you when service resumes (expected 24-48 hours).

Thank you for your patience.

- WawApp Team"

Tone: Apologetic but confident, no technical details
```

**Template C3: Pause Extended (if >48 hours)**

```
Channel: WhatsApp

Message:
"WawApp update:

Our service pause is taking longer than expected. We are working hard
to improve the platform for you.

New expected resume date: [Date]

We apologize for the extended delay. Your feedback is valuable - please
reply with any questions or concerns.

Thank you for your patience.

- WawApp Team"
```

---

### 3.2 Driver Messages

**Template D1: Pause Notification (WhatsApp Group)**

```
Channel: Driver WhatsApp group

Message:
"🚨 IMPORTANT NOTICE - All WawApp Drivers

Service is PAUSED effective immediately.

What this means:
✅ If you have an order right now, complete it
❌ Do NOT go online after completing current delivery
❌ Do NOT accept new orders

Why: System maintenance and improvements

Duration: 24-48 hours (we'll notify you)

Your earnings: SAFE. All payments will be made as scheduled.

Questions: Reply here or call [Ops Lead Phone]

Thank you for your cooperation.

- WawApp Operations Team"
```

**Template D2: Individual Driver Call (Active Drivers)**

```
Channel: Phone call to top 10 most active drivers

Script:
"Hi [Driver Name], this is [Your Name] from WawApp operations.

I'm calling to let you know we're pausing service for 24-48 hours
for system improvements.

Please do not go online during this time. We'll send a WhatsApp
message when you can resume.

[IF DRIVER HAS ACTIVE ORDER:]
Please complete your current delivery, then go offline. No new
orders after that.

[IF DRIVER ASKS: Why the pause?]
We're fixing some technical issues to make the platform better for
you. Your earnings are safe, and we'll be back soon.

[IF DRIVER ASKS: Will I still get paid?]
Yes, absolutely. All your earnings will be paid on schedule.

Thank you for your understanding. We appreciate your patience."

After call:
- Mark driver as "Notified" in tracking sheet
```

**Template D3: Resume Notification (When Service Restarts)**

```
Channel: WhatsApp group + individual messages

Message:
"🎉 WawApp is BACK ONLINE!

Dear drivers,

You can now GO ONLINE and start accepting orders.

What's new:
- [List any improvements made during pause, if applicable]
- [Any new instructions or changes]

Thank you for your patience during the pause. Let's get back to work!

Questions: Reply here or call [Ops Lead Phone]

- WawApp Operations Team"

Follow-up:
- Monitor driver online count (should return to 50%+ of pre-pause levels within 4 hours)
- Call drivers who don't go online after 4 hours (check if they received message)
```

---

### 3.3 Internal Admin Messages

**Template A1: Daily Standup During Pause**

```
Channel: Slack/WhatsApp admin team channel

Message (posted daily at 9:00 AM during pause):
"📊 WawApp Pilot - PAUSED - Day [X] Update

Status: Service remains paused
Duration: [X hours/days since pause began]

Progress on root cause fix:
✅ [Completed tasks]
🔄 [In progress tasks]
⏳ [Pending tasks]

Blocker: [Any issues delaying resume]
ETA for resume: [Date/Time OR TBD]

User communication:
- Clients: [X messages received, Y questions answered]
- Drivers: [X messages received, Y questions answered]

Decision meeting: [Today/Tomorrow at Time - Link]

Team actions today:
- [Task 1 - Owner]
- [Task 2 - Owner]

Questions or concerns → reply here

- [Ops Lead Name]"
```

**Template A2: Resume Decision Alert**

```
Channel: Email + Slack to all stakeholders

Subject: WawApp Pilot RESUME Decision - [GO / NO-GO]

Body:
"Decision: [GO - Service will resume / NO-GO - Pilot ends]

Date/Time of resume: [Specific timestamp]

Root cause identified: [Brief summary]
Fix applied: [What was changed]
Validation: [How we tested the fix]

Resume plan:
- Phase 1 ([Time]): Notify drivers, reopen driver app
- Phase 2 ([Time + 30min]): Notify clients, reopen client app
- Phase 3 ([Time + 1h]): Monitor first 10 orders closely

Monitoring plan post-resume:
- Hourly checks for first 24 hours
- Daily metrics tracked (same as before pause)
- Kill signals monitored (if any trigger again → immediate escalation)

All hands meeting: [Time] - [Link] (attendance required)

Questions → reply all

- [Product Manager Name]"
```

---

## 4. Evidence Collection Procedures

**When to Collect:** Immediately upon pause (Phase 4), AND after any critical incident (K1-K3)

**Owner:** Ops Lead + Admin team

**Storage Location:** Google Drive folder structure:
```
/WawApp_Pilot_Evidence/
  /Pause_[YYYY-MM-DD]/
    /Firestore_Exports/
    /Crashlytics_Reports/
    /Analytics_Screenshots/
    /Admin_Dashboard_Screenshots/
    /User_Feedback/
    /Call_Logs/
    /Daily_Metrics_Export/
```

---

### **Evidence Checklist**

**Firestore Data:**
- [ ] orders collection (all docs, CSV format)
- [ ] drivers collection (all docs, CSV format)
- [ ] clients collection (all docs, CSV format)
- [ ] Export timestamp logged

**Firebase Crashlytics:**
- [ ] Client app: Top 10 crashes (stack traces + device info)
- [ ] Driver app: Top 10 crashes
- [ ] Admin app: Top 10 crashes (if any)
- [ ] Crash-free users % screenshot (last 7 days)

**Firebase Analytics:**
- [ ] Event counts: order_created, order_accepted_by_driver, order_completed_by_driver
- [ ] DAU trend (client + driver, last 7 days)
- [ ] User retention cohort (Day 1 users)
- [ ] Export timestamp logged

**Admin Dashboard:**
- [ ] Dashboard home screenshot (stats summary)
- [ ] Live Ops map screenshot
- [ ] Orders table screenshot (last 24 hours)
- [ ] Drivers table screenshot

**Google Sheets (Manual Tracking):**
- [ ] Daily Metrics Log (export as PDF)
- [ ] Funnel Tracker (export as PDF)
- [ ] Kill Signals Tracker (export as PDF)

**User Feedback:**
- [ ] Client interview transcripts (if conducted)
- [ ] Driver interview transcripts (if conducted)
- [ ] WhatsApp message screenshots (client/driver reactions)
- [ ] Support call logs (who called, what they said)

**Call Logs:**
- [ ] Driver calls (name, phone, time, outcome)
- [ ] Client calls (name, order ID, time, outcome)
- [ ] Format: CSV with columns [Timestamp, User Type, Name, Phone, Reason for Call, Outcome, Notes]

**Incident Documentation:**
- [ ] PILOT_INCIDENT_LOG.md updated (incident type, timeline, actions, outcome)
- [ ] Root cause analysis document (if completed)
- [ ] Post-mortem document (if pause led to NO-GO)

---

### **Evidence Retention Policy**

**Duration:** Keep all evidence for 1 year minimum

**Access Control:**
- Full access: Product Manager, Ops Lead, Founder/CEO
- Read-only: Dev team, Growth lead
- No access: External parties (unless legal requirement)

**Backup:**
- Primary: Google Drive (shared team drive)
- Secondary: Encrypted external hard drive (Ops Lead custody)
- Tertiary: Cloud backup (Google Takeout or similar)

---

## 5. Day-After Playbooks

### 5.1 After GO Decision (Metrics Good)

**Scenario:** Day 7 review completed, North Star ≥70%, no critical kill signals

**Timeline:** Day 8-14 (second week of pilot)

**Owner:** Ops Lead + Growth Lead

---

**Day 8 Morning (9:00 AM) - Resume Planning**

**Step 1: Team Standup (30 minutes)**

```
Agenda:
1. Celebrate success ✅
   - North Star hit: [X% completion rate]
   - Client DAU: [X users]
   - Driver utilization: [X%]

2. Identify key learnings:
   - What worked well? (e.g., manual admin coordination, driver WhatsApp group)
   - What surprised us? (e.g., geographic clustering, peak hour patterns)
   - What almost failed? (e.g., GPS issues, pricing edge cases)

3. Lock Week 2 goals:
   - Maintain North Star ≥70%
   - Grow client DAU to [X] (target: +20% from Week 1 avg)
   - Maintain driver utilization 30-60%

4. Assign Week 2 responsibilities:
   - Ops Lead: Continue daily monitoring, driver support
   - Growth Lead: Client acquisition push (social media, flyers)
   - Admin team: Business as usual, same procedures
```

**Step 2: Document Learnings (2 hours)**

```
Create document: PILOT_WEEK1_LEARNINGS.md

Sections:
1. What Worked Well (Successes)
   - Example: "Manual admin coordination handled 100% of stuck orders successfully"
   - Example: "Driver WhatsApp group enabled fast communication"

2. What Needs Improvement (For v2)
   - Example: "Client indefinite waiting needs timeout UI"
   - Example: "Driver GPS loss mid-shift not detected - need continuous monitoring"

3. Surprising Insights
   - Example: "80% of orders between 10am-2pm (lunch delivery peak)"
   - Example: "Drivers prefer short-distance orders (<3km) - faster completion, more orders/hour"

4. Near-Misses (Almost Failed)
   - Example: "Day 3 assignment time hit 9.8 minutes - almost triggered K5"
   - Example: "Client DAU dropped 30% Day 2-3 - retention campaign prevented K6"

5. User Quotes (from interviews)
   - Client: "[Positive quote]"
   - Driver: "[Positive quote]"
   - Client: "[Constructive feedback]"
   - Driver: "[Constructive feedback]"

6. Data Highlights
   - Total orders: [X]
   - Total completed: [X (Y%)]
   - Total GMV: [X MRU]
   - Avg order value: [X MRU]
   - Top earning driver: [X MRU from Y orders]
   - Most active client: [X orders placed]
```

**Step 3: Start v2 Planning (4 hours - scheduled for Day 8 afternoon)**

```
Meeting: Product Manager + Ops Lead + Growth Lead + Dev Lead

Agenda:
1. Review PRODUCT_SCOPE_V1 "SHOULD HAVE" list
   - Which features unlock next scale tier (100 drivers, 500 clients)?
   - Prioritize: Client order history, Driver order history, Push notifications, etc.

2. Review UX_PILOT_JOURNEYS "Top 5 UX Friction Risks"
   - Which friction points MUST be fixed for v2?
   - Example: Indefinite client waiting → Add timeout + "No drivers available" message

3. Review PILOT_WEEK1_LEARNINGS "What Needs Improvement"
   - Prioritize improvements by ROI

4. Create v2 feature backlog (ranked):
   Rank 1: [Feature name - justification - effort estimate]
   Rank 2: [Feature name - justification - effort estimate]
   ...

5. Set v2 timeline:
   - Week 2-3: Continue pilot as-is (no code changes, only monitoring)
   - Week 4: v2 development sprint
   - Week 5: v2 staging verification
   - Week 6: v2 deployment to production

Output: PRODUCT_SCOPE_V2.md (draft)
```

**Step 4: Scale Recruitment (Ongoing Week 2)**

```
Owner: Growth Lead + Ops Lead

Client Acquisition:
- Continue tactics that worked in Week 1
- Add: Referral program (existing clients invite friends)
- Target: +20 new clients by Day 14

Driver Recruitment:
- Target underserved geographic areas (identified in Week 1 data)
- On-board 10-15 new drivers
- Focus quality over quantity (only drivers with reliable vehicles + smartphones)

Monitoring:
- Track acquisition cost (if spending on ads/flyers)
- Track activation rate (new users who complete first order/trip)
```

**Step 5: Week 2 Daily Operations (Business as Usual)**

```
Continue same procedures as Week 1:
- Daily 9:00 AM standup (15 min)
- Update Daily Metrics Log (Google Sheet)
- Monitor Kill Signals (K1-K7)
- Admin dashboard monitoring (hourly checks during peak hours)
- User support (answer WhatsApp/phone calls)

New additions:
- Track v2 feature requests from users (log in PILOT_USER_FEEDBACK.md)
- Weekly all-hands (every Friday): Review metrics, celebrate wins, plan next week
```

---

### 5.2 After CONDITIONAL GO Decision (Metrics Mixed)

**Scenario:** Day 7 review completed, North Star 50-69%, 1-2 warning kill signals, one funnel step failing

**Timeline:** Day 8-10 (fix + monitor), then re-evaluate

**Owner:** Ops Lead + Product Manager

---

**Day 8 Morning - Emergency Fix Mode**

**Step 1: Root Cause Analysis (4 hours - PRIORITY)**

```
Owner: Ops Lead + Admin team + Growth Lead

Process:
1. Identify which funnel step is failing (from PILOT_METRICS_V1 funnel data):
   - Client funnel: Step 1→2 (order creation), Step 2→3 (matching), Step 3→4 (delivery)
   - Driver funnel: Step 1→2 (activation), Step 2→3 (order acceptance), Step 3→4 (completion)

2. Deep dive into failing step:
   - Export all relevant data from Firestore
   - Segment by time (Day 1 vs Day 7 - did failure worsen over time?)
   - Segment by user (do specific users fail consistently?)
   - Review Crashlytics (any crashes in failing step?)

3. Conduct emergency user interviews (10 users affected by failing step):
   - Clients who didn't create order after opening app
   - Drivers who didn't accept orders after going online
   - etc.

4. Formulate hypothesis:
   Example: "Client Step 1→2 failing (60% expected, only 35% actual)
   because location input is confusing + map blank for users without
   Google Maps API access."

Output: ROOT_CAUSE_HYPOTHESIS.md
```

**Step 2: Prioritize Fix (1 hour)**

```
Meeting: Product Manager + Ops Lead + Dev Lead

Decision matrix:
| Fix Option | Effort | Impact | Risk | Decision |
|------------|--------|--------|------|----------|
| Option A: [Quick workaround - manual] | Low | Medium | Low | ✅ Implement Day 8 |
| Option B: [Code fix - requires dev] | Medium | High | Medium | ⏳ Plan for Day 9-10 |
| Option C: [Pivot strategy - major change] | High | High | High | ❌ Defer to v2 |

Example:
| Fix Option | Effort | Impact | Risk | Decision |
|------------|--------|--------|------|----------|
| Admin calls clients who opened app but didn't order (offer assisted order creation) | 2 hours/day | Medium (may convert 20% of churned clients) | Low | ✅ Start Day 8 |
| Add "Help" button on order creation screen (links to tutorial video) | 1 day dev | High (addresses UX confusion) | Low | ✅ Deploy Day 9 |
| Redesign entire order creation flow | 2 weeks dev | High | High (may introduce new bugs) | ❌ Defer to v2 |

Select: Top 2 fixes (1 manual + 1 code fix)
```

**Step 3: Execute Fixes (Day 8-10)**

**Manual Fix (Day 8 - immediate):**

```
Owner: Ops Lead + Admin team

Example: Assisted order creation for clients
Process:
1. Export client list who opened app Day 6-7 but didn't create order
2. Call each client:
   "Hi [Name], we noticed you opened WawApp but didn't place an order.
   Can I help you create one right now? I'll walk you through it."
3. If client agrees:
   - Admin creates order on behalf of client (using admin dashboard or manual Firestore entry)
   - Assign to nearest driver manually
   - Monitor order to completion
4. Track success rate (how many converted?)

Target: Convert 20% of churned clients by Day 9
```

**Code Fix (Day 9-10):**

```
Owner: Dev team

Example: Add tutorial/help feature
Implementation:
- Day 9 AM: Dev implements feature (4 hours)
- Day 9 PM: Internal testing (2 hours)
- Day 10 AM: Deploy to production (via Firebase App Distribution OR Play Store update)
- Day 10 PM: Monitor uptake (check Firebase Analytics for tutorial views)

Validation:
- If tutorial viewed by >50% of new users → Success
- If Step 1→2 conversion improves to >50% by Day 11 → Success
- Otherwise → Need different fix
```

**Step 4: Intensive Monitoring (Day 8-11)**

```
Ops team actions:
- Increase standup frequency: 2x per day (9:00 AM + 6:00 PM)
- Update metrics: Every 12 hours (not just daily)
- Admin dashboard: Hourly checks (not just during peak)
- User interviews: Daily (5 users/day - ask if they noticed improvements)

Metrics to watch:
- Failing funnel step: Is conversion improving?
- North Star: Is completion rate trending toward 70%?
- Kill signals: Are warning signals (K4-K7) resolving?

Decision checkpoint: Day 11 morning
- If metrics improved → Declare GO, continue pilot
- If no improvement → Escalate to NO-GO procedure
```

**Step 5: Re-Evaluation Meeting (Day 11)**

```
Owner: Product Manager

Attendees: Ops Lead, Growth Lead, Dev Lead, Founder/CEO (if critical)

Agenda:
1. Review metrics Day 8-10 vs Day 5-7:
   - Did failing funnel step improve?
   - Did North Star improve (toward 70%)?
   - Did warning kill signals resolve?

2. Assess fix effectiveness:
   - Manual fix: How many users helped? What was conversion?
   - Code fix: Uptake rate? Impact on conversion?

3. Decision:
   Option A: UPGRADE to GO
     - Metrics improved to target levels
     - Continue pilot as normal (use Day-After GO playbook Section 5.1)

   Option B: EXTEND CONDITIONAL (another 3 days)
     - Metrics improved slightly but not to target
     - Apply additional fixes (repeat Day 8-10 process)
     - Set hard deadline: Day 14 final decision

   Option C: DOWNGRADE to NO-GO
     - Metrics did not improve OR worsened
     - Root cause is fundamental (not fixable in pilot timeline)
     - Pause pilot (use Day-After NO-GO playbook Section 5.3)

Output: Decision logged in PILOT_DECISION_LOG.md
```

---

### 5.3 After NO-GO Decision (Metrics Bad / Pilot Paused)

**Scenario:** Day 7 review completed, North Star <50%, critical kill signal triggered, OR pilot paused due to failure

**Timeline:** Day 8-14 (post-mortem + decision on future)

**Owner:** Product Manager + Founder/CEO

---

**Day 8 - Emergency Post-Mortem**

**Step 1: Full Data Export (4 hours)**

```
Owner: Ops Lead + Dev team

Export everything (even if already collected during pause):
- Firestore: All collections (orders, drivers, clients, analytics_events if stored)
- Firebase Analytics: Full export (not just screenshots - use BigQuery export if available)
- Crashlytics: All crashes (not just top 10)
- Admin dashboard: Historical data (if stored in backend)
- Google Sheets: All tabs (Daily Metrics, Funnels, Kill Signals)
- User feedback: All interview transcripts, call logs, WhatsApp screenshots
- Financial data: Total GMV, earnings paid to drivers, operational costs

Store in: /WawApp_Pilot_Postmortem_[Date]/ (Google Drive + local backup)
```

**Step 2: Post-Mortem Meeting (3 hours)**

```
Owner: Product Manager (facilitator)

Attendees: REQUIRED - All team members (Ops, Growth, Dev, Admin, Founder/CEO)

Pre-reading (send 24 hours before meeting):
- PILOT_METRICS_V1.md (review kill signals)
- Daily Metrics Log (full 7 days)
- Incident log (if any K1-K3 triggered)

Meeting agenda:

1. Timeline Review (30 min):
   - Walk through Day 1-7 chronologically
   - Mark key events: Launch, first order, first incident, pause (if any), final metrics
   - Identify: When did things start going wrong? Was there a turning point?

2. Root Cause Analysis (60 min):
   Use "5 Whys" technique for each failure:

   Example:
   Problem: Order completion rate only 35%
   - Why? Most orders stuck in "assigning" status
   - Why? Not enough drivers online
   - Why? Drivers went online Day 1-2 but quit by Day 4
   - Why? Drivers completed 0-1 orders in first 3 days (low earnings)
   - Why? Not enough client demand (only 15 clients, 3-5 orders/day)

   Root cause category (choose one):
   - Category A: Critical bugs (app crashes, backend failures)
   - Category B: Product-market fit failure (no demand, pricing wrong, competitor preference)
   - Category C: Operational failure (not enough drivers recruited, admin overwhelmed)

3. Hypothesis Validation/Invalidation (30 min):
   Review original hypotheses from PRODUCT_SCOPE_V1:
   - "Clients in Nouakchott need on-demand delivery" → VALIDATED or INVALIDATED?
   - "Drivers will earn 300-500 MRU/day" → VALIDATED or INVALIDATED?
   - "8km matching radius is sufficient" → VALIDATED or INVALIDATED?
   - "Phone + PIN auth is acceptable" → VALIDATED or INVALIDATED?

4. What We Learned (30 min):
   List insights (even if pilot failed, learning has value):
   - Example: "Clients want delivery but only for urgent needs (not daily use)"
   - Example: "Drivers need ≥5 orders/day to stay engaged (we only provided 1-2/day)"
   - Example: "Manual admin coordination works at 10 orders/day but not scalable to 100/day"

5. Decision on Next Steps (30 min):
   Vote: RE-LAUNCH / PIVOT / SHUTDOWN

   RE-LAUNCH:
   - If root cause = fixable bug or operational issue
   - Timeline: Fix within 1-2 weeks, re-launch with same target users
   - Risk: Will users return after failed first attempt?

   PIVOT:
   - If root cause = product-market fit failure
   - Options:
     a) Different target market (e.g., B2B deliveries for businesses, not consumer)
     b) Different pricing (e.g., lower base fare, or premium pricing for guaranteed speed)
     c) Different geography (e.g., different city with less competition)
   - Timeline: 2-4 weeks of replanning + recruitment

   SHUTDOWN:
   - If root cause = fundamental market failure (no demand + no supply)
   - Decision: Stop WawApp project, return to ideation phase or pivot to different business

Output: PILOT_POSTMORTEM.md (30-page detailed document)
```

**Step 3: User Closure (Day 8-9)**

**If RE-LAUNCH or PIVOT:**

```
Message to Clients (WhatsApp):
"Dear WawApp users,

Thank you for trying our service during the pilot phase.

We experienced some technical challenges and have paused service to
make significant improvements.

We will be back with a better experience. Stay tuned for updates.

Thank you for your patience and feedback.

- WawApp Team"

Message to Drivers (WhatsApp):
"Dear WawApp drivers,

Thank you for partnering with us during the pilot.

We have paused service to make improvements to the platform.

All earnings earned during the pilot will be paid to you by [Date].

We will contact you when we re-launch. Your feedback was valuable -
thank you for your patience.

- WawApp Team"

Action: Pay all driver earnings within 7 days (manual mobile money transfers)
```

**If SHUTDOWN:**

```
Message to Clients (WhatsApp):
"Dear WawApp users,

After careful consideration, we have decided to discontinue the WawApp
delivery service.

We sincerely thank you for your support and feedback during our pilot.

We apologize for any inconvenience. If you have questions, please contact
us at [Email].

Thank you.

- WawApp Team"

Message to Drivers (WhatsApp + Phone Calls):
"Dear WawApp drivers,

We have made the difficult decision to shut down WawApp.

All your earnings will be paid to you by [Date - within 7 days].

We sincerely thank you for your partnership. We apologize that we could
not provide more opportunities.

If you have questions about your payments, call [Ops Lead Phone].

Thank you for everything.

- WawApp Team"

Action: Pay all driver earnings within 7 days + offer reference letters (if drivers request)
```

**Step 4: Data Preservation & Deletion (Day 10-14)**

```
Owner: Dev Lead + Ops Lead

Data to PRESERVE (for learning):
- Anonymized analytics (remove PII: names, phone numbers, addresses)
- Aggregate metrics (order counts, completion rates, etc.)
- Code repository (for future reference)
- PILOT_POSTMORTEM.md document

Data to DELETE (privacy compliance):
- Client personal data (names, phone numbers, addresses) - DELETE after 30 days
- Driver personal data (names, phone numbers, vehicle details) - DELETE after 30 days
- Order details with addresses - ANONYMIZE or DELETE after 30 days

Firebase Cleanup:
- IF SHUTDOWN: Delete Firebase project after 60 days (keep for reference period)
- IF RE-LAUNCH/PIVOT: Keep project, archive old data to separate collection

Legal compliance:
- Inform users of data deletion (if required by local privacy laws)
- Provide option for users to request immediate deletion
```

**Step 5: Team Retro & Morale (Day 14)**

```
Owner: Founder/CEO or Product Manager

Purpose: Closure + learning + team morale

Meeting (90 min):
1. Acknowledge effort (30 min):
   - Every team member shares: "What I'm proud of from this pilot"
   - Celebrate small wins (even if overall pilot failed)

2. No-blame reflection (30 min):
   - "If we could do it again, what would we change?"
   - Focus on process, not people

3. Next steps (30 min):
   - IF RE-LAUNCH: Timeline, who's involved, what changes
   - IF PIVOT: New direction, validation plan, timeline
   - IF SHUTDOWN: What's next for the team? New projects? Transition plan?

Output: Team alignment on future, documented in TEAM_NEXT_STEPS.md
```

---

**End of PILOT_OPS_RUNBOOK.md**
