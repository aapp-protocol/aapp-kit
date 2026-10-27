---
title: Lifecycle Plugin Hooks & Action Plugins Engine
description: Architecture, protected registry contract (registry.tsv), dual delivery protocol, exit codes, and lifecycle event matrix.
---

# 🔌 Lifecycle Plugin Hooks & Action Plugins Engine

AAPP provides an extensible, zero-dependency lifecycle hook and action plugin engine. It allows external scripts, linters, quality ratchets (e.g. fallback detectors), remote sync transports, and issue trackers (Jira, Linear, GitHub Issues) to intercept planning events via standard POSIX stdio contracts.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        AAPP LIFECYCLE ENGINE                           │
│  (pre-freeze, post-freeze, pre-start, on-start, post-start,           │
│   pre-done, post-done, pre-sync, on-sync, post-sync, ...)              │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     FAIL-CLOSED INTEGRITY CHECK                        │
│   • Parse .agents/skills/aapp-hooks/registry.tsv (5 columns)           │
│   • Compute SHA256 of entrypoint via portable resolution chain         │
│   • Verify hash matches expected_sha256 (Anti-Self-Modification Gate)  │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        DUAL DELIVERY DISPATCH                          │
│   • STDIN: Stream full JSON envelope (event, plan metadata, actor)     │
│   • POSIX ENV: Export AAPP_EVENT, AAPP_PLAN_ID, AAPP_ACTION, etc.      │
│   • Watchdog: Enforce timeout (default 10s) with POSIX subshell timer  │
│   • Mode: 'gate' (exit 1 aborts) vs. 'notify' (exit 1 warns)           │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 1. System Architecture & The Pure Planning Invariant

1. **Pure Planning Invariant**: `.plans/` is reserved strictly for human-readable planning markdown (blueprints, issues, pickup queue, archive ledgers). Executable hook scripts and registry files **never live in `.plans/`**.
2. **Anti-Self-Modification Gate**: Section 2 of `blast-radius-guard` permanently protects `.agents/skills/aapp-*` from agent writes. If hook registration lived in an unprotected directory, an agent encountering a quality gate (like a fallback ratchet) could simply rewrite the hook script or repoint the registry to exit 0. By housing the registry in `.agents/skills/aapp-hooks/registry.tsv` and verifying each entrypoint's SHA256 before execution, neither the registry nor the handler scripts can be silently modified without invalidating the recorded hash and aborting the lifecycle operation.

---

## 2. Protected Registry & Hash-Lock Contract (`registry.tsv`)

The hook registry is a tab-delimited, line-oriented flat file (`.agents/skills/aapp-hooks/registry.tsv`) conforming to a strict 5-column schema:

```tsv
# event<TAB>handler_path<TAB>expected_sha256<TAB>timeout<TAB>mode
pre-freeze	.agents/skills/migration-guard/scripts/check.sh	sha256:9f3c8e4...	30	gate
post-done	.agents/skills/archiver/scripts/push.sh	sha256:1a7e2b8...	60	notify
on-sync	.agents/skills/team-transport/sync.sh	sha256:4d8a1c3...	45	gate
```

* **5-Column Schema**:
  1. `event`: The lifecycle trigger name (e.g. `pre-freeze`, `pre-start`, `pre-done`, `post-done`, `on-sync`).
  2. `handler_path`: Relative repository path to the executable script or binary.
  3. `expected_sha256`: Expected SHA256 checksum prefixed with `sha256:`.
  4. `timeout`: Execution timeout in seconds (positive integer; defaults to `10` if empty or omitted).
  5. `mode`: Execution mode — `gate` (fails closed, aborts lifecycle on failure/timeout) or `notify` (logs advisory warning and proceeds). Defaults to `gate`.
