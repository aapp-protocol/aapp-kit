# 🗺️ Plan: Lifecycle Plugin Hooks Architecture (`.plans/hooks/`)
* **Created:** 2026-09-10 | **Last Refined:** 2026-09-10
* **Target Issue / Milestone:** Milestone v1.2.0 (Lifecycle Extension Engine)
* **Status:** 🔴 Under Review
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Every commit you make must include your co-author trailer (`Co-authored-by: Antigravity <antigravity@google.com>`).
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

---

## 1. Context & Architectural Goal
* **What**: Implement an extensible, zero-dependency Git-style lifecycle hook engine (`.plans/hooks/*`) for AAPP, allowing external scripts, webhooks, issue trackers (Jira, Linear, GitHub Issues), and distributed databases (SQLite/Turso, CouchDB, Postgres) to intercept planning events via standard POSIX `stdin` JSON envelopes and exit codes.
* **Why**: Core AAPP must remain 100% offline, lightning-fast, and POSIX-pure (zero npm/Python/Go dependencies). Forcing issue tracker integrations or remote databases directly into the core CLI causes API churn, authentication complexity, and fragile networking. By specifying a clean disk-and-stdio protocol contract (following Git's native `.git/hooks/*` design), adopters can build arbitrary enterprise integrations in 10 lines of Bash, Python, or Go without modifying core AAPP.
* **The Invariant**: AAPP core knows nothing about external SaaS APIs or remote networks. It only dispatches structured JSON payloads to executable hook scripts in `.plans/hooks/` and evaluates their standard exit codes.

---

## 2. Technical Blueprint

### A. The Hook Execution Flow
```text
┌───────────────────────────┐
│     AAPP CLI Engine       │
│ (/done, /freeze, sync, …) │
└─────────────┬─────────────┘
              │ 1. Discovers executable: .plans/hooks/<event>
              │ 2. Streams Event Envelope via STDIN (JSON)
              ▼
┌───────────────────────────┐
│   .plans/hooks/<event>    │ ───► External SaaS / Database / Slack / Webhook
│ (Bash, Python, Go, Node)  │
└─────────────┬─────────────┘
              │ 3. Returns POSIX Exit Code & STDERR
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
| `on-freeze` | Plan blast radius locked into 🟢 Ready | `plan_file`, `target_files`, `blocked_files` | Post lock status to team dashboard, notify PR reviewers. |
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

### E. Dispatcher Engine Architecture (`lib/hook_dispatcher.sh`)
* Provides a shared internal function `dispatch_hook <event_name> <json_data_generator_fn>`.
* Checks if `.plans/hooks/<event_name>` exists and has executable permissions (`[ -x ... ]`).
* If not present or not executable: silently and instantly passes (zero overhead).
* If present: constructs the standard metadata header, streams payload to hook's `stdin`, captures exit code and `stderr`, and enforces the contract.
* Includes a configurable timeout (default 10s via `timeout` or portable POSIX subshell watchdog) to prevent hung network calls from blocking local developer workflows.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core Dispatcher Engine & Schema Validator
- [ ] Task 1.1: Create `lib/hook_dispatcher.sh` implementing `dispatch_hook()` with `stdin` streaming and exit-code handling.
- [ ] Task 1.2: Implement portable execution watchdog/timeout mechanism (default 10 seconds).
- [ ] Task 1.3: Author JSON envelope generator for all 6 lifecycle events.

### Phase 2: Hook Wiring into CLI & Protocol Commands
- [ ] Task 2.1: Wire `on-done` into `cmd_done` (or `/done` command execution).
- [ ] Task 2.2: Wire `on-freeze` into `cmd_freeze` (or `/freeze` command execution).
- [ ] Task 2.3: Wire `on-digest` into `cmd_digest` (or `/digest` command execution).
- [ ] Task 2.4: Wire `pre-sync` and `post-sync` into `lib/cmd_sync.sh`.
- [ ] Task 2.5: Update `lib/cmd_init.sh` to scaffold `.plans/hooks/` and deploy `.plans/hooks/README.md`.

### Phase 3: Sample Hooks, Automated Tests & Documentation
- [ ] Task 3.1: Create sample hook templates in `templates/hooks/`:
  - `on-done.sample.sh` (logs completion to a local append-only log or webhook).
  - `on-pickup.sample.py` (demonstrates JSON reading and external notification).
- [ ] Task 3.2: Author automated test suite `tests/hooks_test.sh` verifying:
  - Exit code 0 allows lifecycle transition.
  - Exit code 1 halts lifecycle transition and prints stderr.
  - Exit code 2 emits warning and proceeds.
  - Non-executable hook is safely skipped.
  - Timeout protection on hung scripts.
- [ ] Task 3.3: Document the Lifecycle Hook Contract in `MANUAL.md` and `README.md`.
- [ ] Task 3.4: Update `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **PROPOSED** — confers no execution rights until frozen)*

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `lib/hook_dispatcher.sh` -> Core POSIX hook execution and dispatch engine.
- [ ] `NEW FILE` -> `templates/hooks-readme.md` -> Starter guide deployed into `.plans/hooks/README.md`.
- [ ] `NEW FILE` -> `templates/hooks/on-done.sample.sh` -> Reference hook script in Bash.
- [ ] `NEW FILE` -> `templates/hooks/on-pickup.sample.py` -> Reference hook script in Python.
- [ ] `lib/cmd_init.sh` -> Scaffold `.plans/hooks/` directory during initialization.
- [ ] `lib/cmd_sync.sh` -> Wire `pre-sync` and `post-sync` hook dispatches.
- [ ] `NEW FILE` -> `tests/hooks_test.sh` -> Automated regression test suite for lifecycle hooks.
- [ ] `MANUAL.md` -> Comprehensive specification of JSON envelope schemas and exit codes.
- [ ] `README.md` -> Document extensibility and plugin architecture.
- [ ] `CHANGELOG.md` -> Record v1.2.0 feature additions.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Blast radius enforcement engine remains focused on filesystem writes.
- [ ] `templates/aapp-pre-commit` -> Pre-commit hook remains focused on staged git validations.
- [ ] `aapp` -> Dispatcher requires no changes.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1 (Default Timeout):** Should the hook execution timeout be fixed at 10 seconds with override via `git config aapp.hookTimeout <seconds>`? (Recommended: Yes, prevents broken network requests in custom hooks from freezing developer commits/transitions).
* [ ] **Question 2 (Async vs Synchronous Execution):** Should notifications (like `on-pickup` or `post-sync`) be run synchronously or permitted to fork asynchronously into the background if configured? (Recommended: Synchronous by default for determinism; scripts that wish to run asynchronously can background themselves via `&`).

---

## 📦 6. Change Log & Refinement History
* **2026-09-10:** Plan initialized from `hooks-transcript.md` architectural specification. Defined 6-event lifecycle matrix, POSIX stdio contract, JSON envelope schema, and exit-code semantics.
