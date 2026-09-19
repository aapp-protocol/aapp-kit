# 🗺️ Plan P-12: Lifecycle Plugin Hooks Architecture (`.agents/skills/aapp-hooks/`)
* **Created:** 2026-09-10 | **Last Refined:** 2026-09-19
* **Target Issue / Milestone:** Milestone v1.2.0 (Lifecycle Extension Engine)
* **Plan ID:** P-12
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Every commit you make must include your co-author trailer (`Co-authored-by: Antigravity <antigravity@google.com>`).
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.

---

## 1. Context & Architectural Goal
* **What**: Implement an extensible, zero-dependency lifecycle hook and plugin engine for AAPP governed by a protected registry (`.agents/skills/aapp-hooks/registry.tsv`) and hash-locked execution contract, allowing external scripts, webhooks, issue trackers (Jira, Linear, GitHub Issues), and project-level quality gates (fallback ratchets, security scanners) to intercept planning events via standard POSIX `stdin` JSON envelopes and exit codes.
* **Why**:
  1. **Pure Planning Invariant**: Core AAPP keeps `.plans/` 100% pure markdown planning data (blueprints, issues, pickup, archive). No executables or hook directories live in `.plans/`. Handler scripts naturally live alongside role skills (e.g. `.agents/skills/<name>/scripts/`).
  2. **Anti-Self-Modification Gate**: Section 2 of `blast-radius-guard` already protects `.agents/skills/aapp-*` from agent writes. If hook registration lived in an unprotected path, an agent encountering a gate (like an un-annotated fallback check) could simply rewrite the gate script or repoint the hook to exit 0 and pass itself. By housing the registry in `.agents/skills/aapp-hooks/registry.tsv` and recording each handler's SHA256, the registry cannot be repointed and handlers cannot be silently modified without invalidating the recorded hash.
  3. **Zero-Dependency Pure POSIX Registry**: A line-oriented TSV registry parses with `while IFS=$'\t' read -r event path hash`, honoring the zero-dependency invariant without requiring `python3` or `jq` (avoiding the runtime dependency trap of `#9`/`ISSUE-009`).
  4. **Multi-Hook Multiplexing & Local Overrides**: Multiple hooks can bind to the same event. Adopters get a committed team standard in the repo, paired with `git config --get-all aapp.hook.<event>` for local developer experimentation.
* **The Invariant**: AAPP core knows nothing about external SaaS APIs or language-specific linters. It only validates the registered SHA256, dispatches structured JSON payloads to executable hook scripts, and evaluates standard POSIX exit codes.

---

## 2. Technical Blueprint

### A. The Hook Execution Flow
```text
┌───────────────────────────┐
│     AAPP CLI Engine       │
│ (/done, /freeze, sync, …) │
└─────────────┬─────────────┘
              │ 1. Reads protected registry: .agents/skills/aapp-hooks/registry.tsv
              │    and local overrides (git config --get-all aapp.hook.<event>)
              │ 2. Verifies handler executable and checks SHA256 integrity
              │ 3. Streams Event Envelope via STDIN (JSON)
              ▼
┌───────────────────────────┐
│  Target Handler Script    │ ───► External SaaS / Linter / Ratchet / Slack / DB
│ (Bash, Python, Go, Node)  │
└─────────────┬─────────────┘
              │ 4. Returns POSIX Exit Code & STDERR
              ▼
┌───────────────────────────┐
│     AAPP Action Gate      │
│  0 = Proceed              │
│  1 = Abort Operation      │
│  2 = Warning & Continue   │
└───────────────────────────┘
```

### A.1 CLI Hook & Plugin Management Actions
To audit, debug, and register hooks without mutating repository state, AAPP defines three dedicated CLI actions:

| Action | Syntax | Purpose & Behavior |
| :--- | :--- | :--- |
| **`aapp hooks`**<br>*(or `aapp hook-status`)* | `aapp hooks` | **Audit & Integrity Inspector**: Reads `.agents/skills/aapp-hooks/registry.tsv` and active git config overrides. Validates file existence, permissions (`+x`), and matches live SHA256 hashes against recorded registry hashes (`✅ VALID`, `⚠️ MISMATCH`, `❌ MISSING`). |
| **`aapp hook-test`**<br>*(or `aapp hook-run`)* | `aapp hook-test <event> [plan-id]` | **Dry-Run & Debugging Gate**: Synthesizes a test JSON envelope for `<event>` and executes registered handlers. Streams stdout/stderr, measures execution time, and reports exit code behavior without altering repository or plan state. |
| **`aapp hook-hash`** | `aapp hook-hash <path> [event] [timeout] [mode]` | **Registration Helper**: Computes portable SHA256 hash using the host resolution chain and formats a complete 5-column TSV line ready to be pasted into the protected `registry.tsv`. |

