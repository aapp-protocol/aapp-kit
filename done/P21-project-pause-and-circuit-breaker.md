# 🗺️ Plan P-21: Project Pause & Circuit Breaker Architecture
* **Created:** 2026-09-19 | **Last Refined:** 2026-09-19
* **Target Issue / Milestone:** None
* **Plan ID:** P-21
* **Status:** 🟠 In Development
<!-- Status must be exactly ONE of: 🟣 Under Review | 🟠 Refining | 🔷 Frozen | 🟠 In Development | 🟥 BLOCKED
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. An 🟠 In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 6. **Portability Invariant**: Never write machine-specific absolute paths or `file:///` URIs into tracked files. Use repo-relative paths or backticked basenames only.

---

## 1. Context & Architectural Goal

During modern agentic pair programming, developers frequently operate across multiple mediums simultaneously: multiple IDE windows, parallel terminal tabs, background subagents, or companion chats across different repositories. When no blueprint is actively in development (`🟠 In Development`), the AAPP governance engine operates in fail-open mode for repository files to preserve rapid developer velocity for quick scripts, tests, and typo fixes.

However, this creates a distinct operational vulnerability: **the un-planned cross-window and cross-project collision**. When a developer shifts attention to work on another project ("Project 2"), a loosely framed instruction in that secondary window or terminal can inadvertently find homonymous files (e.g. `templates/AGENTS.md` vs `.agents/AGENTS.md`, or matching filenames across repos) and alter or commit code in this repository without an active plan. Furthermore, half-finished, uncommitted changes left sitting in the working tree are exposed to accidental corruption or overwrites by stray processes.

This plan introduces the **Master Emergency Brake & Multi-Worktree State Preserver ("Hibernate & Wake")** (`aapp pause [reason]` and `aapp resume`):
1. **Zero Daily Friction**: When inactive (normal mode), developers and agents work at full velocity with zero overhead.
2. **Dynamic Multi-Worktree Stash Quarantine & Snapshot**:
   - On `aapp pause`, in-flight uncommitted code across **all dynamically discovered worktrees** (`git worktree list --porcelain`) is quarantined into named, SHA-addressed stashes (`aapp-pause-<timestamp>:<branch>`), leaving every working tree pristine and clean.
   - **In-Flight Operation Guard**: Pre-checks for active merges, rebases, or cherry-picks via canonical plumbing (`git rev-parse --git-path MERGE_HEAD`, `rebase-merge`, `CHERRY_PICK_HEAD`) and refuses to pause if a conflict is unresolved, preventing corrupted stashes across linked worktrees.
   - **Atomic Rollback Invariant**: Validates that all stash commit SHAs are valid 40-character hexadecimal strings; if any worktree fails or returns an invalid SHA, triggers an immediate rollback of all stashes created in that invocation so the project is never left half-paused.
   - **Staged File Forensics**: Records the exact list of staged vs. unstaged files in the snapshot before stashing, providing full visibility into cherry-picked selections without risking index merge failures.
   - **Air-Gap Safety Invariant**: Stashing strictly uses `--include-untracked` and forbids `--all`, preserving `.gitignore` boundaries and guaranteeing that air-gapped stores (such as private notes in `.plans/pickup/`) are never swept into Git objects.
   - An atomic snapshot captures worktree commit SHAs, branches, staged file lists, and exact stash commit SHAs (immune to Git stash index shifting).
