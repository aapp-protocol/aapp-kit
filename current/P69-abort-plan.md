# 🗺️ Plan P-69: Lifecycle Plan Abort & Worktree Decommissioning
* **Created:** 2026-10-11 | **Last Refined:** 2026-10-11
* **Target Issue / Milestone:** #118
* **Plan ID:** P-69
* **Changelog:** Added: `aapp plan abort` command to safely decommission in-flight plans, clean worktrees/branches, and archive to .plans/aborted/
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
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal

In AAPP, blueprint lifecycles are currently strictly unidirectional towards `done`:
- Once started (`aapp start`), a plan can only reach `done` (`aapp done <id>`), which gates on tests, integrates commits, and archives the plan to `.plans/done/`.
- While mini-plans have `aapp issue fix <num> abort` to cleanly drop uncommitted issue fixes, full plans have **no verb-driven exit path** when an approach fails, an RFC is rejected, or an architectural pivot renders the blueprint obsolete.
- Developers and agents are left with manual surgery: deleting worktrees, removing branches, hand-editing `.plans/state_matrix.md`, clearing buffers, and manually moving files.

**Goal:** Implement a first-class `aapp plan abort <id>` lifecycle command that safely decommissions any non-done plan, tears down its worktree/branch resources, reverts promoted issues back to `🟡 Incubated`, unlinks group memberships, and moves the blueprint into `.plans/aborted/`.

---

## 2. Technical Blueprint

### 2.1 CLI Ingress & Command Syntax