### B. Standard Lifecycle Event Matrix
Lifecycle events map directly across the entire project progression (Intake → Triage → Specification → Implementation → Completion → Distribution):

| Hook Name | Trigger Moment | Key Payload Data | Typical Adopter Use Cases |
| :--- | :--- | :--- | :--- |
| `on-pickup` | New idea added to `pickup.md` or via CLI | `raw_text`, `author`, `timestamp` | Push to Slack triage channel, sync with mobile note intake. |
| `on-digest` | Idea promoted to Issue or Draft Blueprint | `lane` ("issue" \| "plan"), `id`, `file_path`, `title` | Scaffold tickets in Jira/Linear, assign project milestones. |
| `on-freeze` | Plan blast radius locked into `🔷 Frozen` | `plan_file`, `target_files`, `blocked_files` | **Quality Gates**: Fallback ratchet, security linters, blast radius boundary audit. |
| `on-start` | Plan activated into `⚡ In Development` | `plan_file`, `target_files` | Spawn ephemeral git feature branch, bind dev containers, alert team of active coding. |
| `on-done` | Blueprint archived to `done/` and ledger | `plan_file`, `commit_hash`, `timestamp`, `linked_issues` | Close Jira/GitHub issues, write audit record to corporate DB, trigger CI. |
| `on-pause` | Emergency brake engaged (`aapp pause`) | `quarantined_worktrees`, `reason`, `timestamp` | Pause external CI watchers, alert team of context switch. |
| `on-resume` | Emergency brake disengaged (`aapp resume`) | `restored_worktrees`, `drift_detected` | Resume background workers, re-verify planning health. |
| `pre-sync` | Before `aapp sync` initiates pulls | `worktrees`, `remote_urls` | Pull remote DB updates and materialize local markdown. |
| `on-sync` | Team sync transport execution (`aapp.syncStrategy = hook`) | `action` ("push" \| "pull" \| "sync"), `remote`, `worktrees` | Replaces core git worktree push/pull with team S3, DB, API, or custom transport. |
| `post-sync` | After `aapp sync` completes all pushes | `synced_worktrees`, `status` | Ping deployment webhooks, update status monitors. |

### C. The Standard Event Envelope Schema (v1.0)
Every hook receives a validated JSON envelope on `stdin`:
```json
{
  "version": "1.0",
  "event": "on-done",
  "timestamp": "2026-09-10T21:30:00Z",
  "actor": "developer",
  "repository": {
    "root": "/home/user/projects/my-app",
    "branch": "develop"
  },
  "data": {
    "plan_file": ".plans/done/plan-v1.0.3-docs.md",
    "target_files": [
      "README.md",
      "templates/pre-commit"
    ],
    "commit_hash": "894b52f",
    "linked_issues": [
      "ISSUE-020",
      "ISSUE-021"
    ]
  }
}
```

### D. POSIX Exit-Code & Timeout Contract
* **`0` (Success / Proceed)**: Hook succeeded. AAPP proceeds with the lifecycle transition.
* **`1` (Failure / Rejection)**:
  - **If `mode = gate`**: Hook failed or explicitly rejected the transition. AAPP prints the hook's `stderr` to the terminal and immediately halts the operation, rolling back uncommitted changes if applicable.
  - **If `mode = notify`**: Hook failed, but is non-blocking. AAPP logs the hook's `stderr` as an advisory warning and continues execution.
* **`2` (Non-Blocking Warning)**: Hook emitted a non-fatal warning. AAPP logs the hook's `stderr` to the user and continues execution without aborting regardless of mode.
* **`Timeout` (POSIX Subshell Watchdog)**:
  - **If `mode = gate`**: Timed-out execution is treated as a **hard gate failure** (exit code 1 abort). Gates must execute within their allotted budget; a hanging gate fails closed.
  - **If `mode = notify`**: Timed-out execution is treated as an advisory warning (exit code 2). A slow webhook or notification transport never blocks a plan transition or archival.

### D.1 Core/Plugin Override Contract (`aapp.<feature>Strategy`)

