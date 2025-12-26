# WawApp – Unified CLAUDE.md (2025 Edition)
This file defines the global rules, safety guarantees, architecture constraints, and execution style for all AI agents working on WawApp (Claude Code, Amazon Q, Specify, and internal WawApp Agents).

The human communicates in Arabic.  
All code, commands, commits, prompts, and specifications must be in English.

=====================================================
SECTION 1 — GLOBAL SAFETY RULES
=====================================================

## 1. Authorized Changes Only
- Edit ONLY what the human explicitly requests.
- Never modify unrelated files.
- Never change Gradle, Flutter SDK paths, environment variables, or PowerShell scripts without explicit approval.
- No “assumptions” or “I thought this is better”.

## 2. Dependency Management
Whenever using imports:
- Add missing dependencies to pubspec.yaml / package.json.
- Never leave unresolved imports.
- Never add placeholder versions.

## 3. No Placeholders or Dummy Data
Forbidden:
❌ YOUR_API_KEY  
❌ TODO  
❌ dummy  
❌ hardcoded secrets  

Allowed:
✔ Secure .env  
✔ api_keys.xml  
✔ Server-side storage  

## 4. Security First
- Never expose secrets in code, diffs, messages, or commits.
- Sanitize tokens always.
- Firebase: apply security rules + RLS patterns.
- Authentication code is HIGH-RISK and treated carefully.

## 5. Evidence-Based Work
To confirm/deny features:
- Show file path
- Quote lines
- Explain reasoning

## 6. No Assumptions
If anything is unclear → STOP → ask the human.

## 7. Preserve Functional Requirements
- Fix bugs without altering logic.
- Ask before refactoring.
- Ask before renaming/moving files.

=====================================================
SECTION 2 — TOOLING RULES
=====================================================

## Git
Allowed:  
git status, diff, add, commit, switch, merge --no-ff  
Forbidden:  
reset --hard, force-push, editing main branch

## Flutter
Allowed:  
flutter analyze  
flutter format .  
flutter build apk  
Forbidden:  
flutter upgrade  
editing SDK paths

## Specify (Speckit)
- Always run: `.\spec.ps1 env:verify` before builds.
- Never modify Speckit scripts.
- Stop immediately if *any* test or check fails.

## Amazon Q Developer
- Only for verify/lint/format/analyze.
- Code edits allowed ONLY in branches named:
  chore/q-fix-*
- Never auto-fix logic without user approval.

=====================================================
SECTION 3 — ARCHITECTURE COMPLIANCE
=====================================================

## Riverpod-Only Architecture
- No BLoC, Cubit, Provider, or GetX.
- Preserve folder structure:

