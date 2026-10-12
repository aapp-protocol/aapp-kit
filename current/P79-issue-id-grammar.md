# 🗺️ Plan P-79: Issue Id Grammar
* **Created:** 2026-10-12 | **Last Refined:** 2026-10-12
* **Target Issue / Milestone:** none
* **Plan ID:** P-79
* **Changelog:** Added: an issue id is defined once, and a tracker's key (`#PROJ-101`) is a valid id (P-79)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `29e3138` (feature/issue-tracker)
* **Worktree:** .workspace/P79 (plan/P79-issue-id-grammar)
* **Group:** P-72
* **Commits:** `5e2a281` (plan/P79-issue-id-grammar), `c827177` (plan/P79-issue-id-grammar), `65ab52a` (plan/P79-issue-id-grammar), `51a8a2a` (plan/P79-issue-id-grammar)
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
An issue id is assumed to be digits on about 90 lines in 12 files, each with its own pattern. A team on a shared tracker cannot use numbers the kit counts locally: every clone counts alone, so colleagues' numbers collide. With a tracker, the tracker's key has to be the issue's identity, and for Jira- or Linear-style trackers that key is not a number (`PROJ-101`).

This plan defines what an issue id is once, and then widens that one definition so a tracker's key is a valid id everywhere the kit uses one.

---

## 2. Technical Blueprint

### Phase A: one definition (no behaviour change)
An id section in `lib/aapp-lib.sh`, which verbs and hooks already load:

| Function | Does |
|---|---|
| `issue_id_valid <text>` | True for one well-formed id, with or without `#` |
| `issue_id_normalize <text>` | `46`, `#46` -> `#46`; refuses anything else with the accepted forms |
| `issue_id_refs <text>` | The ids named in a line (`Target Issue`, `Blocked On`, a commit subject, a road-map line). An id starts at a `#` that follows the start of the line or a character that is neither `#` nor a letter or digit, so a Markdown heading (`### PROJ-101`) and a hex token (`#A1B2C3`) are not ids |
| `issue_id_is_numeric <id>` | True for a kit-counted id (the counter looks at these only) |
| `issue_fix_name <id>` / `issue_fix_id <name>` | The mini plan's file name for an id (`fix-46.md`) and back |

Every caller uses these; no caller keeps an id pattern. `tests/issue_id_test.sh::test_no_id_pattern_outside` fails when code outside the section spells one out.