Events alone let a plugin **add** behaviour; they never let it **replace** a built-in. Without a
replacement mechanism, a core feature and a hook that does the same job both run — two transports,
possibly two destinations, no defined relationship. This contract closes that.

```
git config aapp.<feature>Strategy   →   builtin (default) | hook
```

| Strategy | Core action | Event fires | Meaning |
| :--- | :--- | :--- | :--- |
| `builtin` *(default)* | runs | **yes** | Core performs the work; hooks observe. Unchanged behaviour for anyone who never sets this. |
| `hook` | **stands down** | **yes** | The hook is responsible for the work. |

**Invariant — the event always fires, regardless of strategy.** Notification is independent of who
performs the work, so "post to Slack *and* let the built-in sync run" remains the default rather than
a special case.

**Team Sync Governance: Default vs. Overwritable Syncing for Teams (`aapp.syncStrategy`)**:
For teams collaborating via central infrastructure (e.g. S3 buckets, central databases, or custom internal git mirrors), remote sync can be delegated to a team plugin hook. AAPP establishes a strict three-tier precedence hierarchy balancing committed team standards with individual developer autonomy:

1. **CLI Runtime Flag (Ad-hoc Override)**: `aapp sync [remote] --builtin` or `--hook` immediately forces the strategy for that single execution without altering persistent configuration.
2. **Local Developer Configuration (Clone Override)**: `git config aapp.syncStrategy [builtin|hook]` in the local `.git/config` overrides repository defaults for the current clone. This enables individual developers to operate offline or use native git worktrees even in a repository configured for team hook transport.
3. **Repository Team Standard (Committed Default)**:
   - If `aapp.syncStrategy` is unset in `.git/config`:
     - If an `on-sync` gate handler is registered in `.agents/skills/aapp-hooks/registry.tsv`, AAPP defaults to `hook` transport (and `aapp init` automatically detects the registered handler to seed `aapp.syncStrategy hook`).
     - Otherwise, AAPP defaults to `builtin` git worktree sync.

**The `on-sync` Transport Execution Contract**:
When `aapp.syncStrategy = hook`:
- Core native git worktree push/pull commands stand down.
- `aapp push` dispatches `on-sync` with payload `{"data": {"action": "push", "remote": "<name>", "worktrees": [...]}}`.
- `aapp pull` dispatches `on-sync` with payload `{"data": {"action": "pull", "remote": "<name>", "worktrees": [...]}}`.
- `aapp sync` dispatches `on-sync` with payload `{"data": {"action": "sync", "remote": "<name>", "worktrees": [...]}}`.
- `pre-sync` fires before transport, and `post-sync` fires after successful transport as observer notification hooks.
- The `on-sync` handler executes in `mode=gate`; non-zero exit codes immediately abort the sync and stream stderr.

**Missing-hook behaviour — refuse, never degrade.** If a feature's strategy resolves to `hook` but no
corresponding handler is registered in `.agents/skills/aapp-hooks/registry.tsv` or git config, the
operation is **refused** with an explicit message naming the config key:

```text
❌ aapp.syncStrategy=hook but no executable handler is registered for on-sync in .agents/skills/aapp-hooks/registry.tsv or git config.
```

Silently doing nothing is the dangerous option — the operator believes the work happened. Silently
falling back to the built-in is nearly as bad, because a misconfiguration then looks like success.
Refusal is the only outcome where a mistake is visible at the moment it is made.

**Naming rule.** This plan owns the *pattern*; each core feature declares its own instance. The first
is `aapp.syncStrategy`, declared in `P-10` §B. Subsequent overridable features cost one config key,
not a new design.

### D.2 Protected Registry & Hash-Lock Contract (`.agents/skills/aapp-hooks/registry.tsv`)
To guarantee that quality gates (such as fallback ratchets, linter checks, or security audits) cannot be silently bypassed or rewritten by autonomous agents, the hook registry is housed inside `.agents/skills/aapp-hooks/`, which is permanently protected under Section 2 of `blast-radius-guard`.

1. **Registry Format**: A tab-delimited, line-oriented flat file (`registry.tsv`) with 5 columns:
   ```tsv
   # event<TAB>handler_path<TAB>expected_sha256<TAB>timeout<TAB>mode
   on-freeze	.agents/skills/migration-guard/scripts/check.sh	sha256:9f3c8e4...	30	gate
   on-done	.agents/skills/archiver/scripts/push.sh	sha256:1a7e2b8...	60	notify
   ```
   - `timeout`: Optional timeout in seconds (defaults to `10` if omitted or empty).
   - `mode`: `gate` (default) or `notify`. Gates abort on failure/timeout; notifications warn.

