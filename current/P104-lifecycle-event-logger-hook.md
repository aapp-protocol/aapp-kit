# 🗺️ Plan P-104: Lifecycle Event Logger Hook
* **Created:** 2026-10-17 | **Last Refined:** 2026-10-17
* **Target Issue / Milestone:** none
* **Plan ID:** P-104
* **Changelog:** Added: sample observer event logger hook and post-* lifecycle telemetry (P-104)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `9def1ad` (develop)
* **Worktree:** .workspace/P104 (plan/P104-lifecycle-event-logger-hook)
* **Commits:** `47b9f4b` (plan/P104-lifecycle-event-logger-hook)
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOMIZATIONS OUTSIDE. -->
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** #<num>        <- written by verbs: 'aapp issue hotfix' or 'aapp refine <id> blocked <num>' adds it; 'aapp issue close' removes it -->
<!-- * **Emergency Hotfixes:** #<num> <- append-only, written by 'aapp issue hotfix'; more than aapp.maxEmergencyHotfixes blocks the plan for good -->
<!-- * **Also Closes:** #<n>, #<m>  <- written by 'aapp refine <id> closes <num> [remove]': further issues this plan sorts; 'aapp done' closes them with the plan's commit -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
Autonomous agents and multi-session teams require comprehensive visibility into development and planning lifecycles (plan transitions, code commits, issue progression) without violating repository portability or corrupting Git history.

Today, while the kit provides robust lifecycle hooks for quality gates (`mode=gate`), telemetry across observer events (`mode=observer`) has notable gaps:
1. **Missing Observer Dispatches**: While `freeze`, `start`, `done`, `abort`, `pause`, and `sync` emit `post-*` events, key actions like `draft`, `commit`, and `issue` transitions (`log`, `queue`, `fix`, `close`) emit no generic lifecycle events.
2. **Out-of-Repo Storage Guarantee**: Adopters lack a canonical, battle-tested sample hook that logs structured JSON Lines (`.jsonl`) strictly outside the tracked repository (e.g. in `.git/` or `~/.local/share/aapp/logs/`), ensuring that logging cannot trigger pre-commit blast radius violations or dirty the Git index.
3. **Decoupled Architecture**: Logging must remain entirely decoupled from core kit logic. The kit's role is strictly to pump clean, uniform JSON data to `stdin` of registered hooks; the end user or team configures downstream wrappers, log shippers, or query plugins as they see fit.

The goal of P-104 is to provide the canonical showcase observer hook (`examples/hooks/event-logger.sample`), establish the formal Event Telemetry Contract in `docs/reference/09-event-telemetry.md` (mirroring `docs/reference/08-output-json.md` and pinned by automated tests), wire in adoption tracking, and complete the kit's `post-*` lifecycle event dispatches across all domains.

---

## 2. Technical Blueprint

### 2.1 The Event Logger Showcase Hook (`examples/hooks/event-logger.sample`)
- **Extensionless Executable**: The hook sample is named `examples/hooks/event-logger.sample` and deployed as `.agents/hooks/event-logger`. Hooks can be written in any scripting language or binary and must never mandate a `.sh` file extension.
- **Mode**: Registered as `mode=observer` across any desired `post-*` events via `aapp hook-hash`.
- **Zero-Pollution Storage**: Resolves destination strictly outside Git-tracked workspace:
  1. Primary default: `$(git rev-parse --git-path aapp_events.jsonl)` (resides in `.git/` or worktree gitdir; completely invisible to Git status).
  2. Override via config/env: `aapp.logFile` or `AAPP_LOG_FILE` (e.g. `~/.local/share/aapp/logs/events.jsonl`).
- **Single-Line JSONL Invariant**: While `build_event_envelope` emits pretty-printed multi-line JSON, `event-logger.sample` normalizes standard input into a single unbroken line per event (compact JSONL) using pure POSIX shell constructs (e.g. `tr` or `awk`, avoiding external dependencies on `jq` or `python3`) and appends atomically via `>>`.
- **Fail-Safe Invariant**: Exits `0` on success and logs advisory diagnostics on write failure without interrupting kit operations.

