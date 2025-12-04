# WawApp Fixloops - Quick Reference Guide

**Welcome to the WawApp Fixloops system!** This directory contains automated debugging tools that help you fix crashes, test failures, and build errors with AI assistance.

---

## What Are Fixloops?

Fixloops are automated debugging cycles that:
1. **Run** an operation (dev server, tests, or build)
2. **Detect** failures from logs
3. **Analyze** root causes using Claude Code AI
4. **Fix** code with minimal targeted changes
5. **Re-run** to verify the fix
6. **Stop** when stable or max iterations reached

Think of them as your AI pair programmer that can detect and fix common issues automatically while you focus on features!

---

## Quick Start

### Prerequisites
- Windows machine with PowerShell 5.1+
- Flutter SDK installed and in PATH
- Android toolchain configured
- WawApp repo on a **feature branch** (NOT `main`)

### Using Claude Code (Recommended)

From Claude Code, simply run:

```bash
# Fix client app crashes:
/fixloop-dev-client

# Fix driver app crashes:
/fixloop-dev-driver

# Fix failing tests:
/fixloop-tests

# Fix build errors:
/fixloop-build
```

Claude will automatically:
- Run the scripts
- Analyze logs
- Apply fixes
- Report results

### Manual Script Execution

If you prefer to run scripts manually:

```powershell
# Dev fixloops:
.\tools\fixloops\run_dev_client.ps1
.\tools\fixloops\run_dev_driver.ps1

# Test fixloop:
.\tools\fixloops\run_tests.ps1

# Build fixloops:
.\tools\fixloops\run_build_client.ps1
.\tools\fixloops\run_build_driver.ps1
```

---

## Available Fixloops

### 1. Dev Fixloop - Client (`/fixloop-dev-client`)

**Purpose:** Debug runtime crashes in `wawapp_client`.

**When to use:**
- App crashes on startup
- Null pointer exceptions during development
- Firebase initialization errors
- Plugin version conflicts

**Max iterations:** 3

**Log file:** `tools/fixloops/logs/dev_client.log`

---

### 2. Dev Fixloop - Driver (`/fixloop-dev-driver`)

**Purpose:** Debug runtime crashes in `wawapp_driver`.

**When to use:**
- Driver app crashes on startup
- Location permission errors
- Google Maps API issues
- Order/ride flow crashes

**Max iterations:** 3

**Log file:** `tools/fixloops/logs/dev_driver.log`

---

### 3. Test Fixloop (`/fixloop-tests`)

**Purpose:** Self-heal failing unit/widget/integration tests.

**When to use:**
- Tests fail after code changes
- Assertion mismatches
- Mock/provider setup issues
- Async/await timing problems

**Max iterations:** 5

**Log file:** `tools/fixloops/logs/tests.log`

**Run specific tests:**
```powershell
.\tools\fixloops\run_tests.ps1 -TestPath "test/features/auth/"
```

---

### 4. Build Fixloop (`/fixloop-build`)

**Purpose:** Fix build errors for client and driver APKs.

**When to use:**
- `flutter build apk` fails
- Gradle dependency conflicts
- AndroidManifest errors
- MultiDex issues
- ProGuard/R8 problems

**Max iterations:** 5 per app (10 total)

**Log files:**
- `tools/fixloops/logs/build_client.log`
- `tools/fixloops/logs/build_driver.log`

---

## How Fixloops Work

### Example: Fixing a Crash

```
1. You: /fixloop-dev-client

2. Claude: Running dev server...
   [App crashes with null error]

3. Claude: Analyzing logs...
   Found: NullPointerException in home_screen.dart:28

4. Claude: Creating backup...
   Backup saved to: tools/fixloops/backups/2025-12-03_14-30-15/

5. Claude: Applying fix...
   Added null check: if (user != null) { ... }

6. Claude: Re-running dev server...
   [App runs successfully]

7. Claude: SUCCESS! Fixed in 2 iterations.
   ✓ App runs without crashing
   ✓ Hot reload working
```

---

## Safety Features

### Git Safety
Fixloops **NEVER** run destructive git commands:
- ❌ `git reset --hard`
- ❌ `git push --force`
- ❌ `git clean -fd`

All changes are safe, incremental, and reversible.

### Automatic Backups
Before **every** code modification, fixloops create timestamped backups:
```
tools/fixloops/backups/
├── 2025-12-03_14-30-15/
├── 2025-12-03_15-00-00/
└── 2025-12-03_16-45-30/
```

### Protected Files
Fixloops **cannot** modify:
- Gradle wrapper settings
- SDK paths
- API keys
- Signing configs
- Fixloop scripts themselves

### Iteration Limits
Each fixloop has a max iteration limit to prevent infinite loops:
- Dev fixloops: 3 iterations
- Test fixloop: 5 iterations
- Build fixloop: 5 iterations per app

---

## Monitoring & Logs

### Watch Logs in Real-Time

```powershell
# Client dev logs:
Get-Content tools\fixloops\logs\dev_client.log -Wait -Tail 50

# Test logs:
Get-Content tools\fixloops\logs\tests.log -Wait -Tail 50

# Build logs:
Get-Content tools\fixloops\logs\build_client.log -Wait -Tail 50
```

### Log Files Location
All logs are saved in: `tools/fixloops/logs/`

