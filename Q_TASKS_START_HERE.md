# 🚀 Amazon Q Tasks - Driver Order Management Improvements

**Project:** WawApp Driver App Enhancement
**Supervisor:** Claude Code
**Executor:** Amazon Q Developer

---

## ⚠️ IMPORTANT: Read First

Before starting ANY task, read:
- [`CLAUDE.md`](CLAUDE.md) - Global safety rules (Section 1-7)

**Key Rules:**
- ✅ Edit ONLY what is requested
- ✅ Add dependencies when needed
- ✅ NO placeholders
- ❌ NO assumptions
- ❌ NO refactoring unless asked

---

## 📋 Tasks List (Execute in Order)

### **Phase 1: Quick Wins (1 hour total)**

#### ✅ Task 1: Hide Accepted Orders (15 min)
**File:** [`Q_TASK_1_Hide_Accepted_Orders.md`](Q_TASK_1_Hide_Accepted_Orders.md)
**What:** Filter out accepted orders from nearby screen
**Priority:** ⚡ HIGH
**Start Here:** 👈 **BEGIN WITH THIS TASK**

---

#### ✅ Task 2: Change Reminder Interval (10 min)
**File:** [`Q_TASK_2_Change_Reminder_Interval.md`](Q_TASK_2_Change_Reminder_Interval.md)
**What:** Change reminders from 1 minute → 5 minutes
**Priority:** ⚡ HIGH

---

#### ✅ Task 7: Improve Balance Feedback (30 min)
**File:** [`Q_TASK_7_Improve_Balance_Feedback.md`](Q_TASK_7_Improve_Balance_Feedback.md)
**What:** Better error message when wallet balance insufficient
**Priority:** ⚡ HIGH

---

### **Phase 2: Medium Tasks (2 hours total)**

#### ✅ Task 5: Notification Colors (30 min)
**File:** [`Q_TASK_5_Notification_Colors.md`](Q_TASK_5_Notification_Colors.md)
**What:** Red for rejection, Yellow for acceptance, Blue for updates
**Priority:** 🟡 MEDIUM

---

#### ✅ Task 4: Customer Phone Display (1 hour)
**File:** [`Q_TASK_4_Customer_Phone_README.md`](Q_TASK_4_Customer_Phone_README.md)
**What:** Show customer phone number prominently after acceptance
**Priority:** 🟡 MEDIUM
**Sub-tasks:**
- Part A: [`Q_TASK_4A_Backend_Customer_Phone.md`](Q_TASK_4A_Backend_Customer_Phone.md)
- Part B: [`Q_TASK_4B_Order_Model_Phone.md`](Q_TASK_4B_Order_Model_Phone.md)
- Part C: [`Q_TASK_4C_Display_Phone_UI.md`](Q_TASK_4C_Display_Phone_UI.md)

---

### **Phase 3: Complex Tasks (3 hours total)**

#### ✅ Task 3: Cancellation Flow (2 hours)
**File:** [`Q_TASK_3_Cancellation_Flow_README.md`](Q_TASK_3_Cancellation_Flow_README.md)
**What:** Add cancellation reasons + return order to matching
**Priority:** 🟡 MEDIUM
**Sub-tasks:** 5 parts (A → B → C → D → E)

---

#### ✅ Task 6: Admin Panel (1.5 hours)
**File:** [`Q_TASK_6_Admin_Stuck_Orders.md`](Q_TASK_6_Admin_Stuck_Orders.md)
**What:** Dashboard for admins to view stuck orders
**Priority:** 🟢 LOW

---

## ⏱️ Timeline

| Phase | Tasks | Time | Description |
|-------|-------|------|-------------|
| **Phase 1** | Tasks 1, 2, 7 | 1 hour | Quick fixes, immediate impact |
| **Phase 2** | Tasks 4, 5 | 2 hours | UI improvements |
| **Phase 3** | Tasks 3, 6 | 3 hours | Complex features |
| **TOTAL** | 7 tasks | **~6 hours** | Full implementation |

---

## 🎯 Execution Process

### For Each Task:

1. **Read the task file completely**
2. **Make the changes described**
3. **Run tests** (flutter analyze / npm run build)
4. **Report to Claude:**
   - Files modified
   - Changes made
   - Test results
5. **Wait for Claude's approval** ✅
6. **Move to next task**

---

## ✅ Testing Checklist

After completing ALL tasks:

- [ ] Accepted orders disappear from map
- [ ] Reminders arrive every 5 minutes
- [ ] Cancel dialog shows 4 reasons
- [ ] Cancelled orders return to matching
- [ ] Customer phone displays clearly
- [ ] Notifications have correct colors
- [ ] Admin can see stuck orders
- [ ] Insufficient balance shows clear error
- [ ] NO data loss in any scenario
- [ ] `flutter analyze` → 0 errors
- [ ] `npm run build` → success

---

## 🔄 Progress Tracking

Track your progress here:

- [ ] ✅ Task 1: Hide Accepted Orders
- [ ] ✅ Task 2: Change Reminder Interval
- [ ] ✅ Task 7: Improve Balance Feedback
- [ ] ✅ Task 5: Notification Colors
- [ ] ✅ Task 4: Customer Phone (Parts A, B, C)
- [ ] ✅ Task 3: Cancellation Flow (Parts A, B, C, D, E)
- [ ] ✅ Task 6: Admin Panel

---

## 📝 Supervision Notes

**After each task, Claude will:**
1. Review code quality
2. Verify CLAUDE.md compliance
3. Check for security issues
4. Approve or request fixes

**Do NOT proceed without approval!**

---

## 🆘 If You Get Stuck

1. **Stop immediately**
2. **Report the issue to Claude** with:
   - Task number
   - Error message
   - What you tried
3. **Wait for guidance**

---

## 🎉 Final Deployment

After ALL tasks complete and approved:

```bash
# Flutter apps
cd apps/wawapp_driver
flutter analyze
flutter build apk --release

# Cloud Functions
cd functions
npm run build
firebase deploy --only functions
```

---

**🚀 Ready to Start?**

**Open:** [`Q_TASK_1_Hide_Accepted_Orders.md`](Q_TASK_1_Hide_Accepted_Orders.md)

**Good luck! Claude is supervising. 🤖**
