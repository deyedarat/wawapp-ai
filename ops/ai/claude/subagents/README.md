# WawApp Claude Subagents

This directory contains Claude subagent templates for structured WawApp development workflows.

## Agent Workflow

**Rule: triage → debugger(PaL) → implementer → reviewer → standards**

### 1. wawapp-triage-lead
**When to use:** Start of ANY task or issue
- Classifies requests (bug/feature/refactor/ops/CI/security/performance)
- Identifies affected surfaces (client/driver/shared/functions/MCP/CI)
- Produces problem statement, constraints, risks, Definition of Done
- Delegates to appropriate next agent(s)

### 2. wawapp-debugger
**When to use:** Bugs, regressions, flaky tests, auth/map/OTP issues
- Uses PaL Diagnostic Agent (diag_* tools) for systematic investigation
- Gathers evidence, narrows hypotheses
- Produces root cause analysis and fix plan
- Evidence-based approach (no guessing)

### 3. wawapp-implementer
**When to use:** Execute approved changes
- Implements minimal, safe diffs
- Runs tests and updates docs
- Produces PR-ready output
- Follows approved plan strictly

### 4. wawapp-reviewer
**When to use:** Before merging any changes
- Reviews correctness, security, performance, maintainability
- Checks architecture alignment
- Has veto power
- Provides actionable feedback

### 5. wawapp-standards-guardian
**When to use:** Quality issues repeat or architectural drift detected
- Enforces coding standards and quality gates
- Prevents architectural drift
- Creates/updates lint rules and CI checks
- Provides PR templates and review gates

## Usage

1. Copy the relevant agent template
2. Paste into Claude interface
3. Follow the agent's specific workflow
4. Hand off to next agent in chain as needed

Each agent is designed to be proactive and focused on their specific domain expertise.