* **Pure POSIX Line Parsing**: Parsed using `TAB=$(printf '\t')` to guarantee 100% compatibility with `dash` (`/bin/sh` on Debian/Ubuntu), avoiding non-portable bashisms (`$'\t'`). Malformed lines with unexpected 6th fields are rejected with an explicit error.
* **Portable SHA256 Resolution Chain (Fail-Closed)**: Computes hashes dynamically by resolving host binaries: `sha256sum` (Linux) -> `shasum -a 256` (macOS) -> `sha256` (BSD) -> `openssl dgst -sha256`. If no SHA256 utility exists on the system, the dispatcher hard-aborts.
* **Integrity Gate**: If the live file's SHA256 does not match `expected_sha256`, the lifecycle transition is refused with an integrity violation diagnostic.
* **Multi-Hook Multiplexing**: Multiple handlers may bind to the same event. They execute sequentially in order of registration.

---

## 3. The Dual Delivery Contract (STDIN JSON + POSIX Environment)

To accommodate both zero-dependency shell scripts and rich polyglot webhook integrations, AAPP dispatches events via **Dual Delivery**:

### 1. JSON Envelope on `stdin`
Handlers receive a structured JSON payload on standard input containing metadata and event-specific context:
```json
{
  "event": "post-done",
  "timestamp": "2026-09-19T21:30:00Z",
  "pid": 12345,
  "actor": "user",
  "repo_root": "/path/to/project",
  "plan": {
    "id": "P-12",
    "file": ".plans/current/P12-lifecycle-hooks.md",
    "status": "⚡ In Development"
  },
  "data": {
    "archive_file": ".plans/done/P12-lifecycle-hooks.md"
  }
}
```

### 2. Exported POSIX Environment Variables
For shell scripts that avoid parsing JSON, standard variables are exported into the handler's execution environment:
* `AAPP_EVENT`: Name of the triggering lifecycle event (e.g. `on-done`).
* `AAPP_PLAN_ID`: Identifier of the associated plan (e.g. `P-12`).
* `AAPP_PLAN_FILE`: Path to the plan blueprint.
* `AAPP_ACTION`: Specific sub-action for composite events (e.g. `push`, `pull`, `sync`).
* `AAPP_REMOTE`: Target remote repository (e.g. `origin`).
* `AAPP_MODE`: Handler mode (`gate` or `notify`).
* `AAPP_TIMEOUT`: Execution timeout in seconds.
* `AAPP_ACTOR`: Current system user executing the command.

---

## 4. Exit Code Semantics & Watchdog Timeouts

Handlers communicate their results through standard POSIX process exit codes:

| Exit Code | Gate Mode (`gate`) | Notify Mode (`notify`) | Semantic Meaning |
| :---: | :--- | :--- | :--- |
| `0` | **Pass**: Operation proceeds. | **Pass**: Operation proceeds. | Success / Validated |
| `1` | **Hard Abort**: Lifecycle operation cancelled immediately; stderr streamed. | **Warning**: Diagnostic logged; operation proceeds. | Validation failure or fatal error |
| `2` | **Advisory Warning**: Diagnostic logged; operation proceeds. | **Advisory Warning**: Diagnostic logged; operation proceeds. | Non-fatal check warning |
| `124` | **Hard Abort**: Process terminated by watchdog timeout; operation cancelled. | **Warning**: Timeout logged; operation proceeds. | Watchdog timeout exceeded |
| Other | **Hard Abort**: Treated as Exit Code 1. | **Warning**: Treated as Exit Code 1. | Non-standard failure |

### Subprocess Watchdog
Every handler executes under an automated watchdog timer running in an isolated subshell. If the handler exceeds its configured `timeout`, the watchdog terminates the handler process with `SIGTERM` (followed by `SIGKILL` if unresponsive) and returns exit code 124.

---

## 5. Lifecycle Event Matrix (Unified Lifecycle Taxonomy, P-23)

AAPP wires symmetric pre-mutation quality gates, in-transaction action delegates, and post-mutation observers across all planning and workflow operations:

| Event | Type | Timing | Default Mode | Authority to Stop | Delivered Context (`data`) |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `pre-freeze` | Gate | Pre-mutation | `gate` | **YES** | Plan ID, declared Target Files, proposed blueprint path. |
| `post-freeze` | Observer | Post-commit | `notify` | No | Plan ID, declared Target Files, locked blueprint path. |
| `pre-start` | Gate | Pre-mutation | `gate` | **YES** | Plan ID, declared Target Files, blueprint path. |
| `on-start` | Action Delegate | In-transaction | `gate` | **YES** | Plan ID, declared Target Files, worktree path, branch. Rolls back on non-zero exit (P-54). |
| `post-start` | Observer | Post-commit | `notify` | No | Plan ID, declared Target Files, active buffer / worktree path. |
| `pre-done` | Gate | Pre-mutation | `gate` | **YES** | Plan ID, blueprint path, commit SHA, recorded commits array, `worktree` (plan worktree path, empty without one). |
| `post-done` | Observer | Post-commit | `notify` | No | Plan ID, destination archive path in `.plans/done/`, commit SHA, recorded commits array. |
| `post-abort` | Observer | Post-commit | `notify` | No | Plan ID, archive path in `.plans/aborted/`, reason, worktree, branch, recorded commits array (P-69). |
| `on-integrate` | Action Delegate | In-transaction | `gate` | **YES** | Action delegate (P-55): replaces built-in squash / fast-forward; `plan_id`, `plan_file`, `plan_branch`, `target_branch`, `worktree`. A refusal leaves plan archived; `aapp done <id> integrate` retries. |
| `pre-refine` | Gate | Pre-commit | `gate` | **YES** | Every `aapp refine` (P-99): `plan_id` (empty for `pickup` / `issues`), `kind`, `args`, `files` (empty). A refusal commits nothing. |
| `on-refine` | Action Delegate | In-transaction | `gate` | **YES** | Just before the plans commit of a refine (P-99): `plan_id`, `kind`, `args`, `files`. A refusal commits nothing (a remote record that must succeed). |
| `post-refine` | Observer | Post-commit | `notify` | No | After the plans commit of a refine (P-99): `plan_id`, `kind`, `args`, `files`, `commit`. Logging, notifications, remote records. |
| `post-pause` | Observer | Post-stash | `notify` | No | Pause reason, dirty worktree inventory, pause buffer path. |
| `post-resume` | Observer | Post-restore | `notify` | No | Restored plan ID, restored worktree count, drift detected. |
| `pre-sync` | Gate | Pre-network | `gate` | **YES** | Action (`push`/`pull`/`sync`), remote, worktrees. |
| `on-sync` | Action Delegate | In-transport | `gate` | **YES** | Action, remote, worktrees (transports remote state). |
| `post-sync` | Observer | Post-transport | `notify` | No | Action, remote, worktrees, transport result. |

---

## 6. Reference Samples & CLI Discovery

AAPP ships browsable, production-grade reference examples for action plugins and lifecycle hooks under `examples/` (`examples/plugins/`, `examples/hooks/`).

### 1. The `.sample` Invariant
Mirroring Git's canonical `.git/hooks/*.sample` pattern, all reference scripts and provider mocks strictly carry the `.sample` extension (e.g. `run.sample`, `on-done-sync.sh.sample`).
- **Resolver Filtering**: `resolve_plugin_entrypoint` explicitly ignores `*.sample` files, ensuring that reference samples cannot be executed by accident even if marked executable.
- **Hook Registry Audit**: If a `.sample` script is registered in `registry.tsv`, `aapp hooks` audits it with an advisory `⚠️  INERT SAMPLE` badge.

### 2. Centralized Storage & Project Isolation
Samples are preserved centrally in `~/.local/share/aapp-kit/examples/` (`$SHARE_DIR/examples/`) and refreshed on each upgrade via `aapp upgrade`. Samples are never extracted into adopter projects by default during `aapp init`, protecting AI agent context windows from token bloat.

