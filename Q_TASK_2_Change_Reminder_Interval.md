# Q TASK 2: Change Reminder Interval to 5 Minutes

**Priority:** HIGH ⚡
**Estimated Time:** 10 minutes
**Difficulty:** Very Easy

---

## Objective
Change the trip start reminder interval from 1 minute to 5 minutes.

---

## Current Behavior
- After driver accepts order, reminders are sent every **1 minute**
- User wants reminders every **5 minutes** instead

---

## Files to Modify

### 1. `functions/src/monitorAcceptedOrders.ts`

---

## Implementation Steps

### Step 1: Open the File

Navigate to: `functions/src/monitorAcceptedOrders.ts`

### Step 2: Find the Constant

Locate **line 22**:

```typescript
const REMINDER_INTERVAL_MINUTES = 1;
```

### Step 3: Change the Value

Replace with:

```typescript
const REMINDER_INTERVAL_MINUTES = 5;
```

**That's it!** One line change.

---

## Why This Works

The function `monitorAcceptedOrders` already has smart logic:

- Runs every 1 minute (scheduler frequency stays the same)
- Checks `lastReminderSentAt` timestamp
- Only sends reminder if `REMINDER_INTERVAL_MINUTES` have passed
- So changing this constant from 1→5 means reminders every 5 min

**Idempotency is already built-in** (lines 195-199) ✓

---

## Testing Checklist

- [ ] Accept an order as driver
- [ ] Wait 5 minutes
- [ ] **Verify:** Receive first reminder notification
- [ ] Wait another 5 minutes
- [ ] **Verify:** Receive second reminder
- [ ] Check Firestore: `lastReminderSentAt` field updates every 5 minutes
- [ ] **Verify:** No reminders sent at 1, 2, 3, 4 minute marks

---

## Build & Deploy

After making the change:

```bash
cd functions
npm run build
```

**Expected output:** Build successful, no errors

**Deploy:**
```bash
firebase deploy --only functions:monitorAcceptedOrders
```

---

## Verification

1. **Build Check:**
   ```bash
   cd functions
   npm run build
   ```
   Should complete without errors ✓

2. **Runtime Test:**
   - Accept order
   - Wait 5 minutes → reminder arrives ✓
   - Wait 10 minutes → second reminder ✓

---

## Report Back to Claude

After completing this task, report:

1. ✅ File modified: `functions/src/monitorAcceptedOrders.ts`
2. ✅ Change: Line 22: `REMINDER_INTERVAL_MINUTES = 1` → `5`
3. ✅ Build: `npm run build` successful
4. ✅ Deployed: `firebase deploy --only functions:monitorAcceptedOrders`
5. ✅ Test: Reminders arrive every 5 minutes (not 1 minute)

---

**Ready to start? Copy this entire task and paste to Amazon Q!**
