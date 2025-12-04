# WawApp Fixloops Design Document

**Version:** 1.0
**Last Updated:** 2025-12-03
**Purpose:** Define self-healing automation loops for WawApp development, testing, and builds.

---

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Fixloop Types](#fixloop-types)
4. [Safety Guardrails](#safety-guardrails)
5. [Success & Failure Criteria](#success--failure-criteria)
6. [Usage Guide](#usage-guide)

---

## Overview

### What are Fixloops?
Fixloops are automated debugging cycles that:
1. **Run** an operation (dev server, tests, or build)
2. **Detect** failures from logs
3. **Analyze** root causes using AI
4. **Fix** code with minimal targeted changes
5. **Re-run** to verify the fix
6. **Stop** when stable or max iterations reached

### Goals
- **Reduce manual debugging time** for common crashes and build errors
- **Maintain code safety** through backups and controlled iterations
- **Learn from failures** to improve WawApp stability
- **Never introduce breaking changes** through over-engineering

### Non-Goals
- Replace human developers (fixloops assist, not replace)
- Fix complex architectural issues (these require human design)
- Modify production code without review
- Execute on `main` branch directly

---

## Architecture

### Directory Structure
```
tools/fixloops/
├── FIXLOOPS_DESIGN.md          # This document
├── README.md                   # Human-friendly usage guide
├── logs/                       # Runtime logs (git-ignored)
│   ├── dev_client.log
│   ├── dev_driver.log
│   ├── tests.log
│   ├── build_client.log
│   └── build_driver.log
├── backups/                    # Timestamped backups (git-ignored)
│   └── 2025-12-03_14-30-15/
│       └── [modified files]
├── run_dev_client.ps1          # Start client dev server
├── run_dev_driver.ps1          # Start driver dev server
├── run_tests.ps1               # Run Flutter tests
├── run_build_client.ps1        # Build client APK
└── run_build_driver.ps1        # Build driver APK
```

### Claude Commands
```
.claude/commands/
├── fixloop-dev-client.md       # /fixloop-dev-client
├── fixloop-dev-driver.md       # /fixloop-dev-driver
├── fixloop-tests.md            # /fixloop-tests
└── fixloop-build.md            # /fixloop-build
```

### Flow Diagram
```
┌─────────────────────────────────────────────────────────┐
│  Human invokes: /fixloop-dev-client                    │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│  Claude: Run tools/fixloops/run_dev_client.ps1         │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│  Script: flutter run → logs/dev_client.log             │
│  Exit Code: 0 (success) or non-zero (failure)          │
└─────────────────┬───────────────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
   [Success]           [Failure]
        │                   │
        │                   ▼
        │      ┌─────────────────────────────────┐
        │      │ Claude: Parse logs for errors   │
        │      │ - Stack traces                  │
        │      │ - Exception types                │
        │      │ - Firebase / plugin errors       │
        │      └─────────┬───────────────────────┘
        │                │
        │                ▼
        │      ┌─────────────────────────────────┐
        │      │ Backup files to be modified     │
        │      │ → backups/[timestamp]/          │
        │      └─────────┬───────────────────────┘
        │                │
        │                ▼
        │      ┌─────────────────────────────────┐
        │      │ Apply minimal code fix          │
        │      │ (Edit tool, no git commands)    │
        │      └─────────┬───────────────────────┘
        │                │
        │                ▼
        │      ┌─────────────────────────────────┐
        │      │ Increment iteration counter     │
        │      │ Max: 3 for dev, 5 for test/build│
        │      └─────────┬───────────────────────┘
        │                │
        │                ▼
        │         [Loop back to run script]
        │                │
        └────────────────┴──────► [Report results to human]
```

---

## Fixloop Types

### 1. Dev Fixloop (Client & Driver)

**Purpose:** Debug runtime crashes during local development.

**Invocation:**
- `/fixloop-dev-client` → wawapp_client
- `/fixloop-dev-driver` → wawapp_driver

**Process:**
1. Run `tools/fixloops/run_dev_client.ps1` (or driver variant)
2. Monitor `logs/dev_client.log` for crashes
3. Common issues detected:
   - Null pointer exceptions
   - Firebase initialization errors
   - Plugin version conflicts
   - Missing API keys
   - GoRouter route mismatches
   - Riverpod state errors
4. Apply targeted fixes (never refactor)
5. Re-run dev server
6. Stop when:
   - App runs without crashing for 2+ hot reloads
   - Max 3 iterations reached
   - Structural issue detected (ask human)

**Max Iterations:** 3

**Typical Fixes:**
- Add null checks
- Initialize Firebase before runApp
- Fix import paths
- Add missing dependencies to pubspec.yaml

---

### 2. Test Fixloop

**Purpose:** Self-heal failing unit/widget/integration tests.

**Invocation:** `/fixloop-tests`

**Process:**
1. Run `tools/fixloops/run_tests.ps1`
2. Parse `logs/tests.log` for:
   - Failed test names
   - Assertion errors
   - Mock/stub issues
   - Async timing problems
3. Apply fixes to:
   - Test code (fix expectations)
   - Source code (fix implementation)
   - Test setup (fix mocks/providers)
4. Re-run tests
5. Stop when:
   - All tests pass
   - Max 5 iterations reached
   - Flaky test detected (needs human analysis)

**Max Iterations:** 5

**Typical Fixes:**
- Update test expectations
- Fix async/await usage
- Correct provider overrides
- Add missing test dependencies

---

### 3. Build Fixloop

**Purpose:** Ensure `flutter build apk` succeeds for both apps.

**Invocation:** `/fixloop-build`

**Process:**
1. Run `tools/fixloops/run_build_client.ps1`
2. On failure, parse `logs/build_client.log` for:
   - Gradle dependency conflicts
   - AndroidManifest errors
   - ProGuard / R8 issues
   - Firebase config problems
   - Signing errors
3. Apply targeted fixes
4. Re-run build
5. Repeat for driver app
6. Stop when:
   - Both APKs build successfully
   - Max 5 iterations reached per app
   - Complex Gradle issue (ask human)

**Max Iterations:** 5 per app

**Typical Fixes:**
- Update Gradle dependencies
- Fix AndroidManifest permissions
- Add ProGuard keep rules
- Resolve plugin conflicts

---

## Safety Guardrails

### Critical Rules (NEVER VIOLATE)

#### 1. Git Safety
**FORBIDDEN COMMANDS:**
- ❌ `git reset --hard`
- ❌ `git reset --mixed`
- ❌ `git push --force`
- ❌ `git clean -fd`
- ❌ `git checkout -- .` (discard all changes)

**ALLOWED COMMANDS:**
- ✅ `git status` (read-only)
- ✅ `git diff` (read-only)
- ✅ `git add [specific files]` (staging only)
- ✅ `git commit` (local commits)
- ✅ `git stash` (temporary storage)
- ✅ `git log` (read-only)

**Rationale:** Fixloops must NEVER destroy uncommitted work or rewrite history.

#### 2. File Protection
**READ-ONLY FILES** (fixloops cannot modify):
- `gradle-wrapper.properties`
- `gradle.properties` (global settings)
- `local.properties`
- Flutter SDK paths
- PowerShell scripts under `tools/fixloops/`
- `.gitignore` patterns
- `CLAUDE.md` or `FIXLOOPS_DESIGN.md`

**WRITE-ALLOWED FILES:**
- Dart source code under `lib/`
- Test files under `test/`
- `pubspec.yaml` (only for adding dependencies)
- `AndroidManifest.xml` (only for permissions/config)
- `build.gradle` (only for dependencies, not versions)

#### 3. Branch Protection
- Fixloops ONLY run on feature branches
- Never execute on `main` or `master`
- Before starting, verify branch with `git status`

#### 4. Backup Strategy
**Before every code modification:**
1. Create timestamped backup directory:
   ```
   tools/fixloops/backups/YYYY-MM-DD_HH-MM-SS/
   ```
2. Copy files to be modified to backup dir
3. Apply changes
4. If fixloop fails catastrophically, human can manually restore from backup

**Backup Retention:**
- Keep last 10 backups (auto-cleanup old ones)
- Backups are git-ignored

#### 5. Iteration Limits
| Fixloop Type | Max Iterations | Rationale |
|--------------|----------------|-----------|
| Dev (Client) | 3 | Runtime crashes should be simple |
| Dev (Driver) | 3 | Runtime crashes should be simple |
| Tests | 5 | Tests may have complex dependencies |
| Build | 5 per app | Gradle issues can be chained |

**If max iterations reached:**
- Stop immediately
- Show human a summary of:
  - What was attempted
  - What failed
  - Probable root cause
  - Suggested next steps
- Never continue past the limit

#### 6. Change Scope
**Minimal Diff Policy:**
- Only change lines directly related to the error
- Never refactor surrounding code
- Never add "improvements" or "enhancements"
- Never add comments unless the logic is truly obscure
- Preserve existing code style

**Example (Good):**
```dart
// Before (crashes with null error):
final user = FirebaseAuth.instance.currentUser;
print(user.email);

// After (minimal fix):
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  print(user.email);
}
```

**Example (Bad - over-engineering):**
```dart
// DON'T DO THIS in a fixloop:
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  final email = user.email ?? 'unknown@example.com';
  logger.info('User email: $email'); // Added logging
  print(email);
} else {
  logger.warn('No authenticated user'); // Added logging
  throw AuthException('User not authenticated'); // Added exception
}
```

#### 7. Stop Conditions
**Immediate Stop (ask human):**
- Architecture change needed (e.g., "need to switch from Provider to Riverpod")
- Security vulnerability detected (e.g., exposed API key in code)
- Multiple unrelated errors (suggests deeper issue)
- Flaky tests (pass/fail inconsistently)
- Gradle version conflicts requiring manual resolution

**Success Stop:**
- App runs without crashing for 2+ hot reloads (dev fixloop)
- All tests pass (test fixloop)
- Build succeeds with no warnings (build fixloop)

**Failure Stop:**
- Max iterations reached
- Same error repeats after 2 fix attempts (stuck in loop)
- Error log is ambiguous (cannot determine root cause)

---

## Success & Failure Criteria

### Dev Fixloop

**Success:**
- ✅ `flutter run` exits with code 0 OR runs stably
- ✅ No uncaught exceptions in logs
- ✅ App UI loads successfully
- ✅ Hot reload works without errors

**Failure:**
- ❌ Repeated crash with same stack trace
- ❌ Firebase initialization timeout
- ❌ Plugin version incompatibility (needs pubspec change)
- ❌ Missing API keys (needs manual configuration)

### Test Fixloop

**Success:**
- ✅ All tests pass: `flutter test` exits with code 0
- ✅ No skipped tests
- ✅ Coverage unchanged or improved

**Failure:**
- ❌ Tests fail inconsistently (flakiness)
- ❌ Mock/stub setup requires architectural change
- ❌ Async tests timeout (needs redesign)

### Build Fixloop

**Success:**
- ✅ `flutter build apk` exits with code 0
- ✅ APK file generated in `build/app/outputs/apk/`
- ✅ No ProGuard/R8 warnings
- ✅ APK size is reasonable

**Failure:**
- ❌ Gradle dependency hell (conflicting versions)
- ❌ Missing signing config (needs manual keystore)
- ❌ Firebase config mismatch (needs console update)
- ❌ Native plugin compilation error (needs plugin update)

---

## Usage Guide

### Prerequisites
1. Windows machine with PowerShell
2. Flutter SDK installed and in PATH
3. Android toolchain configured
4. WawApp repo cloned locally
5. On a feature branch (not `main`)

### Quick Start

#### 1. Dev Fixloop (Client)
```bash
# From Claude Code:
/fixloop-dev-client

# Manual script execution:
.\tools\fixloops\run_dev_client.ps1
```

**What happens:**
- Claude runs the dev server script
- Monitors logs for crashes
- Applies fixes automatically
- Re-runs until stable or max 3 iterations

#### 2. Dev Fixloop (Driver)
```bash
/fixloop-dev-driver
```

#### 3. Test Fixloop
```bash
/fixloop-tests
```

**Optional: Run specific tests**
```bash
.\tools\fixloops\run_tests.ps1 test/features/auth/
```

#### 4. Build Fixloop
```bash
/fixloop-build
```

**What happens:**
- Builds client APK first
- If successful, builds driver APK
- Fixes errors automatically
- Stops when both builds succeed

### Manual Rollback

If a fixloop makes things worse:

```powershell
# List available backups:
ls tools/fixloops/backups/

# Restore from backup:
cp -Recurse tools/fixloops/backups/2025-12-03_14-30-15/* .

# Verify restoration:
git status
git diff
```

### Monitoring

**Watch logs in real-time:**
```powershell
# Client dev logs:
Get-Content tools/fixloops/logs/dev_client.log -Wait -Tail 50

# Test logs:
Get-Content tools/fixloops/logs/tests.log -Wait -Tail 50

# Build logs:
Get-Content tools/fixloops/logs/build_client.log -Wait -Tail 50
```

### Cleanup

**Remove old logs and backups:**
```powershell
# Clear logs (safe, they're regenerated):
rm tools/fixloops/logs/*.log

# Clear old backups (keep last 10):
ls tools/fixloops/backups/ | Sort-Object -Descending | Select-Object -Skip 10 | Remove-Item -Recurse
```

---

## Advanced: Extending Fixloops

### Adding a New Fixloop

1. **Create PowerShell script** in `tools/fixloops/`:
   ```powershell
   # Example: run_analyze.ps1
   flutter analyze | Tee-Object -FilePath tools/fixloops/logs/analyze.log
   exit $LASTEXITCODE
   ```

2. **Create Claude command** in `.claude/commands/`:
   ```markdown
   # fixloop-analyze.md
   Run flutter analyze and fix warnings automatically.

   Loop:
   1. Run tools/fixloops/run_analyze.ps1
   2. Parse logs/analyze.log for warnings
   3. Apply minimal fixes
   4. Re-run analyze
   5. Stop when clean or max 5 iterations
   ```

3. **Update this design doc** with the new fixloop type.

### Custom Stop Conditions

Modify Claude command files to add app-specific stop conditions:

```markdown
Stop immediately if:
- Error mentions "Firebase quota exceeded" (needs human intervention)
- Error mentions "Network unreachable" (not a code issue)
- Same file modified 3+ times (fixloop is confused)
```

---

## Troubleshooting

### Fixloop Stuck in Loop
**Symptom:** Same error repeats after multiple fixes.

**Solution:**
1. Stop the fixloop (Ctrl+C)
2. Review `logs/*.log` manually
3. Check if error is environmental (not code):
   - Missing API keys
   - Firebase quota limits
   - Network issues
4. Apply fix manually and commit

### Backup Not Created
**Symptom:** No backup directory before code change.

**Solution:**
1. Check permissions on `tools/fixloops/backups/`
2. Ensure Claude has write access
3. Manually create backup before next fixloop

### Script Exits with Code 0 But App Crashes
**Symptom:** `flutter run` returns success but app crashes after startup.

**Solution:**
1. Increase crash detection window in script
2. Monitor logs for "FATAL EXCEPTION" or "Unhandled Exception"
3. Adjust script to detect these patterns

---

## Appendix: Log Format Examples

### Dev Log (Success)
```
[2025-12-03 14:30:15] Starting flutter run for wawapp_client...
Launching lib\main.dart on Pixel 5 API 31 in debug mode...
✓ Built build\app\outputs\flutter-apk\app-debug.apk.
Installing build\app\outputs\flutter-apk\app-debug.apk...
Debug service listening on ws://127.0.0.1:12345/ws
Synced 1.2MB
```

### Dev Log (Failure)
```
[2025-12-03 14:35:22] Starting flutter run for wawapp_client...
Launching lib\main.dart on Pixel 5 API 31 in debug mode...
Exception has occurred.
_CastError (Null check operator used on a null value)
#0      AuthProvider.currentUser (package:auth_shared/providers/auth_provider.dart:42:15)
#1      HomeScreen.build (package:wawapp_client/features/home/home_screen.dart:28:40)
...
```

### Test Log (Failure)
```
00:05 +42 -1: test\features\auth\auth_provider_test.dart: should return null when user logs out [E]
  Expected: null
  Actual: User:<Instance of 'User'>
  package:test_api                expect
  test\features\auth\auth_provider_test.dart 68:5  main.<fn>.<fn>
```

### Build Log (Failure)
```
FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:mergeDexDebug'.
> A failure occurred while executing com.android.build.gradle.internal.tasks.DexMergingTaskDelegate
   > There was a failure while executing work items
      > A failure occurred while executing com.android.build.gradle.internal.tasks.DexMergingWorkAction
         > com.android.builder.dexing.DexArchiveMergerException: Error while merging dex archives:
         The number of method references in a .dex file cannot exceed 64K.
```

---

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-12-03 | 1.0 | Initial design document |

---

**End of FIXLOOPS_DESIGN.md**
