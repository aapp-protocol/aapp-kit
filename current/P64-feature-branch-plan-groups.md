# 🗺️ Plan P-64: Feature Branch Plan Groups
* **Created:** 2026-10-09 | **Last Refined:** 2026-10-09
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(if this plan was promoted from `ISSUES.md`, put the issue ID here and link this file back in that issue's `Proposed Fix / Target Plan` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-64
* **Changelog:** Added: plan groups on a feature branch (`start … base <branch>`); issue fixes on the development branch, group-caused fixes on the feature branch
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

---

## 2. Technical Blueprint

### 2.1 A group's base on its plans (`lib/cmd_plan.sh`)
`aapp start <id> base <branch>` / `aapp freeze-start <id> base <branch>`: the plan worktree branches from `<branch>` and records `Base: <sha> (<branch>)`; P-55 then integrates the plan into it. Needs a plan worktree; `<branch>` must exist. `aapp.devBranch` is never changed for this.

### 2.2 Fixes on the development branch (`lib/cmd_issue.sh`)
`aapp issue fix` without `base` refuses unless the main checkout is on the development branch (`aapp_dev_branch`; the default branch when none resolves).

### 2.3 Group-caused fixes on the feature branch (`lib/cmd_issue.sh`)
`aapp issue fix <num> base <branch>`: the mini plan opens in its own worktree `.workspace/fix-<num>` on `fix/<num>` from `<branch>`; `aapp issue close <num>` integrates it into `<branch>` and removes the worktree and branch. The issue row and archive are unchanged.
When the issue's files differ between the development branch and a feature branch with plans in `current/`, `fix` without `base` prints a hint naming `base <branch>`. The human decides.

### 2.4 Agent text
`templates/AGENTS.md`, `.agents/AGENTS.md`, skills `aapp-start` and `aapp-fix`: plan files and plan commands under `.workspace/<id>/`; fix files and fix commands in the project root, or in `.workspace/fix-<num>/` with `base`. The scope rule: caused by the group's work → `base <feature-branch>`; unrelated → the development branch.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/start.sh::test_start_base_branch_records_and_branches` -> asserts the worktree branches from `<branch>` and `Base:` names it
- [ ] `tests/verbs/start.sh::test_start_base_refuses_missing_branch` -> asserts an unknown `<branch>` refuses with nothing created
- [ ] `tests/integrate_test.sh::test_group_plan_integrates_into_feature_branch` -> asserts `done` squashes into the feature branch, not the development branch
- [ ] `tests/verbs/issue.sh::test_fix_refuses_off_development_branch` -> asserts `fix` refuses when the main checkout is on another branch
- [ ] `tests/verbs/issue.sh::test_fix_base_opens_worktree_and_close_integrates` -> asserts `fix base <branch>` works in `.workspace/fix-<num>` and `close` lands the fix on `<branch>` only
- [ ] `tests/verbs/issue.sh::test_fix_hints_base_for_group_files` -> asserts the hint names `base <branch>` when the issue's files differ on a feature branch

### Phase 1: Tests First (red)
- [ ] Task 1.1: The assertions above.

### Phase 2: Implementation
- [ ] Task 2.1: `base` token (2.1); contracts `start.md`, `freeze-start.md`.
- [ ] Task 2.2: Development-branch check (2.2); `fix base` worktree and close integration (2.3); hint; contract `issue.md`.
- [ ] Task 2.3: Agent text (2.4).

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
- [ ] `lib/cmd_plan.sh` -> `base <branch>` on start and freeze-start.
- [ ] `lib/cmd_issue.sh` -> Development-branch check; `fix base` worktree, close integration, hint.
- [ ] `lib/docs/verbs/start.md` -> `base` token.
- [ ] `lib/docs/verbs/freeze-start.md` -> `base` token.
- [ ] `lib/docs/verbs/issue.md` -> Branch check, `base`, hint.
- [ ] `tests/verbs/start.sh` -> `base` tests.
- [ ] `tests/verbs/issue.sh` -> Fix branch tests.
- [ ] `tests/integrate_test.sh` -> Group plan integration.
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
- `tests/verbs/start.sh`
- `tests/verbs/issue.sh`
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
* [x] **Question 3 — Grouping in `aapp status`. → RESOLVED (developer, 2026-10-10): later.** List plans under their shared base branch now, or later? Recommendation: later; the base already shows in each plan's header.
* [x] **Question 4 — Order with P-60 and P-62. → RESOLVED (developer, 2026-10-10): P-62, then P-60, then P-64.** P-64 shares `lib/cmd_plan.sh` with P-60 and `tests/verbs/issue.sh`/`tests/integrate_test.sh` with P-62. Recommendation: P-62, then P-60, then P-64; or P-64 is the first plan built on the feature branch you plan to cut.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-10:** Q1–Q4 resolved with the recommended answers (developer).
* **2026-10-09:** Drafted from RFC `worktree-contexts-monorepo-rfc.md` (option 1, fixes on the development branch, group-caused fixes on the feature branch).