### 3. Dynamic CLI Discovery
Run `aapp plugins` and `aapp hooks` to discover available samples:
- `aapp plugins`: Lists kit plugins and local plugins in `.agents/skills/`.
- `aapp hooks`: Displays registered lifecycle hooks, timing taxonomy, and available reference hook samples.

### The Shipped Samples

| Sample | Kind | What it does |
| :--- | :--- | :--- |
| `examples/hooks/test-gate.sh.sample` | `pre-done` gate | Refuses `aapp done` unless your test command passes (§7) |
| `examples/hooks/fallback-ratchet.sh.sample` | `pre-freeze` gate | Refuses a freeze when the plan's code adds legacy fallbacks (deprecated aliases, dual-syntax patterns) not listed in its §2 Fallback Inventory |
| `examples/hooks/on-done-sync.sh.sample` | `post-done` observer | Pushes the planning worktrees after a plan is archived |
| `examples/hooks/on-release.sh.sample` | `on-release` handler | Writes the new version into your project's files during `aapp release`; receives `AAPP_RELEASE_VERSION`, `AAPP_RAW_VERSION`, `AAPP_PREVIOUS_VERSION`, `AAPP_VERSION_BUMP` and the same as JSON |
| `examples/hooks/event-logger.sample` | observer for any event | Appends every event to a JSON Lines log (§8) |
| `examples/hooks/registry.tsv.sample` | registry | Example `registry.tsv` lines for the hooks above |
| `examples/plugins/hello-tool/` | action plugin | The smallest plugin: a command `aapp hello-tool` (§10) |
| `examples/plugins/aapp-planid/` | provider | Hands Plan ID allocation to a program outside the repository ([18. Plan ID Allocation](18-plan-id-allocation.md)) |
| `examples/plugins/aapp-issue-tracker/` | provider | A local issue tracker showing the tracker protocol ([07. Issue Protocol](07-issue-protocol.md)) |
| `examples/plugins/aapp-issue-branch/` | plugin | Says on which branch an issue's fix lands ([07](07-issue-protocol.md)) |
| `examples/plugins/aapp-issue-note-filter/` | plugin | Filters an issue's description and notes before they are shown ([07](07-issue-protocol.md)) |

### 4. Adopting a Sample
To activate a sample, copy it into place and strip the `.sample` suffix:
```bash
# Adopt custom action plugin:
cp -r ~/.local/share/aapp-kit/examples/plugins/hello-tool .agents/skills/hello-tool
mv .agents/skills/hello-tool/run.sample .agents/skills/hello-tool/run
chmod +x .agents/skills/hello-tool/run

# Adopt lifecycle hook:
cp ~/.local/share/aapp-kit/examples/hooks/on-done-sync.sh.sample .githooks/on-done-sync.sh
chmod +x .githooks/on-done-sync.sh
aapp hook-hash .githooks/on-done-sync.sh on-done 10 notify >> .agents/skills/aapp-hooks/registry.tsv
```

---

## 7. Requiring Green Tests on `done` (Test Gate)

`examples/hooks/test-gate.sh.sample` is a `pre-done` gate that runs your test command and refuses `aapp done` unless it passes:
```bash
cp ~/.local/share/aapp-kit/examples/hooks/test-gate.sh.sample .agents/hooks/test-gate.sh
chmod +x .agents/hooks/test-gate.sh
# Set TEST_CMD in the script (npm test, pytest -q, cargo test, …), then:
aapp hook-hash .agents/hooks/test-gate.sh pre-done 900 gate >> .agents/skills/aapp-hooks/registry.tsv
```
- **Where it runs:** in the plan's worktree when it has one (the payload's `worktree`), else in the repository root. A single checkout with uncommitted tracked changes is refused: the tests must run on committed code.
- **Refusals:** a failing command, an empty `TEST_CMD`, or the registry timeout.
- **Changing the command:** changes the script's SHA-256; update the registry line in the same commit.

---

## 8. Lifecycle Event Telemetry & Logging

