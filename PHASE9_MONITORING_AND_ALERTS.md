# Phase 9: Monitoring & Alerts System

**WawApp Production Monitoring**  
**Version**: 1.0  
**Date**: December 2025  
**Status**: 🔴 CRITICAL - Production Monitoring Setup

---

## 🎯 Executive Summary

This document defines the **complete monitoring and alerting strategy** for WawApp production environment. The monitoring system provides real-time visibility into system health, performance, and financial operations with automated alerts for critical issues.

**Monitoring Scope:**
- ✅ Firebase Cloud Functions (execution, errors, latency)
- ✅ Firestore Database (reads, writes, errors)
- ✅ Authentication System (sign-ins, failures)
- ✅ Admin Panel (availability, performance)
- ✅ Financial Operations (settlements, payouts, wallet accuracy)
- ✅ Business Metrics (orders, revenue, driver activity)

**Alert Channels:**
- 🔔 Email (Primary)
- 📱 Telegram Bot (Real-time)
- 💬 Slack Workspace (Team notifications)
- 📲 SMS (Critical only)

---

## 📋 Table of Contents

1. [Monitoring Architecture](#monitoring-architecture)
2. [Key Metrics & Thresholds](#key-metrics--thresholds)
3. [Alert Configuration](#alert-configuration)
4. [Firebase Monitoring Setup](#firebase-monitoring-setup)
5. [Custom Monitoring Dashboard](#custom-monitoring-dashboard)
6. [Alert Response Procedures](#alert-response-procedures)
7. [On-Call Rotation](#on-call-rotation)
8. [Monitoring Tools & Access](#monitoring-tools--access)

---

## 🏗️ Monitoring Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                   MONITORING ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐     │
│  │                   DATA SOURCES                          │     │
│  ├────────────────────────────────────────────────────────┤     │
│  │                                                         │     │
│  │  Cloud Functions ──┐                                   │     │
│  │  Firestore ────────┼──> Firebase Monitoring Console   │     │
│  │  Auth ─────────────┤                                   │     │
│  │  Hosting ──────────┘                                   │     │
│  │                                                         │     │
│  │  Custom Metrics ───> Cloud Logging                     │     │
│  │  Application Logs ─> Log Explorer                      │     │
│  └────────────────────────────────────────────────────────┘     │
│                            │                                     │
│                            ▼                                     │
│  ┌────────────────────────────────────────────────────────┐     │
│  │                ALERT ROUTING                            │     │
│  ├────────────────────────────────────────────────────────┤     │
│  │                                                         │     │
│  │  Firebase Alerts ──> Cloud Monitoring                  │     │
│  │  Custom Alerts ────> Alert Policies                    │     │
│  │  Budget Alerts ────> Billing Notifications             │     │
│  │                                                         │     │
│  └────────────────────────────────────────────────────────┘     │
│                            │                                     │
│                            ▼                                     │
│  ┌────────────────────────────────────────────────────────┐     │
│  │              NOTIFICATION CHANNELS                      │     │
│  ├────────────────────────────────────────────────────────┤     │
│  │                                                         │     │
│  │  🔴 CRITICAL:  SMS + Telegram + Email + Slack         │     │
│  │  🟠 HIGH:      Telegram + Email + Slack                │     │
│  │  🟡 MEDIUM:    Email + Slack                            │     │
│  │  🟢 LOW:       Slack only                               │     │
│  │                                                         │     │
│  └────────────────────────────────────────────────────────┘     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Monitoring Layers

#### Layer 1: Infrastructure Monitoring
- **Firebase Console**: Native monitoring for all Firebase services
- **Cloud Monitoring**: GCP-level metrics and dashboards
- **Uptime Checks**: Admin Panel availability monitoring

#### Layer 2: Application Monitoring
- **Structured Logging**: JSON-formatted logs with severity levels
- **Error Tracking**: Automatic error aggregation and alerting
- **Performance Metrics**: Function execution times, database latency

#### Layer 3: Business Monitoring
- **Financial Metrics**: Settlement accuracy, payout success rate
- **Operational Metrics**: Order processing, driver activity
- **User Metrics**: Admin user actions, authentication events

---

## 📊 Key Metrics & Thresholds

### 1. Cloud Functions Monitoring

#### **Critical Functions**

| Function | Metric | 🟢 Normal | 🟡 Warning | 🔴 Critical | Alert |
|----------|--------|----------|-----------|------------|-------|
| `onOrderCompleted` | Error Rate | < 1% | 1-5% | > 5% | Email + Telegram |
| `onOrderCompleted` | Execution Time | < 30s | 30-60s | > 60s | Email |
| `adminCreatePayoutRequest` | Error Rate | 0% | 0% | > 0% | SMS + Email + Telegram |
| `adminCreatePayoutRequest` | Execution Time | < 10s | 10-30s | > 30s | Email |
| `settleOrder` | Failure Rate | 0% | 0% | > 0% | SMS + Email + Telegram |
| `getFinancialReport` | Error Rate | < 2% | 2-10% | > 10% | Email |
| `getReportsOverview` | Execution Time | < 5s | 5-10s | > 10s | Email |

**Alert Examples:**

```yaml
# onOrderCompleted Error Rate Alert
name: "Order Settlement Error Rate"
condition: "error_rate > 5% over 5 minutes"
severity: CRITICAL
channels: [SMS, Telegram, Email, Slack]
message: |
  🚨 CRITICAL: Order settlement errors > 5%
  Current rate: {error_rate}%
  Failed settlements: {failed_count}
  Action: Check Cloud Functions logs immediately
  Runbook: https://docs.wawapp.com/runbooks/settlement-errors
```

```yaml
# adminCreatePayoutRequest Failure Alert
name: "Payout Creation Failed"
condition: "any failure in last 5 minutes"
severity: CRITICAL
channels: [SMS, Telegram, Email]
message: |
  🚨 CRITICAL: Payout creation failed
  Driver: {driver_id}
  Amount: {amount} MRU
  Error: {error_message}
  Action: Investigate immediately, check wallet balances
```

#### **Supporting Functions**

| Function | Metric | 🟢 Normal | 🟡 Warning | 🔴 Critical | Alert |
|----------|--------|----------|-----------|------------|-------|
| `notifyOrderEvents` | Error Rate | < 5% | 5-10% | > 10% | Slack |
| `aggregateDriverRating` | Error Rate | < 5% | 5-10% | > 10% | Slack |
| `cleanStaleDriverLocations` | Success Rate | > 95% | 90-95% | < 90% | Email |
| `expireStaleOrders` | Success Rate | > 95% | 90-95% | < 90% | Email |

---

### 2. Firestore Database Monitoring

| Metric | 🟢 Normal | 🟡 Warning | 🔴 Critical | Alert |
|--------|----------|-----------|------------|-------|
| **Document Reads/min** | < 10,000 | 10K-50K | > 50K | Email (cost spike) |
| **Document Writes/min** | < 5,000 | 5K-20K | > 20K | Email (cost spike) |
| **Read Errors** | < 10/hour | 10-50/hour | > 50/hour | Email + Telegram |
| **Write Errors** | < 5/hour | 5-20/hour | > 20/hour | SMS + Email + Telegram |
| **Query Latency (p95)** | < 500ms | 500ms-2s | > 2s | Email |
| **Hot Spot Warnings** | 0 | 1-2 | > 2 | Email |

**Critical Collections:**

- `orders`: Write errors indicate order processing issues
- `wallets`: Write errors indicate settlement failures (CRITICAL)
- `transactions`: Write errors indicate ledger corruption (CRITICAL)
- `payouts`: Write errors indicate payout processing failures (CRITICAL)

**Alert Examples:**

```yaml
# Wallet Write Error Alert
name: "Wallet Write Failure"
condition: "wallet write error detected"
severity: CRITICAL
channels: [SMS, Telegram, Email]
message: |
  🚨 CRITICAL: Wallet write failed
  Wallet: {wallet_id}
  Operation: {operation_type}
  Error: {error_message}
  Impact: Financial data integrity at risk
  Action: Stop all financial operations, investigate immediately
```

```yaml
# Transaction Write Error Alert
name: "Transaction Ledger Error"
condition: "transaction write error detected"
severity: CRITICAL
channels: [SMS, Telegram, Email]
message: |
  🚨 CRITICAL: Transaction ledger write failed
  Transaction: {transaction_id}
  Wallet: {wallet_id}
  Amount: {amount} MRU
  Impact: Audit trail incomplete
  Action: Verify wallet balance consistency
```

---

### 3. Authentication Monitoring

| Metric | 🟢 Normal | 🟡 Warning | 🔴 Critical | Alert |
|--------|----------|-----------|------------|-------|
| **Failed Sign-ins** | < 5/hour | 5-20/hour | > 20/hour | Email |
| **Admin Sign-ins** | Normal pattern | Unusual time/location | Multiple failed attempts | Telegram + Email |
| **Auth Errors** | < 10/hour | 10-30/hour | > 30/hour | Email |
| **Token Refresh Failures** | < 5/hour | 5-15/hour | > 15/hour | Email |
| **Unauthorized Access Attempts** | 0 | 1-3 | > 3 | SMS + Telegram |

**Alert Examples:**

```yaml
# Multiple Failed Admin Sign-ins
name: "Admin Brute Force Attempt"
condition: "> 5 failed sign-ins from same IP in 10 minutes"
severity: HIGH
channels: [Telegram, Email, Slack]
message: |
  🔴 SECURITY: Potential brute force attack
  IP: {source_ip}
  Failed attempts: {attempt_count}
  Target account: {email}
  Action: Review security logs, consider blocking IP
```

```yaml
# Unauthorized Admin Access
name: "Unauthorized Admin Access"
condition: "admin function called without isAdmin claim"
severity: CRITICAL
channels: [SMS, Telegram, Email]
message: |
  🚨 SECURITY: Unauthorized admin access attempt
  User: {user_email}
  Function: {function_name}
  IP: {source_ip}
  Action: Verify user permissions, review security rules
```

---

### 4. Admin Panel Monitoring

| Metric | 🟢 Normal | 🟡 Warning | 🔴 Critical | Alert |
|--------|----------|-----------|------------|-------|
| **Availability (Uptime)** | > 99.9% | 99.0-99.9% | < 99.0% | SMS + Telegram |
| **Response Time (p95)** | < 2s | 2-5s | > 5s | Email |
| **JavaScript Errors** | < 5/hour | 5-20/hour | > 20/hour | Email |
| **Failed API Calls** | < 1% | 1-5% | > 5% | Email + Telegram |
| **Page Load Time** | < 3s | 3-8s | > 8s | Slack |

**Alert Examples:**

```yaml
# Admin Panel Down
name: "Admin Panel Unavailable"
condition: "uptime check failed for 2 consecutive minutes"
severity: CRITICAL
channels: [SMS, Telegram, Email]
message: |
  🚨 CRITICAL: Admin Panel is DOWN
  URL: https://wawapp-952d6.web.app
  Status: {http_status_code}
  Duration: {downtime_minutes} minutes
  Action: Check Firebase Hosting status, verify deployment
```

```yaml
# High JavaScript Error Rate
name: "Admin Panel Error Spike"
condition: "JS error rate > 20/hour"
severity: HIGH
channels: [Email, Slack]
message: |
  🔴 Admin Panel experiencing errors
  Error rate: {error_rate}/hour
  Most common: {top_error_message}
  Action: Review browser console logs, check recent deployments
```

---

### 5. Financial Operations Monitoring

#### **Settlement Monitoring**

| Metric | 🟢 Normal | 🟡 Warning | 🔴 Critical | Alert |
|--------|----------|-----------|------------|-------|
| **Settlement Success Rate** | 100% | 99-100% | < 99% | SMS + Telegram + Email |
| **Settlement Latency** | < 30s | 30-60s | > 60s | Email |
| **Wallet Balance Discrepancy** | 0 | 0 | > 0 | SMS + Telegram + Email |
| **Unsettled Orders (> 5 min)** | 0 | 1-3 | > 3 | Telegram + Email |
| **Commission Calculation Error** | 0 | 0 | > 0 | SMS + Telegram + Email |

**Alert Examples:**

```yaml
# Settlement Failure
name: "Order Settlement Failed"
condition: "settlement function returns error"
severity: CRITICAL
channels: [SMS, Telegram, Email]
message: |
  🚨 CRITICAL: Order settlement failed
  Order: {order_id}
  Price: {order_price} MRU
  Driver: {driver_id}
  Error: {error_message}
  Impact: Driver not paid, wallet balance incorrect
  Action: Manual investigation required, verify wallet state
  Runbook: https://docs.wawapp.com/runbooks/settlement-failure
```

```yaml
# Wallet Balance Discrepancy
name: "Wallet Balance Mismatch"
condition: "wallet.balance ≠ (totalCredited - totalDebited)"
severity: CRITICAL
channels: [SMS, Telegram, Email]
message: |
  🚨 CRITICAL: Wallet balance inconsistency detected
  Wallet: {wallet_id}
  Current balance: {current_balance} MRU
  Expected balance: {expected_balance} MRU
  Discrepancy: {discrepancy} MRU
  Impact: Financial data integrity compromised
  Action: STOP all financial operations, audit wallet transactions
```

#### **Payout Monitoring**

| Metric | 🟢 Normal | 🟡 Warning | 🔴 Critical | Alert |
|--------|----------|-----------|------------|-------|
| **Payout Success Rate** | > 98% | 95-98% | < 95% | Email + Telegram |
| **Payout Creation Failures** | 0 | 0 | > 0 | SMS + Telegram + Email |
| **Pending Payouts (> 24h)** | 0 | 1-5 | > 5 | Email |
| **Rejected Payouts** | < 2% | 2-5% | > 5% | Email |
| **Payout Processing Time** | < 48h | 48-72h | > 72h | Email |

**Alert Examples:**

```yaml
# Payout Creation Failed
name: "Payout Request Failed"
condition: "adminCreatePayoutRequest returns error"
severity: CRITICAL
channels: [SMS, Telegram, Email]
message: |
  🚨 CRITICAL: Payout creation failed
  Driver: {driver_id}
  Amount: {requested_amount} MRU
  Admin: {admin_email}
  Error: {error_message}
  Available balance: {driver_balance} MRU
  Action: Verify driver wallet, check validation logic
```

```yaml
# Stale Pending Payouts
name: "Stale Payouts Detected"
condition: "payouts pending > 24 hours"
severity: HIGH
channels: [Email, Telegram]
message: |
  🔴 Payouts pending approval for > 24 hours
  Count: {pending_count}
  Total amount: {total_pending_amount} MRU
  Oldest: {oldest_payout_age} hours
  Action: Review pending payouts in Admin Panel
```

---

### 6. Business Metrics Monitoring

| Metric | 🟢 Normal | 🟡 Warning | 🔴 Critical | Alert |
|--------|----------|-----------|------------|-------|
| **Daily Orders** | Expected range | -20% from avg | -50% from avg | Email |
| **Order Completion Rate** | > 90% | 80-90% | < 80% | Email |
| **Driver Active Rate** | > 70% | 50-70% | < 50% | Slack |
| **Platform Revenue** | Expected range | -20% from avg | -50% from avg | Email |
| **Average Order Value** | Expected range | ±30% | ±50% | Email |

**Alert Examples:**

```yaml
# Order Volume Drop
name: "Order Volume Drop"
condition: "daily orders < 50% of 7-day average"
severity: HIGH
channels: [Email, Slack]
message: |
  🔴 Significant drop in order volume
  Current: {current_orders}
  7-day avg: {avg_orders}
  Change: {percentage_change}%
  Action: Check driver availability, verify app functionality
```

---

## 🔔 Alert Configuration

### Alert Severity Levels

| Severity | Response Time | Channels | On-Call Required |
|----------|--------------|----------|------------------|
| 🔴 **CRITICAL** | Immediate (< 5 min) | SMS + Telegram + Email + Slack | YES |
| 🟠 **HIGH** | < 15 minutes | Telegram + Email + Slack | YES |
| 🟡 **MEDIUM** | < 1 hour | Email + Slack | NO |
| 🟢 **LOW** | Best effort | Slack only | NO |

### Alert Notification Rules

#### Critical Alerts (CRITICAL)
- Financial operations: Settlement failures, wallet errors, payout failures
- Security: Unauthorized access, brute force attempts
- Availability: Admin Panel down, database unavailable
- Data integrity: Balance discrepancies, transaction errors

**Channels**: SMS + Telegram + Email + Slack  
**Recipients**: On-call engineer + CTO + Lead Backend Engineer

#### High Alerts (HIGH)
- Performance degradation: High latency, timeout spikes
- Error rate spikes: > 5% error rate on critical functions
- Security: Multiple failed auth attempts
- Business: Order volume drop > 50%

**Channels**: Telegram + Email + Slack  
**Recipients**: On-call engineer + DevOps team

#### Medium Alerts (MEDIUM)
- Warning thresholds: Approaching limits
- Cost spikes: Unexpected billing increases
- Slow performance: Latency approaching thresholds

**Channels**: Email + Slack  
**Recipients**: DevOps team

#### Low Alerts (LOW)
- Informational: Routine maintenance completed
- Optimization opportunities: Query performance suggestions

**Channels**: Slack only  
**Recipients**: DevOps channel

---

## 🔧 Firebase Monitoring Setup

### Step 1: Enable Firebase Performance Monitoring

```bash
# Install Firebase Performance SDK (if not already)
cd apps/wawapp_admin
flutter pub add firebase_performance
```

**Configure in `lib/main.dart`:**

```dart
import 'package:firebase_performance/firebase_performance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Enable Performance Monitoring
  final performance = FirebasePerformance.instance;
  await performance.setPerformanceCollectionEnabled(true);
  
  // Custom trace for app initialization
  final trace = performance.newTrace('app_initialization');
  await trace.start();
  
  runApp(MyApp());
  
  await trace.stop();
}
```

---

### Step 2: Configure Cloud Monitoring Alerts

**Navigate to**: [Google Cloud Console - Monitoring](https://console.cloud.google.com/monitoring)

#### A. Create Alert Policy for Function Errors

```yaml
# Cloud Functions Error Rate Alert
Display Name: "[CRITICAL] Cloud Functions Error Rate"
Resource Type: Cloud Function
Metric: executions/error_count
Condition: Any time series violates
Threshold: > 5 errors in 5 minutes
Notification Channels:
  - Email: devops@wawapp.com
  - Telegram: @wawapp_alerts_bot
  - Slack: #wawapp-alerts
Documentation: |
  CRITICAL: Cloud Functions experiencing errors
  1. Check Cloud Functions logs
  2. Identify failing function
  3. Review recent deployments
  4. Rollback if necessary
  Runbook: https://docs.wawapp.com/runbooks/function-errors
```

#### B. Create Alert Policy for Firestore Errors

```yaml
# Firestore Write Error Alert
Display Name: "[CRITICAL] Firestore Write Errors"
Resource Type: Firestore Database
Metric: document/write_count (filter: status=error)
Condition: Any time series violates
Threshold: > 10 errors in 5 minutes
Notification Channels:
  - Email: devops@wawapp.com
  - SMS: +222XXXXXXXX
  - Telegram: @wawapp_alerts_bot
Documentation: |
  CRITICAL: Firestore write operations failing
  1. Check Firestore status page
  2. Review security rules
  3. Verify database quotas
  4. Check for permission issues
  Runbook: https://docs.wawapp.com/runbooks/firestore-errors
```

#### C. Create Alert Policy for Admin Panel Uptime

```yaml
# Admin Panel Uptime Check
Display Name: "[CRITICAL] Admin Panel Down"
Check Type: HTTP Uptime Check
URL: https://wawapp-952d6.web.app/admin
Frequency: Every 1 minute
Timeout: 10 seconds
Expected Status: 200 OK
Condition: Check fails for 2 consecutive periods
Notification Channels:
  - SMS: +222XXXXXXXX
  - Telegram: @wawapp_alerts_bot
  - Email: devops@wawapp.com
  - Slack: #wawapp-critical
Documentation: |
  CRITICAL: Admin Panel is unreachable
  1. Verify Firebase Hosting status
  2. Check DNS resolution
  3. Review recent deployments
  4. Check for DDoS or traffic spike
  Runbook: https://docs.wawapp.com/runbooks/panel-down
```

---

### Step 3: Configure Budget Alerts

**Navigate to**: [Google Cloud Console - Billing - Budgets](https://console.cloud.google.com/billing/budgets)

```yaml
# Monthly Budget Alert
Budget Name: "WawApp Production Monthly Budget"
Projects: wawapp-952d6
Amount: $500 USD / month
Alert Thresholds:
  - 50% ($250): Email to billing@wawapp.com + Slack #finance
  - 80% ($400): Email to CTO + CFO + Telegram
  - 100% ($500): SMS + Email + Telegram (all executives)
  - 120% ($600): CRITICAL alert + possible spend cap
Actions:
  - At 100%: Review cost optimization plan
  - At 120%: Consider temporary service restrictions
```

---

### Step 4: Configure Custom Log-Based Metrics

**Cloud Logging - Log-based Metrics**

#### A. Settlement Failure Metric

```yaml
Name: settlement_failures
Description: "Count of order settlement failures"
Resource Type: Cloud Function
Filter: |
  resource.type="cloud_function"
  resource.labels.function_name="onOrderCompleted"
  severity="ERROR"
  jsonPayload.event="settlement_failed"
Metric Type: Counter
Labels:
  - error_type: jsonPayload.errorType
  - order_id: jsonPayload.orderId
```

**Create Alert from Metric:**
```yaml
Condition: settlement_failures > 0 in 5 minutes
Severity: CRITICAL
Channels: [SMS, Telegram, Email]
```

#### B. Payout Failure Metric

```yaml
Name: payout_creation_failures
Description: "Count of failed payout creation attempts"
Resource Type: Cloud Function
Filter: |
  resource.type="cloud_function"
  resource.labels.function_name="adminCreatePayoutRequest"
  severity="ERROR"
  jsonPayload.event="payout_creation_failed"
Metric Type: Counter
Labels:
  - error_type: jsonPayload.errorType
  - driver_id: jsonPayload.driverId
```

#### C. Wallet Discrepancy Metric

```yaml
Name: wallet_balance_discrepancies
Description: "Wallet balance mismatches detected"
Resource Type: Cloud Function
Filter: |
  resource.type="cloud_function"
  severity="ERROR"
  jsonPayload.event="wallet_balance_mismatch"
Metric Type: Counter
Labels:
  - wallet_id: jsonPayload.walletId
  - discrepancy_amount: jsonPayload.discrepancy
```

---

## 📊 Custom Monitoring Dashboard

### Firebase Console Dashboard

**URL**: https://console.firebase.google.com/project/wawapp-952d6/overview

**Key Views:**

1. **Performance Dashboard**
   - Page load times (Admin Panel)
   - Network request durations
   - Screen rendering performance

2. **Functions Dashboard**
   - Invocation count per function
   - Execution duration (p50, p95, p99)
   - Error rate per function
   - Memory usage

3. **Firestore Dashboard**
   - Read/write operations per collection
   - Query performance
   - Index usage
   - Storage size

4. **Auth Dashboard**
   - Sign-in methods usage
   - Sign-in success/failure rate
   - Active users

---

### Cloud Monitoring Custom Dashboard

**Create Custom Dashboard**: [Google Cloud Monitoring Dashboard](https://console.cloud.google.com/monitoring/dashboards)

**Dashboard Name**: "WawApp Production Overview"

#### Dashboard Layout

```
┌─────────────────────────────────────────────────────────────────┐
│              WAWAPP PRODUCTION MONITORING DASHBOARD              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │  System Health   │  │  Function Perf   │  │  Error Rate  │  │
│  │  ● Uptime: 99.9% │  │  ● Avg: 1.2s    │  │  ● 0.3%      │  │
│  │  ● Status: OK    │  │  ● p95: 3.5s    │  │  ● 2 errors  │  │
│  └──────────────────┘  └──────────────────┘  └──────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │            Financial Operations (Last 24h)               │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  ● Orders Settled: 1,247 / 1,247 (100%)                │   │
│  │  ● Settlement Latency: 18s avg (target: < 30s)         │   │
│  │  ● Payouts Created: 34 (0 failures)                    │   │
│  │  ● Wallet Balance Accuracy: 100%                       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌────────────────────────┐  ┌────────────────────────────┐    │
│  │  Firestore Ops         │  │  Authentication            │    │
│  │  ─────────────────     │  │  ──────────────────        │    │
│  │  Reads:  2.3K/min     │  │  Sign-ins:  47/hour       │    │
│  │  Writes:   840/min    │  │  Failures:   2/hour       │    │
│  │  Errors:     0        │  │  Admin Access: 12/hour    │    │
│  └────────────────────────┘  └────────────────────────────┘    │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Business Metrics (Today)                    │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  ● Total Orders: 1,247                                  │   │
│  │  ● Completed: 1,189 (95.3%)                            │   │
│  │  ● Cancelled: 58 (4.7%)                                │   │
│  │  ● Revenue: 625,000 MRU                                │   │
│  │  ● Driver Earnings: 500,000 MRU (80%)                  │   │
│  │  ● Platform Fee: 125,000 MRU (20%)                     │   │
│  │  ● Active Drivers: 87                                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Cost Tracking (Month-to-Date)               │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  ● Total Spend: $127.45 / $500 budget (25.5%)          │   │
│  │  ● Cloud Functions: $45.20 (35%)                       │   │
│  │  ● Firestore: $62.10 (49%)                             │   │
│  │  ● Hosting: $8.15 (6%)                                 │   │
│  │  ● Other: $12.00 (10%)                                 │   │
│  │  ● Projected: $382 (76% of budget)                     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Dashboard Widgets:**

1. **Uptime Checks** (Scorecard)
   - Admin Panel availability
   - API endpoint health

2. **Cloud Functions Performance** (Line Chart)
   - Execution duration (p50, p95, p99)
   - Invocation rate
   - Error rate

3. **Firestore Operations** (Stacked Area Chart)
   - Reads per collection
   - Writes per collection
   - Error rate

4. **Financial Operations** (Table)
   - Settlements (success/failure)
   - Payout requests
   - Wallet operations

5. **Error Breakdown** (Pie Chart)
   - Errors by function
   - Errors by type

6. **Cost Tracking** (Bar Chart)
   - Daily spend by service
   - Cumulative monthly spend

---

## 🚨 Alert Response Procedures

### Response Workflow

```
Alert Received
    │
    ▼
Acknowledge Alert (< 2 min)
    │
    ▼
Assess Severity
    │
    ├── CRITICAL ──> Immediate Action + Escalate
    │                │
    │                ▼
    │           Stop Impacted Operations
    │                │
    │                ▼
    │           Investigate Root Cause
    │                │
    │                ▼
    │           Implement Fix or Rollback
    │                │
    │                ▼
    │           Verify Resolution
    │                │
    │                └──> Post-Incident Review
    │
    └── HIGH/MEDIUM ──> Investigate + Fix (within SLA)
                        │
                        ▼
                   Document Resolution
```

---

### Incident Response Checklist

#### For CRITICAL Alerts

- [ ] **Acknowledge** alert in monitoring system (< 2 min)
- [ ] **Notify** team in Slack #wawapp-incidents
- [ ] **Assess** impact on users and business operations
- [ ] **Stop** affected operations if data integrity at risk
- [ ] **Create** incident ticket with severity level
- [ ] **Investigate** root cause using logs and dashboards
- [ ] **Implement** fix or execute rollback procedure
- [ ] **Verify** resolution with smoke tests
- [ ] **Communicate** status to stakeholders
- [ ] **Document** incident in post-mortem
- [ ] **Schedule** follow-up review meeting

#### For HIGH Alerts

- [ ] **Acknowledge** alert (< 15 min)
- [ ] **Investigate** issue using monitoring tools
- [ ] **Determine** if immediate action required
- [ ] **Implement** fix or mitigation
- [ ] **Monitor** metrics to confirm resolution
- [ ] **Update** alert or close ticket
- [ ] **Document** resolution steps

#### For MEDIUM/LOW Alerts

- [ ] **Review** alert during business hours
- [ ] **Add** to backlog if action needed
- [ ] **Schedule** fix in next sprint
- [ ] **Close** alert if informational

---

### Common Alert Scenarios

#### Scenario 1: Settlement Failure

**Alert**: "Order Settlement Failed"

**Immediate Actions:**
1. Check order details in Firestore
2. Verify driver and platform wallet states
3. Check transaction ledger for partial writes
4. Review Cloud Function logs for error details

**Investigation Steps:**
```bash
# Check order document
firebase firestore:get /orders/{orderId}

# Check driver wallet
firebase firestore:get /wallets/{driverId}

# Check platform wallet
firebase firestore:get /wallets/platform_main

# Check transactions for this order
firebase firestore:query /transactions \
  --where orderId={orderId}

# Review function logs
gcloud logging read \
  "resource.type=cloud_function AND \
   resource.labels.function_name=onOrderCompleted AND \
   jsonPayload.orderId={orderId}" \
  --limit 50 \
  --format json
```

**Resolution Options:**
- If wallet update failed: Retry settlement manually
- If commission calculation wrong: Fix code, redeploy, manual correction
- If transaction write failed: Audit ledger, manual transaction entry

**Post-Resolution:**
- Verify wallet balances match expected values
- Confirm transaction ledger is complete
- Update order.isSettled flag if necessary

---

#### Scenario 2: Payout Creation Failed

**Alert**: "Payout Request Failed"

**Immediate Actions:**
1. Check driver wallet balance
2. Verify payout amount within limits (10K-1M MRU)
3. Check admin user permissions
4. Review validation errors

**Investigation Steps:**
```bash
# Check driver wallet
firebase firestore:get /wallets/{driverId}

# Check recent payouts
firebase firestore:query /payouts \
  --where driverId={driverId} \
  --order-by createdAt desc \
  --limit 10

# Check function logs
gcloud logging read \
  "resource.type=cloud_function AND \
   resource.labels.function_name=adminCreatePayoutRequest AND \
   jsonPayload.driverId={driverId}" \
  --limit 20
```

**Common Issues:**
- Insufficient balance: Driver requested more than available
- Pending payout exists: Another payout already in progress
- Invalid amount: Outside min/max limits
- Permission error: Admin doesn't have `isAdmin` claim

**Resolution:**
- Communicate with driver about available balance
- Wait for pending payout to complete
- Adjust payout amount to valid range
- Verify admin user custom claims

---

#### Scenario 3: Admin Panel Down

**Alert**: "Admin Panel Unavailable"

**Immediate Actions:**
1. Verify Firebase Hosting status
2. Check recent deployments
3. Test direct URL access
4. Review DNS resolution

**Investigation Steps:**
```bash
# Check Firebase Hosting status
firebase hosting:channel:list

# Test HTTP response
curl -I https://wawapp-952d6.web.app/admin

# Check deployment history
firebase hosting:releases:list --limit 5

# Test DNS resolution
nslookup wawapp-952d6.web.app
```

**Common Issues:**
- Deployment in progress: Wait for completion
- Build error: Check build logs, rollback if needed
- DNS issue: Check domain configuration
- CDN cache issue: Purge cache

**Resolution:**
- If build error: Rollback to previous version
- If DNS issue: Update DNS records
- If CDN issue: Clear cache via Firebase Console

---

## 👥 On-Call Rotation

### On-Call Schedule

| Week | Primary | Secondary | Backup |
|------|---------|-----------|--------|
| Week 1 | Engineer A | Engineer B | CTO |
| Week 2 | Engineer B | Engineer C | CTO |
| Week 3 | Engineer C | Engineer A | CTO |
| Week 4 | Engineer A | Engineer B | CTO |

### On-Call Responsibilities

**Primary On-Call:**
- Respond to CRITICAL/HIGH alerts within SLA
- Investigate and resolve issues
- Escalate to secondary if needed
- Document incidents

**Secondary On-Call:**
- Available for escalations
- Assist with complex issues
- Provide second opinion

**Backup (CTO):**
- Final escalation point
- Decision authority for major incidents
- Communication with executives

### On-Call Handoff Checklist

- [ ] Review open incidents
- [ ] Check recent alerts and trends
- [ ] Review upcoming deployments
- [ ] Verify monitoring systems are healthy
- [ ] Ensure access to all tools and dashboards
- [ ] Test alert notification channels
- [ ] Review runbooks and documentation

---

## 🛠️ Monitoring Tools & Access

### Required Tools

| Tool | URL | Purpose | Access Level |
|------|-----|---------|--------------|
| **Firebase Console** | https://console.firebase.google.com/project/wawapp-952d6 | Primary monitoring, functions, database | Admin |
| **Cloud Monitoring** | https://console.cloud.google.com/monitoring | Advanced metrics, custom dashboards | Monitoring Viewer |
| **Cloud Logging** | https://console.cloud.google.com/logs | Detailed logs, log-based metrics | Logs Viewer |
| **Firebase Hosting** | https://console.firebase.google.com/project/wawapp-952d6/hosting | Admin Panel status | Admin |
| **Telegram Bot** | @wawapp_alerts_bot | Real-time alerts | All engineers |
| **Slack Workspace** | wawapp.slack.com | Team collaboration, alert channel | All team |

### Access Requirements

**Production Access:**
- Firebase Admin: Lead Engineers, CTO
- Cloud Monitoring Viewer: All engineers
- Logs Viewer: All engineers
- Firestore Read: All engineers
- Firestore Write: Lead Engineers only (with approval)

**Alert Channel Access:**
- Email: All engineers + management
- Telegram: On-call rotation + leads
- Slack: #wawapp-alerts (all engineers)
- SMS: On-call primary only

---

## 📚 Runbook Quick Links

| Scenario | Runbook URL |
|----------|-------------|
| Settlement Failure | `/runbooks/settlement-failure.md` |
| Payout Issue | `/runbooks/payout-issue.md` |
| Admin Panel Down | `/runbooks/panel-down.md` |
| Database Error | `/runbooks/database-error.md` |
| Auth Issue | `/runbooks/auth-issue.md` |
| Performance Degradation | `/runbooks/performance-degradation.md` |
| Rollback Procedure | `/runbooks/rollback.md` |
| Data Corruption | `/runbooks/data-corruption.md` |

---

## ✅ Phase 9 Monitoring Setup Checklist

### Initial Setup

- [ ] **Firebase Performance Monitoring** enabled
- [ ] **Cloud Monitoring** alerts configured
- [ ] **Uptime checks** created for Admin Panel
- [ ] **Budget alerts** configured ($500/month with thresholds)
- [ ] **Custom log-based metrics** created
- [ ] **Custom dashboard** created in Cloud Monitoring
- [ ] **Notification channels** configured (Email, Telegram, Slack, SMS)
- [ ] **Alert policies** created for all CRITICAL scenarios
- [ ] **On-call rotation** established
- [ ] **Runbooks** created for common scenarios

### Validation

- [ ] **Test alerts** by triggering test failures
- [ ] **Verify** notifications received on all channels
- [ ] **Confirm** alert routing to correct severity levels
- [ ] **Validate** dashboard displays real-time data
- [ ] **Test** on-call escalation procedure
- [ ] **Review** alert thresholds with team

### Documentation

- [ ] **Monitoring documentation** complete
- [ ] **Runbooks** created and accessible
- [ ] **Team training** completed
- [ ] **Access permissions** granted

---

## 🎯 Success Criteria

✅ **All critical alerts configured and tested**  
✅ **Real-time visibility into system health**  
✅ **< 5 minute response time for CRITICAL alerts**  
✅ **< 15 minute response time for HIGH alerts**  
✅ **On-call rotation established with coverage**  
✅ **Custom dashboard provides actionable insights**  
✅ **Alert fatigue minimized (< 5 false alarms per week)**  
✅ **Incident response procedures documented**

---

## 📊 Next Steps

1. **Execute Monitoring Setup** (2-3 hours)
   - Configure all alert policies
   - Create custom dashboard
   - Set up notification channels
   - Test alert delivery

2. **Team Training** (1 hour)
   - Review monitoring dashboard
   - Practice alert response
   - Walk through runbooks

3. **Go-Live Validation** (During launch)
   - Monitor dashboard during deployment
   - Verify alerts trigger correctly
   - Confirm notification delivery

4. **Post-Launch Tuning** (First week)
   - Adjust alert thresholds based on real traffic
   - Reduce false positives
   - Add additional metrics as needed

---

**Document Version**: 1.0  
**Last Updated**: December 2025  
**Owner**: DevOps Team  
**Status**: 🚀 READY FOR IMPLEMENTATION