apps/wawapp_client/lib/features/*
apps/wawapp_driver/lib/features/*
packages/auth_shared/*
security/
tools/

## Firestore Changes
Any DB change requires:
- rules update  
- indexes update  
- migration description in /migrations  

## Navigation
- Use GoRouter exclusively.
- Avoid manual Navigator.push unless legacy.

=====================================================
SECTION 4 — EXECUTION PROTOCOL
=====================================================

## Before ANY Code Change
Claude MUST:
1. Enter **Plan Mode**
2. Read:
   - Root CLAUDE.md  
   - Feature-level CLAUDE.md  
   - Relevant agent in .claude/agents  
3. Produce a clear plan:
   - Files to read
   - Files to edit/create
   - How to test
4. Wait for explicit human approval.

## After Approval
- Apply minimal safe edits.
- Do NOT add enhancements unless asked.

## After Execution
- Show affected files list.
- Provide diffs when requested.
- Verify flutter analyze → no new warnings.

=====================================================
SECTION 5 — WAWAPP AGENT OS COORDINATION
=====================================================

## Agent Delegation
Claude must automatically delegate tasks to the correct internal agent:

- Authentication → wawapp-auth-agent  
- FCM / notifications → wawapp-fcm-agent  
- Maps / geolocation → wawapp-geo-agent  
- Pricing / fare logic → wawapp-pricing-agent  
- Driver app flows → wawapp-driver-agent  
- Client app flows → wawapp-client-agent  
- Security, PIN, identity → wawapp-security-agent  
- DevOps, CI, environment → wawapp-devops-agent  

Agents marked with “use proactively” MUST be invoked automatically.

## Tool Roles
- Claude: main developer, planner, refactorer.
- Amazon Q: verifier (analyze, format, safe-lint).
- Specify: environment checks, safe CI-style validation.
- Human: ambiguity resolution + approvals.

=====================================================
SECTION 6 — FINAL CHECKLIST BEFORE REPLYING
=====================================================

- [ ] Did I touch only what was explicitly requested?
- [ ] Did I avoid placeholders?
- [ ] Did I preserve architecture (Flutter + Riverpod)?
- [ ] Did I enforce security?
- [ ] Did I verify lint/analyze?
- [ ] Did I use the correct internal agent?
- [ ] Did I document the changes?

=====================================================
SECTION 7 — EMERGENCY STOP POLICY
=====================================================

If **anything** is unclear:  
STOP.  
Ask the human.  
Continue ONLY when the requirement is 100% clear.

---

## SECTION 8 — External Agents & Budget Mode (Claude + Amazon Q + Specify)

### 8.1 Budget Principle

You are NOT the only agent in this system.

We have:
- Amazon Q Developer → environment, logs, build, Git introspection
- Specify / spec.ps1 → validation, planning, diagnostics
- Claude Code → high-value reasoning and code changes only

**Default rule:**
- For ENV / BUILD / LOG issues → Prefer Amazon Q + spec.ps1
- For PLANNING / SPECS / CHECKLISTS → Prefer Specify + spec.ps1
- For IMPLEMENTATION / REFACTORING / DELICATE FLOWS → Use Claude Code

Your goal is to **minimize Claude token usage**:
- Avoid long “research essays”.
- Ask the human to run `.\spec.ps1 ...` or Amazon Q when they can do the same cheaper.
- Focus on precise diffs and decisions.

---

### 8.2 External Agents

We conceptually use three external agent families:

1) **Q-Agents (Amazon Q Developer)**
   - Q-Env: environment checks, PATH issues, SDK versions
   - Q-Build: Gradle / Flutter / CI failures
   - Q-Logs: reading long stack traces and device logs

2) **S-Agents (Specify via spec.ps1)**
   - Spec-Auth, Spec-FCM, Spec-Geo, Spec-Driver, Spec-Client
   - They produce plans, diagnostics, and violations reports.

3) **C-Agents (Claude inside .claude/agents)**
   - wawapp-auth-agent, wawapp-fcm-agent, wawapp-geo-agent, etc.
   - They implement code changes in

---

# 🔒 Nexus Tool Governance (Mandatory)

This project enforces **Nexus-style deterministic tool governance**
to prevent tool hallucination and uncontrolled execution.

All tool-based actions MUST follow this exact loop:

## Mandatory 4-Phase Loop

### 1. Discovery (REQUIRED)
You MUST discover available tools explicitly before any execution.
- Do NOT assume tool names.
- Do NOT infer capabilities.

### 2. Literal Mapping
Map the request to exact discovered tool IDs.
- If no matching tool exists, STOP immediately.
- Respond with: **"Task impossible with current tools."**

### 3. Schema Verification
Request the input schema ONLY for the selected tool(s).
- Never preload schemas.
- Never guess parameters.

### 4. Bridged Execution
Execute tools strictly using:
- Exact tool name
- Schema-compliant parameters

## Forbidden Behavior
- ❌ Tool usage without discovery
- ❌ Tool name hallucination
- ❌ Schema guessing
- ❌ Partial or speculative execution

## Failure Policy
Early failure is the correct behavior.
A correct failure is preferred over an incorrect success.