2. **Pure POSIX Line-Oriented Parsing (`dash` Compatible)**:
   Avoids bashisms like ANSI-C quoting (`IFS=$'\t'`) which fail silently in `dash` (`/bin/sh` on Debian/Ubuntu). Parsed with strict column count validation:
   ```bash
   TAB=$(printf '\t')
   while IFS="$TAB" read -r event handler expected_hash timeout mode extra; do
       [ -z "$event" ] || [ "${event#\#}" != "$event" ] && continue
       if [ -n "$extra" ]; then
           echo "❌ Malformed registry line in $REGISTRY_FILE: unexpected 6th field" >&2
           exit 1
       fi
       timeout="${timeout:-10}"
       mode="${mode:-gate}"
       # dispatch handler, assert sha256, enforce mode/timeout
   done < "$REGISTRY_FILE"
   ```

3. **Portable SHA256 Resolution Chain (Fail-Closed)**:
   Different OS environments ship different hashing binaries (`sha256sum` on GNU/Linux, `shasum -a 256` on macOS, `sha256` on BSD, `openssl dgst -sha256` as fallback).
   The dispatcher resolves the hashing command dynamically:
   - `sha256sum` → `shasum -a 256` → `sha256` → `openssl dgst -sha256`.
   - **Fail-Closed Invariant**: If no SHA256 utility is discovered on the host system, the dispatcher immediately **hard aborts** with a diagnostic. It never skips hash verification.

4. **Hash-Lock Verification & Tamper Evidence**:
   Before executing any handler defined in the registry, the dispatcher computes its SHA256 hash. If the current hash does not match `expected_hash`:
   - The operation is **hard-aborted** with an integrity violation notice.
   - An agent cannot modify the handler script to pass itself because altering the script breaks the registered hash, and the agent is denied write access to `registry.tsv`.

5. **Multi-Hook Multiplexing**:
   Multiple lines with the same `<event>` are permitted. The dispatcher iterates through all registered handlers in sequence. Any handler in `gate` mode exiting 1 halts the entire lifecycle event.

6. **Honest Architectural Boundaries**:
   - **Shallow Entrypoint Hashing**: The recorded SHA256 covers only the entrypoint file itself, not external modules it imports or helper scripts it sources. Adopters must be aware that deep dependencies are not transitively hashed.
   - **Gate Registration Requires Human Action**: Because `registry.tsv` lives in Section-2 protected `.agents/skills/aapp-*`, an agent asked to "add a quality gate" will be refused by write-guard. Registering a new gate or updating a hash is a deliberate human act.

### D.3 Local Developer Override Contract (`git config aapp.hook.<event>`)
For local debugging or temporary hook scripts that should not be committed to the repository:
- `git config --get-all aapp.hook.<event>` allows specifying ad-hoc handler paths.
- **Security Invariant: Only registry handlers can gate. Local hooks observe; they never block.**
  Local hooks run strictly in `mode=notify`. They receive the event envelope and execute with a global timeout (`aapp.hookTimeout`, default 10s), but cannot abort a lifecycle transition.
- This deletes precedence collisions entirely: registry hooks gate and live in `registry.tsv`; local hooks observe and live in `git config`.
- **CI Confining**: Setting `git config aapp.allowLocalHooks false` confines execution strictly to committed `registry.tsv` entries.

### D.4 Transparent Command Fallthrough & Extension-Agnostic Plugin Discovery (`aapp <plugin-name>`)
For standalone CLI tools and Action Plugins authored as project skills (e.g. `adversarial-review`, `check-fallbacks`, `threat-model`), the CLI switchboard in `aapp` provides transparent discovery in its default `*)` branch.

**Extension-Agnostic Resolution Invariant**:
Plugin discovery must **never** rely on a specific script extension (`.sh`). The entrypoint may have **any extension or no extension at all** (e.g. extensionless compiled binary or script with shebang, `.py`, `.sh`, `.bash`, `.js`, `.rb`, etc.).

When `aapp <cmd> [args...]` is called and `<cmd>` is not a core built-in command, the CLI switchboard scans candidate paths in `.agents/skills/$CMD/` using a deterministic resolution order:

