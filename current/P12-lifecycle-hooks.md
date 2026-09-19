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

### B. Standard Lifecycle Event Matrix
| Hook Name | Trigger Moment | Key Payload Data | Typical Adopter Use Cases |
| :--- | :--- | :--- | :--- |
| `on-pickup` | New idea added to `pickup.md` or via CLI | `raw_text`, `author`, `timestamp` | Push to Slack triage channel, sync with mobile note intake. |
| `on-digest` | Idea promoted to Issue or Draft Blueprint | `lane` ("issue" \| "plan"), `id`, `file_path`, `title` | Scaffold tickets in Jira/Linear, assign project milestones. |
| `on-freeze` | Plan blast radius locked into `🔷 Frozen` | `plan_file`, `target_files`, `blocked_files` | Post lock status to team dashboard, notify PR reviewers. |
| `on-done` | Blueprint archived to `done/` and ledger | `plan_file`, `commit_hash`, `timestamp`, `linked_issues` | Close Jira/GitHub issues, write audit record to corporate DB, trigger CI. |
| `pre-sync` | Before `aapp sync` initiates pulls | `worktrees`, `remote_urls` | Pull remote DB updates and materialize local markdown. |
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

### D. POSIX Exit-Code Contract
* **`0` (Success / Proceed)**: Hook succeeded. AAPP proceeds with the lifecycle transition.
* **`1` (Abort / Hard Gate)**: Hook failed or explicitly rejected the transition. AAPP prints the hook's `stderr` to the terminal and immediately halts the operation, rolling back uncommitted changes if applicable.
* **`2` (Non-Blocking Warning)**: Hook emitted a non-fatal warning. AAPP logs the hook's `stderr` to the user and continues execution without aborting.
* **`124` / timeout — UNDEFINED, must be decided (see Open Question 1)**: §E specifies a watchdog but the contract never says what a timeout *means*. Today it is ambiguous whether a timed-out hook is treated as `1` (abort the lifecycle transition) or `2` (warn and continue). This matters more than the timeout value: a slow Slack webhook must never block a plan from being archived.

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

**Missing-hook behaviour — refuse, never degrade.** If a feature's strategy is `hook` but the
corresponding `.plans/hooks/<event>` is absent or not executable, the operation is **refused** with an
explicit message naming the config key and the expected path:

```text
❌ aapp.syncStrategy=hook but no executable handler is registered for post-sync in .agents/skills/aapp-hooks/registry.tsv or git config.
```

Silently doing nothing is the dangerous option — the operator believes the work happened. Silently
falling back to the built-in is nearly as bad, because a misconfiguration then looks like success.
Refusal is the only outcome where a mistake is visible at the moment it is made.

**Naming rule.** This plan owns the *pattern*; each core feature declares its own instance. The first
is `aapp.syncStrategy`, declared in `P-10` §B. Subsequent overridable features cost one config key,
not a new design.

### D.2 Protected Registry & Hash-Lock Contract (`.agents/skills/aapp-hooks/registry.tsv`)
To guarantee that quality gates (such as fallback ratchets, linter checks, or security audits) cannot be silently bypassed or rewritten by autonomous agents, the hook registry is housed inside `.agents/skills/aapp-hooks/`, which is permanently protected under Section 2 of `blast-radius-guard`.

1. **Registry Format**: A tab-delimited, line-oriented flat file (`registry.tsv`):
   ```tsv
   # event<TAB>handler_path<TAB>expected_sha256
   on-freeze	.agents/skills/migration-guard/scripts/check.sh	sha256:9f3c8e4...
   on-done	.agents/skills/archiver/scripts/push.sh	sha256:1a7e2b8...
   ```
2. **Pure POSIX Line-Oriented Parsing**: Parsed in standard POSIX shell with zero external dependencies:
   ```bash
   while IFS=$'\t' read -r event handler expected_hash; do
       [ -z "$event" ] || [ "${event#\#}" != "$event" ] && continue
       # match event, verify sha256 of handler, dispatch
   done < "$REGISTRY_FILE"
   ```
3. **Hash-Lock Verification**: Before executing any handler defined in the registry, the dispatcher computes `sha256sum "$handler"`. If the current file hash does not match `expected_hash`:
   - The operation is **hard-aborted** with an integrity violation notice.
   - An agent cannot modify the handler script to pass itself because altering the script breaks the registered hash, and the agent is denied write access to `registry.tsv`.
   - Modifying a handler or registering a new gate is a deliberate human act requiring an update to the protected registry.
4. **Multi-Hook Multiplexing**: Multiple lines with the same `<event>` are permitted. The dispatcher iterates through all registered handlers in sequence. An exit code `1` from any handler halts the entire lifecycle event.

