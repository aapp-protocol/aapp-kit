# 🗺️ Plan P-107: Integration Parent Lock And Queue
* **Created:** 2026-10-18 | **Last Refined:** 2026-10-18
* **Target Issue / Milestone:** none
* **Plan ID:** P-107
* **Changelog:** Added: parent-branch integration lock and serialized landing queue (P-107)
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

During parallel multi-agent development or concurrent developer workflows, plans are implemented in isolated worktrees (`.workspace/<plan-id>`). While Plan P-65 guarantees code disjointness during development and Plan P-106 introduces automated clean rebasing on `integrate ff`, a critical **Time-of-Check to Time-of-Use (TOCTOU) race condition** exists during integration:

1. **The Concurrency Gap**:
   In `aapp done <id> integrate`:
   - `_ig_preflight` verifies that the plan contains the parent branch (or auto-rebases onto it).
   - The `pre-done` test gate hook executes (e.g. `./aapp test quiet`, which may take anywhere from 10 seconds to several minutes).
   - If another agent or developer lands a commit on the parent branch while `pre-done` is running, the parent branch tip advances.
   - Once tests pass, `aapp done` moves the plan to `.plans/done/` and records it on the `plans` branch.
   - Finally, `_ig_run` attempts `git merge --ff-only <plan-branch>`. Because the parent branch moved forward during testing, the fast-forward fails!
2. **The Inconsistent State (Orphan Archival)**:
   The plan is archived in `.plans/done/`, but its code never merged into the parent branch. Retrying via `aapp done <id> integrate` runs `_ig_standalone`, which rebases again but skips the test gate, landing untested code on the new parent tip.

### Architectural Goals:
1. **Target-Parent-Scoped Integration Lock (`aapp.integrateLock`)**:
   Key the integration mutex to the **specific parent/target branch** (e.g. `develop`, `module/auth`, `feature/foo`), NOT hardcoded globally to `develop`. Concurrent plans targeting different parent branches integrate simultaneously without contention; plans targeting the *same* parent branch are safely serialized.
2. **Configurable Wait with Low Starting Minimum (`aapp.integrateWait`)**:
   The wait timeout must be configurable via `git config aapp.integrateWait <seconds>` (default: 15s; configurable from a minimum of 10s up to 600s), utilizing a fast 2-3s polling roller so short test suites don't incur unnecessary latency.
3. **Atomic Landing Sequence (Zero Orphan Archival)**:
   Ensure parent-branch fast-forward succeeds before committing plan archival. If integration fails, the plan remains in `.plans/current/` with its worktree clean and untouched.

---

## 2. Technical Blueprint

### 2.1 Parent-Branch Integration Mutex Architecture

Instead of a monolithic global lock, the integration lock is scoped to the canonical parent branch name:

```bash
# _ig_lock_file <target_branch>: derives safe filesystem path for parent branch lock
_ig_lock_file() {
    local target="$1"
    local safe_target
    safe_target="$(echo "$target" | tr '/:' '__')"
    local common_dir
    common_dir="$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir)"
    echo "$common_dir/aapp_integrate_${safe_target}.lock"
}
```

#### Lock Lifecycle:
1. **Acquisition**: `_ig_lock_acquire <target_branch> <plan_id>`
   - Uses atomic directory creation (`mkdir "$lock_file.d"`) or atomic `ln -s` to prevent race conditions.
   - Writes holding metadata: `{"plan_id": "$pid", "pid": "$$", "target": "$target", "start": "<timestamp>"}`.
   - If held by another process: enters roller wait loop up to `aapp.integrateWait` seconds (default: 15s).
   - If holding process died (stale lock detection): verifies PID liveness (`kill -0 <pid>`); removes stale lock if holding process is dead.
2. **Release**: `_ig_lock_release <target_branch>`
   - Cleans up the lock on normal exit, error exit, or signal trap (`EXIT INT TERM`).

---

### 2.2 Integration Flow Sequencing

```text
aapp done <id> integrate ff
  │
  ├── 1. Resolve Target Parent Branch (e.g. develop or module/auth)
  │
  ├── 2. Acquire Parent-Branch Lock: _ig_lock_acquire "$target" "$id"
  │      └── Wait if held (up to aapp.integrateWait seconds, poll every 2s)
  │
  ├── 3. Preflight & Clean Rebase: _ig_preflight "$target" "$id"
  │      └── Rebase onto latest parent tip under lock (guaranteed stable)
  │
  ├── 4. Pre-Done Test Gate: dispatch_hook "pre-done"
  │      └── Parent branch CANNOT move because lock is held!
  │
  ├── 5. Fast-Forward Parent: git merge --ff-only
  │      └── Guaranteed 100% fast-forward success (0 race window)
  │
  ├── 6. Archive Plan: move to .plans/done/ and commit to plans branch
  │
  └── 7. Release Parent-Branch Lock: _ig_lock_release "$target"
```

