# 🗺️ Plan P-66: Issue Fix Changelog From The Fix
* **Created:** 2026-10-10 | **Last Refined:** 2026-10-10
* **Target Issue / Milestone:** #117
* **Plan ID:** P-66
* **Changelog:** Fixed: an issue fix's changelog entry describes the change; the issue log's fix cell holds links only
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

**Problem (#117).** `aapp issue fix` writes the mini plan's `Changelog:` from the issue row's *Target Plan / Fix* cell, or from the symptom when the cell is empty or holds `blocks [P-xx](…)` (`lib/cmd_issue.sh:927-932`). The first `aapp commit` writes it to `CHANGELOG.md`. The cell is written at logging time, before the fix is known, and `templates/issues.md:36` defines it as "Direction of fix": agents put notes there. #115 and #116 shipped notes as changelog lines; #108, #110 and #111 carry notes in that cell today. `aapp issue close` defaults its resolution to "Fixed via aapp issue fix: <files>", so the archive does not say what changed either.

**Goal.** The entry is written by the fixer after the change, in every session and project, enforced by the verbs: nothing at logging time can become a changelog line, a fix cannot commit without its own entry, and the archive row records the same text.

---

## 2. Technical Blueprint

### 2.1 The fix cell holds links only (ledger check)
A row's *Target Plan / Fix* cell is empty or holds only links written by verbs: `[P-xx](…)` (`aapp draft … issue`) and `blocks [P-xx](…)` (`aapp issue hotfix`). The ledger checks run by `aapp refine issues` and the pre-commit ledger check (`lib/planning_health.sh`) refuse any other text, naming the row. Depends on Q1.

### 2.2 `issue fix` opens with no entry
`_issue_write_mini` writes `* **Changelog:** Fixed:` with no text; the cell and the symptom are never copied.

### 2.3 The fixer supplies the entry at its first commit
`aapp commit` refuses a mini plan's first commit while its entry is empty, with the way to supply it (Q3). The 300-character limit and the bullet rules apply as for plans (#111 is covered: no copied text exists).

### 2.4 `close` records the same text
`aapp issue close` refuses while the mini plan's entry is empty (no fix commit). Without `summary`, the archive row's resolution is the changelog entry.

### 2.5 Agent text
`templates/issues.md` (column definitions), `templates/AGENTS.md` (issue logging and promotion), `templates/skills/aapp-fix/SKILL.md` (Step 2: the entry). Wording follows Q1/Q2.

### 2.6 Existing rows
The new check flags this repository's rows with notes in the cell (#108, #110, #111); they are emptied with `aapp refine issues` in this plan (Q1).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. Adopters' existing rows with notes in the cell are refused by the ledger check until emptied; the message names each row.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/refine.sh::test_issues_refuses_text_in_fix_cell` -> asserts `aapp refine issues` refuses a row whose fix cell holds text other than verb-written links, naming the row
- [ ] `tests/verbs/refine.sh::test_issues_accepts_plan_and_blocks_links` -> asserts an empty cell, `[P-xx](…)` and `blocks [P-xx](…)` pass
- [ ] `tests/verbs/issue.sh::test_fix_opens_with_empty_changelog` -> asserts the mini plan's `Changelog:` carries no text from the row
- [ ] `tests/verbs/commit.sh::test_mini_plan_commit_refuses_empty_changelog` -> asserts the first fix commit refuses without an entry and names how to supply it
- [ ] `tests/verbs/commit.sh::test_mini_plan_commit_writes_supplied_entry` -> asserts the supplied entry lands in `CHANGELOG.md`
- [ ] `tests/verbs/issue.sh::test_close_refuses_without_fix_entry` -> asserts `close` refuses while the entry is empty
- [ ] `tests/verbs/issue.sh::test_close_resolution_is_changelog_entry` -> asserts without `summary` the archive resolution equals the entry

### Phase 1: Tests First (red)
- [ ] Task 1.1: The Required Tests above.

### Phase 2: Implementation
- [ ] Task 2.1: Ledger check (2.1) in `lib/planning_health.sh`.
- [ ] Task 2.2: `issue fix` and `close` (2.2, 2.4) in `lib/cmd_issue.sh`.
- [ ] Task 2.3: First-commit refusal and entry (2.3) in `lib/cmd_commit.sh`.
- [ ] Task 2.4: Contracts `lib/docs/verbs/{issue,commit,refine}.md`; agent text (2.5).
- [ ] Task 2.5: Empty the fix cells of #108, #110, #111 (2.6).

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
- [ ] `lib/cmd_issue.sh` -> `issue fix` opens with an empty entry; `close` refuses without one and records it.
- [ ] `lib/cmd_commit.sh` -> A mini plan's first commit needs its entry.
- [ ] `lib/planning_health.sh` -> Fix cell holds links only.
- [ ] `lib/docs/verbs/issue.md` -> Contract.
- [ ] `lib/docs/verbs/commit.md` -> Contract.
- [ ] `lib/docs/verbs/refine.md` -> Contract (ledger check).
- [ ] `templates/issues.md` -> Column definition of the fix cell.
- [ ] `templates/AGENTS.md` -> Issue logging and fix rules.
- [ ] `templates/skills/aapp-fix/SKILL.md` -> Step 2: write the entry after the change.
- [ ] `MANUAL.md` -> Issue fix flow.
- [ ] `CHANGELOG.md` -> Entry written by `aapp commit`.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/refine.sh`
- [ ] `tests/verbs/issue.sh`
- [ ] `tests/verbs/commit.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_plan.sh` -> Plan changelog declarations are unchanged.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1 — The fix cell's role.** (a) Links only: the mini plan's entry is the one source of the changelog text. (b) The cell stays the entry, but may be written only at fix time and is copied when the fix commits. Recommendation: (a); one place to write it, nothing to drift.
* [ ] **Question 2 — Where a fix direction goes, if anywhere.** (a) Nowhere: the symptom is enough; a fix needing direction becomes a plan. (b) A new column. Recommendation: (a); the eight-column table stays as `AGENTS.md` defines it.
* [ ] **Question 3 — How the fixer supplies the entry.** (a) A `changelog "<text>"` token on the first `aapp commit` of a mini plan. (b) Edit the mini plan's `Changelog:` line, then commit it with a verb. Recommendation: (a); one command, written when the change is known.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-10:** Drafted from #117.
