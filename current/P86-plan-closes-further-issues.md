# 🗺️ Plan P-86: Plan Closes Further Issues
* **Created:** 2026-10-13 | **Last Refined:** 2026-10-13
* **Target Issue / Milestone:** #122
* **Plan ID:** P-86
* **Changelog:** Added: a plan lists the further issues it sorts (`aapp refine <plan> closes <num>`); `done` closes them with the plan's commit (P-86)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `53a254f` (develop)
* **Worktree:** .workspace/P86 (plan/P86-plan-closes-further-issues)
* **Commits:** `6b572cf` (plan/P86-plan-closes-further-issues), `e99dc6e` (plan/P86-plan-closes-further-issues), `b7ff32c` (plan/P86-plan-closes-further-issues)
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
A plan names one issue, in `Target Issue`, and only when it is drafted from it. A plan whose work also sorts another issue, by design or by coincidence, has no way to say so: the other issue is closed by hand afterwards, with a commit and a summary someone has to look up.

This plan lets a plan list the further issues it sorts. At `done` each is archived with the commit the plan was recorded with and a link to the plan: one SHA per issue, traceable from the issue to the commit and to the plan.

It completes the tracing of issues to commits begun by P-84 (plans made for an issue) and P-85 (small fixes), and follows them.

---

## 2. Technical Blueprint
- **Saying so:** `aapp refine <plan> closes <num>` adds `#<num>` to the plan's header line `* **Also Closes:** #<n>, #<m>` (a list, in the order given), in one commit on the plans branch. The issue must be active and must not be the plan's own `Target Issue`; an issue already listed changes nothing. `aapp refine <plan> closes <num> remove` takes it off again; the line goes when the list is empty.
- **The issue's row is not touched.** The plan is not a plan for that issue: the row stays as it is, is not marked `Planned` and does not link the plan, and the issue can still be fixed or planned on its own. Whoever closes it first wins; the other finds it archived.
- **At `done`,** after the plan's own archive is settled, each listed issue that is still active is archived as the plan's `Target Issue` is: with **the commit the plan is recorded with** (its one squashed commit, or its last commit when it was not squashed) and the summary `[<plan>](<file>) - <title>`. Plans blocked on it resume under the usual rule, and the provider is told (`issue.close`), once per issue. All of it is in the plan's archive commit.
- **A listed issue is one the plans depend on.** Where a tracker keeps the record, the sync asks it for the issues the plans name (`_issue_dependent_ids`: `Blocked On`, `Target Issue`, open fixes); a listed issue joins them, so its row stays current until `done` closes it.
- **A plan is never squashed because of a listed issue.** Only a plan made for an issue is (P-84). Several issues may share one commit; an issue has exactly one.
- **What does not stop the `done`:** a listed issue that is already archived is skipped, with a line. A listed issue whose branch does not hold the plan's commit (P-78) is left open, with a line naming the branch: it is closed by hand once the commit is there.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Backwards Compatible`
- **Fallback Inventory**: `None`. A plan without the line behaves as today.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/done.closes.sh::test_refine_closes_lists_the_issue` -> asserts `refine <plan> closes <num>` writes `* **Also Closes:** #<num>` in one commit holding only the plan, and a second issue is appended to the same line
- [ ] `tests/verbs/done.closes.sh::test_refine_closes_refusals` -> asserts an unknown or archived issue and the plan's own `Target Issue` are refused with the plan unchanged, and an issue already listed commits nothing
- [ ] `tests/verbs/done.closes.sh::test_refine_closes_remove` -> asserts `refine <plan> closes <num> remove` takes the issue off the line, removes the line when it was the last, and refuses an issue that is not listed
- [ ] `tests/verbs/done.closes.sh::test_listed_row_is_untouched` -> asserts the listed issue's row keeps its status and link
- [ ] `tests/verbs/done.closes.sh::test_done_archives_listed_issues` -> asserts `done` archives each listed issue with the commit the plan is recorded with and a summary linking the plan, in the plan's archive commit
- [ ] `tests/verbs/done.closes.sh::test_done_unblocks_and_notifies` -> asserts a plan blocked on a listed issue resumes, and the provider gets one `issue.close` per listed issue with that commit
- [ ] `tests/verbs/done.closes.sh::test_already_archived_is_skipped` -> asserts a listed issue closed meanwhile is skipped with a line, and `done` completes
- [ ] `tests/verbs/done.closes.sh::test_issue_on_another_branch_stays_open` -> asserts a listed issue whose branch does not hold the plan's commit is left open with a line naming the branch, and `done` completes
- [ ] `tests/verbs/done.closes.sh::test_listed_issue_is_a_dependent` -> asserts the ids the sync asks the tracker for include a plan's listed issues
- [ ] `tests/verbs/done.closes.sh::test_plan_not_squashed_for_listed_issue` -> asserts under `ff` a plan with a listed issue reaches the parent with every commit and its SHA

### Phase 1: Tests First (red)
- [ ] Task 1.1: Write `tests/verbs/done.closes.sh`; confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: The `closes <num>` token of `refine` and the `Also Closes` header line.
- [ ] Task 2.2: `done` archives each listed issue with the plan's recorded commit; the two cases that are skipped.
- [ ] Task 2.3: `_issue_dependent_ids` includes the listed issues.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update `MANUAL.md`, `CHEATSHEET.md`, the `refine`, `done` and `issue` contracts, the plan template and the agent rules.
- [ ] Task 3.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` if new modules, commands, or interface contracts were introduced.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue; none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_plan.sh` -> `refine <plan> closes <num>`; `done` archives the listed issues.
- [ ] `lib/docs/verbs/refine.md` -> Contract: the `closes` token.
- [ ] `lib/docs/verbs/done.md` -> Contract: listed issues are closed with the plan's commit.
- [ ] `templates/plan-template.md` -> The `Also Closes` line, as a commented example in the header.
- [ ] `templates/AGENTS.md` -> Agent rules: say which further issues a plan sorts; never close them by hand afterwards.
- [ ] `MANUAL.md` -> A plan that sorts further issues.
- [ ] `lib/cmd_issue.sh` -> `_issue_dependent_ids` includes a plan's listed issues.
- [ ] `lib/docs/verbs/issue.md` -> Contract: the ids the sync asks for include listed issues.
- [ ] `ARCHITECTURE.md` -> A plan may close further issues with its recorded commit.
- [ ] `CHEATSHEET.md` -> `aapp refine <plan> closes <num> [remove]`.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `NEW FILE` -> `tests/verbs/done.closes.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/aapp-pre-commit` -> No hook rule changes.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — Taking an issue off the list? → RESOLVED (developer, 2026-10-13):** a form of its own, `aapp refine <plan> closes <num> remove`: header lines are written by verbs.

---

## 📦 6. Change Log & Refinement History
* **2026-10-15:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-13:** Plan locked and frozen into 🔷 Frozen via freeze.
*Tracks how the plan evolved across sessions.*
* **2026-10-13:** Drafted from #122. Follows P-84 and P-85.
