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
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-72
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
- **Default when logging:** the branch the issue is logged from; for `issue hotfix`, the parent branch of the plan that raises it. `branch <name>` names another (on `issue hotfix` here; on `issue log` with P-74).
- **Ledger:** a `Branch` column in `ISSUES.md` and the archive. The ledger functions (P-73) read cells by the header's column names, so a ledger without the column keeps working; the column is added by the first write that names a branch other than the development branch. `templates/issues.md` ships with it.
- **Fixing:** `issue fix <n>` opens the fix on the issue's branch: in the main checkout when it is on that branch, otherwise in `.workspace/fix-<n>` cut from it (the group mechanism, generalised).
- **Closing follows the code:** `issue close <n> sha <sha>` refuses while `<sha>` is not reachable from the issue's branch, naming the branch to update. The kit never pulls or merges a code branch itself. A withdrawn issue (`issue abort`) has no commit and is not subject to this.
- **Unblocking follows the code:** closing an issue unblocks a plan waiting on it only when the fix commit is reachable from the plan's parent branch. Otherwise the plan stays blocked and shows as "#<n> fixed on `<branch>`, not yet in `<parent>`"; once the branches are merged, the next `aapp status` unblocks it and says so. A plan blocked by a withdrawn issue resumes at once: there is no fix to wait for.
- **Views:** `status` and `issue list` show each issue's branch, the current branch's issues first.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Backwards Compatible`
- **Fallback Inventory**: a ledger with no `Branch` column, or an empty cell, reads as the development branch. Not a legacy shim: it is the meaning of "no branch named".

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/issue.branch.sh::test_no_branch_means_dev_branch` -> asserts a row with an empty cell, and a ledger without the column, read as `aapp.devBranch`
- [ ] `tests/verbs/issue.branch.sh::test_hotfix_takes_plan_parent_branch` -> asserts a hotfix raised from a plan carries that plan's parent branch
- [ ] `tests/verbs/issue.branch.sh::test_branch_token_adds_column` -> asserts `branch <name>` writes the cell and adds the column to a ledger that lacks it
- [ ] `tests/verbs/issue.branch.sh::test_fix_opens_on_issue_branch` -> asserts `issue fix` works in the main checkout on the issue's branch and in `.workspace/fix-<n>` cut from it otherwise
- [ ] `tests/verbs/issue.branch.sh::test_close_refuses_sha_not_in_branch` -> asserts `close … sha` refuses a commit not reachable from the issue's branch and names the branch
- [ ] `tests/verbs/issue.branch.sh::test_unblock_waits_for_parent_branch` -> asserts a plan whose parent branch lacks the fix stays blocked, and one whose parent has it is unblocked
- [ ] `tests/verbs/issue.branch.sh::test_abort_ignores_branch_rules` -> asserts `issue abort` archives the issue and resumes the plans it blocked whatever their branches
- [ ] `tests/verbs/issue.branch.sh::test_status_unblocks_after_merge` -> asserts after the fix is merged into the plan's parent branch, `aapp status` unblocks the plan and reports it
- [ ] `tests/verbs/issue.branch.sh::test_views_show_branch` -> asserts `status` and `issue list` show the branch, the current branch's issues first

### Phase 1: Tests First (red)
- [ ] Task 1.1: Write `tests/verbs/issue.branch.sh`; confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: `Branch` cell in the ledger functions (read by header name; add the column on first need); template.
- [ ] Task 2.2: Default and `branch` token at logging (`issue hotfix`).
- [ ] Task 2.3: `issue fix` on the issue's branch.
- [ ] Task 2.4: `issue close`: the commit must be in the issue's branch; unblock per plan parent branch.
- [ ] Task 2.5: `status` and `issue list`; `status` unblocks plans whose fix has reached their parent branch.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update `MANUAL.md` and the verb contracts.
- [ ] Task 3.3: Architecture and Codemap sections live in group P-72.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/aapp-lib.sh` -> Ledger functions: `Branch` cell, cells by header name.
- [ ] `lib/cmd_issue.sh` -> `branch` token, fix on the issue's branch, close and unblock rules, list.
- [ ] `lib/cmd_plan.sh` -> `done` closes its issue under the same rule.
- [ ] `lib/cmd_status.sh` -> Branch in the issues pillar.
- [ ] `templates/issues.md` -> `Branch` column and its definition.
- [ ] `lib/docs/verbs/issue.md` -> Contract.
- [ ] `lib/docs/verbs/status.md` -> Contract.
- [ ] `MANUAL.md` -> Issues on several branches.

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
*Tracks how the plan evolved across sessions.*
* **2026-10-12:** Drafted as a member of P-72.
