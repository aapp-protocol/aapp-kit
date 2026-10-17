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
* **Status:** 🟣 Under Review
* **Base:** none
* **Commits:** none
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

The goal of P-104 is to provide the canonical showcase observer hook (`examples/hooks/event-logger.sample`) and complete the kit's `post-*` lifecycle event dispatches.

---

## 2. Technical Blueprint

### 2.1 The Event Logger Showcase Hook (`examples/hooks/event-logger.sample`)
- **Mode**: Registered as `mode=observer` across any desired `post-*` events via `aapp hook-hash`.
- **Zero-Pollution Storage**: Resolves destination strictly outside Git-tracked workspace:
  1. Primary default: `$(git rev-parse --git-path aapp_events.jsonl)` (resides in `.git/` or worktree gitdir; completely invisible to Git status).
  2. Override via config/env: `aapp.logFile` or `AAPP_LOG_FILE` (e.g. `~/.local/share/aapp/logs/events.jsonl`).
- **Data Contract**: Reads JSON envelope from `stdin`, decorates with ISO-8601 UTC timestamp and PID if absent, and appends a single-line JSON (`.jsonl`) string using atomic file redirection (`>>`).
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

The kit standardizes 19 `post-*` observer events spanning all system lifecycles. Below are the exact `data` payloads pumped out to registered hooks:

#### A. Blueprint & Planning Lifecycle
1. **`post-draft`** (`cmd_draft` in `lib/cmd_plan.sh`):
   ```json
   {
     "plan_id": "P-104",
     "slug": "lifecycle-event-logger-hook",
     "plan_file": "current/P104-lifecycle-event-logger-hook.md",
     "group": "none"
   }
   ```
2. **`post-freeze`** (`cmd_freeze` / `cmd_freeze_start` in `lib/cmd_plan.sh`):
   ```json
   {
     "plan_id": "P-102",
     "plan_file": "current/P102-group-done-lifecycle-order.md"
   }
   ```
3. **`post-start`** (`cmd_start` / `cmd_freeze_start` in `lib/cmd_plan.sh`):
   ```json
   {
     "plan_id": "P-102",
     "plan_file": "current/P102-group-done-lifecycle-order.md",
     "worktree": "/path/to/repo/.workspace/P102",
     "branch": "feature/group-done-lifecycle-order"
   }
   ```
4. **`post-refine`** (`cmd_refine` in `lib/cmd_plan.sh`, delivered by P-99):
   ```json
   {
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
     "plan_id": "P-80",
     "plan_file": "aborted/P80-experimental-feature.md",
     "target_issue": "none"
   }
   ```
7. **`post-active`** (`cmd_active` in `lib/cmd_plan.sh`):
   ```json
   {
     "action": "set|swap|clear",
     "active_plan": "P-102",
     "previous_plan": "P-104"
   }
   ```
8. **`post-tdd`** (`cmd_tdd` in `lib/cmd_plan.sh`):
   ```json
   {
     "plan_id": "P-102",
     "test_files": ["tests/verbs/done.sh"],
     "assertions_count": 4
   }
   ```

#### B. Implementation & Group Landing Lifecycle
9. **`post-commit`** (`cmd_commit` in `lib/cmd_commit.sh`):
   ```json
   {
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
      "group_id": "P-103",
      "amendment_id": "P-101",
      "feature_branch": "feature/group-lifecycle-and-amendments",
      "commit_sha": "f1e2d3c"
    }
    ```

#### C. Issue Lifecycle (`lib/cmd_issue.sh`)
11. **`post-issue-log`** (`cmd_issue_log`):
    ```json
    {
      "issue_id": "166",
      "sev": "MED",
      "type": "CLI",
      "symptom": "parser fails on trailing newline",
      "files": ["lib/cmd_issue.sh"]
    }
    ```
12. **`post-issue-queue`** (`cmd_issue_queue` / `cmd_issue_unqueue`):
    ```json
    {
      "issue_id": "166",
      "action": "queue|unqueue",
      "level": "urgent|normal|low"
    }
    ```
13. **`post-issue-fix`** (`cmd_issue_fix`):
    ```json
    {
      "issue_id": "166",
      "worktree": "/path/to/repo/.workspace/fix-166",
      "branch": "fix/166"
    }
    ```
