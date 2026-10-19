---
title: "Authoring Custom Action Plugins (`aapp <command>`)"
description: "How to build custom CLI commands that extend AAPP, tap into kit internal helpers, and enforce project-specific automation."
category: "plugins-and-hooks"
difficulty: "advanced"
tags: [plugins, action-plugins, cli, extensibility, automation]
---

# 🍳 Recipe: Authoring Custom Action Plugins (`aapp <command>`)

## 🎯 Goal
Extend the `aapp` CLI with your own subcommands (e.g., `aapp release-check`, `aapp lint-plans`, `aapp deploy`) without modifying kit source code, while directly tapping into AAPP's pure internal functions (`$AAPP_LIB/aapp-lib.sh`).

## 📋 Prerequisites
- A repository initialized with AAPP.
- Bash 4+ or Python for executable authoring.

## 🛠️ Step-by-Step Instructions

### 1. Choose a Command Name and Create Directory
Action plugins are discovered automatically by directory name in `.agents/skills/<name>/run`:
```bash
# Create custom plugin for 'aapp release-check'
mkdir -p .agents/skills/release-check
```
*(Avoid using names starting with `aapp-`, which are reserved for kit internal engines).*

### 2. Author the Plugin Entrypoint (`run`)
Create `.agents/skills/release-check/run`:
```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Discover and source AAPP core libraries
if [ -n "${AAPP_LIB:-}" ] && [ -f "$AAPP_LIB/aapp-lib.sh" ]; then
  # shellcheck source=/dev/null
  source "$AAPP_LIB/aapp-lib.sh"
else
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  if [ -f "$REPO_ROOT/lib/aapp-lib.sh" ]; then
    # shellcheck source=/dev/null
    source "$REPO_ROOT/lib/aapp-lib.sh"
  fi
fi

echo "🔍 [Release-Check] Auditing workspace readiness before release..."

# 2. Tap into kit internals: check active plan buffer
ACTIVE_PLAN=$(read_active_buffer 2>/dev/null || echo "")
if [ -n "$ACTIVE_PLAN" ]; then
  echo "⚠️  [Warning] An active plan is currently bound in the execution buffer: $ACTIVE_PLAN"
fi

# 3. Tap into kit internals: check unresolved plan blockers
BLOCKERS=$(grep -c '^[0-9]' .plans/issues_road_map.md 2>/dev/null || echo "0")
if [ "$BLOCKERS" -gt 0 ]; then
  echo "❌ [Error] Found $BLOCKERS unresolved plan blockers in .plans/issues_road_map.md!"
  echo "   All blockers must be resolved or unqueued before releasing."
  exit 1
fi

# 4. Check for uncommitted working tree modifications
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
if [ "$UNCOMMITTED" -gt 0 ]; then
  echo "❌ [Error] Working tree has $UNCOMMITTED uncommitted modifications."
  exit 1
fi

echo "✅ [Release-Check] Workspace is 100% clean and ready for release!"
exit 0
```

Make the script executable:
```bash
chmod +x .agents/skills/release-check/run
```

### 3. Discover and Execute Your Command
List all installed action plugins:
```bash
aapp plugins
```
Notice that `release-check` appears under **Your Plugins**.

Now execute your custom command directly through the AAPP dispatcher:
```bash
aapp release-check
```

## ⚠️ Critical Invariants & Gotchas
- **Extension-Agnostic Entrypoint**: The entrypoint can be named `run`, `run.sh`, `run.py`, or `run.rb`. If multiple exist, `run` takes highest precedence.
- **Reserved Prefix**: Do not name custom plugins with the `aapp-` prefix (e.g. `aapp-deploy`). The `aapp-` prefix is strictly reserved for kit core subsystems.
- **Fail-Closed Execution**: Action plugins run in the user's interactive context; ensure errors exit with non-zero codes to prevent unintended pipeline continuation.

## 🔗 Related References
- 📖 [Technical Manual: Action Plugins Engine](../../../MANUAL.md#transparent-action-plugins-aapp-plugin)
- 🍳 [Recipe: Continuous Deployment on Plan Done](01-deploy-on-done-hook.md)
- 🍳 [Recipe: Custom Pre-Gate Validation](02-custom-pre-gate-hooks.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
