# 🗺️ Plan P-64: Feature Branch Plan Groups
* **Created:** 2026-10-09 | **Last Refined:** 2026-10-09
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(if this plan was promoted from `ISSUES.md`, put the issue ID here and link this file back in that issue's `Proposed Fix / Target Plan` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-64
* **Changelog:** Added: group plans: a group cuts a feature branch from its parent branch, members start into it (`group <id>`), the group's `done` merges it into the parent; group-caused fixes land on the feature branch
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

A complex feature spans several plans. They share one feature branch cut from the development branch; each plan runs `done` into it (test gate, then integration); the feature branch merges into the development branch only when everything is green. Issue fixes keep their rule: on the development branch, unless the bug was caused by the group's work, then on the feature branch.

Design record: RFC `worktree-contexts-monorepo-rfc.md` (§4 decisions, C1/C2, A1/A2, option 1).

**The group has its own plan** (developer, 2026-10-11): one blueprint centralises the group's goal, shared decisions, feature branch and members, and its lifecycle carries the group: its `start` cuts the feature branch, its `done` runs the gate on the feature branch and merges it into the parent. Without it, the final merge is manual (P-60/P-62 were merged by hand).

**Always the parent branch** (developer): a group merges into the branch it was cut from, which is not necessarily the development branch: a module branch, a test branch, a release branch. Work always starts from a branch; tags are added after. Groups nest: a group's parent may be another group's feature branch.

---

## 2. Technical Blueprint

### 2.0 The group plan
- `aapp draft <slug> group`: a plan with the next Plan ID, marked by its title heading `# 🧩 Group Plan P-<n>: <title>` (the one marker verbs read), from its own template: goal, shared decisions, `* **Feature Branch:**`, `* **Members:**`, merge criterion. No Target Files; `freeze` checks the group fields instead.
- `aapp start <group>` (optionally `base <branch>`, an existing branch; default: the development branch): creates `feature/<slug>` from it, records `Base: <sha> (<parent>)`. No worktree, no buffer: the group writes no code.
- `aapp done <group>`: refuses while a member is not archived; runs `pre-done` with the feature branch checked out in a temporary worktree (the payload's `worktree`), so the gate tests the merged result; merges the feature branch into the parent (fast-forward, or a merge commit when the parent moved: recorded SHAs stay valid); removes the feature branch.

### 2.1 Members start into the group (`lib/cmd_plan.sh`)
`aapp start <id> group <group>` / `aapp freeze-start <id> group <group>`: the plan worktree branches from the group's feature branch, records `Base: <sha> (<feature-branch>)` and `* **Group:** <group>`, and the group plan lists the member. P-55 then integrates the plan into the feature branch. Needs a plan worktree; the group must be ⚡ In Development. `aapp.devBranch` is never changed for this.

### 2.2 Fixes on the development branch (`lib/cmd_issue.sh`)
`aapp issue fix` without `base` refuses unless the main checkout is on the development branch (`aapp_dev_branch`; the default branch when none resolves).

### 2.3 Group-caused fixes on the feature branch (`lib/cmd_issue.sh`)
`aapp issue fix <num> group <group>`: the mini plan opens in its own worktree `.workspace/fix-<num>` on `fix/<num>` from the group's feature branch; `aapp issue close <num>` integrates it there and removes the worktree and branch. The issue row and archive are unchanged.
When the issue's files differ between the development branch and an active group's feature branch, `fix` without `group` prints a hint naming `group <group>`. The human decides.

### 2.5 Status
`aapp status` lists members under their group (supersedes Q3's "later": the group plan makes it a lookup).

### 2.4 Agent text
`templates/AGENTS.md`, `.agents/AGENTS.md`, skills `aapp-start`, `aapp-done` and `aapp-fix`: plan files and plan commands under `.workspace/<id>/`; fix files and fix commands in the project root, or in `.workspace/fix-<num>/` with `group`. The scope rule: caused by the group's work → `group <group>`; unrelated → the development branch. A group's `done` is the merge into the parent; never merge a feature branch by hand.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/draft.sh::test_draft_group_scaffolds_group_plan` -> asserts `draft <slug> group` takes the next Plan ID and writes the `🧩 Group Plan` heading with the group fields and no Target Files
- [ ] `tests/verbs/start.sh::test_group_start_cuts_feature_branch_from_parent` -> asserts the feature branch starts at the parent (default or `base <branch>`) and `Base:` names the parent
- [ ] `tests/verbs/start.sh::test_group_start_refuses_missing_branch` -> asserts an unknown `base <branch>` refuses with nothing created
- [ ] `tests/verbs/start.sh::test_member_start_branches_from_feature_branch` -> asserts the member's worktree branches from the feature branch, records `Group:`, and the group lists it
- [ ] `tests/verbs/start.sh::test_member_start_refuses_unstarted_group` -> asserts `group <id>` refuses unless the group is ⚡ In Development
- [ ] `tests/integrate_test.sh::test_member_integrates_into_feature_branch` -> asserts a member's `done` lands on the feature branch, not the parent
- [ ] `tests/integrate_test.sh::test_group_done_refuses_open_member` -> asserts the group's `done` refuses while a member is not archived
- [ ] `tests/integrate_test.sh::test_group_done_gates_and_merges_into_parent` -> asserts `pre-done` sees the feature branch's worktree, the merge lands on the parent (a module branch, not develop), recorded member SHAs stay reachable
- [ ] `tests/verbs/issue.sh::test_fix_refuses_off_development_branch` -> asserts `fix` refuses when the main checkout is on another branch
- [ ] `tests/verbs/issue.sh::test_fix_group_opens_worktree_and_close_integrates` -> asserts `fix <num> group <id>` works in `.workspace/fix-<num>` and `close` lands the fix on the feature branch only
- [ ] `tests/verbs/issue.sh::test_fix_hints_group_for_group_files` -> asserts the hint names `group <id>` when the issue's files differ on an active group's feature branch
- [ ] `tests/verbs/status.sh::test_members_listed_under_group` -> asserts members appear under their group

### Phase 1: Tests First (red)
- [ ] Task 1.1: The assertions above.

### Phase 2: Implementation
- [ ] Task 2.0: Group plan: `draft … group`, template, freeze checks, group `start` and `done` (2.0); contracts `draft.md`, `start.md`, `done.md`.
- [ ] Task 2.1: `group` token on member start (2.1); contracts `start.md`, `freeze-start.md`.
- [ ] Task 2.2: Development-branch check (2.2); `fix … group` worktree and close integration (2.3); hint; contract `issue.md`.
- [ ] Task 2.3: Agent text (2.4); status (2.5).

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update user-facing documentation per `.agents/PROJECT.MD` (`MANUAL.md`, `README.md`, or `docs/`) if CLI verbs, configuration, or workflows were introduced or changed.
- [ ] Task 3.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` if new modules, commands, or interface contracts were introduced.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_plan.sh` -> Group `draft`/`freeze`/`start`/`done`; `group <id>` on member start and freeze-start.
- [ ] `lib/aapp-lib.sh` -> Group heading check; header parsers and writers (`Group`, `Feature Branch`, `Members`).
- [ ] `NEW FILE` -> `templates/group-template.md` -> The group plan template.
- [ ] `lib/cmd_issue.sh` -> Development-branch check; `fix … group` worktree, close integration, hint.
- [ ] `lib/cmd_status.sh` -> Members under their group.
- [ ] `lib/docs/verbs/draft.md` -> `group` token.
- [ ] `lib/docs/verbs/start.md` -> Group start; `group` token.
- [ ] `lib/docs/verbs/freeze-start.md` -> `group` token.
- [ ] `lib/docs/verbs/done.md` -> Group `done`.
- [ ] `lib/docs/verbs/issue.md` -> Branch check, `group`, hint.
- [ ] `tests/verbs/draft.sh` -> Group draft.
- [ ] `tests/verbs/start.sh` -> Group and member start.
- [ ] `tests/verbs/issue.sh` -> Fix branch tests.
- [ ] `tests/verbs/status.sh` -> Group listing.
- [ ] `tests/integrate_test.sh` -> Member and group integration.
- [ ] `templates/skills/aapp-done/SKILL.md` -> Group `done` is the merge into the parent.
- [ ] `templates/AGENTS.md` -> Where work and fixes happen.
- [ ] `.agents/AGENTS.md` -> Same as the template.
- [ ] `templates/skills/aapp-start/SKILL.md` -> `base`; work under `.workspace/<id>/`.
- [ ] `templates/skills/aapp-fix/SKILL.md` -> Scope rule; `base`.
- [ ] `MANUAL.md` -> Feature-branch plan groups.
- [ ] `CHEATSHEET.md` -> `base` token rows.
- [ ] `.agents/CODEMAP.md` -> New functions.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit`.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- `tests/verbs/draft.sh`
- `tests/verbs/start.sh`
- `tests/verbs/issue.sh`
- `tests/verbs/status.sh`
- `tests/integrate_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Routing by file location is P-61/P-62's.
- [ ] `lib/verbs.tsv` -> No new verbs.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — How `close` lands a `base` fix. → RESOLVED (developer, 2026-10-10): (a), fast-forward.** (a) Fast-forward onto `<branch>` (rebasing `fix/<num>` first if the branch moved): the fix's SHA stays as recorded. (b) Squash. Recommendation: (a).
* [x] **Question 2 — Branch check strictness (2.2). → RESOLVED (developer, 2026-10-10): (a), refuse.** (a) Refuse. (b) Warn and continue. Recommendation: (a).
* [x] **Question 3 — Grouping in `aapp status`. → RESOLVED (developer, 2026-10-10): later. Superseded 2026-10-11 by the group plan (§2.5).** List plans under their shared base branch now, or later? Recommendation: later; the base already shows in each plan's header.
* [x] **Question 4 — Order with P-60 and P-62. → RESOLVED (developer, 2026-10-10): P-62, then P-60, then P-64.** P-64 shares `lib/cmd_plan.sh` with P-60 and `tests/verbs/issue.sh`/`tests/integrate_test.sh` with P-62. Recommendation: P-62, then P-60, then P-64; or P-64 is the first plan built on the feature branch you plan to cut.
* [x] **Question 5 — A group's ID. → RESOLVED (developer, 2026-10-11): (a), the Plan ID; a marker heading distinguishes a group plan (§2.0).** (a) The normal `P-` numbering (`aapp.planId`). (b) Its own prefix, e.g. `G-`. Recommendation: (a); nothing new to allocate, and every verb already resolves it.
* [x] **Question 6 — Membership. → RESOLVED (developer, 2026-10-11): (a), members join when started.** (a) A member joins when it is started with `group <id>`. (b) The group lists planned members up front, while they are still drafts. Recommendation: (a); the list then only names plans that exist on the feature branch.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-11:** Group plan added (developer): the group's own blueprint, `start`/`done` cut and merge the feature branch, always into the parent branch; `group <id>` replaces `base <branch>` for members and fixes; status grouping. Q5, Q6 open.
* **2026-10-10:** Q1–Q4 resolved with the recommended answers (developer).
* **2026-10-09:** Drafted from RFC `worktree-contexts-monorepo-rfc.md` (option 1, fixes on the development branch, group-caused fixes on the feature branch).