These files are:
- ✅ Git-ignored (won't clutter your commits)
- ✅ Persistent (stay between runs)
- ✅ Timestamped (each run is logged separately)

---

## Manual Rollback

If a fixloop makes things worse, you can easily roll back:

### Step 1: List Available Backups
```powershell
ls tools\fixloops\backups\
```

### Step 2: Restore from Backup
```powershell
# Copy files from backup (replace timestamp with actual backup):
cp -Recurse tools\fixloops\backups\2025-12-03_14-30-15\* .
```

### Step 3: Verify Restoration
```powershell
git status
git diff
```

---

## Troubleshooting

### Issue: Fixloop Stuck in Loop
**Symptom:** Same error repeats after multiple fixes.

**Solution:**
1. Stop the fixloop (it will auto-stop after max iterations)
2. Review the log file manually
3. Check if the error is environmental (missing API keys, network issues, etc.)
4. Apply fix manually and commit

---

### Issue: Script Fails to Run
**Symptom:** PowerShell error when running script.

**Solution:**
```powershell
# Check execution policy:
Get-ExecutionPolicy

# If "Restricted", set to RemoteSigned:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

### Issue: Logs Directory Missing
**Symptom:** Script creates logs but they disappear.

**Solution:**
The scripts auto-create `logs/` directory. If missing:
```powershell
mkdir tools\fixloops\logs
```

---

### Issue: Backup Not Created
**Symptom:** No backup directory before code change.

**Solution:**
1. Check permissions on `tools/fixloops/backups/`
2. Ensure you have write access
3. Manually create backup before next run:
```powershell
mkdir tools\fixloops\backups\manual-backup
cp [file-to-backup] tools\fixloops\backups\manual-backup\
```

---

## Cleanup

### Clear Old Logs
```powershell
# Remove all logs (safe, they regenerate):
rm tools\fixloops\logs\*.log
```

### Clear Old Backups
```powershell
# Keep last 10 backups, delete older ones:
ls tools\fixloops\backups\ | Sort-Object -Descending | Select-Object -Skip 10 | Remove-Item -Recurse
```

---

## Advanced Usage

### Running Tests with Coverage
```powershell
.\tools\fixloops\run_tests.ps1 -Coverage
```

### Building Release APKs
```powershell
.\tools\fixloops\run_build_client.ps1 -BuildMode release
.\tools\fixloops\run_build_driver.ps1 -BuildMode release
```

### Building Split APKs (Per-ABI)
```powershell
.\tools\fixloops\run_build_client.ps1 -BuildMode release -SplitPerAbi
```

### Running Specific Device
```powershell
.\tools\fixloops\run_dev_client.ps1 -Device "emulator-5554"
```

---

## Best Practices

### ✅ DO:
- Use fixloops on **feature branches** only
- Review fixloop changes with `git diff` after completion
- Commit fixloop changes with clear messages
- Use fixloops for **common, repetitive issues**
- Run `/fixloop-tests` before pushing code

### ❌ DON'T:
- Run fixloops on `main` branch
- Skip reviewing AI-generated changes
- Rely on fixloops for complex architectural issues
- Disable safety features (backups, iteration limits)
- Commit without testing manually

---

## When Fixloops Can't Help

Fixloops are great for common issues, but some problems require human expertise:

### Fixloops Give Up When:
- Error requires architectural redesign
- Security vulnerability detected (needs careful review)
- Multiple unrelated errors (systemic issue)
- Flaky tests (inconsistent pass/fail)
- Missing API keys or environment setup
- Firebase quota/network issues

**When this happens:** Claude will stop and provide a detailed report with recommendations for next steps.

---

## Getting Help

### Check Documentation
1. [FIXLOOPS_DESIGN.md](FIXLOOPS_DESIGN.md) - Full technical design
2. [.claude/commands/fixloop-*.md](.claude/commands/) - Detailed command documentation

### Ask Claude Code
```
# In Claude Code, ask:
"Explain how fixloop-dev-client works"
"Why did my fixloop fail?"
"How do I roll back fixloop changes?"
```

### Report Issues
If fixloops aren't working correctly:
1. Check logs in `tools/fixloops/logs/`
2. Review backup in `tools/fixloops/backups/`
3. Report to your team lead with:
   - Which fixloop you ran
   - Log file contents
   - Error message

---

## File Structure

```
tools/fixloops/
├── README.md                    # This file (human guide)
├── FIXLOOPS_DESIGN.md          # Technical design doc
├── logs/                       # Runtime logs (git-ignored)
│   ├── dev_client.log
│   ├── dev_driver.log
│   ├── tests.log
│   ├── build_client.log
│   └── build_driver.log
├── backups/                    # Timestamped backups (git-ignored)
│   └── YYYY-MM-DD_HH-MM-SS/
├── run_dev_client.ps1          # Start client dev server
├── run_dev_driver.ps1          # Start driver dev server
├── run_tests.ps1               # Run Flutter tests
├── run_build_client.ps1        # Build client APK
└── run_build_driver.ps1        # Build driver APK

.claude/commands/               # Claude Code integration
├── fixloop-dev-client.md       # /fixloop-dev-client command
├── fixloop-dev-driver.md       # /fixloop-dev-driver command
├── fixloop-tests.md            # /fixloop-tests command
└── fixloop-build.md            # /fixloop-build command
```

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2025-12-03 | 1.0 | Initial release with 4 fixloop types |

---

## Summary

Fixloops are your automated debugging assistants. They:
- ✅ Save time on repetitive debugging
- ✅ Learn from common error patterns
- ✅ Apply minimal, safe fixes
- ✅ Create automatic backups
- ✅ Stop when uncertain (never guess)

**Use them wisely, review their changes, and happy coding!**

---

**Questions?** Ask Claude Code or check [FIXLOOPS_DESIGN.md](FIXLOOPS_DESIGN.md) for technical details.