3. **Cross-Medium Hook Realism ("Uncommittable, Not Untouchable")**:
   - **Local Session Writes (Layer 1)**: For sessions rooted in this repository, `blast-radius-guard` intercepts and blocks write tools at execution time.
   - **External & Cross-Repo Sessions (Layer 2)**: For sessions rooted in other directories or plain terminals (where Project 1's PreToolUse hook is not in the call stack), Layer 2 (`pre-commit`) serves as the strict, inescapable gate that executes inside this repository and rejects any code commit attempt.
4. **Resumption Sanity & Forensic Drift Verification**:
   - On `aapp resume`, the engine verifies workspace integrity against the pause snapshot, detecting any commits or untracked file intrusions that occurred while away.
   - Stashes are safely restored per-worktree using 40-character commit SHAs (never fragile indices).
   - **No-Loss Conflict & Buffer Survival Invariants**: If a stash apply encounters a conflict, the stash entry is permanently preserved in the stash list—never dropped—and the pause buffer remains active on disk. A partially-resumed project remains PAUSED until all worktrees restore cleanly.
   - Planning health integrity checks are verified, and full developer velocity is restored.
5. **Preserved Cognitive Functions**: Reading code, codebase analysis, conversational Q&A, logging defects in `.plans/ISSUES.md`, drafting blueprints in `.plans/current/`, recording behavioral notes in `.agents/`, and capturing ideas in `.plans/pickup.md` remain 100% functional throughout the pause.

---

## 2. Technical Blueprint

### A. State Storage, Snapshot Schema & Scoping (`--git-common-dir`)
The pause state and workspace snapshot are recorded in a lightweight, atomic state buffer:
- **Repo-Wide Scope (Default)**: `$(git rev-parse --git-common-dir)/aapp_paused`. Contains an atomic JSON record:
  ```json
  {
    "paused": true,
    "timestamp": "2026-09-19T02:30:00Z",
    "reason": "switching focus to project-2",
    "user": "lorand",
    "snapshot": {
      "worktrees": {
        "develop": {
          "path": "/path/to/repo",
          "head_sha": "ce81102",
          "branch": "develop",
          "staged_files": ["src/main.py"],
          "unstaged_files": ["README.md"]
        },
        "agents": {
          "path": "/path/to/repo/.agents",
          "head_sha": "3f335d0",
          "branch": "agents",
          "staged_files": [],
          "unstaged_files": []
        },
        "plans": {
          "path": "/path/to/repo/.plans",
          "head_sha": "eec823e",
          "branch": "plans",
          "staged_files": [],
          "unstaged_files": []
        }
      },
      "stashes": [
        {
          "worktree": "/path/to/repo",
          "branch": "develop",
          "sha": "40968636854f58f5278fdcad9531d17d9ea56d44",
          "tag": "aapp-pause-20260919-023000:develop"
        }
      ]
    }
  }
  ```
  *Scoping Invariant:* Using `--git-common-dir` ensures the pause buffer is physically shared across all linked worktrees (`develop`, `.plans`, `.agents`) without isolation splits, while remaining uncommitted with zero git history noise.
- **Team-Wide Shared Scope (Optional `--shared`)**: If invoked with `--shared`, creates or updates `.plans/PAUSED.md`, committing the freeze to the `plans` branch so remote clones, team members, and CI pipelines inherit the project pause.

### B. Dynamic Multi-Worktree SHA-Addressed Stash Quarantine Engine (`cmd_pause`)
When `aapp pause [reason]` is invoked:
1. **Idempotency & Inspector Check**:
   - If project is already paused, act as an inspector: display current pause reason, timestamp, duration, snapshot details, and quarantined stashes without modifying state.
2. **Dynamic Worktree Discovery**:
   - Discover all mounted worktrees dynamically via `git worktree list --porcelain | grep '^worktree ' | cut -d' ' -f2-`.
3. **In-Flight Operation Guard (Canonical Plumbing)**:
   - For each worktree `$wt`, verify no merge, rebase, or cherry-pick is in progress using canonical gitdir resolution:
     - `MERGE_FILE=$(git -C "$wt" rev-parse --git-path MERGE_HEAD)`
     - `REBASE_DIR=$(git -C "$wt" rev-parse --git-path rebase-merge)`
     - `CHERRY_FILE=$(git -C "$wt" rev-parse --git-path CHERRY_PICK_HEAD)`
   - If any of these paths exist on disk, abort pause with advisory: `❌ Cannot pause while a merge/rebase/cherry-pick is in progress in worktree '<wt>'. Complete or abort it first.`
4. **Per-Worktree Stash, SHA Assertion & Atomic Rollback**:
   - Initialize tracking array: `CREATED_STASHES=()`.
   - For each worktree directory `$wt`:
     - Inspect status: `STATUS=$(git -C "$wt" status --porcelain 2>/dev/null)`.
     - Record staged files (`git -C "$wt" diff --name-only --cached`) and unstaged files (`git -C "$wt" diff --name-only`).
     - If `$STATUS` is non-empty:
       - Determine branch: `BRANCH=$(git -C "$wt" branch --show-current 2>/dev/null || echo "detached")`.
       - Generate unique tag: `STASH_TAG="aapp-pause-$(date +%Y%m%d-%H%M%S):$BRANCH"`.
       - Execute stash:
         ```bash
         git -C "$wt" stash push --include-untracked -m "$STASH_TAG"
         ```
       - **Air-Gap Invariant**: `--include-untracked` strictly respects `.gitignore` rules (preserving private/air-gapped reference stores such as `.plans/pickup/`). `--all` is strictly prohibited.
       - **SHA Capture & Hex Assertion**:
         - Extract the 40-character commit SHA:
           ```bash
           STASH_SHA=$(git stash list --format='%H %gs' | grep -F "$STASH_TAG" | head -n 1 | cut -d' ' -f1)
           ```
         - **Atomic Rollback Invariant**: If stash push failed or `STASH_SHA` does not match `^[0-9a-f]{40}$`:
           - Roll back all stashes created during this invocation: for each entry in `$CREATED_STASHES`, run `git -C "$created_wt" stash apply "$created_sha" && git stash drop "$created_idx"`.
           - Abort with error: `❌ Failed to capture valid stash SHA for worktree '$wt'. All stashes rolled back. Pause aborted.`
           - Exit code 1. All-or-nothing guarantee.
         - Record `CREATED_STASHES+=("$wt:$BRANCH:$STASH_SHA:$STASH_TAG")`.
         - Record `{"worktree": "$wt", "branch": "$BRANCH", "sha": "$STASH_SHA", "tag": "$STASH_TAG"}` in `snapshot.stashes`.
5. Capture HEAD commit SHAs across all worktrees.
6. Write state JSON to `$(git rev-parse --git-common-dir)/aapp_paused`.
7. Every worktree is left in a clean, pristine state with in-flight code safely quarantined in Git's object store.

### C. Layer 1: Write-Time Interception (`templates/blast-radius-guard.sh`)
Add an early Circuit Breaker check in `templates/blast-radius-guard.sh` before Section 3:
1. Probe for pause state in `$(git rev-parse --git-common-dir 2>/dev/null)/aapp_paused` or `.plans/PAUSED.md`.
2. If paused:
   - Allow external scratchpads and authorized agent memory paths (Section 2c allowlist).
   - Allow `.plans/*` paths (blueprints, issues, pickup queue) and `.agents/*` paths (codemap, agent rules, project notes).
   - Deny all other file writes inside the repository:
     ```text
     🛑 [Project Circuit Breaker] The project is currently PAUSED.
        Reason : <reason>
        Stashes: In-flight changes quarantined across worktrees
        All code and template modifications are strictly refused.
        To resume modifications, run 'aapp resume'.
     ```

### D. Layer 2: Commit-Time Gate (`templates/aapp-pre-commit`)
Add a Circuit Breaker check in `templates/aapp-pre-commit`:
1. Probe for pause state in `$(git rev-parse --git-common-dir 2>/dev/null)/aapp_paused` or `.plans/PAUSED.md`.
2. If paused:
   - If staged files are strictly confined to `.plans/*` or `.agents/*`, allow the commit (documenting the pause, filing issues, or refining plans).
   - If any staged file touches tracked code, templates, libraries, or hooks, refuse the commit with exit code 1:
     ```text
     ❌ [Project Circuit Breaker] Commits to codebase are refused while the project is PAUSED.
        Reason: <reason>
        To resume commits, run 'aapp resume'.
     ```

### E. Resumption, Forensic Drift Verification & Safe SHA-Restoration (`cmd_resume`)
When `aapp resume` is invoked:
1. **Idempotency Check**:
   - If project is not paused, output `ℹ️ Project is already active (not paused).` and exit 0.
2. **Forensic Drift Detection**:
   - Compare current HEAD SHAs of all worktrees against `snapshot.worktrees`.
   - Check if foreign untracked files appeared.
   - If drift is detected, output exact forensic details (worktree, previous SHA, current SHA).
   - *No Auto-Rebase Invariant:* Drift is reported for human inspection, not automatically rebased, preventing silent endorsement of unauthorized `--no-verify` commits.
3. **SHA-Addressed Stash Restoration & Pause Buffer Survival**:
   - For each entry in `snapshot.stashes`:
     - Apply explicitly by commit SHA:
       ```bash
       git -C "$worktree" stash apply "$STASH_SHA"
       ```
     - **Pause Buffer Survival & No-Loss Conflict Invariant**:
       - If `stash apply` exits non-zero (merge conflict or failure):
         - **STOP IMMEDIATELY AND KEEP THE STASH**. The stash entry remains intact in `git stash list` so no work can ever be lost.
         - **DO NOT REMOVE THE PAUSE BUFFER (`aapp_paused`)**. The project remains PAUSED.
         - Alert the developer: `❌ Merge conflict encountered in worktree '$worktree'. Project remains PAUSED to protect integrity. Stash preserved in git stash list. Resolve conflicts, then re-run 'aapp resume'.`
         - Abort resumption with exit code 1.
       - Only if `stash apply` exits with 0: drop the stash entry by locating its current index matching `$STASH_SHA`:
         ```bash
         STASH_IDX=$(git stash list --format='%gd %H' | grep -F "$STASH_SHA" | head -n 1 | cut -d' ' -f1)
         [ -n "$STASH_IDX" ] && git stash drop "$STASH_IDX"
         ```
     - **Forensic Notice vs. `--index` Design Rationale**:
       - If the snapshot recorded files that were staged prior to pause, output an informative notice:
         `ℹ️ Prior to pause, the following files were staged: [files...]. Restored unstaged for review.`
       - *Deliberate Architecture Decision:* Using standard SHA apply with forensic reporting rather than `git stash apply --index` is an intentional trade: `--index` frequently aborts on minor hunk or index boundary differences, whereas standard apply + forensic reporting guarantees reliable restoration without risking spurious failures.
4. **Sanity Verification**:
   - Only reached when ALL stashes have applied cleanly with exit code 0.
   - Execute `lib/planning_health.sh` to confirm planning integrity across all 7 pairs.
5. **Buffer Deactivation**:
   - Only reached after all stashes have been restored and sanity checks pass.
   - Remove `$(git rev-parse --git-common-dir)/aapp_paused` (and remove `.plans/PAUSED.md` if shared).
6. **Briefing Output**:
   - Output clean wakeup report summarizing restored worktrees, drift status, and planning health results.

### F. Emergency Escape Hatches
- Write-time bypass: `SKIP_BLAST_RADIUS=1` bypasses Layer 1.
- Commit-time bypass: `git commit --no-verify` or `SKIP_BLAST_RADIUS=1` bypasses Layer 2.
- Manual stash recovery: `git stash list` and `git stash apply <sha>` if manual inspection is desired.

### G. CLI Ergonomics & Switchboard (`lib/cmd_pause.sh` & `aapp`)
- `aapp pause [reason]`: Snapshot workspace, quarantine in-flight changes per-worktree into SHA-addressed stashes, and engage brake. If already paused, acts as an inspector.
- `aapp pause --shared [reason]`: Engage team-wide freeze via `.plans/PAUSED.md`.
- `aapp resume` (or `aapp unpause`): Verify drift, restore stashes by SHA, verify planning health, and disengage brake.
- `aapp status`: Display prominent warning banner when paused:
  ```text
  🛑 PROJECT STATUS: PAUSED
     Reason : switching focus to project-2
     Paused : 2026-09-19 02:30:00 (45 minutes ago)
     Stashes: 2 worktrees quarantined (develop, .plans)
  ```

### H. Universal Skills Bridging
Author `templates/skills/aapp-pause/SKILL.md` (exposing `/aapp-pause` and `/aapp-resume`), bridged to `.agents/skills/` and `.claude/skills/`, and protected under Guard Section 2 self-protection.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Core CLI, Dynamic Discovery & Multi-Worktree Stash Engine
- [x] Task 1.1: Author `lib/cmd_pause.sh` implementing `cmd_pause` with dynamic worktree discovery (`git worktree list --porcelain`), canonical gitdir in-flight merge/rebase guard, `--include-untracked` stash quarantine, 40-char SHA assertion, and atomic rollback on failure.
- [x] Task 1.2: Implement `cmd_resume` in `lib/cmd_pause.sh` with forensic drift comparison, SHA-addressed `git stash apply`, staged-file reporting, short-circuit buffer retention on conflict, conditional stash drop, and planning health check.
- [x] Task 1.3: Add idempotent inspector handling to `cmd_pause` (inspecting active pause) and `cmd_resume` (handling unpaused state).
- [x] Task 1.4: Integrate `pause`, `resume`, and `unpause` into `aapp` command router.
- [x] Task 1.5: Update `lib/cmd_status.sh` to surface project pause status, reason, duration, and quarantined worktree stashes in Context Recovery briefing.
- [x] Task 1.6: Update `lib/cmd_help.sh` documenting `aapp pause` and `aapp resume`.

### Phase 2: Guard & Hook Enforcement
- [x] Task 2.1: Add Circuit Breaker check to `templates/blast-radius-guard.sh` using `--git-common-dir`, allowing `.plans/*` and `.agents/*`.
- [x] Task 2.2: Add Circuit Breaker check to `templates/aapp-pre-commit` refusing code commits while paused.
- [x] Task 2.3: Add `.agents/skills/aapp-pause` and `.claude/skills/aapp-pause` to Guard Section 2 self-protection.

### Phase 3: Universal Skill & Adoption Sync
- [x] Task 3.1: Author `templates/skills/aapp-pause/SKILL.md` for agent chat interaction.
- [x] Task 3.2: Update `lib/cmd_init.sh` to synchronize `aapp-pause` skill and mount hooks.

### Phase 4: Governance & Documentation
- [x] Task 4.1: Document the Hibernate & Wake protocol, stash quarantine invariants, and escape hatches in `templates/AGENTS.md`.
- [x] Task 4.2: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` with pause/resume contracts.
- [x] Task 4.3: Update `README.md`, `MANUAL.md`, and `CHEATSHEET.md`.

### Phase 5: Automated Verification & Regression Suite
- [x] Task 5.1: Add test cases in `tests/write-guard_test.sh` asserting write refusal on code while paused, allowing `.plans/*` and `.agents/*`.
- [x] Task 5.2: Add test cases in `tests/pre-commit_test.sh` asserting commit refusal on code while paused across linked worktrees (`--git-common-dir`).
- [x] Task 5.3: Add test cases validating dynamic worktree discovery, in-flight merge guard refusal, atomic rollback on pause failure, SHA-addressed restore, conflict buffer retention, and drift detection.
- [x] Task 5.4: Add test cases in `tests/install_test.sh` validating `aapp-pause` skill sync and drift control.
- [x] Task 5.5: Run full regression suite across all suites against 262-test baseline (target: 275+ passing tests).
- [x] Task 5.6: Update `CHANGELOG.md` with release notes.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_pause.sh` -> NEW FILE: Implementation of pause, snapshot, dynamic worktree stash quarantine, drift detection, and resume commands.
- [ ] `aapp` -> Add router cases for pause, resume, and unpause.
- [ ] `lib/cmd_status.sh` -> Display pause state, duration, and quarantined stash in briefing banner.
- [ ] `lib/cmd_help.sh` -> Catalog and usage examples for pause/resume.
- [ ] `lib/cmd_init.sh` -> Sync aapp-pause skill and self-protection.
- [ ] `templates/blast-radius-guard.sh` -> Write-time interception on paused state.
- [ ] `templates/aapp-pre-commit` -> Pre-commit interception on paused state.
- [ ] `templates/skills/aapp-pause/SKILL.md` -> NEW FILE: Slash command for pause/resume.
- [ ] `templates/AGENTS.md` -> Document Project Circuit Breaker & Hibernate/Wake protocol.
- [ ] `ARCHITECTURE.md` -> Architectural boundary documentation for pause buffer and stash quarantine.
- [ ] `.agents/CODEMAP.md` -> Callable contracts for cmd_pause.sh.
- [ ] `README.md` -> User documentation for emergency brake and state preserver.
- [ ] `MANUAL.md` -> Comprehensive operational guide in Chapter 5.
- [ ] `CHEATSHEET.md` -> Command cheat sheet updates.
- [ ] `tests/write-guard_test.sh` -> Automated tests for write-guard circuit breaker and pause lifecycle.
- [ ] `tests/pre-commit_test.sh` -> Automated tests for pre-commit circuit breaker and worktree sharing.
- [ ] `tests/install_test.sh` -> Skill synchronization test coverage.
- [ ] `CHANGELOG.md` -> Feature entry under Unreleased.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/plan_resolver.sh` -> Plan ID shorthand resolver engine is untouched.
- [ ] `lib/planning_health.sh` -> Planning health integrity engine is untouched.
- [ ] `.githooks/*` -> Hook dispatcher entrypoints are untouched.

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1: State Buffer Scoping Architecture**
  - *Resolution:* Default scope strictly uses `$(git rev-parse --git-common-dir)/aapp_paused` (repo-wide uncommitted, shared across all linked worktrees `.plans`, `.agents`, and code worktrees without git commit noise). An optional `--shared` flag creates or updates `.plans/PAUSED.md` (committed to `plans` branch for team-wide/remote synchronization). Per-worktree scoping (`--git-path`) is rejected as an architectural bug.
* [x] **Question 2: Multi-Worktree Stash Isolation & SHA-Addressing**
  - *Resolution:* Worktrees are discovered dynamically (`git worktree list --porcelain`) and stashed per-worktree using `--include-untracked` and unique tags (`aapp-pause-$TS:$branch`). Commit SHAs are immediately captured from `git stash list` and stored in the snapshot JSON. Restoration applies explicitly by commit SHA, eliminating vulnerability to index shifting on the shared stash stack.
* [x] **Question 3: In-Flight Operation Safety Guard**
  - *Resolution:* Pre-checks for active merges, rebases, or cherry-picks using canonical plumbing (`git rev-parse --git-path MERGE_HEAD`, `rebase-merge`, `CHERRY_PICK_HEAD`). If an operation is in-flight, `aapp pause` is refused, preventing stashing half-resolved merge conflicts.
* [x] **Question 4: Staged File Forensics vs. Index Restoration**
  - *Resolution:* Rather than risking fragile `--index` merge conflicts on cherry-picked changes, the snapshot captures the exact list of staged vs. unstaged files prior to pause. Changes are restored cleanly via standard SHA apply, and `aapp resume` prints the exact list of previously staged files so the developer has full visibility without index corruption.
* [x] **Question 5: Air-Gap Safety Invariant**
  - *Resolution:* Quarantine strictly uses `git stash push --include-untracked` and forbids `--all`. This ensures `.gitignore` rules are respected and air-gapped stores (such as private notes in `.plans/pickup/`) are never swept into stash objects.
* [x] **Question 6: No-Loss Conflict Guarantee & Forensic Drift Policy**
  - *Resolution:* If `git stash apply <sha>` encounters a merge conflict, the stash entry is permanently preserved in the stash stack (never dropped). On resume, drift between snapshot HEAD SHAs and current worktree HEADs is reported as forensic data for human evaluation; auto-rebasing is rejected to prevent silent endorsement of unauthorized `--no-verify` commits.
* [x] **Question 7: Permitted Path Boundaries During Pause**
  - *Resolution:* Both Layer 1 and Layer 2 permit writes and commits exclusively confined to `.plans/*` (planning, issues, pickup) and `.agents/*` (codemap, agent behavioral rules, project notes), enabling reflection and triage while blocking all code, templates, libraries, and tests.
* [x] **Question 8: Atomic Pause Rollback Invariant**
  - *Resolution:* On `aapp pause`, if any stash push fails or `STASH_SHA` fails 40-character hexadecimal validation, an immediate rollback is executed: all stashes created in that invocation are re-applied and dropped, and the pause is aborted with exit code 1. No half-paused state is possible.
* [x] **Question 9: Pause Buffer Survival on Resume Conflict**
  - *Resolution:* On `aapp resume`, if any worktree hits a merge conflict during stash apply, resumption short-circuits immediately. The pause buffer (`aapp_paused`) remains on disk and the project remains PAUSED. Buffer deactivation occurs exclusively when all stashes restore cleanly (exit code 0).

---

## 📦 6. Change Log & Refinement History
* **2026-09-19:** Implementation complete: multi-worktree SHA-addressed stash quarantine engine (`cmd_pause`), dual-layer circuit breaker hooks (Layer 1 write-guard & Layer 2 pre-commit), universal skill bridging (`aapp-pause`), documentation updates, and 280 automated regression tests passing across all suites.
* **2026-09-19:** Plan frozen and activated into 🟠 In Development via freeze-start.
* **2026-09-19:** Plan hardened with failure-path invariants: Atomic Pause Rollback Invariant (asserting 40-char hex SHA and rolling back on partial failure), Pause Buffer Survival Invariant (retaining pause buffer on stash conflict until clean restoration), canonical plumbing for in-flight operation checks (`git rev-parse --git-path`), and documented design rationale for staged file forensics vs `--index`.
* **2026-09-19:** Plan refined with Dynamic Worktree Discovery (`git worktree list --porcelain`), In-Flight Merge/Rebase Guard (`MERGE_HEAD`/`rebase-merge`/`CHERRY_PICK_HEAD` check), Staged File Forensic Snapshotting (preserving cherry-picked visibility without fragile index restoration), and Idempotent Inspector CLI ergonomics.
* **2026-09-19:** Plan refined with Multi-Worktree SHA-Addressed Stash Quarantine: per-worktree dirty detection (`develop`, `.plans`, `.agents`), 40-character commit SHA tracking (immune to index reordering), safe SHA-based `stash apply` with conditional drop, No-Loss Conflict Guarantee (stash preserved on conflict), Air-Gap Safety Invariant (`--include-untracked` strictly preserving `.gitignore` boundaries), and forensic drift reporting without auto-rebase.
* **2026-09-19:** Plan expanded with Snapshot & Stash Quarantine ("Hibernate & Wake") architecture: automated named stash quarantine on pause (`aapp-pause-<timestamp>`), pristine working tree preservation, drift detection against worktree commit snapshot on resume, stash restoration, and post-resume planning sanity verification.
* **2026-09-19:** Plan refined from Red Team insights: corrected state buffer scoping from per-worktree (`--git-path`) to repo-wide (`--git-common-dir`); aligned `.agents/*` and `.plans/*` permission across both Layer 1 and Layer 2; documented cross-repo hook execution reality ("uncommittable, not untouchable"); added explicit documentation for `SKIP_BLAST_RADIUS=1` and `--no-verify` emergency escapes; calibrated test baselines against 262 passing tests; and resolved Open Questions 1, 2, and 3.
* **2026-09-19:** Plan initialized from user request for project-level blockage and multi-window pause mechanism.
