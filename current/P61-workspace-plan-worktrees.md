# 🗺️ Plan P-61: Workspace Plan Worktrees & Cross-Worktree Guard Resolution
* **Created:** 2026-10-09 | **Last Refined:** 2026-10-09
* **Target Issue / Milestone:** #112
* **Plan ID:** P-61
* **Changelog:** Changed: default plan worktrees to .workspace/{id} and enable cross-worktree guard resolution (#112)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
* **Status:** ⚡ In Development
* **Base:** `948abe7` (develop)
* **Worktree:** .workspace/P61 (plan/P61-workspace-plan-worktrees)
* **Commits:** `0c0b004` (plan/P61-workspace-plan-worktrees)
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
Plan worktrees introduced in P-54 allow isolated implementation branches on dedicated worktrees. However, two operational frictions have emerged:

1. **Worktree Directory Location**:
   The initial default path was `../{repo}-{id}`, placing plan worktrees outside the project directory. In repositories where developers work with other worktrees or value strict self-containment, placing directories in parent folders creates clutter, causes orphan directory risk, and confuses users unfamiliar with worktrees. Grouping plan worktrees under `.workspace/{id}` inside the repository keeps everything self-contained (alongside `.plans/`, `.agents/`, and `.githooks/`), while the dot-prefix prevents inadvertent scanning by external linters and language servers.
2. **Cross-Worktree Blast Radius Guard (#112)**:
   The write-time blast radius guard (`templates/blast-radius-guard.sh`) currently resolves repository boundaries and the active plan pointer buffer (`aapp_active_plan`) strictly from the agent session's current working directory (`REPO_ROOT="$(git rev-parse --show-toplevel)"`). When an agent or developer operates from the primary checkout and attempts to edit files inside an active plan worktree (whether at `.workspace/{id}` or a custom path), the guard treats the target as outside the repository or foreign to the primary buffer, rejecting valid edits.

This plan delivers:
- Changing the default `aapp.planWorktreePath` template to `.workspace/{id}`.
- Ensuring `/.workspace/` is added to `.git/info/exclude` on `init` and `_wt_create`.
- Enhancing `templates/blast-radius-guard.sh` to recognize linked worktrees sharing `GIT_COMMON_DIR`, resolve the target file's own worktree root and pointer buffer, and enforce target file blast radius transparently from a primary session.

---

## 2. Technical Blueprint

### 2.1 Default Path & Ignore Handling
- **Default Config**: In `lib/cmd_init.sh` and `lib/cmd_plan.sh`, change the fallback template for `aapp.planWorktreePath` from `../{repo}-{id}` to `.workspace/{id}`.
- **Git Exclude**:
  - In `lib/cmd_plan.sh` (`_wt_create`), add `/.workspace/` to the primary repo's `.git/info/exclude` (or Git common dir `info/exclude`), alongside `.githooks`, `.agents`, `.plans`, and `.claude`.
  - In `lib/cmd_init.sh`, ensure `/.workspace/` is seeded into `info/exclude` when initializing or refreshing an AAPP repository.

### 2.2 Cross-Worktree Blast Radius Guard Resolution (#112)
In `templates/blast-radius-guard.sh`:
1. **Target Worktree Detection**:
   When receiving `CANONICAL_TARGET`:
   ```bash
   TARGET_DIR="$(dirname "$CANONICAL_TARGET")"
   TARGET_COMMON_DIR="$(git -C "$TARGET_DIR" rev-parse --git-common-dir 2>/dev/null || true)"
   ```
   Normalize `TARGET_COMMON_DIR` to an absolute canonical path.
   If `[ -n "$TARGET_COMMON_DIR" ] && [ "$TARGET_COMMON_DIR" = "$GIT_COMMON_DIR" ]`:
   The target file belongs to the **same repository** (either the primary checkout or one of its linked worktrees).

2. **Worktree-Relative Path & Active Buffer Resolution**:
   - Determine the target file's worktree root:
     ```bash
     TARGET_WT_ROOT="$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
     TARGET_WT_ROOT="$(canonicalize_path "$TARGET_WT_ROOT")"
     ```
   - Relativize the target file against its own worktree root:
     ```bash
     TARGET_FILE="${CANONICAL_TARGET#"$TARGET_WT_ROOT"/}"
     ```
   - Determine the active plan buffer for this specific worktree:
     ```bash
     WT_ACTIVE_BUF="$(git -C "$TARGET_DIR" rev-parse --git-path aapp_active_plan 2>/dev/null || true)"
     case "$WT_ACTIVE_BUF" in /*) ;; *) WT_ACTIVE_BUF="$TARGET_WT_ROOT/$WT_ACTIVE_BUF" ;; esac
     ```
   - If `WT_ACTIVE_BUF` contains a designated plan (e.g. `P-60`), evaluate `TARGET_FILE` against that plan's declared `### 📂 Target Files` and `### 🛑 Out of Bounds`.
   - If the target file is in a linked worktree bound to a plan, an edit matching that plan's targets succeeds (`exit 0`), while an edit outside targets is denied with the standard blast-radius diagnostic.
   - If the worktree is unbound (no plan in `WT_ACTIVE_BUF`), apply standard unbound repository checks relative to that worktree.

3. **Fallback to Foreign Paths**:
   If `TARGET_COMMON_DIR` does not match `GIT_COMMON_DIR`, continue to evaluate against `aapp.allowPath` allowlists or deny as outside repository.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Backwards Compatible`
- **Fallback Inventory**:
  - Existing repositories with custom `aapp.planWorktreePath` (e.g. `../{repo}-{id}`) retain their configuration without regression.
  - The guard resolution logic checks `GIT_COMMON_DIR` match across all linked worktrees, so both `.workspace/{id}` and existing sibling worktrees like `../{repo}-{id}` gain cross-worktree editing capabilities immediately.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Default Path & Ignore Wiring
- [ ] Task 1.1: Update default `aapp.planWorktreePath` to `.workspace/{id}` in `lib/cmd_init.sh` and `lib/cmd_plan.sh`.
- [ ] Task 1.2: Add `/.workspace/` to `info/exclude` in `lib/cmd_init.sh` and `lib/cmd_plan.sh` (`_wt_create`).

### Phase 2: Guard Cross-Worktree Resolution
- [ ] Task 2.1: Update `templates/blast-radius-guard.sh` to inspect target file directory for `git-common-dir` match.
- [ ] Task 2.2: Relativize target file against its specific worktree root when in a linked worktree.
- [ ] Task 2.3: Read `aapp_active_plan` from the target worktree's git-path and enforce its blast radius.

### Phase 3: Test Verification
- [ ] Task 3.1: Update `tests/install_test.sh` for the new `.workspace/{id}` default path in `aapp init`.
- [ ] Task 3.2: Update `tests/verbs/start.sh` to verify plan worktrees scaffold into `.workspace/{id}` and are ignored.
- [ ] Task 3.3: Add cross-worktree guard tests in `tests/worktree_hooks_test.sh`: test editing plan worktree target files from the primary checkout session without changing cwd.
- [ ] Task 3.4: Run full test suite `./aapp test` and verify zero regressions.

### Phase 4: Documentation & Manual Sync
- [ ] Task 4.1: Update `MANUAL.md`, `CHEATSHEET.md`, and `lib/docs/verbs/start.md` to document `.workspace/{id}` default and cross-worktree session support.
- [ ] Task 4.2: Run `aapp init` to refresh local `.githooks` and `.agents`.
- [ ] Task 4.3: Verify `CHANGELOG.md` entry.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_init.sh` -> Update default aapp.planWorktreePath seed and info/exclude entries.
- [ ] `lib/cmd_plan.sh` -> Update fallback planWorktreePath template and _wt_create exclude handling.
- [ ] `templates/blast-radius-guard.sh` -> Add cross-worktree GIT_COMMON_DIR detection, worktree-root relativization, and target buffer resolution.
- [ ] `tests/install_test.sh` -> Update test_init_seeds_plan_worktree_keys expectation to .workspace/{id}.
- [ ] `tests/verbs/start.sh` -> Verify worktree creation in .workspace/{id} and ignore behavior.
- [ ] `tests/worktree_hooks_test.sh` -> Add test coverage for cross-worktree editing from primary checkout session.
- [ ] `MANUAL.md` -> Update documentation of default plan worktree path and single-session workflow.
- [ ] `CHEATSHEET.md` -> Update default configuration table for aapp.planWorktreePath.
- [ ] `lib/docs/verbs/start.md` -> Update start command documentation for .workspace/{id}.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/` -> Managed via templates and aapp init; do not edit directly.
- [ ] `templates/aapp-pre-commit` -> Pre-commit runs inside the committing worktree; commit boundary is unchanged.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1:** Existing worktrees created at `../{repo}-{id}` (such as P-60) are recognized and allowed by the enhanced guard without relocation, because the guard checks repo membership via `GIT_COMMON_DIR`. Settled: Leave existing paths intact.

---

## 📦 6. Change Log & Refinement History
* **2026-10-09:** Plan activated into ⚡ In Development via start.
* **2026-10-09:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-09:** Plan initialized from Issue #112; scoped default path to `.workspace/{id}` and cross-worktree guard resolution in `templates/blast-radius-guard.sh`.
