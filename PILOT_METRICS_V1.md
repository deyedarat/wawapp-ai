# WawApp v1 – Pilot Metrics & Decision Playbook

**Document Owner:** Growth & Analytics Lead
**Date:** 2025-12-22
**Status:** LOCKED FOR PILOT (Day 1-7 measurement framework)

---

## 1. North Star Metric

### **Order Completion Rate**

**Definition:**
```
Order Completion Rate = (Completed Orders / Created Orders) × 100%
```

**Tracking:**
- Numerator: Count of orders with `status = "completed"` in Firestore
- Denominator: Count of orders created (any status)
- Exclude: Admin test orders (identified by test client IDs documented pre-launch)

**Why This Metric:**
This is the ONLY metric that proves the marketplace works end-to-end. It validates:
1. **Supply:** Enough online drivers with working GPS
2. **Demand:** Clients creating real orders (not just browsing)
3. **Matching:** Algorithm successfully pairing clients with drivers within acceptable time
4. **Execution:** Drivers completing deliveries without cancellation
5. **Technical stability:** No critical crashes blocking any step

If this metric fails, the pilot fails. All other metrics are diagnostic signals to understand WHY completion rate is high or low.

**Target for Day 7:** ≥ 70%

**Acceptable Range:**
- **GO (v2 planning):** 70-100%
- **CONDITIONAL GO (investigate):** 50-69%
- **NO-GO (pause pilot):** <50%

---

## 2. Supporting Metrics (Max 5)

### 2.1 Client Side

#### **C1: Client App Opens (Daily Active Users)**
**Definition:** Count of unique client user IDs with any Firebase Analytics session on a given day

**Data Source:** Firebase Analytics dashboard → Users → Active users (filter: user_type = 'client')

**Why:** Measures client acquisition success and app stickiness. If DAU drops Day 2-3, indicates poor first experience.

**Target:** Stable or growing (Day 1: 20-30 clients → Day 7: 40-60 clients)

**Kill Signal:** DAU decreases >50% from Day 1 to Day 7 (e.g., 30 → <15)

---

#### **C2: Orders Created Per Active Client**
**Definition:**
```
Orders Per Client = Total Orders Created / Client DAU
```

**Calculation:** Manual (export Firestore orders CSV + Firebase Analytics DAU)

**Why:** Measures demand intensity. High ratio (>1.5) means clients ordering multiple times = product-market fit signal. Low ratio (<0.5) means clients opening app but not ordering = friction in order creation flow.

**Target:** 0.8-1.2 orders/client/day (indicates healthy repeat usage)

**Kill Signal:** <0.3 orders/client/day for 3+ consecutive days (clients not converting)

---

### 2.2 Driver Side

#### **D1: Driver Utilization Rate**
**Definition:**
```
Driver Utilization = (Drivers with ≥1 Completed Order Today / Drivers Online Today) × 100%
```

**Data Source:**
- Numerator: Firestore query: `orders` collection → filter `status = "completed"` + `completedAt >= today` → count distinct `assignedDriverId`
- Denominator: Firestore query: `drivers` collection → filter `onlineAt >= today` (driver went online at least once today) → count distinct driver IDs

**Why:** Measures supply-side efficiency. Low utilization (<30%) means drivers wasting time waiting for orders → driver churn risk. High utilization (>70%) means undersupply → long client wait times.

**Target:** 30-60% (balanced supply-demand)

**Kill Signal:** <20% for 3+ consecutive days (drivers not earning, will quit)

---

#### **D2: Average Driver Online Duration (Hours/Day)**
**Definition:**
```
Avg Online Duration = Total hours all drivers online / Driver DAU
```

**Calculation:** Manual tracking via admin dashboard exports
- Export driver online/offline events from Firestore (timestamps)
- Calculate duration per driver per day
- Average across all drivers

**Why:** Measures driver engagement and economic viability. If drivers stay online <2 hours/day, indicates low earnings expectations or bad experience. If >8 hours/day, indicates strong earnings potential.

**Target:** 3-6 hours/day (part-time driver model)

**Kill Signal:** <2 hours/day average for 3+ consecutive days (drivers not committed)

---

### 2.3 Ops/Admin Side

#### **O1: Average Order-to-Assignment Time (Minutes)**
**Definition:**
```
Assignment Time = Median (acceptedAt - createdAt) for all accepted orders
```

**Data Source:** Firestore orders collection
- Export: `createdAt`, `acceptedAt` timestamps
- Calculate: `acceptedAt - createdAt` in minutes
- Aggregate: Median (not mean, to avoid outlier skew)