1. **Canonical Extensionless Entrypoints**:
   - `[ -x ".agents/skills/$CMD/run" ]`
   - `[ -x ".agents/skills/$CMD/$CMD" ]`
2. **Subdirectory Extensionless Entrypoints**:
   - `[ -x ".agents/skills/$CMD/scripts/run" ]`
   - `[ -x ".agents/skills/$CMD/scripts/$CMD" ]`
3. **Extension-Agnostic Pattern Search (Any Extension)**:
   If no exact extensionless entrypoint exists, search for any executable matching `$CMD` or `run` with arbitrary file extensions:
   - Search `.agents/skills/$CMD/$CMD.*` for the first file where `[ -x "$f" ]`.
   - Search `.agents/skills/$CMD/run.*` for the first file where `[ -x "$f" ]`.
   - Search `.agents/skills/$CMD/scripts/$CMD.*` for the first file where `[ -x "$f" ]`.
   - Search `.agents/skills/$CMD/scripts/run.*` for the first file where `[ -x "$f" ]`.
4. **Execution Delegation**:
   If an executable candidate is discovered, execute immediately via `exec "$CANDIDATE" "$@"`, forwarding all positional arguments, stdio streams, and exit codes directly without overhead.
5. **Fallback**:
   If no matching executable candidate is found, print the standard unknown command error and display `aapp help`.

This gives complete language freedom to project teams: plugins can be written in Go, Rust, Python, Node, Ruby, or Bash, with or without file extensions, without touching core AAPP dispatcher code.

### E. Dispatcher Engine Architecture (`lib/hook_dispatcher.sh`)
* Provides a shared internal function `dispatch_hook <event_name> <json_data_generator_fn>`.
* Discovers handlers from `.agents/skills/aapp-hooks/registry.tsv` (mode `gate` or `notify`) and local `git config --get-all aapp.hook.<event_name>` (mode `notify`).
* If no handlers are registered: silently and instantly passes (zero overhead).
* For each handler:
  1. Asserts handler path exists and is executable (`[ -x ... ]`).
  2. If registered in `registry.tsv`, asserts SHA256 integrity using the portable resolution chain. If hash mismatches, prints error to `stderr` and aborts (exit 1).
  3. Constructs standard metadata header, streams payload to handler's `stdin`, captures exit code and `stderr`.
  4. Enforces timeout watchdog and exit code semantics based on handler's `mode` (`gate` vs `notify`).

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core Dispatcher Engine & CLI Management
- [ ] Task 1.1: Create `lib/hook_dispatcher.sh` implementing `dispatch_hook()` with `dash`-compatible TSV parsing (`TAB=$(printf '\t')`), 5-column validation, portable SHA256 resolution chain, and exit-code/mode handling.
- [ ] Task 1.2: Implement portable execution watchdog/timeout mechanism honoring `mode` (gate fails closed, notify warns).
- [ ] Task 1.3: Author JSON envelope generator for all 10 lifecycle events (including `on-sync`).
- [ ] Task 1.4: Implement CLI commands `aapp hooks`, `aapp hook-test`, and `aapp hook-hash` in `lib/cmd_hook.sh`.

### Phase 2: Hook Wiring into CLI & Protocol Commands
- [ ] Task 2.1: Wire `on-done` into `cmd_done` (or `/done` command execution).
- [ ] Task 2.2: Wire `on-freeze` and `on-start` into `lib/cmd_plan.sh` (`freeze`, `start`, `freeze-start`).
- [ ] Task 2.3: Wire `on-digest` into `cmd_digest` (or `/digest` command execution).
- [ ] Task 2.4: Wire `pre-sync`, `post-sync`, and `on-sync` into `lib/cmd_sync.sh`. **Depends on `P-10`**, which creates that file — this task cannot execute until remote sync ships. Also honour `aapp.syncStrategy` and three-tier precedence per §D.1.
- [ ] Task 2.5: Implement `aapp.<feature>Strategy` resolution in `lib/hook_dispatcher.sh` per §D.1, including the refuse-on-missing-hook path.
- [ ] Task 2.6: Wire `on-pause` and `on-resume` into `lib/cmd_pause.sh`.
- [ ] Task 2.7: Wire transparent command fallthrough (`aapp <plugin-name>`) into `aapp` switchboard with extension-agnostic discovery (no extension or any extension).
- [ ] Task 2.8: Update `lib/cmd_init.sh` to scaffold `.agents/skills/aapp-hooks/` and deploy starter `registry.tsv` and `SKILL.md`.

