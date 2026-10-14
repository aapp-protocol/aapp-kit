# 🗺️ Plan P-85: One Commit Per Fix
* **Created:** 2026-10-13 | **Last Refined:** 2026-10-13
* **Target Issue / Milestone:** none
* **Plan ID:** P-85
* **Changelog:** Changed: every issue fix is made in its own worktree and lands as one commit, the SHA its archive row names (P-85)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `a245881` (develop)
* **Worktree:** .workspace/P85 (plan/P85-one-commit-per-fix)
* **Commits:** `85085a6` (plan/P85-one-commit-per-fix), `c78b5cc` (plan/P85-one-commit-per-fix), `21aec47` (plan/P85-one-commit-per-fix), `85946f7` (plan/P85-one-commit-per-fix), `53a254f` (plan/P85-one-commit-per-fix)
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
An issue is closed in one of two ways: by a plan made for it, or by a small fix (`aapp issue fix`). P-84 gives the first way one commit per issue: the plan has its own branch, is squashed there, and its one commit is what the archive names. A small fix does not have that yet. It is made on the issue's branch directly when the main checkout is on it, between whatever else lands there, and when it takes several commits the issue's row records only the last.

This plan makes small fixes follow the same rule, so there is one system for issues: every fix is made in its own worktree, lands as one commit, and that commit is the SHA in the archive. On a repository with one branch it may look more than is needed, but the history stays smooth and each issue is traceable to one commit.

It follows P-84 and group P-72.

---

## 2. Technical Blueprint
- **Every fix has its own worktree.** `aapp issue fix <n>` (and `fix next-blocker`) always opens `.workspace/fix-<n>` on `fix/<n>`, cut from the issue's branch (P-78, P-83). The form that worked in the main checkout when it was on the issue's branch goes: the main checkout is never bound to a fix, and its buffer and files are left alone.
- **One commit per fix.** At `aapp issue close <n>`, when the fix has more than one commit they are squashed into one on `fix/<n>`: subject `fix: <the fix's changelog entry> (#<n>)`, cut at a word boundary with `...` to fit `aapp.subjectMaxLen` (72 by default; a changelog entry may run to 300 characters); the full entry and the replaced subjects in the body; the attribution of the fix's last commit, its trailers and its git notes, as the squash at `done` carries them (P-84, #149). A fix with one commit is left exactly as it is: its SHA is already the one to record.
- **Attribution: the fix's last commit,** as in P-84: one set of trailers, from the agent that finished the fix.
- **Landing is unchanged** (P-78): `fix/<n>` is rebased onto the issue's branch when that branch moved, the branch is fast-forwarded to it, and the fix worktree and branch are removed. The archive row, and what the provider is told, name that one commit.
- **What is no longer needed at `fix`:** waiting for uncommitted work in the fix's files in the main checkout (P-58). The fix has its own working copy, so `fix` opens at once. The wait for another open fix, and the issue lock, stay: one fix at a time.
- **Where uncommitted work still matters:** at `close`, when the issue's branch is checked out somewhere with uncommitted changes in the fixed files, the fast-forward cannot be made there. `close` refuses, the fix stays as it is, and the message names the files; commit or set that work aside, then close again. A hotfix raised from a plan in a single checkout still sets that plan's work in the fixed files aside, and `close` still re-applies it on top of the fix.
- **Unchanged:** `fix <n> abort` (it removes the worktree and branch), `fix <n> file <path>`, `fix <n> group <group>`, the refusal inside a plan's worktree, the group hint.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. A fix open in the main checkout when this lands is closed, or dropped with `fix <n> abort`, by the code it was opened with.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [x] `tests/verbs/issue.onecommit.sh::test_fix_always_opens_in_its_worktree` -> asserts `issue fix` opens `.workspace/fix-<n>` cut from the issue's branch also when the main checkout is on that branch
- [x] `tests/verbs/issue.onecommit.sh::test_main_checkout_left_alone` -> asserts the main checkout's active buffer and files are unchanged by `fix`, by the fix's commits and by `fix abort`
- [x] `tests/verbs/issue.onecommit.sh::test_close_squashes_to_one_commit` -> asserts a fix of several commits lands on the issue's branch as one commit whose subject is `fix: <changelog entry> (#<n>)`, within `aapp.subjectMaxLen` when the entry is longer, with the full entry in the body
- [x] `tests/verbs/issue.onecommit.sh::test_single_commit_fix_keeps_its_sha` -> asserts a fix of one commit lands with the SHA it had
- [x] `tests/verbs/issue.onecommit.sh::test_row_and_provider_name_the_commit` -> asserts the archive row and `issue.close` name the commit that is on the issue's branch
- [x] `tests/verbs/issue.onecommit.sh::test_attribution_is_the_last_commit` -> asserts the squashed commit carries the trailers of the fix's last commit
- [x] `tests/verbs/issue.onecommit.sh::test_fix_does_not_wait_for_dirty_files` -> asserts `fix` opens at once while the main checkout has uncommitted changes in the fix's files
- [x] `tests/verbs/issue.onecommit.sh::test_close_refuses_over_uncommitted_work` -> asserts `close` refuses, naming the files, while the checkout of the issue's branch has uncommitted changes in the fixed files; the fix worktree, its commits and the issue are unchanged
- [x] `tests/verbs/issue.onecommit.sh::test_hotfix_stash_reapplied` -> asserts work a hotfix set aside in a single checkout is re-applied on top of the landed fix