### D.3 Local Developer Override Contract (`git config aapp.hook.<event>`)
For local debugging or temporary hook scripts that should not be committed to the repository:
- `git config --get-all aapp.hook.<event>` allows specifying ad-hoc handler paths.
- Local overrides run in addition to committed registry hooks.
- If a project wishes to disable local overrides in CI, setting `git config aapp.allowLocalHooks false` confines execution strictly to the committed `registry.tsv`.

### E. Dispatcher Engine Architecture (`lib/hook_dispatcher.sh`)
* Provides a shared internal function `dispatch_hook <event_name> <json_data_generator_fn>`.
* Discovers handlers from `.agents/skills/aapp-hooks/registry.tsv` and local `git config --get-all aapp.hook.<event_name>`.
* If no handlers are registered: silently and instantly passes (zero overhead).
* For each handler:
  1. Asserts handler path exists and is executable (`[ -x ... ]`).
  2. If registered in `registry.tsv`, asserts SHA256 integrity. If hash mismatches, prints error to `stderr` and aborts (exit 1).
  3. Constructs the standard metadata header, streams payload to handler's `stdin`, captures exit code and `stderr`, and enforces the contract.
* Includes a configurable timeout (default per-event or 10s via portable POSIX subshell watchdog) to prevent hung network calls from blocking workflows.

> **⏱️ Timeout calibration — field evidence (2026-09-16).** A 10-second default assumes every hook is a
> fire-and-forget notification. That holds for the Slack/webhook cases in the §B matrix, but not for the
> projects most likely to adopt hooks at all:
> * The `logsniffer` project runs a **pre-commit of up to 30 seconds** (test suite + `perltidy`).
>   Teams that invest in hooks invest in *slow* hooks.
> * An `on-done` hook that triggers CI or writes an audit record to a corporate database is not
>   fire-and-forget either.
> * An adversarial-review hook (`P-15` layer L2) runs **1–5 minutes** against a large blueprint.
>
> The consequence is not that 10s is wrong everywhere — it is right for notifications — but that a
> single global default cannot serve both classes. Resolve via Open Question 1 before freeze.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core Dispatcher Engine & Schema Validator
- [ ] Task 1.1: Create `lib/hook_dispatcher.sh` implementing `dispatch_hook()` with TSV parsing, SHA256 hash verification, `stdin` streaming, and exit-code handling.
- [ ] Task 1.2: Implement portable execution watchdog/timeout mechanism (default 10 seconds).
- [ ] Task 1.3: Author JSON envelope generator for all 6 lifecycle events.

### Phase 2: Hook Wiring into CLI & Protocol Commands
- [ ] Task 2.1: Wire `on-done` into `cmd_done` (or `/done` command execution).
- [ ] Task 2.2: Wire `on-freeze` into `cmd_freeze` (or `/freeze` command execution).
- [ ] Task 2.3: Wire `on-digest` into `cmd_digest` (or `/digest` command execution).
- [ ] Task 2.4: Wire `pre-sync` and `post-sync` into `lib/cmd_sync.sh`. **Depends on `P-10`**, which creates that file — this task cannot execute until remote sync ships. Also honour `aapp.syncStrategy` per §D.1.
- [ ] Task 2.5: Implement `aapp.<feature>Strategy` resolution in `lib/hook_dispatcher.sh` per §D.1, including the refuse-on-missing-hook path.
- [ ] Task 2.6: Update `lib/cmd_init.sh` to scaffold `.agents/skills/aapp-hooks/` and deploy `registry.tsv` and `SKILL.md`.

### Phase 3: Sample Hooks, Automated Tests & Documentation
- [ ] Task 3.1: Create sample hook templates in `templates/skills/aapp-hooks/`:
  - `registry.tsv` (starter registry template with documented syntax and examples).
  - `scripts/on-done.sample.sh` (logs completion to a local append-only log or webhook).
  - `scripts/on-pickup.sample.py` (demonstrates JSON reading and external notification).
- [ ] Task 3.2: Author automated test suite `tests/hooks_test.sh` verifying:
  - Exit code 0 allows lifecycle transition.
  - Exit code 1 halts lifecycle transition and prints stderr.
  - Exit code 2 emits warning and proceeds.
  - Non-executable hook is safely skipped.
  - SHA256 hash mismatch halts lifecycle transition and prints diagnostic.
  - Timeout protection on hung scripts.
  - Local `git config` overrides execute cleanly alongside registry entries.