### 2.2 Standard Dispatch Envelope (`build_event_envelope`)
Every hook dispatched via `dispatch_hook "$event" "$data_json"` receives the standard outer envelope on `stdin`:
```json
{
  "version": "1.0",
  "event": "post-done",
  "timestamp": "2026-10-17T04:15:00Z",
  "actor": "developer",
  "repository": {
    "root": "/home/lorand/000/agent-planning-kit",
    "branch": "develop",
    "remote": "origin"
  },
  "data": { ... event-specific payload ... },
  "extra": {}
}
```

### 2.3 Complete Post-* Event Catalog & JSON Output Payloads

The kit standardizes 14 `post-*` observer events spanning all system lifecycles, consolidating all issue operations into a unified `post-issue` event with plugin-aligned `{"command": "issue", "event": ...}` payloads. Below are the exact `data` payloads pumped out to registered hooks:

#### A. Blueprint & Planning Lifecycle (`command: "plan"`)
1. **`post-draft`** (`cmd_draft` in `lib/cmd_plan.sh`):
   ```json
   {
     "command": "plan",
     "event": "draft",
     "plan_id": "P-104",
     "slug": "lifecycle-event-logger-hook",
     "plan_file": "current/P104-lifecycle-event-logger-hook.md",
     "group": "none"
   }
   ```
2. **`post-freeze`** (`cmd_freeze` / `cmd_freeze_start` in `lib/cmd_plan.sh`):
   ```json
   {
     "command": "plan",
     "event": "freeze",
     "plan_id": "P-102",
     "plan_file": "current/P102-group-done-lifecycle-order.md"
   }
   ```
3. **`post-start`** (`cmd_start` / `cmd_freeze_start` in `lib/cmd_plan.sh`):
   ```json
   {
     "command": "plan",
     "event": "start",
     "plan_id": "P-102",
     "plan_file": "current/P102-group-done-lifecycle-order.md",
     "worktree": "/path/to/repo/.workspace/P102",
     "branch": "feature/group-done-lifecycle-order"
   }
   ```
4. **`post-refine`** (`cmd_refine` in `lib/cmd_plan.sh`, delivered by P-99):
   ```json
   {
     "command": "plan",
     "event": "refine",
     "plan_id": "P-101",
     "plan_file": "current/P101-group-amendments-member.md",
     "refine_kind": "request|approve|refuse|file|message|group|slug|closes|blocked",
     "commit_sha": "a3d784a",
     "args": ["tests/verbs/done.sh"]
   }
   ```
5. **`post-done`** (`cmd_done` in `lib/cmd_plan.sh`):
   ```json
   {
     "command": "plan",
     "event": "done",
     "plan_id": "P-97",
     "plan_file": "done/P97-pickup-metadata-split.md",
     "commit_hash": "4a7da2f",
     "commits": ["4a7da2f", "cd0dd85"],
     "worktree": "/path/to/repo/.workspace/P97"
   }
   ```
6. **`post-abort`** (`cmd_plan_abort` in `lib/cmd_plan.sh`):
   ```json
   {
     "command": "plan",
     "event": "abort",
     "plan_id": "P-80",
     "plan_file": "aborted/P80-experimental-feature.md",
     "target_issue": "none"
   }
   ```
7. **`post-active`** (`cmd_active` in `lib/cmd_plan.sh`):
   ```json
   {
     "command": "plan",
     "event": "active",
     "action": "set|swap|clear",
     "active_plan": "P-102",
     "previous_plan": "P-104"
   }
   ```
8. **`post-tdd`** (`cmd_tdd` in `lib/cmd_plan.sh`):
   ```json
   {
     "command": "plan",
     "event": "tdd",
     "plan_id": "P-102",
     "test_files": ["tests/verbs/done.sh"],
     "assertions_count": 4
   }
   ```

