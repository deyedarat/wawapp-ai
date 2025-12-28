# Security Guidelines

## Overview
WawApp implements automated security guards to prevent common vulnerabilities.

## Security Guards

### 1. Secrets Guard (Pre-commit)
Blocks commits containing:
- API keys, tokens, passwords
- Firebase/AWS/GCP credentials
- Private keys
- OAuth client secrets

**Bypass**: Never bypass. Use `.env` files or Firebase Remote Config.

### 2. Dependencies Guard (Pre-push)
Checks for:
- Vulnerable package versions
- Missing lock files
- Keystores in repository

**Fix**: Update dependencies, generate lock files, move keystores to secure locations.

## Setup
```bash
# Install hooks
.\tools\git\setup-hooks.ps1

# Test manually
.\tools\guards\guard-secrets.ps1
.\tools\guards\guard-deps.ps1
```

## Best Practices

### Secrets Management
- Use `.env` files (gitignored)
- Store keystores in `~/.android/` or secure vault
- Use Firebase Remote Config for runtime secrets
- Never commit `google-services.json` with real keys

### Dependencies
- Run `flutter pub upgrade` regularly
- Keep `package-lock.json` committed
- Review dependency updates before merging

### Keystores
```
✅ ~/.android/release.keystore
❌ apps/wawapp_client/android/release.keystore
```

## Incident Response
If secrets are committed:
1. Rotate all exposed credentials immediately
2. Use `git filter-branch` or BFG to remove from history
3. Force push cleaned history
4. Notify team

## Contact
Report security issues to: [security contact]