14. **`post-issue-close`** (`cmd_issue_close`):
    ```json
    {
      "issue_id": "166",
      "commit_sha": "b2c3d4e",
      "summary": "Fix trailing newline in parser"
    }
    ```
15. **`post-issue-hotfix`** (`cmd_issue_hotfix`):
    ```json
    {
      "issue_id": "167",
      "blocked_plan": "P-102",
      "files": ["lib/cmd_plan.sh"]
    }
    ```
16. **`post-issue-withdraw`** (`cmd_issue_withdraw`):
    ```json
    {
      "issue_id": "166",
      "reason": "Not reproducible on latest develop"
    }
    ```

#### D. Operational & Emergency Lifecycle
17. **`post-pause`** (`cmd_pause` in `lib/cmd_pause.sh`):
    ```json
    {
      "reason": "switching tasks",
      "shared": false
    }
    ```
18. **`post-resume`** (`cmd_resume` in `lib/cmd_pause.sh`):
    ```json
    {
      "restored_count": 2,
      "drift_found": 0
    }
    ```
19. **`post-sync`** (`cmd_sync` in `lib/cmd_sync.sh`):
    ```json
    {
      "action": "pull_push",
      "remote": "origin",
      "worktrees": [".plans", ".agents", ".githooks"]
    }
    ```

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`. All new dispatches are additive observer events; existing handlers receive enriched telemetry without breaking contracts.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Showcase Hook Sample
- [ ] Task 1.1: Author `examples/hooks/event-logger.sample` conforming to observer mode, out-of-repo path resolution, and atomic JSONL append.
- [ ] Task 1.2: Add unit tests in `tests/hooks_test.sh` verifying registration, SHA-256 verification, and payload ingestion.

### Phase 2: Completing Core Lifecycle Dispatches
- [ ] Task 2.1: Add `post-draft`, `post-active`, and `post-tdd` dispatches in `lib/cmd_plan.sh`.
- [ ] Task 2.2: Add `post-commit` dispatch in `lib/cmd_commit.sh`.
- [ ] Task 2.3: Add `post-issue-log`, `post-issue-queue`, `post-issue-fix`, `post-issue-close`, `post-issue-hotfix`, and `post-issue-withdraw` dispatches in `lib/cmd_issue.sh`.

### Phase 3: Documentation & Verification
- [ ] Task 3.1: Update `lib/cmd_hook.sh` and `lib/docs/verbs/hooks.md` with the full 19-event catalog and JSON payloads.
- [ ] Task 3.2: Update `MANUAL.md` with instructions on setting up out-of-repo lifecycle event logging.
- [ ] Task 3.3: Verify all kit test suites pass (`./aapp test quiet`).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `examples/hooks/event-logger.sample` -> Sample observer hook script for out-of-repo JSONL event logging.
- [ ] `lib/cmd_commit.sh` -> Emit `post-commit` lifecycle event after plan commit recording.
- [ ] `lib/cmd_issue.sh` -> Emit `post-issue-*` lifecycle events (log, queue, fix, close, hotfix, withdraw).
- [ ] `lib/cmd_plan.sh` -> Emit `post-draft`, `post-active`, and `post-tdd` lifecycle events.
- [ ] `lib/cmd_hook.sh` -> Add all 19 events to available events list in `help hooks`.
- [ ] `lib/docs/verbs/hooks.md` -> Update event documentation and payload schemas.
- [ ] `MANUAL.md` -> Add Event Logger showcase section and telemetry guide.
- [ ] `tests/hooks_test.sh` -> Add automated tests for event-logger hook and new dispatches.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Write guard is untouched.
- [ ] `templates/aapp-pre-commit` -> Pre-commit gate is untouched (P-99 handles design lock).
- [ ] `lib/aapp-lib.sh` -> Core resolver untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
* [ ] **Question 1 — Default Out-of-Repo Path.** Should the sample default to `$(git rev-parse --git-path aapp_events.jsonl)` (repository git directory) or `~/.local/share/aapp/logs/events.jsonl` (centralized user log)? (Proposed: gitdir default with env/config override).

---

## 📦 6. Change Log & Refinement History
* **2026-10-17:** Plan scaffolded and authored from user requirement for decoupled, out-of-repo lifecycle event logging.
* **2026-10-17:** Expanded Technical Blueprint with complete 19-event catalog and explicit JSON output schemas.