**Why:** Measures matching efficiency. Long assignment time (>5 min) indicates:
- Not enough online drivers
- Drivers too far from pickup locations
- Driver app UX friction (not seeing orders, race conditions)

Short assignment time (<2 min) indicates healthy supply-demand balance.

**Target:** ≤ 5 minutes (median)

**Kill Signal:** >10 minutes median for 2+ consecutive days (unacceptable wait times)

---

## 3. Funnels

### 3.1 Client Funnel: App Open → Order Completed

**Steps (Tracked via Firebase Analytics + Firestore):**

```
Step 1: App Open
↓ [Firebase Analytics: session_start event, user_type = 'client']
Count: All client app sessions

Step 2: Order Created
↓ [Firebase Analytics: order_created event]
Count: order_created events
Dropoff: (Step 1 - Step 2) / Step 1 = Client Browse Rate

Step 3: Order Accepted by Driver
↓ [Firestore: orders with status = "accepted"]
Count: Orders transitioned to "accepted"
Dropoff: (Step 2 - Step 3) / Step 2 = Driver Matching Failure Rate

Step 4: Order Completed
↓ [Firestore: orders with status = "completed"]
Count: Orders transitioned to "completed"
Dropoff: (Step 3 - Step 4) / Step 3 = Delivery Failure Rate
```

**Full Funnel Conversion:**
```
Overall Conversion = (Completed Orders / App Opens) × 100%
```

**Benchmark Targets (Day 7):**
- Step 1 → Step 2 (Order Creation Rate): ≥ 60% (clients who open app create order)
- Step 2 → Step 3 (Driver Match Rate): ≥ 80% (orders get assigned)
- Step 3 → Step 4 (Delivery Success Rate): ≥ 90% (assigned orders complete)
- **Overall Conversion (Step 1 → Step 4): ≥ 43%** (60% × 80% × 90%)

**Diagnostic Signals:**
- **Low Step 1 → Step 2:** UX friction in order creation (location input, pricing confusion, map failure)
- **Low Step 2 → Step 3:** Supply shortage (not enough drivers, drivers too far)
- **Low Step 3 → Step 4:** Execution problems (driver cancellations, GPS loss, driver churn mid-delivery)

---

### 3.2 Driver Funnel: Go Online → Order Completed

**Steps (Tracked via Firebase Analytics + Firestore):**

```
Step 1: App Open (Driver)
↓ [Firebase Analytics: session_start event, user_type = 'driver']
Count: All driver app sessions

Step 2: Go Online
↓ [Firebase Analytics: driver_went_online event]
Count: driver_went_online events
Dropoff: (Step 1 - Step 2) / Step 1 = Driver Activation Rate

Step 3: Accept Order
↓ [Firebase Analytics: order_accepted_by_driver event]
Count: order_accepted_by_driver events
Dropoff: (Step 2 - Step 3) / Step 2 = Order Discovery/Acceptance Rate

Step 4: Complete Order
↓ [Firebase Analytics: order_completed_by_driver event]
Count: order_completed_by_driver events
Dropoff: (Step 3 - Step 4) / Step 3 = Completion Failure Rate
```

**Full Funnel Conversion:**
```
Overall Conversion = (Completed Orders by Driver / Driver App Opens) × 100%
```

**Benchmark Targets (Day 7):**
- Step 1 → Step 2 (Activation Rate): ≥ 70% (drivers who open app go online)
- Step 2 → Step 3 (Order Acceptance Rate): ≥ 50% (online drivers get at least 1 order)
- Step 3 → Step 4 (Completion Success): ≥ 95% (accepted orders are completed)
- **Overall Conversion (Step 1 → Step 4): ≥ 33%** (70% × 50% × 95%)

**Diagnostic Signals:**
- **Low Step 1 → Step 2:** Driver onboarding friction (profile incomplete, GPS issues, confusion)
- **Low Step 2 → Step 3:** Demand shortage (not enough orders) OR driver UX issues (not seeing nearby orders, race conditions)
- **Low Step 3 → Step 4:** Driver execution problems (GPS loss, navigation issues, cancellations, admin intervention)

---

## 4. Kill Signals (Pilot Failure Thresholds)

### 4.1 Critical Kill Signals (Immediate Pause)

