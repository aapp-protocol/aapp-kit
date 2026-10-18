# 🗺️ Plan P-107: Integration Parent Lock And Queue
* **Created:** 2026-10-18 | **Last Refined:** 2026-10-18
* **Target Issue / Milestone:** none
* **Plan ID:** P-107
* **Changelog:** Added: parent-branch integration lock, atomic landing CAS, and unified named locks (P-107)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `576d4b5` (develop)
* **Worktree:** .workspace/P107 (plan/P107-integration-parent-lock-and-queue)
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

During parallel multi-agent development or concurrent developer workflows, plans are implemented in isolated worktrees (`.workspace/<plan-id>`). While Plan P-65 guarantees code disjointness during development and Plan P-106 introduces automated clean rebasing on `integrate ff`, a critical **Time-of-Check to Time-of-Use (TOCTOU) race condition** exists during branch integration:

### 1.1 The Vulnerability Surface
1. **The Concurrency Gap**:
   In `aapp done <id> integrate`:
   - `_ig_preflight` currently verifies ancestry and runs auto-rebase *before* acquiring any lock.
   - At its end, `_ig_preflight` takes the legacy global `aapp_issue.lock` (line 959), holding it through `pre-done`. This has two fatal flaws:
     a) It unnecessarily serializes integrations globally across different parent branches (e.g. `module/auth` vs `develop`).
     b) A waiter that queued for the lock evaluated its contains-parent check *stale* before waiting!
   - `aapp issue close` moves parent branches without taking any integration lock (`_issue_land_fix` in `lib/cmd_issue.sh:842-849`), racing with concurrent `done` runs.
   - A raw human git commit or push on the parent branch completely ignores the lock.
2. **Main Checkout Contention**:
   `_ig_run` currently switches the main checkout (`PRIMARY_ROOT`) to the target parent branch (`git checkout "$IG_TARGET_BR"`), runs `git merge --ff-only`, and switches back. Concurrent parent integrations collide in the main checkout, and any uncommitted developer files in `PRIMARY_ROOT` abort the entire integration.
3. **Inconsistent State (Orphan Archival)**:
   `cmd_plan.sh` moves the plan to `.plans/done/` *before* `_ig_run` executes. If `git merge --ff-only` fails (because the parent branch moved), the plan is archived on the `plans` branch, but its code never merged into the parent branch.
4. **Untested Standalone Retry**:
   When retrying an archived plan via `aapp done <id> integrate`, `_ig_standalone` rebases diverged code but skips the `pre-done` test gate entirely, landing un-gated code onto the parent branch.

### 1.2 Architectural Goals
1. **Unified Named Lock Subsystem (`lib/aapp-lib.sh`)**:
   Consolidate lock mechanics into a single, clean API supporting named locks (`issue` and `integrate/<parent>`), atomic `mkdir` directories, PID ownership, stale-process takeover, multi-lock tracking, and chained `EXIT` signal handlers.
2. **Per-Parent Integration Lock**:
   Acquire the parent lock `integrate/<parent>` **before** the contains-parent check and auto-rebase. Integrations into different parent branches run in parallel without contention.
3. **Headless Fast-Forward via Compare-and-Swap (CAS)**:
   Fast-forward parent branches directly via `git update-ref refs/heads/<parent> <new_sha> <old_sha>` (or inside the worktree holding the target branch), without touching `PRIMARY_ROOT`. CAS guarantees that if a raw commit advanced the parent branch, the update refuses cleanly.
4. **Atomic Landing Sequence (Option i)**:
   Execute parent-branch fast-forward (via CAS) **before** committing plan archival to `.plans/done/`. If archival fails, CAS rolls the parent branch back to `<old_sha>` while the lock is held. Address issue #124 so active plan buffers are preserved on failure.
5. **Pre-Commit Raw Commit Boundary**:
   In `templates/aapp-pre-commit`, refuse raw commits directly touching a branch currently held by an `integrate/<branch>` lock.
6. **Pre-Done Gate on Standalone Rebase**:
   Ensure `_ig_standalone` invokes `pre-done` whenever an automated rebase is performed.
7. **Configurable Wait with Low Minimum (`aapp.integrateWait`)**:
   Default wait of 15 seconds (configurable from 10s to 600s, 2s poll step) with clean diagnostics naming lock holder PID and plan ID. Clean break: drop the redundant `aapp.integrateLock` switch.

---

## 2. Technical Blueprint

### 2.1 Unified Named Lock Engine (`lib/aapp-lib.sh`)

Replace legacy `_issue_lock_*` functions and hardcoded lock paths with a unified named lock subsystem:

```bash
# Sanitizes lock name into safe path in git common dir
# aapp_lock_path <name>
aapp_lock_path() {
    local name="$1"
    local safe_name
    safe_name="$(printf '%s' "$name" | sed 's|/|%2F|g')"
    local common
    common="$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir)"
    case "$common" in /*) ;; *) common="$(cd "$common" && pwd)" ;; esac
    echo "$common/aapp_${safe_name}.lock"
}

# Global list of locks held by the current process
_AAPP_HELD_LOCKS=()

_aapp_locks_cleanup_trap() {
    for lk in "${_AAPP_HELD_LOCKS[@]}"; do
        [ -n "$lk" ] && rm -rf "$lk" 2>/dev/null || true
    done
    _AAPP_HELD_LOCKS=()
}

# aapp_lock_acquire <name> <limit_seconds> [diagnostic_label]
aapp_lock_acquire() {
    local name="$1" limit="${2:-15}" label="${3:-$name}"
    local lock waited=0 step=2 pid mtime age
    lock="$(aapp_lock_path "$name")"

    # Re-entrancy: allow if already held by this process
    for held in "${_AAPP_HELD_LOCKS[@]}"; do
        [ "$held" = "$lock" ] && return 0
    done

    while ! mkdir "$lock" 2>/dev/null; do
        pid="$(cat "$lock/pid" 2>/dev/null || true)"
        if [ -z "$pid" ]; then
            mtime="$(stat -c %Y "$lock" 2>/dev/null || stat -f %m "$lock" 2>/dev/null || date +%s)"
            age=$(( $(date +%s) - mtime ))
            if [ "$age" -ge 5 ]; then
                echo "⚠️  [Lock] Taking over stale $label lock (no holder PID)." >&2
                rm -rf "$lock"; continue
            fi
        elif ! kill -0 "$pid" 2>/dev/null; then
            echo "⚠️  [Lock] Taking over stale $label lock (holder PID $pid is gone)." >&2
            rm -rf "$lock"; continue
        fi
        if [ "$waited" -ge "$limit" ]; then
            local holder_info=""
            [ -f "$lock/info" ] && holder_info=" ($(cat "$lock/info" 2>/dev/null))"
            echo "⏳ [Lock Refusal] $label lock is still held${pid:+ by process $pid}${holder_info}; waited ${waited}s (limit ${limit}s)." >&2
            echo "   Retry when the holder finishes, or raise limit with 'git config aapp.integrateWait <seconds>'." >&2
            return 1
        fi
        echo "⏳ [Lock] $label lock held${pid:+ by PID $pid}; waiting ${step}s (elapsed ${waited}s)..." >&2
        sleep "$step"; waited=$((waited + step)); step=$((step + 1))
    done

    echo "$$" > "$lock/pid"
    _AAPP_HELD_LOCKS+=("$lock")
    trap '_aapp_locks_cleanup_trap' EXIT INT TERM
}

# aapp_lock_release <name>
aapp_lock_release() {
    local name="$1"
    local lock
    lock="$(aapp_lock_path "$name")"
    rm -rf "$lock" 2>/dev/null || true
    local remaining=()
    for held in "${_AAPP_HELD_LOCKS[@]}"; do
        [ "$held" != "$lock" ] && remaining+=("$held")
    done
    _AAPP_HELD_LOCKS=("${remaining[@]}")
}
```

---

### 2.2 Integration Flow Sequencing (`lib/cmd_plan.sh`)

1. **Lock Scope & Acquisition**:
   Before preflight checks, resolve the parent target branch: `IG_TARGET_BR="$(resolve_plan_integrate_target "$pf")"`.
   Acquire the parent lock immediately:
   ```bash
   aapp_lock_acquire "integrate/$IG_TARGET_BR" "$integrate_wait" "Parent branch '$IG_TARGET_BR'" || exit 1
   echo "Plan $pid (PID $$)" > "$(aapp_lock_path "integrate/$IG_TARGET_BR")/info"
   ```
2. **Drop Global Issue Lock from Preflight**:
   Remove `_issue_lock_acquire` and `_issue_wait_limit` from `_ig_preflight`. Since Plan P-85, issue fixes operate in dedicated worktrees (`.workspace/fix-<num>`) and no longer occupy the main checkout.
3. **Preflight Under Lock**:
   With `integrate/$IG_TARGET_BR` held:
   - Check ancestry. If diverged, automated clean rebase runs.
   - Capture `PARENT_OLD_SHA="$(git rev-parse "refs/heads/$IG_TARGET_BR")"`.
