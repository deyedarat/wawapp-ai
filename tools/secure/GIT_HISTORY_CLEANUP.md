# Git History Cleanup - Remove Leaked API Keys

## ⚠️ WARNING
This process rewrites Git history. Coordinate with all team members before proceeding.

## Prerequisites

1. **Install git-filter-repo**:
   ```powershell
   # Using pip
   pip install git-filter-repo
   
   # Or download from: https://github.com/newren/git-filter-repo
   ```

2. **Backup your repository**:
   ```powershell
   cd c:\Users\hp\Music
   Copy-Item -Recurse WawApp WawApp-backup
   ```

## Step 1: Purge API Keys from History

```powershell
cd c:\Users\hp\Music\WawApp

# Create patterns file
@"
AIza[0-9A-Za-z\-_]{35}
AAAA[0-9A-Za-z\-_:]{100,}
"@ | Out-File -FilePath patterns.txt -Encoding UTF8

# Run filter-repo to remove matches
git filter-repo --replace-text patterns.txt --force

# Alternative: Remove specific files entirely
# git filter-repo --path apps/wawapp_client/android/app/src/main/res/values/api_keys.xml --invert-paths --force
```

## Step 2: Verify Cleanup

```powershell
# Search for any remaining keys
git log --all --full-history --source --pretty=format:"%H" | ForEach-Object {
    git grep -i "AIza" $_ 2>$null
}

# Should return nothing
```

## Step 3: Force Push (⚠️ DESTRUCTIVE)

### Pre-Push Checklist:
- [ ] All team members have committed and pushed their work
- [ ] Backup created
- [ ] New API keys generated and tested
- [ ] .gitignore updated
- [ ] Team notified of upcoming force push

### Force Push Commands:
```powershell
# Push to remote (overwrites history)
git push origin --force --all

# Push tags if needed
git push origin --force --tags

# Verify on GitHub
# Check: https://github.com/deya2021/wawapp/commits/main
```

## Step 4: Team Re-Clone Instructions

Send this to all team members:

```
🚨 REPOSITORY HISTORY REWRITTEN 🚨

The WawApp repository history has been cleaned to remove leaked API keys.

ACTION REQUIRED:

1. Commit and push any pending work to a backup branch:
   git checkout -b backup-before-cleanup
   git push origin backup-before-cleanup

2. Delete your local repository:
   cd c:\Users\<your-username>\Music
   Remove-Item -Recurse -Force WawApp

3. Fresh clone:
   git clone https://github.com/deya2021/wawapp.git
   cd WawApp

4. Restore your work from backup branch if needed:
   git checkout backup-before-cleanup
   git checkout main
   git cherry-pick <commit-hash>

5. Get new API keys from team lead and update .env files

DO NOT try to pull/merge - you must re-clone!
```

## Step 5: Rotate All Keys

```powershell
# Run key rotation script
.\tools\secure\rotate_keys.ps1 -CreateEnvFiles

# Follow instructions to create new restricted keys in GCP
.\tools\secure\rotate_keys.ps1 -Help
```

## Step 6: Enable CI Guard

Already configured in `codemagic.yaml` - will prevent future leaks.

## Verification

```powershell
# Run secret scanner
.\tools\guards\guard-secrets.ps1 -Verbose

# Should show: "✅ No secrets detected"
```

## Rollback (if needed)

```powershell
# Restore from backup
cd c:\Users\hp\Music
Remove-Item -Recurse -Force WawApp
Copy-Item -Recurse WawApp-backup WawApp
cd WawApp

# Force push old history back
git push origin --force --all
```

## Post-Cleanup

1. Delete backup after 1 week:
   ```powershell
   Remove-Item -Recurse -Force c:\Users\hp\Music\WawApp-backup
   ```

2. Monitor GCP Console for unauthorized API usage

3. Set up billing alerts in GCP

## Resources

- git-filter-repo: https://github.com/newren/git-filter-repo
- GCP API Key Best Practices: https://cloud.google.com/docs/authentication/api-keys
- GitHub: Removing sensitive data: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