**K1: Order Completion Rate < 50% for 2 Consecutive Days**
- **Meaning:** Marketplace fundamentally broken. Orders created but majority fail.
- **Action:** PAUSE pilot immediately. Root cause analysis via admin dashboard + Firestore exports.
- **Likely Causes:**
  - Driver supply shortage (not enough online drivers)
  - Driver GPS failure (drivers online but unmatchable)
  - Critical crashes blocking order flow (check Crashlytics)
  - Pricing too low (drivers rejecting all orders)

---

**K2: Zero Completed Orders for 24 Hours**
- **Meaning:** Complete marketplace failure. Either no demand or no supply.
- **Action:** PAUSE pilot. Emergency meeting with ops team.
- **Likely Causes:**
  - All drivers quit (check driver DAU)
  - All clients abandoned app (check client DAU)
  - Critical backend failure (check Firestore, Auth, Firebase Console)
  - Admin accidentally set all drivers offline

---

**K3: Crash-Free Rate < 95% in Any App (Client or Driver)**
- **Meaning:** Critical crashes blocking core flows (auth, order creation, order acceptance).
- **Data Source:** Firebase Crashlytics → Crash-free users metric
- **Action:** PAUSE pilot. Fix crashes immediately.
- **Threshold:** If ≥5% of users experiencing crashes, pilot is unusable.

---

### 4.2 Warning Kill Signals (Investigate, Possible Pause)

**K4: Driver Utilization < 20% for 3 Consecutive Days**
- **Meaning:** Drivers not earning. Churn imminent.
- **Action:** Investigate demand shortage. Consider:
  - Client acquisition too slow (DAU not growing)
  - Pricing too high (clients not ordering)
  - Geographic mismatch (drivers in wrong areas)
- **Decision:** If no improvement by Day 6, pause pilot and recruit more clients OR adjust pricing.

---

**K5: Average Assignment Time > 10 Minutes Median for 2 Consecutive Days**
- **Meaning:** Client experience unacceptable. Orders waiting too long.
- **Action:** Investigate supply shortage or matching algorithm failure.
- **Decision:** If no improvement by Day 5, pause pilot and recruit more drivers.

---

**K6: Client DAU Decreases > 50% from Day 1 to Day 7**
- **Meaning:** Client retention catastrophic. Poor first experience.
- **Action:** Conduct user interviews (phone calls) to understand why clients abandoned.
- **Decision:** If root cause is fixable quickly (e.g., UX confusion, single bug), fix and continue. If fundamental (e.g., pricing too high, no value), pause and pivot.

---

**K7: Driver DAU Decreases > 50% from Day 1 to Day 7**
- **Meaning:** Driver churn catastrophic. Not earning enough or bad experience.
- **Action:** Conduct driver interviews (phone calls) to understand why they quit.
- **Decision:** If root cause is fixable (e.g., UX confusion, GPS training), fix and continue. If fundamental (e.g., earnings too low, too few orders), pause and pivot.

---

## 5. Review Cadence

### 5.1 Daily Reviews (Every Morning, 9:00 AM)

**Owner:** Admin team lead + Growth lead (15-minute standup)

**Data Sources:**
- Admin dashboard (live stats)
- Firebase Crashlytics (crash-free rate)
- Firebase Analytics (DAU, event counts)

**What to Check:**
1. **Yesterday's North Star:** Order completion rate (target: ≥70%)
2. **Yesterday's DAU:** Client DAU, Driver DAU (target: growing or stable)
3. **Critical Crashes:** Any new crashes affecting >5 users?
4. **Kill Signals:** Any K1-K7 thresholds crossed?
5. **Admin Interventions:** How many orders manually cancelled/reassigned?

**Output:**
- GO: Continue pilot, no action
- WARNING: Log issue, monitor today
- PAUSE: Immediate escalation to product manager

**Documentation:** Daily log in Google Sheet (template below)

---

### 5.2 Weekly Review (End of Day 7)

**Owner:** Product Manager + Growth Lead + Admin Lead (60-minute meeting)

**Data Sources:**
- Manual Firestore exports (orders, drivers, clients)
- Firebase Analytics dashboard (funnels, cohorts)
- Admin dashboard historical stats
- Daily log aggregation

**What to Analyze:**
1. **North Star Performance:**
   - Week 1 order completion rate (aggregate Day 1-7)
   - Trend: Improving, stable, or declining?
   - Compare to 70% target

2. **Supporting Metrics Trends:**
   - C1 (Client DAU): Did we reach 40-60 clients by Day 7?
   - C2 (Orders per client): Average across 7 days
   - D1 (Driver utilization): Average across 7 days
   - D2 (Driver online hours): Average across 7 days
   - O1 (Assignment time): Median across 7 days

