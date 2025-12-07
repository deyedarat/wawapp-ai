# Security Guards

Automated security checks for WawApp monorepo.

## Guards

### guard-secrets.ps1 (Pre-commit)
Scans staged files for:
- API keys and tokens
- Passwords and secrets
- Firebase/AWS/GCP credentials
- OAuth secrets
- Private keys

**Status**: ✅ Active (pre-commit hook)

### guard-deps.ps1 (Pre-push)
Checks for:
- Vulnerable Flutter packages
- Missing package-lock.json files
- Keystores in repository

**Status**: ✅ Active (pre-push hook)

## Usage

### Manual Testing
```powershell
# Test secrets guard
.\tools\guards\guard-secrets.ps1

# Test deps guard
.\tools\guards\guard-deps.ps1
```

### Install/Reinstall Hooks
```powershell
.\tools\git\setup-hooks.ps1
```

## Verification
Hooks installed at:
- `.git\hooks\pre-commit` → guard-secrets.ps1
- `.git\hooks\pre-push` → guard-deps.ps1

## See Also
- [docs/SECURITY.md](../../docs/SECURITY.md) - Full security guidelines