### ♻️ Existing Tests Changed or Retired
> Tests that exist today and assert behaviour this plan changes. Each is rewritten or removed in the same commit as the change, with its contract line.
- Tests that open or expect a fix in the main checkout (`tests/verbs/issue.sh`, `issue.fixes.sh`, `issue.branch.sh`, `issue.branchplugin.sh`, `issue.keyid.sh`, `issue.abort.sh`, `issue.provider.sh`, `issue.notefilter.sh`, `commit.sh`): rewritten to work in `.workspace/fix-<n>`.
- `tests/verbs/issue.fixes.sh`: the tests of waiting for uncommitted files at `fix` (`test_fix_wait_zero_refuses_at_once`, `test_fix_waits_for_dirty_file_then_proceeds`, `test_next_blocker_waits_when_every_blocker_is_dirty`, `test_fix_timeout_on_bound_plan_file_hints_hotfix`) and `tests/verbs/issue.sh::test_fix_refuses_dirty_file`, `test_next_blocker_skips_untakeable`: retired with the wait; `test_close_refuses_over_uncommitted_work` covers what remains.
- `tests/verbs/issue.branch.sh::test_fix_opens_on_issue_branch`, `test_no_branch_means_dev_branch`: rewritten: the fix is always in its worktree.

### Phase 1: Tests First (red)
- [x] Task 1.1: Write `tests/verbs/issue.onecommit.sh`; confirm red.

### Phase 2: Core Implementation
- [x] Task 2.1: `issue fix` always in `.workspace/fix-<n>`; the main-checkout form and the wait for uncommitted files removed.
- [x] Task 2.2: The squash at `close`, with the changelog entry as subject and the last commit's trailers.
- [x] Task 2.3: `close` refuses over uncommitted work where the issue's branch is checked out.

### Phase 3: Verification & Documentation
- [x] Task 3.1: Run automated test suites and verify edge cases.
- [x] Task 3.2: Update `MANUAL.md`, the `issue` contract, the agent rules and the fix skill.
- [x] Task 3.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` if new modules, commands, or interface contracts were introduced.
- [x] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [x] Task 3.5: Log every finding outside the Target Files as an issue; none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_issue.sh` -> `fix` always in its worktree; the squash at `close`; the refusal over uncommitted work.
- [ ] `lib/docs/verbs/issue.md` -> Contract.
- [ ] `MANUAL.md` -> Small fixes: always in their own worktree, one commit per issue.
- [ ] `templates/AGENTS.md` -> Agent rules: a fix is worked in `.workspace/fix-<n>`.
- [ ] `templates/skills/aapp-fix/SKILL.md` -> The fixer works and commits in `.workspace/fix-<n>`, closes from the main checkout.
- [ ] `templates/skills/aapp-start/SKILL.md` -> Where issue fixes are made.
- [ ] `tests/verbs/issue.sh` -> Existing tests changed or retired (§3).
- [ ] `tests/verbs/issue.fixes.sh` -> Existing tests changed or retired (§3).
- [ ] `tests/verbs/issue.branch.sh` -> Existing tests changed (§3).
- [ ] `tests/verbs/issue.branchplugin.sh` -> Existing tests changed (§3).
- [ ] `tests/verbs/issue.keyid.sh` -> Existing tests changed (§3).
- [ ] `tests/verbs/issue.abort.sh` -> Existing tests changed (§3).
- [ ] `tests/verbs/issue.provider.sh` -> Existing tests changed (§3).
- [ ] `tests/verbs/issue.notefilter.sh` -> Existing tests changed (§3).
- [ ] `tests/verbs/commit.sh` -> Existing tests changed (§3).
- [ ] `ARCHITECTURE.md` -> One commit per fix: every fix in its own worktree, squashed at `close`.
- [ ] `CHEATSHEET.md` -> `aapp issue fix` in its worktree; `aapp.issueFixWait` waits for an open fix only.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `NEW FILE` -> `tests/verbs/issue.onecommit.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/aapp-pre-commit` -> No hook rule changes.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — Do small fixes follow the rule of P-84? → RESOLVED (developer, 2026-10-13):** yes, all the same: one unified system for issues. Even on a one-branch repository, where it looks odd, the history stays smooth and well traceable.
* [x] **Question 2 — The squashed fix's message. → RESOLVED (developer, 2026-10-14):** subject `fix: <the fix's changelog entry> (#<n>)`, the replaced commits' subjects in the body; a fix of one commit is left as it is. The subject keeps to the repository's short subject limit (`aapp.subjectMaxLen`), cut with `...`; the full entry goes in the body.

---

## 📦 6. Change Log & Refinement History
* **2026-10-15:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-14:** Plan activated into ⚡ In Development via start.
* **2026-10-14:** Plan locked and frozen into 🔷 Frozen via freeze.
*Tracks how the plan evolved across sessions.*
* **2026-10-13:** Drafted. Follows P-84 and group P-72.
