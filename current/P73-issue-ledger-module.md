# 🗺️ Plan P-73: Issue Ledger Module
* **Created:** 2026-10-11 | **Last Refined:** 2026-10-11
* **Target Issue / Milestone:** none
* **Plan ID:** P-73
* **Changelog:** Changed: every issue ledger read and write goes through `lib/issue_ledger.sh` (P-73)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-72
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
The three issue ledgers (`ISSUES.md`, `done/000-issues-archive.md`, `issues_road_map.md`) are named on about 130 lines in 9 files (`lib/cmd_issue.sh`, `lib/cmd_plan.sh`, `lib/cmd_status.sh`, `lib/planning_health.sh`, `lib/cmd_init.sh`, `lib/cmd_matrix.sh`, `lib/plan_resolver.sh`, `templates/aapp-pre-commit`, `templates/blast-radius-guard.sh`), and each reader carries its own awk/grep/sed over the table. A change to the row format means finding every copy; they already diverge (`lib/cmd_status.sh` looks for `.plans/ISSUES.md` before `ISSUES.md`, `templates/aapp-pre-commit` the other way round).

This plan moves all of it into one module that every caller reuses. Behaviour does not change. P-74 (remote cache) and P-75 (`.offline` ledgers) then add sources behind the same functions, so callers never learn where an issue came from. The readers are built for that: rows carry a source field (`local` for now).

---

## 2. Technical Blueprint
**Module:** `lib/issue_ledger.sh`. The function set below is provisional; the refine-time research fixes it.

| Function | Does |
|---|---|
| `ledger_path issues\|archive\|roadmap` | Resolves the file once (one lookup order for every caller) |
| `ledger_rows [<status>]` | Active rows as tab-separated cells (id, sev, type, date, location, symptom, link, status); escaped pipes handled once |
| `ledger_row <n>` / `ledger_locate <n>` | One row; `active`, `archive` or nothing |
| `ledger_add_row <cells…>` | Appends an active row |
| `ledger_set_cell <n> link\|status <value>` | Lifecycle cells only; observation cells never change |
| `ledger_archive_row <n> <sha> <summary>` | Moves a row to the archive and prunes the road map |
| `ledger_relink <old> <new>` | Rewrites plan links in the ledger and the road map |
| `roadmap_*` | Road-map entries: add, prune, list |

The health checks (fix cells, Pair 1/Pair 8 duplicates, resolved rows in the active ledger) read rows through `ledger_rows`. The hooks reach the module the way they reach `aapp-lib.sh`: `aapp init` copies it into `.githooks/`.

**A guard against new copies:** `tests/issue_ledger_test.sh::test_no_direct_ledger_access` fails when a file outside the module reads or writes a ledger. Path names in permission lists (write guard, pre-commit allow-lists) are path patterns, not access, and are listed in the test.

**Research at refine time:** classify every reference (read, write, path only), map each to a function, and record each divergence with the behaviour kept.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/issue_ledger_test.sh::test_rows_keep_escaped_pipes` -> asserts a row with `\|` in a cell yields its eight cells unchanged
- [ ] `tests/issue_ledger_test.sh::test_locate_active_archive_unknown` -> asserts `ledger_locate` prints `active`, `archive`, or nothing
- [ ] `tests/issue_ledger_test.sh::test_set_cell_changes_lifecycle_only` -> asserts `ledger_set_cell` changes only the link or status cell and refuses any other
- [ ] `tests/issue_ledger_test.sh::test_archive_row_moves_and_prunes` -> asserts the row leaves `ISSUES.md`, lands in the archive, and its road-map entry is gone
- [ ] `tests/issue_ledger_test.sh::test_relink_ledger_and_roadmap` -> asserts a plan link is rewritten in both files
- [ ] `tests/issue_ledger_test.sh::test_no_direct_ledger_access` -> asserts no file outside `lib/issue_ledger.sh` reads or writes a ledger

### Phase 1: Tests First (red)
- [ ] Task 1.1: Write `tests/issue_ledger_test.sh`; confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: Write `lib/issue_ledger.sh`; the module tests pass.
- [ ] Task 2.2: Move callers onto it one file per commit (`cmd_issue`, `cmd_plan`, `cmd_status`, `planning_health`, `cmd_matrix`, `plan_resolver`, `cmd_init`, the hooks); the full suite stays green after each.
- [ ] Task 2.3: `test_no_direct_ledger_access` passes.

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
- [ ] `NEW FILE` -> `lib/issue_ledger.sh` -> The ledger module.
- [ ] `lib/cmd_issue.sh` -> Calls the module.
- [ ] `lib/cmd_plan.sh` -> Calls the module.
- [ ] `lib/cmd_status.sh` -> Calls the module.
- [ ] `lib/planning_health.sh` -> Health checks read rows through the module.
- [ ] `lib/cmd_matrix.sh` -> Calls the module.
- [ ] `lib/plan_resolver.sh` -> Issue-id seeding reads through the module.
- [ ] `lib/cmd_init.sh` -> Seeds the ledgers through the module; ships it to the hooks.
- [ ] `templates/aapp-pre-commit` -> Ledger checks call the module.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/issue_ledger_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Names ledger paths in its allow-list only; no access to move.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — How do the hooks reach the module? → RESOLVED (developer, 2026-10-11):** a separate `lib/issue_ledger.sh`, which `aapp init` copies into `.githooks/` next to `aapp-lib.sh`.
* [x] **Question 2 — One lookup order for the ledger? → RESOLVED (developer, 2026-10-11):** the kit supports both places (`.plans/` or the repo root, the adopter's preference); the two do not normally coexist, so the order is not significant. `ledger_path` looks in `.plans/` first, and the pre-commit hook follows by calling it.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-11:** Drafted as a member of P-72.