- **Entrypoint**: `aapp plan abort <id> [reason "<text>"] [keep-branch] [force]`, a subcommand of the existing `plan` verb (beside `conflict-check`); no top-level `abort` verb is registered.
- **Positional `<id>`**: Resolves plan identifier via `resolve_plan_file` (accepts `P-<N>`, bare `<N>`, filename stem, or slug).
- **Keyword Tokens**:
  - `reason "<text>"`: Human or agent justification for abandonment (default: `Abandoned`).
  - `keep-branch`: Decommissions the worktree and archives the plan, but preserves the git branch `plan/<id>-<slug>` in ref history for reference.
  - `force`: Bypasses dirty worktree checks (force removes untracked/uncommitted changes in the plan's worktree).

### 2.2 Preconditions & Scope

- **Eligible Statuses**: Any active or inactive blueprint in `.plans/current/`:
  - `🟣 Under Review` / `📝 Refining` (cancels early incubator drafts).
  - `🔷 Frozen` (drops approved specifications before code is written).
  - `⚡ In Development` (safely halts in-flight execution).
  - `🟥 BLOCKED` (retires permanently blocked plans).
- **Ineligible**: Plans in `.plans/done/` or `.plans/aborted/` refuse with exit code 1 (`Cannot abort an already completed/aborted plan`).

### 2.3 Teardown & Worktree Decommissioning

If the plan was started in its own worktree (`* **Worktree:** .workspace/<id>`):
1. **Dirty Worktree Guard**:
   - Inspects `git -C <worktree> status --porcelain`.
   - If uncommitted tracked changes exist and `force` is **not** specified: refuses with exit code 1, reporting dirty files and advising `commit`, `stash`, or `plan abort ... force`.
2. **Worktree Removal**:
   - Executes `git worktree remove --force "$wt_path"`.
   - Prunes kit symlinks (`.githooks`, `.agents`, `.plans`, `.claude`).
3. **Branch Cleanup**:
   - Unless `keep-branch` is specified:
     - Deletes branch `plan/<id>-<slug>` via `git branch -D "$plan_branch"`.
     - If `keep-branch` is passed: preserves the branch and emits `ℹ️  Branch 'plan/<id>-<slug>' preserved.`
4. **Buffer Reset**:
   - Checks active plan buffer (`aapp_active_plan`). If currently set to `<id>`, clears or restores `.prev`.

### 2.4 Archival in `.plans/aborted/` & Ledger Recording

- **Target Directory**: Moves file from `.plans/current/P<n>-<slug>.md` to `.plans/aborted/P<n>-<slug>.md`.
- **Status Mutation**: Updates header to:
  ```markdown
  * **Status:** ❌ Aborted
  * **Aborted:** 2026-10-11 | **Reason:** <reason>
  ```
- **Change Log Entry**: Appends dated entry to `## 📦 6. Change Log`:
  `* **2026-10-11:** Plan aborted: <reason>`
- **Aborted Ledger (`.plans/aborted/000-aborted-ledger.md`)**:
  Appends structured row to the ledger table:
  `| Date | ID | Blueprint | Target Issue | Reason | Commits |`
- **State Matrix Sync**:
  Re-derives or prunes `<id>` from `.plans/state_matrix.md`.

### 2.5 Issue Lane & Group Plan Integration

1. **Target Issue Reversion (#118 contract)**:
   - If the plan was promoted from an active issue (`* **Target Issue / Milestone:** #<n>`):
     - The issue in `ISSUES.md` is **NOT closed**.
     - Issue status in `ISSUES.md` reverts from `🔵 Planned` to `🟡 Incubated`.
     - The `Target Plan / Fix` cell keeps the plan link, repointed to the archive: `[P-<id>](aborted/P<n>-<slug>.md)`. It is a verb-written link, as P-66 requires; no note is written.
     - The row edit is the issue module's abort step in `lib/cmd_issue.sh`, the one `aapp issue fix <num> abort` runs; `plan abort` calls it and writes no issue row itself.
     - Other rows and road-map lines linking the plan file are repointed to `aborted/` by `issue_relink`, as `done` does for `done/`.
2. **Group Plan Unlinking (P-64 interaction)**:
   - If the plan has `* **Group:** <group>`:
     - Removes `<id>` from the group plan's `* **Members:**` header list.
   - If the plan *is* a group plan (`# 🧩 Group Plan P-<n>`):
     - Refuses if active members are still `⚡ In Development` in the group.
     - If all members are completed or aborted: removes feature branch `feature/<slug>` and archives the group.

### 2.6 Lifecycle Commit & Hooks

- **Plans Worktree Commit**:
  Commits all ledger, matrix, issue, and plan file moves in one atomic commit:
  `plan(abort): <id> <reason>`
- **Hook Dispatch**:
  Dispatches `post-abort` lifecycle observer hook (passing `plan_id`, `plan_file`, `reason`, `worktree`, `branch`).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/verbs/plan.abort.sh`: Add test `test_abort_incubator_draft_moves_to_aborted_and_cleans_matrix`.
- [ ] Task 1.2: `tests/verbs/plan.abort.sh`: Add test `test_abort_frozen_plan_cleans_resources`.
- [ ] Task 1.3: `tests/verbs/plan.abort.sh`: Add test `test_abort_inflight_plan_refuses_dirty_worktree_without_force`.
- [ ] Task 1.4: `tests/verbs/plan.abort.sh`: Add test `test_abort_inflight_plan_removes_worktree_and_deletes_branch`.
- [ ] Task 1.5: `tests/verbs/plan.abort.sh`: Add test `test_abort_with_keep_branch_preserves_ref`.
- [ ] Task 1.6: `tests/verbs/plan.abort.sh`: Add test `test_abort_reverts_target_issue_to_incubated`.
- [ ] Task 1.7: `tests/verbs/plan.abort.sh`: Add test `test_abort_group_member_unlinks_from_group_plan`.
- [ ] Task 1.8: `tests/verbs/plan.abort.sh`: Add test `test_abort_writes_aborted_ledger_entry`.

### Phase 2: Core Implementation
- [ ] Task 2.1: Implement `cmd_plan_abort()` in `lib/cmd_plan.sh`.
- [ ] Task 2.2: Route `abort` in `cmd_plan_switchboard` and list it in the switchboard text.
- [ ] Task 2.3: Implement worktree cleanup, buffer unbinding, and branch removal logic.
- [ ] Task 2.4: Implement `.plans/aborted/` movement, header mutation, and `000-aborted-ledger.md` appender.
- [ ] Task 2.5: Issue abort step in `lib/cmd_issue.sh` (`🔵 Planned` -> `🟡 Incubated`, link repointed to `aborted/`), shared by `issue fix <num> abort` and `plan abort`.
- [ ] Task 2.6: Implement group plan member unlinking for P-64 integration.
- [ ] Task 2.7: Dispatch `post-abort` lifecycle hook.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify all failure assertions pass.
- [ ] Task 3.2: Add the `plan abort` form to the `plan` verb contract `lib/docs/verbs/plan.md`.
- [ ] Task 3.3: Update `MANUAL.md` with Plan Abort & Decommissioning lifecycle guide.
- [ ] Task 3.4: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
- [ ] Task 3.5: Verify `CHANGELOG.md` updates and run syntax/build checks.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_plan.sh` -> Implement `plan abort`, worktree teardown, and plan archival logic.
- [ ] `lib/cmd_issue.sh` -> Issue abort step: status back to Incubated, plan link repointed to `aborted/`.
- [ ] `lib/docs/verbs/plan.md` -> `plan abort` form in the `plan` verb contract.
- [ ] `NEW FILE` -> `tests/verbs/plan.abort.sh` -> `plan` verb suite part covering incubator, frozen, in-flight, and group aborts.
- [ ] `MANUAL.md` -> User guide documentation for abandoning and archiving blueprints.
- [ ] `.agents/CODEMAP.md` -> Architectural boundary mapping for abort lifecycle.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Core git hooks untouched.
- [ ] `templates/blast-radius-guard.sh` -> Write guard untouched.
- [ ] `lib/planning_health.sh` -> Planning health engine untouched.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Aborted Ledger Location & Format. → RESOLVED (developer, 2026-10-11): (a) Dedicated .plans/aborted/000-aborted-ledger.md.** Keeps clean architectural separation between completed implementations and abandoned plans, mirroring the directory structure.
* [x] **Question 2 — Branch deletion on unmerged commits. → RESOLVED (developer, 2026-10-11): (a) Warn and delete branch.** In a normal case if the plan is aborted that implies there is no need of the code. A clear diagnostic warning is printed naming the deleted branch SHA. If the developer explicitly wishes to preserve the commits for future reference, `keep-branch` is used.

---

## 📦 6. Change Log & Refinement History
* **2026-10-11:** Issue side runs through the issue module's abort step; the row keeps the plan link, repointed to `aborted/`.
* **2026-10-11:** Single command form `aapp plan abort <id>`: no top-level `abort` verb, contract in `lib/docs/verbs/plan.md`, tests in the suite part `tests/verbs/plan.abort.sh`.
* **2026-10-11:** Resolved Q1 (dedicated aborted ledger) and Q2 (warn and delete unmerged branch unless keep-branch). Blueprint fully specified.
* **2026-10-11:** Scaffolded from Issue #118 and refined technical blueprint: defined CLI ingress (`aapp abort`), worktree teardown, `.plans/aborted/` archival, issue reversion to Incubated, and group member unlinking.