#### B. Implementation & Group Landing Lifecycle (`command: "commit"`)
9. **`post-commit`** (`cmd_commit` in `lib/cmd_commit.sh`):
   ```json
   {
     "command": "commit",
     "event": "record",
     "plan_id": "P-102",
     "commit_sha": "59e5399",
     "subject": "fix: reorder group done lifecycle to verify gate first",
     "worktree": "/path/to/repo/.workspace/P102",
     "agent": "Antigravity",
     "vendor": "Google",
     "model": "gemini-3.8-flash"
   }
   ```
10. **`post-land`** (`aapp commit land` in `lib/cmd_commit.sh`, delivered by P-101):
    ```json
    {
      "command": "commit",
      "event": "land",
      "group_id": "P-103",
      "amendment_id": "P-101",
      "feature_branch": "feature/group-lifecycle-and-amendments",
      "commit_sha": "f1e2d3c"
    }
    ```

#### C. Issue Lifecycle (`lib/cmd_issue.sh`)
11. **`post-issue`** (unified observer hook across all issue operations):
    Dispatched after every issue state transition, adopting the exact command/event model used by kit plugins (`{"command": "issue", "event": "<action>", ...}`).

    - **`log`** (`cmd_issue_log`):
      ```json
      {
        "command": "issue",
        "event": "log",
        "issue_id": "#166",
        "sev": "MED",
        "type": "CLI",
        "symptom": "parser fails on trailing newline",
        "files": ["lib/cmd_issue.sh"]
      }
      ```
    - **`queue`** / **`unqueue`** (`cmd_issue_queue` / `cmd_issue_unqueue`):
      ```json
      {
        "command": "issue",
        "event": "queue",
        "issue_id": "#166",
        "level": "urgent"
      }
      ```
    - **`fix`** (`cmd_issue_fix`):
      ```json
      {
        "command": "issue",
        "event": "fix",
        "issue_id": "#166",
        "worktree": "/path/to/repo/.workspace/fix-166",
        "branch": "fix/166"
      }
      ```
    - **`close`** (`cmd_issue_close`):
      ```json
      {
        "command": "issue",
        "event": "close",
        "issue_id": "#166",
        "commit_sha": "b2c3d4e",
        "summary": "Fix trailing newline in parser"
      }
      ```
    - **`hotfix`** (`cmd_issue_hotfix`):
      ```json
      {
        "command": "issue",
        "event": "hotfix",
        "issue_id": "#167",
        "blocked_plan": "P-102",
        "files": ["lib/cmd_plan.sh"]
      }
      ```
    - **`withdraw`** (`cmd_issue_withdraw`):
      ```json
      {
        "command": "issue",
        "event": "withdraw",
        "issue_id": "#166",
        "reason": "Not reproducible on latest develop"
      }
      ```

#### D. Operational & Emergency Lifecycle
12. **`post-pause`** (`cmd_pause` in `lib/cmd_pause.sh`):
    ```json
    {
      "command": "pause",
      "event": "pause",
      "reason": "switching tasks",
      "shared": false
    }
    ```
13. **`post-resume`** (`cmd_resume` in `lib/cmd_pause.sh`):
    ```json
    {
      "command": "pause",
      "event": "resume",
      "restored_count": 2,
      "drift_found": 0
    }
    ```
14. **`post-sync`** (`cmd_sync` in `lib/cmd_sync.sh`):
    ```json
    {
      "command": "sync",
      "event": "sync",
      "action": "pull_push",
      "remote": "origin",
      "worktrees": [".plans", ".agents", ".githooks"]
    }
    ```

### 2.4 The Event Telemetry Contract (`docs/reference/09-event-telemetry.md`)
To provide the same architectural durability and machine-readable certainty as `docs/reference/08-output-json.md`, P-104 establishes `docs/reference/09-event-telemetry.md` as the formal reference contract for all kit telemetry events.