### Phase 3: Sample Hooks, Automated Tests & Documentation
- [ ] Task 3.1: Create sample hook templates in `templates/skills/aapp-hooks/`:
  - `registry.tsv` (starter 5-column registry template with documented syntax and examples).
  - `scripts/on-done.sample.sh` (logs completion to a local append-only log or webhook).
  - `scripts/on-pickup.sample.py` (demonstrates JSON reading and external notification).
- [ ] Task 3.2: Author automated test suite `tests/hooks_test.sh` verifying:
  - `dash` shell compatibility on TSV parsing and field count validation.
  - Portable SHA256 resolution chain across tools (`sha256sum`, `shasum`, `openssl`).
  - SHA256 hash mismatch halts lifecycle transition and prints diagnostic.
  - Exit code 0 allows lifecycle transition.
  - Exit code 1 halts lifecycle transition for `gate` mode; warns for `notify` mode.
  - Exit code 2 emits warning and proceeds.
  - Timeout halts lifecycle transition for `gate` mode; warns for `notify` mode.
  - Local `git config` overrides execute in `notify` mode and cannot gate.
  - `aapp.allowLocalHooks false` cleanly disables uncommitted hooks.
  - `aapp hooks`, `aapp hook-test`, and `aapp hook-hash` CLI actions.
  - Transparent command fallthrough execution with extensionless binaries, `.py`, `.sh`, and arbitrary extensions.
  - `on-sync` transport hook execution and three-tier team sync precedence (`--builtin`/`--hook` CLI flag > local git config > committed repo default).