- [ ] Task 3.3: Document the Lifecycle Hook Contract in `MANUAL.md` and `README.md`.
- [ ] Task 3.4: Update `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **PROPOSED** — confers no execution rights until frozen)*

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `lib/hook_dispatcher.sh` -> Core POSIX hook execution and dispatch engine.
- [ ] `NEW FILE` -> `templates/skills/aapp-hooks/SKILL.md` -> Skill interface and registry documentation.
- [ ] `NEW FILE` -> `templates/skills/aapp-hooks/registry.tsv` -> Starter registry template with commented schema.
- [ ] `NEW FILE` -> `templates/skills/aapp-hooks/scripts/on-done.sample.sh` -> Reference hook script in Bash.
- [ ] `NEW FILE` -> `templates/skills/aapp-hooks/scripts/on-pickup.sample.py` -> Reference hook script in Python.
- [ ] `lib/cmd_init.sh` -> Scaffold `.agents/skills/aapp-hooks/` and seed starter `registry.tsv`.
- [ ] `lib/cmd_sync.sh` -> Wire `pre-sync` and `post-sync` hook dispatches.
- [ ] `NEW FILE` -> `tests/hooks_test.sh` -> Automated regression test suite for lifecycle hooks.
- [ ] `MANUAL.md` -> Comprehensive specification of JSON envelope schemas, registry format, and exit codes.
- [ ] `README.md` -> Document extensibility and plugin architecture.
- [ ] `CHANGELOG.md` -> Record v1.2.0 feature additions.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Blast radius enforcement engine remains focused on filesystem writes.
- [ ] `templates/aapp-pre-commit` -> Pre-commit hook remains focused on staged git validations.
- [ ] `aapp` -> Dispatcher requires no changes.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1 (Timeout Default *and* Semantics):** Two decisions, previously conflated as one.
  * **(a) What does a timeout mean?** The exit-code contract in §D covers `0`/`1`/`2` but never defines a timeout, so it is currently ambiguous whether a timed-out hook aborts the lifecycle transition or merely warns. *Recommendation: treat a timeout as `2` (warn and continue) for notification events, and `1` (abort) only where the hook is a declared gate. A slow webhook must never block archival.*
  * **(b) What default, and is one default enough?** 10s suits the notification cases in §B, but field evidence (§E) shows real hooks running 30s (`logsniffer` pre-commit: test suite + perltidy) to several minutes (adversarial review, `P-15` L2). *Recommendation: per-event defaults rather than one global value — short for `on-pickup`/`post-sync`, generous for `on-done`/`on-refine` — with `git config aapp.hookTimeout` overriding globally and `aapp.hookTimeout.<event>` per event.*
* [ ] **Question 2 (Async vs Synchronous Execution):** Should notifications (like `on-pickup` or `post-sync`) be run synchronously or permitted to fork asynchronously into the background if configured? (Recommended: Synchronous by default for determinism; scripts that wish to run asynchronously can background themselves via `&`).

---

## 📦 6. Change Log & Refinement History
* **2026-09-19:** Architectural refinement: Replaced directory-based `.plans/hooks/` with the Protected Registry & Hash-Lock Contract (`.agents/skills/aapp-hooks/registry.tsv`). Neutralizes the agent self-modification vulnerability (an agent rewriting its own gate script to pass) by housing the registry under Section-2 protected `.agents/skills/aapp-*` with SHA256 integrity verification. Adopts pure POSIX line-oriented TSV parsing (`while IFS=$'\t' read -r event path hash`) eliminating runtime dependencies on `python3`/`jq` (#9), supports multi-hook multiplexing per event, provisions local developer overrides via `git config --get-all aapp.hook.<event>`, and preserves `.plans/` as 100% pure planning data.
* **2026-09-19:** Added §D.1 Core/Plugin Override Contract, paired with the matching amendment to `P-10`. Events previously allowed plugins only to *add* behaviour, so a core feature and a hook doing the same job would both run. `aapp.<feature>Strategy` (`builtin` default, `hook`) lets a plugin replace a built-in while the event still fires either way. Missing-hook behaviour is refusal rather than silent no-op or silent fallback. This plan owns the pattern; `P-10` declares the first instance (`aapp.syncStrategy`). Also recorded the previously undeclared dependency on `P-10` in Task 2.4, which wires hooks into a file `P-10` creates.
* **2026-09-16:** Split Open Question 1 into timeout *semantics* and timeout *value* after review of P-14 surfaced both. §D never defined what a timeout means, leaving it ambiguous whether a timed-out hook aborts a transition or warns — a slow webhook must not block archival. Added field evidence to §E that a 10s global default cannot serve both notification hooks and working hooks: a real pre-commit runs 30s (test suite + perltidy) and an adversarial-review hook (P-15 L2) runs 1–5 minutes. Recommends per-event defaults. Closes the first of the three P-12 mismatches recorded in P-15 §2.8.
* **2026-09-10:** Plan initialized from `hooks-transcript.md` architectural specification. Defined 6-event lifecycle matrix, POSIX stdio contract, JSON envelope schema, and exit-code semantics.