### Phase B: the tracker's key is an id
The definition accepts two forms after `#`:
- digits: `#46` (the kit's counter, or a tracker that numbers);
- a key, a dash, digits: `#PROJ-101` (capital letter, then capitals or digits, `-`, digits). A key typed or returned in lowercase is uppercased (`proj-101` -> `#PROJ-101`), by the CLI and for a plugin's answer alike; the stored form is always uppercase.

Consequences, each through the functions above:
- **Everywhere an id goes:** the ledger row, `Target Issue`, `Blocked On`, the road map, `aapp issue fix PROJ-101`, the mini plan `fix-PROJ-101.md`, its worktree `.workspace/fix-PROJ-101` and branch `fix/PROJ-101` (the key form is safe as a file name and a Git ref), the commit subject `(#PROJ-101)`, the bound-plan buffer.
- **The counter** (`aapp.issueId`) is seeded from, and moved past, numeric ids only.
- **Order:** numeric ids by number, then key ids by key and number.
- **A project without a tracker** never produces the second form and sees no change.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Backwards Compatible`
- **Fallback Inventory**: none. Every existing id stays valid; the definition only accepts one more form.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/issue_id_test.sh::test_normalize_numeric_forms` -> asserts `46` and `#46` normalize to `#46`
- [ ] `tests/issue_id_test.sh::test_refs_from_plan_lines` -> asserts `issue_id_refs` returns every id of a `Blocked On` line with several
- [ ] `tests/issue_id_test.sh::test_refs_ignore_headings_and_hex` -> asserts `### PROJ-101`, `#A1B2C3` and `x#12` yield no id, and `(#PROJ-101)` yields one
- [ ] `tests/issue_id_test.sh::test_no_id_pattern_outside` -> asserts no code outside the id section spells out an id pattern
- [ ] `tests/issue_id_test.sh::test_key_id_valid` -> asserts `PROJ-101`, `#PROJ-101` and `proj-101` all normalize to `#PROJ-101`
- [ ] `tests/issue_id_test.sh::test_malformed_id_refused` -> asserts `PROJ-`, `#-7`, `PROJ 101` and `101-PROJ` are refused, naming the accepted forms
- [ ] `tests/issue_id_test.sh::test_counter_ignores_key_ids` -> asserts seeding and advancing `aapp.issueId` look at numeric ids only
- [ ] `tests/verbs/issue.keyid.sh::test_fix_and_close_with_key_id` -> asserts `issue fix PROJ-101` opens `fix-PROJ-101.md`, a commit `(#PROJ-101)` passes the hooks, and `issue close PROJ-101` archives the row
- [ ] `tests/verbs/issue.keyid.sh::test_key_id_blocks_and_unblocks_plan` -> asserts a plan with `Blocked On: #PROJ-101` is blocked, and unblocked when it closes
- [ ] `tests/verbs/issue.keyid.sh::test_draft_promotes_key_id` -> asserts `draft <slug> issue PROJ-101` writes `Target Issue: #PROJ-101` and the plan's `done` closes it
- [ ] `tests/verbs/issue.keyid.sh::test_write_guard_binds_key_id_fix` -> asserts the write guard allows the files of `fix-PROJ-101.md` and refuses others

### Phase 1: Tests First (red)
- [ ] Task 1.1: Write `tests/issue_id_test.sh` and `tests/verbs/issue.keyid.sh`; confirm red.

### Phase 2: One Definition (Phase A)
- [ ] Task 2.1: The id section in `lib/aapp-lib.sh`, accepting digits only.
- [ ] Task 2.2: Move callers onto it one file per commit; the full suite stays green after each.
- [ ] Task 2.3: `test_no_id_pattern_outside` passes.

### Phase 3: Key Ids (Phase B)
- [ ] Task 3.1: Widen the definition; the counter and the ordering rules.
- [ ] Task 3.2: The key-id tests pass.

### Phase 4: Verification & Documentation
- [ ] Task 4.1: Run automated test suites and verify edge cases.
- [ ] Task 4.2: Update `MANUAL.md`, `templates/issues.md` and the verb contracts.
- [ ] Task 4.3: Architecture and Codemap sections live in group P-72.
- [ ] Task 4.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 4.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/aapp-lib.sh` -> The id section.
- [ ] `lib/cmd_issue.sh` -> Uses the id functions.
- [ ] `lib/cmd_plan.sh` -> Uses the id functions.
- [ ] `lib/plan_resolver.sh` -> Uses the id functions; counter looks at numeric ids.
- [ ] `lib/planning_health.sh` -> Uses the id functions.
- [ ] `lib/cmd_status.sh` -> Uses the id functions.
- [ ] `lib/cmd_init.sh` -> Uses the id functions.
- [ ] `lib/cmd_test.sh` -> Uses the id functions.
- [ ] `lib/cmd_matrix.sh` -> Uses the id functions.
- [ ] `lib/plan_states.sh` -> Uses the id functions.
- [ ] `templates/aapp-pre-commit` -> Uses the id functions.
- [ ] `templates/blast-radius-guard.sh` -> Uses the id functions.
- [ ] `templates/issues.md` -> The id column's definition.
- [ ] `lib/docs/verbs/issue.md` -> Contract.
- [ ] `MANUAL.md` -> Issue ids.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/issue_id_test.sh`
- [ ] `tests/verbs/issue.keyid.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/hook_dispatcher.sh` -> The plugin protocol is P-77's.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-12:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-12:** Drafted as a member of P-72.
