# 🗺️ Plan P-81: Verb Tests Named By Contracts
* **Created:** 2026-10-12 | **Last Refined:** 2026-10-12
* **Target Issue / Milestone:** none
* **Plan ID:** P-81
* **Changelog:** Changed: every verb test is named by its verb's contract; a test no contract names fails the suite (P-81)
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
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
`tests/verb_contracts_test.sh` checks that every test a verb contract names exists. It does not check the other direction. When a behaviour leaves a contract, its test can stay in the suite, keep passing and assert something nobody promises any more; nothing reports it. Eight verb tests are named by no contract today.

This plan makes the correspondence two-way for the verb suites: every named test in `tests/verbs/` is named by its verb's contract.

---

## 2. Technical Blueprint
- **The check.** For each `tests/verbs/<verb>.sh` and `tests/verbs/<verb>.<part>.sh`, every test name the suite reports (`ok "test_…"`) must appear in `lib/docs/verbs/<verb>.md` as `tests/verbs/<file>::<test_name>`. A test no contract names fails the check, with the file and the name.
- **The eight tests named by no contract** each get their line in the contract of their verb, under the behaviour they prove: two in `ai`, two in `commit`, two in `start`, one in `matrix`, one in `status`.
- **Scope.** The verb suites only. The suites in `tests/*_test.sh` report their assertions by description, not by test name, and are not covered.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verb_contracts_test.sh::test_every_verb_test_named_by_contract` -> asserts every test name reported by a verb suite or part is named in that verb's contract, and lists each one that is not

### Phase 1: Tests First (red)
- [ ] Task 1.1: Add the check to `tests/verb_contracts_test.sh`; confirm it fails on the eight tests.

### Phase 2: Core Implementation
- [ ] Task 2.1: Name the eight tests in their contracts; the check passes.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: No user-facing change; nothing to document outside the Codemap.
- [ ] Task 3.3: Update `.agents/CODEMAP.md` (`lib/docs/verbs/` section): the correspondence is two-way.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/docs/verbs/ai.md` -> Names `test_ai_notes_toggle`, `test_ai_status_reports_dual_policy`.
- [ ] `lib/docs/verbs/commit.md` -> Names `test_note_token_attached_in_none_mode`, `test_note_token_attached_in_strict_mode`.
- [ ] `lib/docs/verbs/start.md` -> Names `test_shared_code_file_still_blocks_start`, `test_shared_docs_do_not_block_start`.
- [ ] `lib/docs/verbs/matrix.md` -> Names `test_matrix_ignores_mini_plans`.
- [ ] `lib/docs/verbs/status.md` -> Names `test_members_listed_under_group`.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verb_contracts_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `tests/verbs/` -> No test is changed or removed here; only contracts gain lines.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-12:** Drafted.
