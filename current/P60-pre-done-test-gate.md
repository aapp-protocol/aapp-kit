# 🗺️ Plan P-60: Pre Done Test Gate
* **Created:** 2026-10-08 | **Last Refined:** 2026-10-08
* **Target Issue / Milestone:** First release (reliability: a plan cannot close on red tests)
* **Plan ID:** P-60
* **Changelog:** Added: `pre-done` test gate sample: `aapp done` refuses while the project's test command fails
* **Commit Mode:** atomic
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🔷 Frozen
* **Base:** `948abe7` (develop)
* **Worktree:** ../agent-planning-kit-P60 (plan/P60-pre-done-test-gate)
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

**Problem.** `aapp done` archives a plan, and with P-55 integrates it, without knowing whether the project's tests pass. The TDD gate (P-35) checks ticked assertions and declared test files, not results. P-23 shipped and was archived while `tests/sync_test.sh` failed (#109). For a reliable project, "done" must mean "green".

**Mechanism already there.** P-23's `pre-done` gate runs before any mutation of `done` (and, since P-55, before integration): a non-zero exit aborts with nothing archived. What is missing is a ready, correct handler and the instructions to register it.

**Goal.** Ship a `pre-done` test-gate sample that runs the project's own test command where the plan's code lives (its worktree, P-54, or the checkout), refuses on red with a short failure summary, and is cheap to adopt; dogfood it in this repository. No new verb, event or core config key.