`examples/hooks/event-logger.sample` provides a zero-dependency reference observer hook that logs structured JSON envelopes across all kit lifecycle events to an out-of-repo append-only JSONL file.

```bash
cp ~/.local/share/aapp-kit/examples/hooks/event-logger.sample .agents/hooks/event-logger
chmod +x .agents/hooks/event-logger

# Register event-logger as an observer hook (notify mode)
aapp hook-hash .agents/hooks/event-logger post-done 10 notify >> .agents/skills/aapp-hooks/registry.tsv
```

- **Out-of-Repo Storage Guarantee**: By default, logs write to `$(git rev-parse --git-path aapp_events.jsonl)` (the Git directory), remaining completely out of the working tree so file writes never dirty the workspace or trip blast-radius guards.
- **Configurable Destination**: Override the log file destination via `aapp.logFile` configuration or the `AAPP_LOG_FILE` environment variable:
  ```bash
  git config aapp.logFile /var/log/aapp/events.jsonl
  ```
- **Universal 2-Key Invariant**: Every event payload under `data` consistently carries `command` and `event` keys.
- **Contract Reference**: For the formal envelope schema, field definitions, and payloads across all 14 lifecycle events, see [Event Telemetry Specification](09-event-telemetry.md).

---

## 9. Hook and Plugin Commands

| Command | What it does |
| :--- | :--- |
| `aapp hooks` | Audits `registry.tsv`: each handler's event, path, mode and timeout, whether the file exists and is executable, and whether its SHA-256 still matches the registry. Also lists local handlers (§11) and the reference samples. |
| `aapp hooks events` | The catalog of lifecycle events (§5). |
| `aapp plugins` | The kit's reserved plugin names (installed or not), then your own plugins in `.agents/skills/` with the entrypoint each one resolves to. |
| `aapp hook-test <event> [plan-id]` | Runs the handlers registered for `<event>` with a mock payload, showing their output, exit codes and timeouts, without changing the repository. `aapp hook-run` is the same command. |
| `aapp hook-hash <file> [event] [timeout] [mode]` | Prints the file's SHA-256 as a ready `registry.tsv` line; append it with `>> .agents/skills/aapp-hooks/registry.tsv`. Run it again whenever the handler changes. |

Example audit:
```text
🪝 AAPP Lifecycle Hook Registry (.agents/skills/aapp-hooks/registry.tsv)
  • pre-freeze -> .agents/skills/migration-guard/scripts/check.sh [gate, 30s] (hash: valid)
  • post-done  -> .agents/skills/archiver/scripts/push.sh [notify, 60s] (hash: valid)
```

---

## 10. Plugins as Commands

An action plugin in `.agents/skills/<name>/` is also a command: `aapp <name> [args…]` runs it when `<name>` is not one of the kit's verbs. The entrypoint is found in this order, whatever the language:
1. `run` or `<name>` (an executable without extension)
2. `scripts/run` or `scripts/<name>`
3. `<name>.*` or `run.*` (`.py`, `.sh`, `.js`, `.rb`, …)
4. the same names under `scripts/`

`.sample` files are never run. The kit hands over with `exec`: arguments, input, output and the exit code are the plugin's own. Plugin protocol: [06. Action Plugin Protocol](06-plugin-protocol.md).

---

## 11. Local Handlers and CI Confinement

Besides the committed registry, a person can add handlers for their own clone without changing any tracked file:

```bash
git config --add aapp.hook.on-done "/path/to/desktop-notify.sh"
```

- **Observe only:** local handlers always run in `notify` mode. They can log, notify or play a sound, but never refuse a step; only handlers in the committed `registry.tsv` can gate.
- **Time limit:** `aapp.hookTimeout` seconds (default 10).
- **CI confinement:** on a build runner, turn them off so only the committed registry runs: `git config aapp.allowLocalHooks false`. `aapp hooks` then says local hooks are disabled.

Settings: [Hooks & Plugins](03-configuration-matrix.md#hooks--plugins).

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