- [ ] Task 3.3: Document the Lifecycle Hook Contract and CLI actions in `MANUAL.md` and `README.md`.
- [ ] Task 3.4: Update `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **PROPOSED** — confers no execution rights until frozen)*

### 📂 Target Files (Modifications & Additions)
- [ ] `aapp` -> Add `hooks`, `hook-test`, `hook-hash` commands and extension-agnostic transparent plugin fallthrough.
- [ ] `NEW FILE` -> `lib/cmd_hook.sh` -> CLI implementation for `hooks`, `hook-test`, and `hook-hash`.
- [ ] `NEW FILE` -> `lib/hook_dispatcher.sh` -> Core POSIX hook execution and dispatch engine.
- [ ] `lib/cmd_plan.sh` -> Wire `on-freeze` and `on-start` lifecycle event triggers.
- [ ] `lib/cmd_pause.sh` -> Wire `on-pause` and `on-resume` lifecycle event triggers.
- [ ] `lib/cmd_sync.sh` -> Wire `pre-sync`, `post-sync`, and `on-sync` hook dispatches and `aapp.syncStrategy` resolution.
- [ ] `NEW FILE` -> `templates/skills/aapp-hooks/SKILL.md` -> Skill interface and registry documentation.
- [ ] `NEW FILE` -> `templates/skills/aapp-hooks/registry.tsv` -> Starter registry template with commented 5-column schema.
- [ ] `NEW FILE` -> `templates/skills/aapp-hooks/scripts/on-done.sample.sh` -> Reference hook script in Bash.
- [ ] `NEW FILE` -> `templates/skills/aapp-hooks/scripts/on-pickup.sample.py` -> Reference hook script in Python.
- [ ] `lib/cmd_init.sh` -> Scaffold `.agents/skills/aapp-hooks/` and seed starter `registry.tsv`.
- [ ] `NEW FILE` -> `tests/hooks_test.sh` -> Automated regression test suite for lifecycle hooks.
- [ ] `MANUAL.md` -> Comprehensive specification of JSON envelope schemas, 5-column registry format, and exit codes.
- [ ] `README.md` -> Document extensibility and plugin architecture.
- [ ] `CHANGELOG.md` -> Record v1.2.0 feature additions.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Blast radius enforcement engine remains focused on filesystem writes.
- [ ] `templates/aapp-pre-commit` -> Pre-commit hook remains focused on staged git validations.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 (Timeout Default, Gate-ness & Semantics):** *(Resolved 2026-09-19)*
  Closed via 5-column registry schema (`event<TAB>handler<TAB>sha256<TAB>timeout<TAB>mode`) where `gate` mode fails closed on timeout/exit-1 and `notify` mode logs an advisory warning and proceeds. Local hooks (`git config aapp.hook.<event>`) observe in `notify` mode only with a single global `aapp.hookTimeout` (default 10s), eliminating configuration overlap.
* [ ] **Question 2 (Async vs Synchronous Execution):** Should notifications (like `on-pickup` or `post-sync`) be run synchronously or permitted to fork asynchronously into the background if configured? (Recommended: Synchronous by default for determinism; scripts that wish to run asynchronously can background themselves via `&`).

---

## 📦 6. Change Log & Refinement History
* **2026-09-19:** Refined plugin discovery and team sync governance: (1) Mandated extension-agnostic plugin discovery in §D.4 (supporting extensionless executables, .py, .sh, or any extension with deterministic resolution). (2) Formalized `on-sync` transport execution contract and three-tier precedence for team sync governance in §D.1 (CLI flag > local git config > committed registry default). (3) Expanded event matrix to 10 events.
* **2026-09-19:** Expanded workflow actions and team sync governance: (1) Added CLI inspection & management actions: `aapp hooks` (audit & SHA256 integrity check), `aapp hook-test` (dry-run testing), and `aapp hook-hash` (portable registration helper). (2) Added §D.4 Transparent Command Fallthrough enabling `aapp <plugin>` to execute `.agents/skills/<plugin>/run` directly. (3) Expanded lifecycle event matrix from 6 to 9 events: added `on-start` (implementation start), `on-pause` (emergency brake), and `on-resume` (brake release). (4) Clarified team sync override in §D.1 and aligned with P-10.
* **2026-09-19:** Resolved red-team findings on P-12: (1) Replaced bash-only `IFS=$'\t'` with POSIX `TAB=$(printf '\t')` tested in `dash` with strict 5-column line validation. (2) Added portable SHA256 resolution chain (`sha256sum` -> `shasum -a 256` -> `sha256` -> `openssl`) with fail-closed security. (3) Resolved Open Question 1 by expanding registry schema to 5 columns (`event\tpath\tsha256\ttimeout\tmode`) where `gate` fails closed on timeout and `notify` warns. (4) Established the Local Hook Isolation Invariant (`git config aapp.hook.<event>` handlers observe in notify mode only and cannot gate). (5) Documented shallow entrypoint hashing limits and human-mandatory gate registration.
* **2026-09-19:** Architectural refinement: Replaced directory-based `.plans/hooks/` with the Protected Registry & Hash-Lock Contract (`.agents/skills/aapp-hooks/registry.tsv`). Neutralizes the agent self-modification vulnerability (an agent rewriting its own gate script to pass) by housing the registry under Section-2 protected `.agents/skills/aapp-*` with SHA256 integrity verification. Adopts pure POSIX line-oriented TSV parsing (`while IFS=$'\t' read -r event path hash`) eliminating runtime dependencies on `python3`/`jq` (#9), supports multi-hook multiplexing per event, provisions local developer overrides via `git config --get-all aapp.hook.<event>`, and preserves `.plans/` as 100% pure planning data.
* **2026-09-19:** Added §D.1 Core/Plugin Override Contract, paired with the matching amendment to `P-10`. Events previously allowed plugins only to *add* behaviour, so a core feature and a hook doing the same job would both run. `aapp.<feature>Strategy` (`builtin` default, `hook`) lets a plugin replace a built-in while the event still fires either way. Missing-hook behaviour is refusal rather than silent no-op or silent fallback. This plan owns the pattern; `P-10` declares the first instance (`aapp.syncStrategy`). Also recorded the previously undeclared dependency on `P-10` in Task 2.4, which wires hooks into a file `P-10` creates.
* **2026-09-16:** Split Open Question 1 into timeout *semantics* and timeout *value* after review of P-14 surfaced both. §D never defined what a timeout means, leaving it ambiguous whether a timed-out hook aborts a transition or warns — a slow webhook must not block archival. Added field evidence to §E that a 10s global default cannot serve both notification hooks and working hooks: a real pre-commit runs 30s (test suite + perltidy) and an adversarial-review hook (P-15 L2) runs 1–5 minutes. Recommends per-event defaults. Closes the first of the three P-12 mismatches recorded in P-15 §2.8.
* **2026-09-10:** Plan initialized from `hooks-transcript.md` architectural specification. Defined 6-event lifecycle matrix, POSIX stdio contract, JSON envelope schema, and exit-code semantics.
