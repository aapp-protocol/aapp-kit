# 🗺️ Plan P-78: Issue Branch
* **Created:** 2026-10-12 | **Last Refined:** 2026-10-12
* **Target Issue / Milestone:** none
* **Plan ID:** P-78
* **Changelog:** Added: an issue carries the branch its fix lands on; fixing, closing and unblocking follow that branch (P-78)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Emergency Hotfixes:** #134
* **Base:** `5df988d` (feature/issue-tracker)
* **Worktree:** .workspace/P78 (plan/P78-issue-branch)
* **Group:** P-72
* **Commits:** `943b98b` (plan/P78-issue-branch), `5564828` (plan/P78-issue-branch)
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
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
The kit assumes one development branch: an issue fix is refused anywhere else (a group's feature branch is the one exception), and closing an issue unblocks every plan waiting on it. A project with several long-lived branches (say `develop`, a `core` branch and module branches, merged at release or in a temporary test branch) does not fit: a fix lands on one branch and is of no use to a plan on another until the branches are merged.

This plan lets an issue carry the branch its fix must land on, and makes fixing, closing and unblocking follow the code.

---

## 2. Technical Blueprint
- **The branch of an issue** is where its fix must land. No branch named (an empty cell, a ledger without the column, a payload without the field) means the development branch (`aapp.devBranch`).
- **Default when logging:** the branch the issue is logged from. From a plan's or a fix's worktree it is that plan's parent branch, never the plan or fix branch, which `done` removes; `issue hotfix` follows the same rule. `branch <name>` names another (on `issue hotfix` here; on `issue log` with P-74). `aapp refine issues "<msg>" branch <n> <name>` sets it later.
- **Ledger:** a `Branch` column in `ISSUES.md` and the archive. The ledger functions (P-73) read cells by the header's column names, so a ledger without the column keeps working; the column is added by the first write that names a branch other than the development branch. `templates/issues.md` ships with it.
- **Fixing:** `issue fix <n>` opens the fix on the issue's branch: in the main checkout when it is on that branch, otherwise in `.workspace/fix-<n>` cut from it (the group mechanism, generalised).
- **A branch that is gone.** A branch that exists only on the remote counts as existing. When the kit removes a branch itself (a group's `done`, a plan abort), it moves that branch's open issues to the branch's parent in the same step. When an issue's branch was removed otherwise, nothing blocks: `issue fix` and `issue close` treat the issue as having no branch named, so the fix lands on the development branch; the cell is cleared and one line says so (`#12 targeted test-oct, which no longer exists; it now targets develop`). `aapp status` reports such issues before anyone meets them. A person who wants another target sets it with the `branch` token.
- **Closing follows the code:** `issue close <n> sha <sha>` refuses while `<sha>` is not reachable from the issue's branch, naming the branch to update. The kit never pulls or merges a code branch itself. A withdrawn issue (`issue abort`) has no commit and is not subject to this.
- **Unblocking follows the code:** closing an issue unblocks a plan waiting on it only when the fix commit is reachable from the plan's parent branch. Otherwise the plan stays blocked and shows as "#<n> fixed on `<branch>`, not yet in `<parent>`"; once the branches are merged, the next `aapp status` unblocks it and says so. A plan blocked by a withdrawn issue resumes at once: there is no fix to wait for.
- **The fix is recognised by its commit, and by nothing else.** Work that moves the way the kit moves it (fast-forwards and merges) keeps its commits, so the kit can tell where a fix is; scripts and agents that follow the kit's flow are unblocked without anyone acting. A fix carried another way (a squash merge, a cherry-pick, a rebase) has a different commit and is not recognised: the plan stays blocked, `aapp status` says which commit it waits for and on which branch, and a person removes the block with `aapp refine <plan-id> unblocked <num>`. The kit does not read commit messages or compare changes to guess. The MANUAL states this.
- **Views:** `status` and `issue list` show each issue's branch, the current branch's issues first.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Backwards Compatible`
- **Fallback Inventory**: a ledger with no `Branch` column, or an empty cell, reads as the development branch. Not a legacy shim: it is the meaning of "no branch named".

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [x] `tests/verbs/issue.branch.sh::test_no_branch_means_dev_branch` -> asserts a row with an empty cell, and a ledger without the column, read as `aapp.devBranch`
- [x] `tests/verbs/issue.branch.sh::test_hotfix_takes_plan_parent_branch` -> asserts a hotfix raised from a plan carries that plan's parent branch
- [x] `tests/verbs/issue.branch.sh::test_branch_token_adds_column` -> asserts `branch <name>` writes the cell and adds the column to a ledger that lacks it
- [x] `tests/verbs/issue.branch.sh::test_log_from_plan_worktree_takes_parent` -> asserts an issue logged from a plan worktree carries the plan's parent branch, not the plan branch
- [x] `tests/verbs/issue.branch.sh::test_group_done_moves_issues_to_parent` -> asserts open issues targeting a group's feature branch target its parent after the group's `done`
- [x] `tests/verbs/issue.branch.sh::test_gone_branch_falls_back_to_dev` -> asserts `issue fix` on an issue whose branch was deleted opens on the development branch, clears the cell and prints the notice; a branch present only on the remote is not gone
- [x] `tests/verbs/issue.branch.sh::test_refine_sets_branch` -> asserts `refine issues "<msg>" branch <n> <name>` changes the cell and refuses a branch that does not exist
- [x] `tests/verbs/issue.branch.sh::test_fix_opens_on_issue_branch` -> asserts `issue fix` works in the main checkout on the issue's branch and in `.workspace/fix-<n>` cut from it otherwise
- [x] `tests/verbs/issue.branch.sh::test_close_refuses_sha_not_in_branch` -> asserts `close … sha` refuses a commit not reachable from the issue's branch and names the branch
- [x] `tests/verbs/issue.branch.sh::test_unblock_waits_for_parent_branch` -> asserts a plan whose parent branch lacks the fix stays blocked, and one whose parent has it is unblocked
- [x] `tests/verbs/issue.branch.sh::test_abort_ignores_branch_rules` -> asserts `issue abort` archives the issue and resumes the plans it blocked whatever their branches
- [x] `tests/verbs/issue.branch.sh::test_cherry_picked_fix_stays_blocked` -> asserts a fix cherry-picked into the plan's parent branch leaves the plan blocked, and `aapp status` names the commit and the branch it waits for
- [x] `tests/verbs/issue.branch.sh::test_refine_unblocked` -> asserts `aapp refine <plan-id> unblocked <num>` removes the block, restores the recorded status when it was the last, and refuses an issue that is still open
- [x] `tests/verbs/issue.branch.sh::test_status_unblocks_after_merge` -> asserts after the fix is merged into the plan's parent branch, `aapp status` unblocks the plan and reports it
- [x] `tests/verbs/issue.branch.sh::test_views_show_branch` -> asserts `status` and `issue list` show the branch, the current branch's issues first

### ♻️ Existing Tests Changed or Retired
> Tests that exist today and assert behaviour this plan changes. Each is rewritten or removed in the same commit as the change, with its contract line.
- `tests/verbs/issue.fixes.sh::test_fix_refuses_off_development_branch`: removed; a fix now opens on the issue's branch (`test_fix_opens_on_issue_branch` replaces it).
- `tests/verbs/issue.fixes.sh::test_fix_group_opens_worktree_and_close_integrates`: kept, as one case of the general rule; its refusal message for the development branch changes.
- `tests/integrate_test.sh` (`test_plan_without_worktree_never_integrated`): checked for its development-branch wording; changed only if the message it reads changes.
- Tests of unblocking at close (`tests/verbs/issue.sh`, `issue.abort.sh`): unchanged where the fix is on the plan's parent branch, which is the case in all of them today; any that fails shows a fixture whose plan has another parent.

### Phase 1: Tests First (red)
- [x] Task 1.1: Write `tests/verbs/issue.branch.sh`; confirm red.

### Phase 2: Core Implementation
- [x] Task 2.1: `Branch` cell in the ledger functions (read by header name; add the column on first need); template.
- [x] Task 2.2: Default (parent branch from a plan or fix worktree) and `branch` token at logging (`issue hotfix`) and on `refine issues`; issues moved when the kit removes a branch; the gone-branch fallback.
- [x] Task 2.3: `issue fix` on the issue's branch.
- [x] Task 2.4: `issue close`: the commit must be in the issue's branch; unblock per plan parent branch; `refine <plan-id> unblocked <num>`.
- [x] Task 2.5: `status` and `issue list`; `status` unblocks plans whose fix has reached their parent branch.

### Phase 3: Verification & Documentation
- [x] Task 3.1: Run automated test suites and verify edge cases.
- [x] Task 3.2: Update `MANUAL.md` and the verb contracts.
- [x] Task 3.3: Architecture and Codemap sections live in group P-72.
- [x] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [x] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/aapp-lib.sh` -> Ledger functions: `Branch` cell, cells by header name.
- [ ] `lib/cmd_issue.sh` -> `branch` token, fix on the issue's branch, close and unblock rules, list.
- [ ] `lib/cmd_plan.sh` -> `done` closes its issue under the same rule; `refine issues … branch`; a group's `done` and a plan abort move the removed branch's issues.
- [ ] `lib/docs/verbs/refine.md` -> Contract: `branch` token on `refine issues`; `unblocked <num>` on a plan.
- [ ] `lib/cmd_status.sh` -> Branch in the issues pillar.
- [ ] `templates/issues.md` -> `Branch` column and its definition.
- [ ] `lib/docs/verbs/issue.md` -> Contract.
- [ ] `lib/docs/verbs/status.md` -> Contract.
- [ ] `MANUAL.md` -> Issues on several branches; how a fix must travel to be recognised, and the manual unblock.
- [ ] `tests/verbs/issue.fixes.sh` -> Existing tests changed or retired (§3).
- [ ] `tests/integrate_test.sh` -> Development-branch wording, if it changes.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/issue.branch.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/aapp-pre-commit` -> No ledger rule changes here.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — Which moment unblocks a plan left waiting for the fix to reach its parent branch? → RESOLVED (developer, 2026-10-12):** `aapp status`: it notices the fix is now in the parent branch, unblocks the plan (the same edit and commit `issue close` makes) and says so.

---

## 📦 6. Change Log & Refinement History
* **2026-10-12:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-12:** Drafted as a member of P-72.