4. **Pre-Done Test Gate**:
   Execute `dispatch_hook "pre-done"`. Because the parent lock is held, no other kit verb or fix can land on `$IG_TARGET_BR` while tests run.
5. **Headless Fast-Forward via Compare-and-Swap (CAS)**:
   In `_ig_run`, avoid switching `PRIMARY_ROOT`:
   ```bash
   if [ "$IG_WT_HOLDS_TARGET" -eq 1 ]; then
       git -C "$WT_HOLDING_TARGET" merge -q --ff-only "$IG_PLAN_BR"
   else
       git update-ref "refs/heads/$IG_TARGET_BR" "$NEW_PLAN_HEAD" "$PARENT_OLD_SHA" || {
           echo "❌ [Integrate] Target branch '$IG_TARGET_BR' moved concurrently (CAS mismatch); aborting integration." >&2
           return 1
       }
   fi
   ```
   If `PRIMARY_ROOT` happens to be on `$IG_TARGET_BR` and clean, fast-forward or sync its index/worktree.
6. **Atomic Archive & Rollback**:
   Execute plan archival commit into `.plans/done/`.
   If the archive commit fails (snapshot rollback triggered):
   - Roll back the parent branch: `git update-ref "refs/heads/$IG_TARGET_BR" "$PARENT_OLD_SHA" "$NEW_PLAN_HEAD"`.
   - Restore active plan buffer (resolving #124).
7. **Release Lock**:
   `aapp_lock_release "integrate/$IG_TARGET_BR"` runs on success or via the exit trap.

---

### 2.3 Issue Fix Landing Safety (`lib/cmd_issue.sh`)

In `_issue_land_fix`:
```bash
local target_br="$fix_parent"
aapp_lock_acquire "integrate/$target_br" "$wait_limit" "Parent branch '$target_br'" || return 1
# Execute rebase, squash, and update-ref under lock
...
aapp_lock_release "integrate/$target_br"
```

---

### 2.4 Pre-Commit Raw Commit Boundary (`templates/aapp-pre-commit`)

In `templates/aapp-pre-commit`:
```bash
# Check if committing to a branch currently locked for integration
TARGET_LOCK="$(aapp_lock_path "integrate/$CURRENT_BRANCH")"
if [ -d "$TARGET_LOCK" ]; then
    HOLDER_PID="$(cat "$TARGET_LOCK/pid" 2>/dev/null || true)"
    if [ -n "$HOLDER_PID" ] && kill -0 "$HOLDER_PID" 2>/dev/null; then
        echo "❌ [AAPP Guard] Branch '$CURRENT_BRANCH' is currently locked for integration by PID $HOLDER_PID." >&2
        echo "   Raw commits to a landing parent branch are prohibited during active integration." >&2
        exit 1
    fi
fi
```

---

### 2.5 Clean Break Invariants
- **Legacy Issue Lock**: Completely eliminate `_issue_lock_acquire`, `_issue_lock_release`, and `aapp_issue.lock`. Replace all call sites in `lib/cmd_issue.sh` with `aapp_lock_acquire "issue"`.
- **IntegrateLock Config**: Drop `aapp.integrateLock`. Locking is mandatory across all repository clones.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Unified Named Lock Subsystem (`lib/aapp-lib.sh`)
- [x] Task 1.1: Implement `aapp_lock_path`, `aapp_lock_acquire`, `aapp_lock_release`, multi-lock tracking array, and trap handler in `lib/aapp-lib.sh`.
- [x] Task 1.2: Refactor `lib/cmd_issue.sh` to use `aapp_lock_acquire "issue"` / `aapp_lock_release "issue"`, removing legacy `_issue_lock_*` functions.
- [x] Task 1.3: Add unit tests in `tests/integrate_test.sh` verifying lock acquisition, re-entrancy, stale takeover, and timeout diagnostics.

### Phase 2: Per-Parent Integration Lock & Preflight Sequencing (`lib/cmd_plan.sh`)
- [x] Task 2.1: Acquire `integrate/<parent>` lock before ancestry checks and auto-rebase in `cmd_plan.sh`.
- [x] Task 2.2: Remove global issue lock acquisition from `_ig_preflight`.
- [x] Task 2.3: Implement headless fast-forward via Compare-and-Swap (`git update-ref`) in `_ig_run`, eliminating main checkout switching.
- [x] Task 2.4: Implement Option i atomic landing order: CAS parent ref first, then archive plan; rollback CAS if archive fails (fixing #124 buffer restoration).
- [x] Task 2.5: Ensure `_ig_standalone` executes `pre-done` test gate whenever an automated rebase occurs.

### Phase 3: Issue Fix Locking & Pre-Commit Protection
- [x] Task 3.1: Wrap `_issue_land_fix` in `lib/cmd_issue.sh` with `integrate/<parent>` lock.
- [x] Task 3.2: Add integration lock detection in `templates/aapp-pre-commit` to reject raw commits on locked parent branches.
- [x] Task 3.3: Add `SET-INTEGRATE-WAIT` review task in `lib/adoption.sh` under `⚙️ Settings to Review`.

### Phase 4: Reference Documentation & Test Suite
- [x] Task 4.1: Update `docs/reference/10-integration-and-rebase.md` with parent-branch locking, CAS fast-forward, and concurrency mechanics.
- [x] Task 4.2: Update `MANUAL.md` with integration locking, `aapp.integrateWait`, and race prevention.
- [x] Task 4.3: Update `ARCHITECTURE.md` with named lock architecture, CAS landing, and headless integration.
- [x] Task 4.4: Add comprehensive test suites in `tests/integrate_test.sh`:
  - Contended parent wait and rebase under lock.
  - Concurrent integrations targeting different parent branches proceeding without contention.
  - `issue close` contention against concurrent plan integration.
  - CAS rejection on external raw commit.
  - Archive failure rollback restoring parent ref and active plan buffers (#124).
- [x] Task 4.5: Run full test runner (`./aapp test quiet`) and verify 100% pass rate.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/aapp-lib.sh` -> Implement unified named lock engine (`aapp_lock_path`, `aapp_lock_acquire`, `aapp_lock_release`).
- [ ] `lib/cmd_plan.sh` -> Re-sequence integration flow under parent lock, headless CAS fast-forward, and standalone pre-done re-gate.
- [ ] `lib/cmd_issue.sh` -> Use unified `issue` lock and acquire `integrate/<parent>` in `_issue_land_fix`.
- [ ] `templates/aapp-pre-commit` -> Reject raw commits on branches currently locked for integration.
- [ ] `lib/adoption.sh` -> Add `SET-INTEGRATE-WAIT` onboarding review item.
- [ ] `docs/reference/10-integration-and-rebase.md` -> Document parent locking, CAS invariants, and concurrency boundaries.
- [ ] `MANUAL.md` -> Document integration lock, `aapp.integrateWait`, and parent-branch isolation.
- [ ] `ARCHITECTURE.md` -> Document named lock subsystem, CAS fast-forward, and atomic landing order.
- [ ] `tests/integrate_test.sh` -> Automated test coverage for concurrent parent locks, CAS refusals, and rollbacks.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Write-time guard is untouched.
- [ ] `lib/cmd_pause.sh` -> Pause subsystem is untouched.
- [ ] `lib/attribution.sh` -> Attribution subsystem is untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Lock Subsystem Location.** Should the unified lock engine live in `lib/aapp-lib.sh` or a separate `lib/locks.sh`? -> **Resolved**: In `lib/aapp-lib.sh`. Sourced by both CLI verbs and `templates/aapp-pre-commit`, allowing the pre-commit hook to verify whether a raw commit targets a locked parent branch.
* [x] **Question 2 — Archive vs Fast-Forward Order.** Should fast-forward precede archival (Option i) or follow archival (Option ii)? -> **Resolved**: Option i. Fast-forward the parent ref via CAS first, then commit plan archival. If archival fails, CAS rolls the parent branch back to `<old_sha>` while the lock is held, eliminating orphan plan records and resolving #124.
* [x] **Question 3 — Pre-Done on Standalone Rebase.** Should `_ig_standalone` re-run the `pre-done` test gate if a rebase occurs? -> **Resolved**: Yes. Code rebased onto a moved parent branch must be re-verified before landing.
* [x] **Question 4 — Toggle Configuration.** Should `aapp.integrateLock` (`true`/`false`) exist? -> **Resolved**: No (Clean Break). Uncontended lock acquisition takes < 1ms; a toggle only reopens concurrency race conditions.

---

## 📦 6. Change Log & Refinement History
* **2026-10-18:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-18:** Plan initialized and scaffolded to address integration TOCTOU race conditions via parent-branch scoped locks and atomic sequencing.
* **2026-10-18:** Refined with Red Team findings: unified named lock subsystem in `lib/aapp-lib.sh`, headless CAS fast-forward via `git update-ref`, `_issue_land_fix` locking, pre-commit raw commit protection, Option i atomic rollback, standalone pre-done re-gating, and clean break retirement of `_issue_lock_*` and `aapp.integrateLock`.