3. **Funnel Deep Dive:**
   - Client funnel: Which step has biggest dropoff?
   - Driver funnel: Which step has biggest dropoff?
   - Cohort analysis: Day 1 users vs Day 7 users (retention)

4. **Kill Signals Audit:**
   - Were any K1-K7 thresholds crossed?
   - If yes, were they resolved? How?

5. **Qualitative Feedback:**
   - Admin team: Top 3 operational pain points
   - Phone interviews: Client and driver feedback (sample 5 of each)

**Output:**
- **Decision:** GO / CONDITIONAL GO / NO-GO (using playbook below)
- **Report:** 2-page summary with charts (Google Slides)
- **Action Items:** If CONDITIONAL GO, what must improve for v2?

---

## 6. Decision Playbook

### 6.1 If Metrics Are GOOD (GO Signal)

**Criteria:**
- ✅ Order completion rate ≥ 70% (North Star hit)
- ✅ No critical kill signals (K1-K3) triggered
- ✅ At most 1 warning kill signal (K4-K7) triggered (and resolved)
- ✅ Client DAU growing or stable (≥40 clients Day 7)
- ✅ Driver utilization ≥ 30%
- ✅ Assignment time ≤ 5 minutes median

**Interpretation:** Pilot validated core hypothesis. Marketplace works at small scale.

**Actions:**
1. **Lock pilot scope (no changes):** Keep running pilot as-is for another 7 days (Day 8-14) to confirm sustainability.
2. **Start v2 planning:**
   - Feature prioritization (from PRODUCT_SCOPE_V1 "SHOULD HAVE" list)
   - Scale targets (50 drivers → 100 drivers, 200 clients → 500 clients)
   - UX friction fixes (from UX_PILOT_JOURNEYS top 5 risks)
3. **Document learnings:**
   - What worked well? (e.g., pricing, onboarding, matching algorithm)
   - What surprised us? (e.g., unexpected driver behavior, client usage patterns)
4. **Recruit more users:**
   - Client acquisition: Social media, flyers, referrals
   - Driver acquisition: Driver associations, word-of-mouth

**Timeline:**
- Week 2 (Day 8-14): Continue pilot, monitor metrics
- Week 3: Start v2 development (based on feedback)
- Week 4-5: v2 testing and staging verification
- Week 6: v2 deployment to production

---

### 6.2 If Metrics Are MIXED (CONDITIONAL GO)

**Criteria:**
- ⚠️ Order completion rate 50-69% (below target but not critical)
- ⚠️ 1-2 warning kill signals (K4-K7) triggered
- ⚠️ Client or driver DAU declining but not >50% drop
- ⚠️ One funnel step has major dropoff (>40%)

**Interpretation:** Marketplace partially working but has fixable issues. Need diagnostic investigation.

**Actions:**
1. **Root cause analysis (24-hour deadline):**
   - Identify which funnel step is failing
   - Review admin intervention logs (why are orders being cancelled?)
   - Conduct 10 user interviews (5 clients, 5 drivers) via phone
   - Check Firestore for data anomalies (e.g., stuck orders, drivers with no GPS)

2. **Prioritize fixes:**
   - **If supply shortage (driver utilization <20%):**
     - Recruit 10-20 more drivers immediately
     - Offer driver incentives (bonus for first 5 completed orders)
   - **If demand shortage (client orders/client <0.5):**
     - Client acquisition push (social media ads, flyers)
     - Price adjustment test (reduce base fare by 10 MRU, measure response)
   - **If matching failure (assignment time >10 min):**
     - Admin manual coordination (call drivers to accept orders)
     - Check driver GPS issues (call drivers with no location data)
   - **If delivery failure (Step 3 → Step 4 <90%):**
     - Driver training (navigation, app usage)
     - Check GPS tracking bugs (Crashlytics review)

3. **Decision timeline:**
   - Apply fixes on Day 8
   - Monitor Day 8-10 metrics
   - If improvement → Continue pilot (GO)
   - If no improvement → PAUSE and pivot (NO-GO)

**Documentation:** Create "PILOT_FIX_LOG.md" documenting:
- Issue identified (with data)
- Hypothesis for root cause
- Fix applied (when, how)
- Result (did metric improve?)

---

### 6.3 If Metrics Are BAD (NO-GO / PAUSE)

**Criteria:**
- ❌ Order completion rate < 50%
- ❌ Any critical kill signal (K1-K3) triggered
- ❌ Multiple warning kill signals (≥3 of K4-K7) triggered
- ❌ Zero completed orders for 24 hours
- ❌ Client or driver DAU dropped >50%

