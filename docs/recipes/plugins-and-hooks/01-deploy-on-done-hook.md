---
title: "Continuous Deployment on Plan Done (`post-done` Hook)"
description: "Trigger automated preview or staging deployments immediately when a plan is completed and archived."
category: "plugins-and-hooks"
difficulty: "intermediate"
tags: [hooks, post-done, deployment, automation, ci-cd]
---

# 🍳 Recipe: Continuous Deployment on Plan Done (`post-done` Hook)

## 🎯 Goal
Automatically trigger a preview or staging deployment (e.g. to Coolify, Dokku, Render, Kubernetes, or via SSH) whenever an implementation blueprint is successfully archived via `aapp done`.

## 📋 Prerequisites
- A repository initialized with AAPP.
- An external deployment webhook endpoint or deployment script.
- `jq` and `curl` installed on the host machine.

## 🛠️ Step-by-Step Instructions

### 1. Author the Deployment Hook Handler
Create an executable script at `scripts/deploy-on-done.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Read Dual Delivery payload from STDIN
INPUT_PAYLOAD=$(cat)

# Extract event metadata using jq (or fallback to environment variables)
PLAN_ID=$(echo "$INPUT_PAYLOAD" | jq -r '.plan_id // empty' 2>/dev/null || echo "${AAPP_PLAN_ID:-}")
EVENT=$(echo "$INPUT_PAYLOAD" | jq -r '.event // empty' 2>/dev/null || echo "${AAPP_EVENT:-}")
VERIFICATION_COMMIT=$(echo "$INPUT_PAYLOAD" | jq -r '.data.verification_commit // empty' 2>/dev/null || echo "")

if [ -z "$PLAN_ID" ]; then
  echo "⚠️  [Deploy Hook] No Plan ID detected in payload; skipping deployment."
  exit 0
fi

echo "🚀 [Deploy Hook] Detected completion of plan '$PLAN_ID' at commit '$VERIFICATION_COMMIT'..."

# Define your deployment webhook endpoint (read from environment or secret)
WEBHOOK_URL="${DEPLOY_WEBHOOK_URL:-https://api.example.com/deploy/preview}"

# Dispatch webhook with retry and timeout
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEPLOY_TOKEN:-}" \
  -d "{\"plan_id\":\"$PLAN_ID\",\"commit\":\"$VERIFICATION_COMMIT\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
  --max-time 15 \
  --retry 2 \
  "$WEBHOOK_URL" || echo "000")

if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
  echo "✅ [Deploy Hook] Successfully triggered staging rollout for plan $PLAN_ID (HTTP $HTTP_STATUS)."
  exit 0
else
  echo "⚠️  [Deploy Hook] Webhook dispatch returned HTTP $HTTP_STATUS. Deployment notification failed."
  # post-* hooks are observers; non-zero exit logs a warning without undoing the archive
  exit 0
fi
```

Make the script executable:
```bash
chmod +x scripts/deploy-on-done.sh
```

### 2. Register the Hook
You can register the hook either via Git configuration or in the hook registry:

#### Option A: Project Git Configuration (Recommended for local / personal environments)
```bash
git config aapp.hook.post-done "scripts/deploy-on-done.sh"
```

#### Option B: Cryptographic Registry (`.agents/skills/aapp-hooks/registry.tsv`)
Compute the hook hash and register it:
```bash
aapp hook-hash scripts/deploy-on-done.sh post-done 30 notify >> .agents/skills/aapp-hooks/registry.tsv
```

### 3. Test Hook Execution
Test your handler safely using the built-in test harness:
```bash
aapp hook-test post-done
```
Verify that the script receives the mock payload and logs diagnostic messages without errors.

## ⚠️ Critical Invariants & Gotchas
- **Observer Semantics**: The `post-done` event is an *observer* hook (`notify` mode). It runs strictly *after* the plan has been archived, git notes attached, and ledgers updated. A failure in the deployment webhook will log an advisory warning, but will *never* undo the plan's archive state.
- **Dual Delivery**: Always support reading payload data from both STDIN JSON envelopes and exported environment variables (`$AAPP_PLAN_ID`, `$AAPP_EVENT`).
- **Secrets Management**: Never commit deployment tokens into tracked files or `registry.tsv`. Read credentials from environment variables (`$DEPLOY_TOKEN`).

## 🔗 Related References
- 📖 [Technical Manual: Lifecycle Hooks Engine](../../../MANUAL.md#extensibility-lifecycle-hooks--action-plugins)
- 🍳 [Recipe: Custom Pre-Gate Validation](02-custom-pre-gate-hooks.md)
- 🍳 [Recipe: Authoring Custom Action Plugins](04-authoring-custom-action-plugins.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
