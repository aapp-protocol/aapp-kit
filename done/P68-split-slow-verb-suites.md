# 🗺️ Plan P-68: Split Slow Verb Suites
* **Created:** 2026-10-11 | **Last Refined:** 2026-10-11
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(if this plan was promoted from `ISSUES.md`, put the issue ID here and link this file back in that issue's `Proposed Fix / Target Plan` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-68
* **Changelog:** Changed: a verb suite may have parts (`tests/verbs/<verb>.<part>.sh`) that run in parallel; the slowest verb suites are split
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ✅ Done
* **Base:** `2fea533` (feature/faster-test-runs)
* **Worktree:** .workspace/P68 (plan/P68-split-slow-verb-suites)
* **Group:** P-71
* **Commits:** `2e03253` (plan/P68-split-slow-verb-suites), `663eac8` (plan/P68-split-slow-verb-suites), `bd799ca` (plan/P68-split-slow-verb-suites), `ce3e4d3` (plan/P68-split-slow-verb-suites), `fd7b8c2` (plan/P68-split-slow-verb-suites), `0c010df` (plan/P68-split-slow-verb-suites)
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

**Problem.** With parallel suites (P-67) the run lasts as long as the slowest suite. Measured: `verb/issue` 51 s, `verb/start` 51 s, `verb/done` 43 s, then `pre-commit` and `verb/commit` 22 s. Each test in these suites runs the real verb (about 2 s per call, mostly git commits). `start.sh` also spends ~7 s in one test by design: `test_worktree_session_runs_detached_with_placeholders` sets a session command starting with `sleep 6` and polls up to 14 s for its output.

**Goal.** Shorten the critical path without dropping a test: a verb suite can be split into parts that run in parallel, the slowest suites are split, and the fixed wait is replaced. Expected floor ~25–30 s (estimate, to be measured).

**Depends on P-67** (parallel runner; both change `lib/cmd_test.sh`, so this plan starts after it).

**Research (2026-10-11, measured on the P-67 runner).** Section times: `start` 50 s (P-54 worktrees 22 s incl. the 7 s session wait, P-64 groups 11 s, the rest 13 s); `issue` 41 s (P-58 fixes alongside plans 15.5 s, P-52 hotfix 8 s); `done` 28 s (P-39 recorded commits 11.5 s, worktree sections 13 s). Every split falls where a section starts its own sandbox (`init_sandbox_project`); `issue`'s P-54 section reuses P-58's sandbox, so they move together. Each part repeats the suite header (sources, `ok`/`bad`, helpers it uses): no shared state. Other fixed waits: `issue.sh`'s two `sleep 3` test the fix-wait roller (kept); `hooks_test.sh` (15 s) is off the critical path. Expected floor after the split: about 22 s, set by `pre-commit` and `commit`, which stay whole.

---

## 2. Technical Blueprint
### 2.1 Suite parts (`lib/cmd_test.sh`)
- `tests/verbs/<verb>.<part>.sh` belongs to `<verb>`. `aapp test verb <verb>` runs `<verb>.sh` and all its parts; `aapp test` schedules each part as its own suite.
- Labels: `verb/<verb>` and `verb/<verb>.<part>`; `aapp test list` shows parts under their verb.

### 2.2 Splits
- `tests/verbs/start.sh` keeps refusals … P-58 (~13 s); `start.worktree.sh` takes the P-54 worktree and base-branch sections (~15 s after 2.3); `start.group.sh` takes the P-64 group section (~11 s).
- `tests/verbs/issue.sh` keeps next … P-52 hotfix by scope (~21 s); `issue.fixes.sh` takes P-58, P-54 (same sandbox) and P-64 (~20 s).
- `tests/verbs/done.sh` keeps refusals … P-50 link repair (~17 s); `done.worktree.sh` takes P-54, #119 and P-60 (~11 s).
- Each part builds its own sandbox and carries the header and helpers it uses; no part depends on another's state. The total number of tests is unchanged.

### 2.3 The session test
The session command waits for a marker file the test creates after `aapp start` returns, then writes its output. `start` returning before the marker exists proves it does not wait; no fixed `sleep`.

### 2.4 Contracts
The `## Tests` lists in `lib/docs/verbs/{start,issue,done}.md` name the part file of each moved test; `lib/docs/verbs/test.md` describes parts.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [x] `tests/verbs/test.sh::test_verb_runs_all_its_parts` -> asserts `aapp test verb x` runs stub `x.sh` and `x.part.sh`, labelled `verb/x` and `verb/x.part`
- [x] `tests/verbs/test.sh::test_parts_listed_under_their_verb` -> asserts `aapp test list` shows `verb/x.part`
- [x] `tests/verb_contracts_test.sh::test_contract_tests_exist_in_suite_or_part` -> asserts every `## Tests` entry names a test present in the named file (verb suite or part)

### Phase 0: Research (refine time)
- [x] Task 0.1: Research in §1; finalise §2.2 split points, §4 part files, and the measured floor.

### Phase 1: Tests First (red)
- [x] Task 1.1: The Required Tests above.

### Phase 2: Implementation
- [x] Task 2.1: Suite parts in the runner (2.1).
- [x] Task 2.2: Session test without a fixed wait (2.3).
- [x] Task 2.3: Splits (2.2); every moved test passes in its part; the total test count is unchanged.
- [x] Task 2.4: Contracts (2.4).

### Phase 3: Verification & Documentation
- [x] Task 3.1: Run automated test suites and verify edge cases.
- [x] Task 3.2: Update user-facing documentation per `.agents/PROJECT.MD` (`MANUAL.md`, `README.md`, or `docs/`) if CLI verbs, configuration, or workflows were introduced or changed.
- [x] Task 3.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` if new modules, commands, or interface contracts were introduced.
- [x] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [x] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_test.sh` -> Suite parts.
- [ ] `tests/verbs/start.sh` -> Keeps refusals … P-58.
- [ ] `NEW FILE` -> `tests/verbs/start.worktree.sh` -> P-54 worktree and base-branch sections; session test without a fixed wait.
- [ ] `NEW FILE` -> `tests/verbs/start.group.sh` -> P-64 group section.
- [ ] `tests/verbs/issue.sh` -> Keeps next … P-52.
- [ ] `NEW FILE` -> `tests/verbs/issue.fixes.sh` -> P-58, P-54 and P-64 sections.
- [ ] `tests/verbs/done.sh` -> Keeps refusals … P-50.
- [ ] `NEW FILE` -> `tests/verbs/done.worktree.sh` -> P-54, #119 and P-60 sections.
- [ ] `lib/docs/verbs/start.md` -> Test list names the part files.
- [ ] `lib/docs/verbs/issue.md` -> Test list names the part files.
- [ ] `lib/docs/verbs/done.md` -> Test list names the part files.
- [ ] `lib/docs/verbs/test.md` -> Suite parts.
- [ ] `MANUAL.md` -> `aapp test`: parts.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit`.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/test.sh`
- [ ] `tests/verb_contracts_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_plan.sh` -> Verbs are unchanged; only their tests move.
- [ ] `lib/cmd_issue.sh` -> Verbs are unchanged; only their tests move.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Part naming. → RESOLVED (developer, 2026-10-11): (a) tests/verbs/<verb>.<part>.sh.** Flat structure in tests/verbs/, sorting naturally alongside its parent verb suite. Preserves simple single-glob suite discovery in the test runner and requires no directory nesting.
* [x] **Question 2 — Which suites to split. → RESOLVED (developer, 2026-10-11): (a) start, issue, done (over 40 s).** Splits the three slowest suites that bound the parallel critical path. Brings the execution ceiling down to ~20-25 s, matching the natural floor of monolithic suites (such as pre-commit at ~22 s) without diminishing returns.

---

## 📦 6. Change Log & Refinement History
* **2026-10-11:** Plan implementation completed and archived to done/.
* **2026-10-11:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-11:** Resolved Q1 (flat part naming '<verb>.<part>.sh') and Q2 (split 'start', 'issue', 'done' to reach ~20-25 s ceiling). Blueprint fully specified.
* **2026-10-11:** Drafted: suite parts, splits, session test; research at refine time.