**Constraints.**
- Not `aapp test`: it runs kit suites only (#92); the gate runs the *project's* command.
- Not `aapp.testCommand`: per-clone git config can be changed by any agent and is slated for removal (#92). The command lives in the handler script, which the registry pins by SHA-256: changing what "green" means is a reviewed, committed change (layer 0 stays the deployment's, see pickup).
- Fail closed: a missing or unconfigured command refuses; it never passes silently.

---

## 2. Technical Blueprint

### 2.1 The sample: `examples/hooks/test-gate.sh.sample` (gate on `pre-done`)
- Header: purpose, registration (`aapp hook-hash .agents/hooks/test-gate.sh pre-done <timeout> gate`), exit codes.
- `TEST_CMD=""` at the top: the adopter sets the command (`npm test`, `pytest -q`, `cargo test`, `./aapp test strict quiet`, …). Empty → exit 1 with "set TEST_CMD in <path>".
- Reads the envelope from stdin; takes `plan_id` and `worktree` from `data`.
- Runs `TEST_CMD` in the plan's worktree when the payload names one (P-54), else in the repository root; captures output to a temp file.
- Pass → exit 0 with one line (`✅ tests green for P-xx`). Fail → exit 1, printing the command, its exit status and the last 20 lines of output.
- The gate runs on the working tree. `done` already refuses a dirty plan worktree (P-54); for a single checkout the sample refuses when tracked files are dirty, so the tested code is the committed code (Q2).

### 2.2 `pre-done` payload carries the worktree (`lib/cmd_plan.sh`)
`pre_done_data` gains `"worktree": "<abs path>"` when the plan records `* **Worktree:**` (empty string otherwise), so handlers need not parse plan headers. Additive; existing handlers unaffected.

### 2.3 Timeout
Test suites take minutes; the registry's per-handler timeout column carries it (the sample's header recommends a value; this repository uses 900 s). A watchdog timeout (124) is a refusal (P-23).

### 2.4 Dogfooding in this repository
Copy to `.agents/hooks/test-gate.sh` with `TEST_CMD='./aapp test strict quiet'`, register it in `.agents/skills/aapp-hooks/registry.tsv` (gate, 900 s). Sequenced after #109 is fixed, or `done` refuses every plan (Q3).

### 2.5 Agent text
`templates/skills/aapp-done/SKILL.md` failure branch: a test-gate refusal means fix the failing tests (or log an issue outside the plan's files and stop); never edit the handler, the registry or `TEST_CMD` to pass.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. Opt-in: nothing changes for a repository that does not register the handler.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/hooks_test.sh`: the sample registered on `pre-done` in a sandbox: a passing `TEST_CMD` lets `done` archive; a failing one refuses with the command, status and output tail, nothing archived; an empty `TEST_CMD` refuses with the instruction; a dirty tracked file in a single checkout refuses; a watchdog timeout refuses.
- [ ] Task 1.2: `tests/verbs/done.sh`: the `pre-done` payload carries `worktree` for a worktree plan (and the command runs there: the handler records its cwd), empty for a single checkout.

### Phase 2: Implementation
- [ ] Task 2.1: `examples/hooks/test-gate.sh.sample` (2.1).
- [ ] Task 2.2: `worktree` in `pre_done_data` (2.2); contract `lib/docs/verbs/done.md`.
- [ ] Task 2.3: `examples/hooks/registry.tsv.sample` gains the commented `pre-done` line.
- [ ] Task 2.4: Dogfood (2.4), after #109 (Q3).

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
- [ ] `NEW FILE` -> `examples/hooks/test-gate.sh.sample` -> The `pre-done` test gate sample.
- [ ] `examples/hooks/registry.tsv.sample` -> Commented `pre-done` registration line.
- [ ] `lib/cmd_plan.sh` -> `worktree` in the `pre-done` payload.
- [ ] `lib/docs/verbs/done.md` -> Payload field; the gate as the way to require green tests.
- [ ] `tests/hooks_test.sh` -> Sample behaviour (pass, fail, unset, dirty, timeout).
- [ ] `tests/verbs/done.sh` -> `worktree` in the payload.
- [ ] `templates/skills/aapp-done/SKILL.md` -> Test-gate refusal: fix, never weaken the gate.
- [ ] `NEW FILE` -> `.agents/hooks/test-gate.sh` -> This repository's gate (dogfood).
- [ ] `.agents/skills/aapp-hooks/registry.tsv` -> Register it (gate, 900 s).
- [ ] `MANUAL.md` -> Requiring green tests on `done`: registration, timeout, worktree behaviour.
- [ ] `CHEATSHEET.md` -> One line under hooks.
- [ ] `.agents/CODEMAP.md` -> The sample and payload field.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit` from the declaration.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_test.sh` -> `aapp test` stays kit-only; its `aapp.testCommand` delegation is #92.
- [ ] `lib/hook_dispatcher.sh` -> P-23's gate protocol is used as is.
- [ ] `docs/recipes/` -> The cookbook recipe and configuration profiles belong to P-56 (pickup note).

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — Where the test command lives. → RESOLVED (developer, 2026-10-08): (a), in the handler script, SHA-pinned (§2.1).** (a) In the handler script (`TEST_CMD=`), pinned by the registry's SHA-256: changing it is a reviewed commit. (b) A git config key: easier to change, but per clone and editable by any agent, and `aapp.testCommand` is slated for removal (#92). Recommendation: (a).
* [x] **Question 2 — Dirty working tree in a single checkout. → RESOLVED (developer, 2026-10-08): (a), refuse (§2.1).** (a) Refuse: the tests must run on the committed code. (b) Run anyway with a warning (uncommitted work may make red green or the reverse). Recommendation: (a); plan worktrees are already clean-checked by `done` (P-54).
* [x] **Question 3 — Dogfooding order. → RESOLVED (developer, 2026-10-08): (a), P-60 ships with the dogfood step, after #109 is fixed (§2.4, Task 2.4).** Registering the gate here makes every `done` run the full suite (about 5 minutes) and refuse while #109 is red. (a) Ship P-60 with the dogfood step, after #109 is fixed. (b) Ship the sample now, dogfood separately later. Recommendation: (a) — it is the point of the plan.

---

## 📦 6. Change Log & Refinement History
* **2026-10-09:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-08:** Q1–Q3 resolved with the recommended answers (developer): command in the SHA-pinned handler script; refuse a dirty single checkout; dogfood in this plan, after #109.
* **2026-10-08:** Drafted from the developer's request after the reliability review: P-23 closed with a red suite (#109); `done` should require green tests before the first release. Cookbook recipe and configuration profiles left to P-56 (pickup note).
