# 🗺️ Plan P-67: Parallel Test Suites
* **Created:** 2026-10-11 | **Last Refined:** 2026-10-11
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(if this plan was promoted from `ISSUES.md`, put the issue ID here and link this file back in that issue's `Proposed Fix / Target Plan` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-67
* **Changelog:** Changed: `aapp test` runs suites in parallel (`jobs <n>`; `jobs 1` runs them one at a time)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `150cc2b` (feature/faster-test-runs)
* **Worktree:** .workspace/P67 (plan/P67-parallel-test-suites)
* **Group:** P-71
* **Commits:** `d84c786` (plan/P67-parallel-test-suites), `3736e8d` (plan/P67-parallel-test-suites), `2fea533` (plan/P67-parallel-test-suites)
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

**Problem.** `aapp test` runs its 32 suites one after another: about 6 minutes (2m user, 4m sys, 6m real; the suites mostly wait on `git` and process start-up). The `pre-done` test gate (P-60) runs it on every `done`, and agents run it during their work: three plans cost 18 minutes in gates alone.

**Measured.** All 32 suites run concurrently with `xargs -P 8`: green in 65 s; `-P 12`: green in 59 s. The longest suite (`verb/start`, ~60 s) bounds the wall time. Suites already run in their own sandboxes (`confine_test_runtime` or their own `mktemp -d`); no suite needs to run alone today.

**Goal.** `aapp test` runs suites in parallel by default, with the same selection, output, summary and exit contract. The gate is unchanged; it gets faster with it. Scoped or partial runs are not part of this plan (pickup: Test Time & Kit Modularity).

---

## 2. Technical Blueprint

### 2.1 Scheduling (`lib/cmd_test.sh`)
- Up to N suites run at once, each as today (`bash <suite>` from the repository root, `AAPP_TEST_SANDBOX_STRICT` passed through). A suite's exit status comes from `wait <pid>`.
- N: the `jobs <n>` token (bare token, positive integer). Default: the CPU count (`getconf _NPROCESSORS_ONLN`) rounded down to a multiple of 4 (10 → 8, 12 → 12); below 4 CPUs, the CPU count. An unreadable count runs serially with a notice. `jobs 1` is today's serial run.
- `bail`: after the first failing suite no new suite starts; running ones finish; exit 1.

### 2.2 Output
- Each suite writes to its own temporary file (a background suite cannot write into the runner's variables). When it finishes, the runner reads the file into a variable and flushes it in one write: default mode the whole output, `quiet` its row. Output is never interleaved. One `trap` on `EXIT INT TERM` stops any suite still running, then removes the files; an interrupted run exits non-zero.
- The summary lists rows in the selection order, with the same counts, durations and exit rules as today. The banner names the job count.

### 2.3 Contract
`lib/docs/verbs/test.md`: `jobs <n>` in Ingress; Effects: suites run concurrently, output per suite, summary in selection order; tests listed.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: one: an unreadable CPU count runs serially (`jobs 1`) with a notice; serial is today's behaviour and always correct. A suite that cannot share the machine is a bug in that suite.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/test.sh::test_suites_run_concurrently` -> asserts four stub suites sleeping 2 s each finish under 5 s with `jobs 4`
- [ ] `tests/verbs/test.sh::test_jobs_one_runs_serially` -> asserts three stub suites sleeping 1 s each take at least 3 s with `jobs 1`
- [ ] `tests/verbs/test.sh::test_parallel_failure_fails_the_run` -> asserts one failing stub among passing ones: exit 1 and its `FAILED (exit 1)` row
- [ ] `tests/verbs/test.sh::test_suite_output_not_interleaved` -> asserts each stub's lines appear contiguous in default output
- [ ] `tests/verbs/test.sh::test_summary_in_selection_order` -> asserts summary rows follow the selection order, not finish order
- [ ] `tests/verbs/test.sh::test_interrupt_cleans_up` -> asserts a run sent TERM while stubs sleep exits non-zero, leaves no temporary files in its `TMPDIR` and no stub process running
- [ ] `tests/verbs/test.sh::test_default_jobs_multiple_of_four` -> asserts with a stubbed `getconf` the banner reports 8 jobs for 10 CPUs, 12 for 12, 2 for 2, and 1 with a notice when the count is unreadable
- [ ] `tests/verbs/test.sh::test_jobs_refuses_non_number` -> asserts `jobs 0` and `jobs x` exit 1 with usage

### Phase 1: Tests First (red)
- [ ] Task 1.1: The Required Tests above.

### Phase 2: Implementation
- [ ] Task 2.1: Scheduling and `jobs` (2.1).
- [ ] Task 2.2: Output and summary (2.2).
- [ ] Task 2.3: Contract (2.3); `aapp test help` text.

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
- [ ] `lib/cmd_test.sh` -> Parallel scheduling, `jobs`, per-suite output.
- [ ] `lib/docs/verbs/test.md` -> Contract.
- [ ] `MANUAL.md` -> `aapp test` section: `jobs`.
- [ ] `CHEATSHEET.md` -> `jobs <n>`.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit`.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `tests/*_test.sh` -> Suites are unchanged; none needs to run alone today.
- [ ] `.agents/hooks/test-gate.sh` -> The gate stays as it is.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — Default job count. → RESOLVED (developer, 2026-10-11): the CPU count rounded down to a multiple of 4 (10 → 8, 12 → 12); below 4 CPUs, the CPU count (§2.1).** (a) The number of CPUs, capped at 8 (measured: 8 → 65 s, 12 → 59 s). (b) A fixed 4, predictable on any machine. (c) The number of CPUs, uncapped. Recommendation: (a).
* [x] **Question 2 — A config key for the default. → RESOLVED (developer, 2026-10-11): (a), no key; the default is worked out from the CPU count.** (a) None: the `jobs` token only. (b) `aapp.testJobs`. Recommendation: (a); one more key is one more thing to keep in sync (#99).

---

## 📦 6. Change Log & Refinement History
* **2026-10-11:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-11:** Drafted: parallel suites; gate unchanged.
