---
name: aapp-hooks
description: Lifecycle Plugin Hooks & Quality Gate registry for AAPP. Inspect registered hooks, verify SHA256 integrity, test events, and manage project gates.
disable-model-invocation: true
---

# AAPP Lifecycle Hooks & Quality Gates

The AAPP Lifecycle Hook system allows external scripts, linters, notification webhooks, issue trackers, and team transports to intercept planning and worktree events via standard POSIX stdio and exit codes.

## 🪝 Protected Registry Contract

All quality gates and lifecycle hooks are declared in the protected registry:
`.agents/skills/aapp-hooks/registry.tsv`

Because this directory is protected under Section 2 of `blast-radius-guard`, autonomous agents cannot tamper with or rewrite quality gates to bypass them.

### Registry Schema (5-Column Tab-Delimited TSV)
```tsv
# event<TAB>handler_path<TAB>expected_sha256<TAB>timeout<TAB>mode
on-freeze	.agents/skills/migration-guard/scripts/check.sh	sha256:9f3c8e4...	30	gate
on-done	.agents/skills/archiver/scripts/push.sh	sha256:1a7e2b8...	60	notify
```
- **event**: One of the standard lifecycle events (`on-pickup`, `on-digest`, `on-freeze`, `on-start`, `on-done`, `on-pause`, `on-resume`, `pre-sync`, `on-sync`, `post-sync`).
- **handler_path**: Path to executable handler script relative to project root.
- **expected_sha256**: `sha256:<hex>` digest of handler script for tamper evidence.
- **timeout**: Max execution time in seconds (defaults to `10` if omitted).
- **mode**: `gate` (fails closed / aborts on error) or `notify` (logs advisory warning).

## 🚀 CLI Management Commands

- `aapp hooks`: Audit registered hooks, test permissions, and verify live SHA256 integrity.
- `aapp plugins`: Inspect discovered standalone action plugins (`.agents/skills/*/`).
- `aapp hook-test <event> [plan-id]`: Dry-run test a lifecycle event and inspect output.
- `aapp hook-hash <path> [event] [timeout] [mode]`: Compute SHA256 and generate a 5-column TSV line.

## 📦 Dual Delivery Contract

Handlers receive event data in two forms simultaneously:
1. **Rich JSON envelope** streamed directly to `stdin`.
2. **Exported POSIX environment variables**:
   - `AAPP_EVENT`: Event name (e.g. `on-done`, `on-freeze`, `on-sync`)
   - `AAPP_PLAN_ID`: Plan identifier (e.g. `P-12`)
   - `AAPP_PLAN_FILE`: Path to plan file
   - `AAPP_ACTION`: Sub-action for sync (`push`, `pull`, `sync`)
   - `AAPP_REMOTE`: Target remote name (e.g. `origin`)
   - `AAPP_MODE`: `gate` or `notify`
   - `AAPP_TIMEOUT`: Execution timeout in seconds
   - `AAPP_ACTOR`: Actor executing the transition (`developer` or `agent`)