- **Contract Equality**: `09-event-telemetry.md` mirrors the format and rigor of `08-output-json.md`:
  - Top-level YAML frontmatter (`title: Event Telemetry`, `category: reference`).
  - Core rules governing envelope guarantees, timestamps (ISO-8601 UTC), string encoding (UTF-8), and error handling.
  - Field-by-field specification tables (`Field | Type | Holds`) for the outer envelope, `repository` object, and all 14 lifecycle event payload schemas.
  - **Universal 2-Key Invariant**: Every event payload in `data` consistently carries `command` (the kit subsystem) and `event` (the lifecycle action), enabling uniform ingestion by any downstream log parser or broker.
- **Contract Enforcement Test (`tests/event_telemetry_test.sh`)**:
  - Mirroring `tests/output_json_test.sh`, an automated test suite verifies that sample payloads generated during real or simulated kit lifecycle executions match the tables defined in `docs/reference/09-event-telemetry.md`.
  - Ensures documentation and code cannot drift apart during future kit development.

### 2.5 Adoption Tracking Integration (`lib/adoption.sh`)
To make event logging a first-class, visible recommendation during project onboarding and `aapp status`, P-104 adds an adoption checklist rule to `lib/adoption.sh` and syncs `.plans/adoption.md`:
- **Rule ID**: `EVENT-LOG`
- **Section**: `🛡️ Hooks & Gates`
- **Manual Heading**: `Lifecycle Event Telemetry & Logging`
- **Trigger**: `_trig_always`
- **Check (`_chk_event_log`)**: Passes (`0`) if any observer hook is configured in `git config --get-regexp '^aapp\.hook\.'`; otherwise returns `1` to keep the task open until configured or ticked by the user.
- **Rule Array Specification (`lib/adoption.sh`)**:
  ```bash
  "EVENT-LOG|🛡️ Hooks & Gates|Lifecycle Event Telemetry & Logging|_trig_always|_chk_event_log|Register an observer event logger hook from examples/hooks/event-logger.sample with aapp hook-hash; tick it when you do not want one."
  ```