---

### 2.3 Configuration Invariants

- **`aapp.integrateWait`**: Maximum time to wait for parent-branch integration lock in seconds.
  - Default: `15` seconds (allows rapid turnaround for projects with fast test suites).
  - Minimum allowed: `10` seconds.
  - Configurable via `git config aapp.integrateWait 60` for repositories with larger test suites.
- **`aapp.integrateLock`**: Boolean switch (`true` | `false`, defaults to `true`).
  - When `true`, serializes integrations per parent branch.
  - When `false`, bypasses locking (for solo manual environments).

---

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Backwards Compatible`
- **Fallback Inventory**: `aapp.integrateLock` defaults to `true`. Legacy solo workflows experience zero latency when no contention exists. Lock paths are ephemeral inside `.git/` and require no repository migrations.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Parent-Branch Lock Primitives
- [ ] Task 1.1: Implement `_ig_lock_file`, `_ig_lock_acquire`, and `_ig_lock_release` in `lib/cmd_plan.sh` with stale lock detection.
- [ ] Task 1.2: Implement configurable roller wait loop reading `aapp.integrateWait` (default 15s, min 10s, 2s poll step).
- [ ] Task 1.3: Add unit tests in `tests/integrate_test.sh` verifying lock acquisition, contention waiting, stale lock recovery, and parallel execution on different parent branches.

### Phase 2: Atomic Integration Sequencing
- [ ] Task 2.1: Wrap the entire pre-done through merge sequence in `_ig_lock_acquire` / `_ig_lock_release`.
- [ ] Task 2.2: Ensure fast-forward succeeds before plan relocation to `.plans/done/`, preventing orphan plan states on merge failure.
- [ ] Task 2.3: Verify signal trapping (`trap ... EXIT INT TERM`) guarantees lock release on unexpected exit or abort.

### Phase 3: Adoption & Manual Documentation
- [ ] Task 3.1: Add `SET-INTEGRATE-WAIT` review task in `lib/adoption.sh` under `⚙️ Settings to Review`.
- [ ] Task 3.2: Update `MANUAL.md` with integration locking mechanics and parent-branch isolation.
- [ ] Task 3.3: Update `ARCHITECTURE.md` and author reference specification `docs/reference/11-integration-lock-and-queue.md`.
- [ ] Task 3.4: Verify all test suites pass cleanly (`./aapp test quiet`).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `NEW FILE` -> `docs/reference/11-integration-lock-and-queue.md` -> Reference specification documenting parent-branch integration mutex and locking invariants.
- [ ] `lib/cmd_plan.sh` -> Implement parent-branch integration lock primitives and re-sequence integration flow.
- [ ] `lib/adoption.sh` -> Add `SET-INTEGRATE-WAIT` task under `⚙️ Settings to Review`.
- [ ] `MANUAL.md` -> Document parent-branch lock, `aapp.integrateWait`, and race condition prevention.
- [ ] `ARCHITECTURE.md` -> Document parent-branch integration mutex and atomic landing sequence.
- [ ] `tests/integrate_test.sh` -> Add automated test fixtures covering concurrent integration locking and parent-branch isolation.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Tool write guard is untouched.
- [ ] `lib/cmd_issue.sh` -> Issue workflows untouched.
- [ ] `templates/aapp-pre-commit` -> Pre-commit hook untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Lock Scope.** Should the integration lock be global or per-parent branch? -> **Resolved**: Per-parent branch (`aapp_integrate_<parent>.lock`). Plans integrating into `develop` serialize against each other, while plans integrating into `module/auth` proceed independently without contention.
* [x] **Question 2 — Default Wait Timeout.** What should `aapp.integrateWait` default to? -> **Resolved**: Default to `15` seconds (with minimum 10s and 2s poll steps). This accommodates fast test suites without artificial delays, while remaining fully configurable for repositories with multi-minute suites.

---

## 📦 6. Change Log & Refinement History
* **2026-10-18:** Plan initialized and scaffolded to address integration TOCTOU race conditions via parent-branch scoped locks and atomic sequencing.
