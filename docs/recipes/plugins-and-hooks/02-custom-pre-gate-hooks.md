---
title: "Custom Pre-Gate Validation & Compliance (`pre-*` Hooks)"
description: "How to enforce automated pre-flight quality, security, and compliance gates before blueprints are frozen or archived."
category: "plugins-and-hooks"
difficulty: "advanced"
tags: [hooks, pre-freeze, pre-done, compliance, security, quality-gates]
---

# 🍳 Recipe: Custom Pre-Gate Validation & Compliance (`pre-*` Hooks)

## 🎯 Goal
Author and register project-specific quality gates that intercept lifecycle transitions before any commits are made — preventing blueprints from freezing without compliance review (`pre-freeze`), or blocking plan completion if test coverage or security scans fail (`pre-done`).

## 📋 Prerequisites
- A repository initialized with AAPP.
- Understanding of the AAPP Hook Return Code Contract (Exit 0 = Pass, Exit 1 = Veto, Exit 2 = Advisory Warning).

## 🛠️ Step-by-Step Instructions

### 1. Author the Pre-Gate Compliance Script
Create `scripts/compliance-gate.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Read event payload from STDIN
INPUT_PAYLOAD=$(cat)

# Extract event and plan ID
EVENT=$(echo "$INPUT_PAYLOAD" | jq -r '.event // empty' 2>/dev/null || echo "${AAPP_EVENT:-}")
PLAN_ID=$(echo "$INPUT_PAYLOAD" | jq -r '.plan_id // empty' 2>/dev/null || echo "${AAPP_PLAN_ID:-}")

echo "🔍 [Compliance Gate] Evaluating '$EVENT' rules for plan '$PLAN_ID'..."

# Rule 1: Secrets Scanning Check
if command -v gitleaks >/dev/null 2>&1; then
  if ! gitleaks protect --staged --verbose >/dev/null 2>&1; then
    echo "❌ [VETO] Gitleaks detected unencrypted secrets in staged files!" >&2
    echo "   Remediation: Unstage the secret, rotate the credential, and update .gitleaksignore." >&2
    exit 1 # Hard veto aborts transition immediately
  fi
fi

# Rule 2: In-Development / Done Branch Parity Assertion
if [ "$EVENT" = "pre-done" ]; then
  # Verify that primary develop/main is clean and reachable
  UNTRACKED=$(git status --porcelain | grep '^??' | wc -l)
  if [ "$UNTRACKED" -gt 5 ]; then
    echo "⚠️  [ADVISORY] Detected $UNTRACKED untracked scratch files in workspace."
    echo "   Recommendation: Run 'git clean -nd' to verify no unexpected assets are left behind."
    exit 2 # Exit code 2 prints advisory warning but permits completion
  fi
fi

echo "✅ [Compliance Gate] All compliance checks passed."
exit 0 # Pass allows command to proceed
```

Make the script executable:
```bash
chmod +x scripts/compliance-gate.sh
```

### 2. Register the Gate for `pre-freeze` and `pre-done`
Register the script in `.agents/skills/aapp-hooks/registry.tsv` (or local git config):
```bash
# Register as pre-freeze gate with 20 second timeout
aapp hook-hash scripts/compliance-gate.sh pre-freeze 20 gate >> .agents/skills/aapp-hooks/registry.tsv

# Register as pre-done gate with 30 second timeout
aapp hook-hash scripts/compliance-gate.sh pre-done 30 gate >> .agents/skills/aapp-hooks/registry.tsv
```

### 3. Test Veto and Pass Behaviors
Execute a pre-flight test:
```bash
# Test pre-freeze event
aapp hook-test pre-freeze
```
Observe that exit code 0 prints green success, exit code 1 vetoes and halts the command before touching disk, and exit code 2 displays an advisory warning while continuing.

## ⚠️ Critical Invariants & Gotchas
- **The Pre-Mutation Guarantee**: All `pre-*` hooks run strictly *before* any Git commits, file relocations, or ledger writes happen. If your hook exits with `1`, the entire command aborts with zero modifications made to repository state.
- **Strict Return Codes**:
  - `0`: Pass (greenlight transition).
  - `1`: Fatal Veto (aborts immediately in `gate` mode).
  - `2`: Non-fatal Advisory Warning (logs message and continues).
  - `124`: Watchdog timeout reached (treated as hard failure in `gate` mode).
- **Anti-Circumvention**: The hook registry in `.agents/skills/aapp-hooks/registry.tsv` is protected by Layer 1 write-guard. Autonomous AI agents cannot disable gates or alter expected SHA256 hashes during plan implementation.

## 🔗 Related References
- 📖 [Technical Manual: Pre-Mutation Quality Gates](../../../MANUAL.md#pre-mutation-quality-gates--return-code-contract)
- 🍳 [Recipe: Continuous Deployment on Plan Done](01-deploy-on-done-hook.md)
- 🍳 [Recipe: Authoring Custom Action Plugins](04-authoring-custom-action-plugins.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