**Interpretation:** Pilot failed. Marketplace not viable at current state.

**Actions:**
1. **PAUSE pilot immediately:**
   - Stop all client acquisition efforts (social media, ads)
   - Inform active drivers and clients via phone call: "Temporarily pausing service for technical improvements"
   - Set all drivers offline in admin dashboard

2. **Emergency post-mortem (48-hour deadline):**
   - Full data export: Firestore orders, drivers, clients, analytics events
   - Crash analysis: Crashlytics top crashes, reproduction steps
   - User interviews: 10 clients, 10 drivers (why did they stop using app?)
   - Admin team debrief: Top 3 operational failures

3. **Root cause categorization:**
   - **Category A: Critical bugs** (e.g., auth failure, order creation crash, GPS not working)
     - Action: Fix bugs, re-run staging gates, re-launch pilot in 1 week
   - **Category B: Product-market fit failure** (e.g., pricing too high, no demand, drivers prefer competitor)
     - Action: Pivot strategy (adjust pricing, change target market, recruit different driver segment)
     - Timeline: 2-4 weeks of replanning before re-launch
   - **Category C: Operational failure** (e.g., not enough drivers onboarded, admin team overwhelmed)
     - Action: Recruit more drivers, add admin team member, simplify operations
     - Timeline: 1-2 weeks before re-launch

4. **Decision authority:**
   - Product Manager + Founder/CEO must approve:
     - RE-LAUNCH (with fixes)
     - PIVOT (change strategy)
     - SHUTDOWN (abandon project)

**Documentation:** Create "PILOT_POSTMORTEM.md" with:
- What went wrong (with data evidence)
- Why it went wrong (root cause analysis)
- What we learned (hypotheses validated/invalidated)
- Next steps (re-launch plan or pivot plan)

---

## 7. Manual Tracking Template (Google Sheets)

**Sheet 1: Daily Metrics Log**

| Date | Client DAU | Driver DAU | Orders Created | Orders Completed | Completion Rate | Assignment Time (Median) | Driver Utilization | Kill Signals | Notes |
|------|------------|------------|----------------|------------------|-----------------|--------------------------|--------------------|--------------+-------|
| Day 1 | 25 | 15 | 10 | 7 | 70% | 4.2 min | 60% (9/15) | None | Launch day |
| Day 2 | 28 | 18 | 15 | 11 | 73% | 3.8 min | 67% (12/18) | None | Growing |
| ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |

**Sheet 2: Funnel Tracking**

| Date | Client Funnel: Step 1 (Opens) | Step 2 (Orders) | Step 3 (Accepted) | Step 4 (Completed) | Driver Funnel: Step 1 (Opens) | Step 2 (Online) | Step 3 (Accept) | Step 4 (Complete) |
|------|-------------------------------|-----------------|-------------------|--------------------|-------------------------------|-----------------|-----------------|-------------------|
| Day 1 | 30 | 10 (33%) | 9 (90%) | 7 (78%) | 20 | 15 (75%) | 10 (67%) | 7 (70%) |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |

**Sheet 3: Kill Signals Tracker**

| Date | K1 (Completion <50%) | K2 (Zero Orders) | K3 (Crash Rate >5%) | K4 (Utilization <20%) | K5 (Assignment >10min) | K6 (Client DAU -50%) | K7 (Driver DAU -50%) | Action Taken |
|------|----------------------|------------------|---------------------|-----------------------|------------------------|----------------------|----------------------|--------------|
| Day 1 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | None |
| ... | ... | ... | ... | ... | ... | ... | ... | ... |

---

## 8. Data Collection Checklist (Pre-Launch)

**Before Day 1, verify:**

- [ ] Firebase Analytics configured in client app (events logging correctly)
- [ ] Firebase Analytics configured in driver app (events logging correctly)
- [ ] Firebase Crashlytics enabled in all 3 apps (crash reports visible)
- [ ] Admin dashboard accessible (live stats loading)
- [ ] Firestore export script ready (CSV export for orders, drivers, clients)
- [ ] Google Sheets template created (Daily Metrics Log, Funnel Tracker, Kill Signals)
- [ ] Test client IDs documented (for exclusion from metrics)
- [ ] Admin team trained on daily review process (who checks what, when)
- [ ] Alert thresholds configured (if possible via Firebase Console)

---

**End of PILOT_METRICS_V1.md**