- **Rendered Onboarding Task (`.plans/adoption.md`)**:
  ```markdown
  - [ ] `[EVENT-LOG]` Register an observer event logger hook from examples/hooks/event-logger.sample with aapp hook-hash; tick it when you do not want one. → MANUAL: Lifecycle Event Telemetry & Logging
  ```

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`. All new dispatches are additive observer events; existing handlers receive enriched telemetry without breaking contracts.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Showcase Hook Sample & Adoption Rule
- [x] Task 1.1: Author extensionless `examples/hooks/event-logger.sample` conforming to observer mode, out-of-repo path resolution, and atomic POSIX single-line JSONL append.
- [x] Task 1.2: Add `EVENT-LOG` adoption rule, manual heading, and check helper in `lib/adoption.sh`.
- [x] Task 1.3: Add unit tests in `tests/hooks_test.sh` verifying registration, SHA-256 verification, payload ingestion, and single-line file output.

### Phase 2: Completing Core Lifecycle Dispatches Across All Domains
- [x] Task 2.1: Add `post-draft`, `post-active`, and `post-tdd` dispatches in `lib/cmd_plan.sh`.
- [x] Task 2.2: Add `post-commit` dispatch in `lib/cmd_commit.sh`.
- [x] Task 2.3: Add unified `post-issue` dispatch in `lib/cmd_issue.sh` with plugin-style payloads (`{"command": "issue", "event": ...}`) across log, queue, unqueue, fix, close, hotfix, and withdraw.

### Phase 3: Contract Reference, Automated Contract Tests & Documentation
- [x] Task 3.1: Author `docs/reference/09-event-telemetry.md` documenting the envelope, repository object, 14 lifecycle events, and unified `post-issue` payload schemas in markdown tables.
- [x] Task 3.2: Author `tests/event_telemetry_test.sh` verifying that runtime dispatches and payload fixtures match `docs/reference/09-event-telemetry.md`.
- [x] Task 3.3: Update `lib/cmd_hook.sh` and `lib/docs/verbs/hooks.md` with all 14 events in help/docs.
- [x] Task 3.4: Update `MANUAL.md` with the Event Logger showcase, out-of-repo setup, and telemetry reference link.
- [x] Task 3.5: Verify all kit test suites pass (`./aapp test quiet`).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `examples/hooks/event-logger.sample` -> Sample observer hook script for out-of-repo JSONL event logging (extensionless).
- [ ] `NEW FILE` -> `docs/reference/09-event-telemetry.md` -> Reference specification documenting the event telemetry contract and schemas (mirrors `08-output-json.md`).
- [ ] `NEW FILE` -> `tests/event_telemetry_test.sh` -> Automated contract verification test suite for event telemetry schemas.
- [ ] `lib/adoption.sh` -> Add `EVENT-LOG` advisory rule and heading under `🛡️ Hooks & Gates`.
- [ ] `lib/cmd_commit.sh` -> Emit `post-commit` lifecycle event with `command: "commit"` and `event: "record"`.
- [ ] `lib/cmd_issue.sh` -> Emit unified `post-issue` lifecycle event across all issue operations with `{"command": "issue", "event": ...}` payloads.
- [ ] `lib/cmd_plan.sh` -> Emit planning lifecycle events with `command: "plan"` and specific `event` action.
- [ ] `lib/cmd_pause.sh` -> Emit `post-pause` and `post-resume` lifecycle events with `command: "pause"` and specific `event` action.
- [ ] `lib/cmd_sync.sh` -> Emit `post-sync` lifecycle event with `command: "sync"` and `event: "sync"`.
- [ ] `lib/cmd_hook.sh` -> Add all 14 lifecycle events to available events list in `help hooks`.
- [ ] `lib/docs/verbs/hooks.md` -> Update event documentation and payload schemas.
- [ ] `MANUAL.md` -> Add Event Logger showcase section and telemetry guide.
- [ ] `tests/hooks_test.sh` -> Add automated tests for event-logger hook and new dispatches.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Write guard is untouched.
- [ ] `templates/aapp-pre-commit` -> Pre-commit gate is untouched (P-99 handles design lock).
- [ ] `lib/aapp-lib.sh` -> Core resolver untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Default Out-of-Repo Path.** Should the sample default to `$(git rev-parse --git-path aapp_events.jsonl)` (repository git directory) or `~/.local/share/aapp/logs/events.jsonl` (centralized user log)? -> **Resolved**: Default to gitdir `$(git rev-parse --git-path aapp_events.jsonl)` (immune to workspace pollution and blast-radius guards), with configurable override via `aapp.logFile` or `AAPP_LOG_FILE`.

---

## 📦 6. Change Log & Refinement History
* **2026-10-17:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-17:** Plan scaffolded and authored from user requirement for decoupled, out-of-repo lifecycle event logging.
* **2026-10-17:** Expanded Technical Blueprint with complete 19-event catalog and explicit JSON output schemas.
* **2026-10-17:** Detailed the formal Event Telemetry Contract (`docs/reference/09-event-telemetry.md`), adoption tracking (`lib/adoption.sh`), extensionless hook standard (`examples/hooks/event-logger.sample`), and automated telemetry verification suite (`tests/event_telemetry_test.sh`).
* **2026-10-17:** Unified issue lifecycle telemetry into a single `post-issue` observer event with plugin-aligned payload structure (`{"command": "issue", "event": "<step>", ...}`).
* **2026-10-17:** Standardized the universal 2-key invariant (`command` and `event`) across all 14 kit lifecycle telemetry payloads (plan, commit, issue, pause, sync) for seamless downstream log parsing.
* **2026-10-17:** Detailed the rendered `[EVENT-LOG]` onboarding adoption task line and check helper specification in Section 2.5.
