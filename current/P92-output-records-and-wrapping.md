# 🗺️ Plan P-92: Output Records And Wrapping
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Target Issue / Milestone:** none
* **Plan ID:** P-92
* **Changelog:** Changed: `aapp status` collects each section into records; every line of the briefing keeps to `aapp.statusOutputWidth` (P-92)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-91
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
<!-- * **Also Closes:** #<n>, #<m>  <- written by 'aapp refine <id> closes <num> [remove]': further issues this plan sorts; 'aapp done' closes them with the plan's commit -->

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
`lib/cmd_status.sh` prints each section as it computes it, so nothing it knows can be printed another way, and `aapp issue list` builds its line in `ledger_issue_lines` with the layout baked in. This member lays the foundation of group P-91 (§2.2): every section is collected into records, `lib/output.sh` provides width, wrapping and cutting, and a terminal renderer prints the records.

What a person sees changes only where a line is too wide: the frame, the Plans pillar, the notices, the offline block and the next action keep to `aapp.statusOutputWidth`. Shipped, Issues and Pickup print as today; P-88 and P-93 restyle them, P-94 adds JSON.

---

## 2. Technical Blueprint

### 2.1 `lib/output.sh` (new)
- `out_width` -> `aapp.statusOutputWidth`, default `85`; a value that is not a number of at least `40` is refused with a message naming the key.
- `out_wrap <first-indent> <hang-indent>` -> stdin wrapped: the first line indented by `<first-indent>` spaces, continuation lines by `<hang-indent>`, no line longer than `out_width`, broken at spaces. A word longer than the room left stands on its own line, uncut. Width is counted in characters: under a UTF-8 locale where available, otherwise by counting UTF-8 lead bytes, so `…`, emoji and accented letters count one each.
- `out_cut <limit>` -> stdin cut at the last space before `<limit>` characters, ending in `…`; shorter text is unchanged.
- Sourced by `lib/cmd_status.sh` and `lib/cmd_issue.sh`; the hooks never load it.

### 2.2 Records
Tab-separated lines, one per item, fields in the order of group P-91 §2.5; an absent value is an empty field; a list inside a field is comma-separated.

- `ledger_issue_records [<n>…]` (`lib/aapp-lib.sh`) -> `id`, `severity`, `type`, `status`, `logged`, `location`, `symptom`, `plan`, `blocks`, `queue_section`, `queue_level`, `queued`, `branch`, `offline`, `tracker_name`, `tracker_url`, `tracker_release`. One record per active issue (offline ones included, `offline` = `1`), in ledger order, or the ids given, in that order. `ledger_issue_lines` becomes a renderer over these records, printing what it prints today.
- In `lib/cmd_status.sh`, one function per section: `status_records_overview`, `_templates`, `_pause`, `_shipped`, `_issues`, `_plans`, `_pickup`, `_adoption`, `_offline`, `_next`; and `status_notices` -> `level`, `section`, `text` for every remark a section makes today (sync output, unblocking, matrix re-derived, gone branch, drift).
- `status_records_pickup` -> `title`, `text`, `files` per unworked entry, split as group P-91 §2.5 says (first `: ` outside backticks; the existing files under `.plans/pickup/` the text names). A named file that is missing gives a `warning` notice. The terminal still prints the entry as today until P-88.
- Records are collected once per run, before anything is printed; side effects (sync, unblock, matrix) run where they run today, and their output becomes notices.

### 2.3 The terminal renderer
- `status_render_terminal` prints the briefing from the records. For Shipped, Issues and Pickup it prints byte for byte what the briefing prints today (a test compares a fixture's briefing before and after).
- The frame lines, the Plans pillar lines, the notices, the offline block and the next action go through `out_wrap` (2 spaces, continuation under the text); the `=` frame is `out_width` characters wide.

### 2.4 Not in this member
- The layouts of Shipped and Pickup (P-88) and of the Issues lines (P-93); the JSON renderer (P-94).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/output_test.sh::test_wrap_hanging_indent` -> asserts a 300-character text wraps with the given first and hanging indents and no line exceeds the width
- [ ] `tests/output_test.sh::test_wrap_counts_characters` -> asserts a line of `…`, emoji and accented letters is measured in characters, not bytes
- [ ] `tests/output_test.sh::test_wrap_long_word_uncut` -> asserts a word longer than the width stands on its own line, whole
- [ ] `tests/output_test.sh::test_cut_at_word` -> asserts `out_cut 220` cuts at the last space before 220 characters and ends in `…`, and leaves shorter text unchanged
- [ ] `tests/output_test.sh::test_width_setting` -> asserts `aapp.statusOutputWidth` sets the width and a value below 40 or not a number is refused naming the key
- [ ] `tests/verbs/status.sh::test_briefing_unchanged_for_pillars` -> asserts Shipped, Issues and Pickup of a fixture's briefing are byte-identical to the briefing before this member
- [ ] `tests/verbs/status.sh::test_briefing_lines_within_width` -> asserts with a long plan worktree path, a long notice and a 60-column width no frame, plan, notice or next-action line exceeds 60 characters
- [ ] `tests/verbs/status.sh::test_pickup_records` -> asserts entries split into title and text at the first `: ` outside backticks, an entry without one has an empty title, `files` holds the named `.plans/pickup/` files that exist, and a missing one gives a warning notice
- [ ] `tests/issue_ledger_test.sh::test_issue_records_fields` -> asserts `ledger_issue_records` gives every field of P-91 §2.5 for a queued, a planned, a blocking, a branched and an offline issue
- [ ] `tests/verbs/issue.sh::test_list_unchanged` -> asserts `aapp issue list` prints what it printed before this member

### Phase 1: Foundation & Setup
- [ ] Task 1.1: Write the tests of this section; commit them red.

### Phase 2: Core Implementation
- [ ] Task 2.1: `lib/output.sh`: `out_width`, `out_wrap`, `out_cut`.
- [ ] Task 2.2: `lib/aapp-lib.sh`: `ledger_issue_records`; `ledger_issue_lines` renders them.
- [ ] Task 2.3: `lib/cmd_status.sh`: the section records and notices, collected before printing; `status_render_terminal`.
- [ ] Task 2.4: `lib/docs/verbs/status.md` and `lib/docs/verbs/issue.md`: `aapp.statusOutputWidth`, the width rule, the new tests.

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
- [ ] `NEW FILE` -> `lib/output.sh` -> width, wrapping, cutting.
- [ ] `lib/aapp-lib.sh` -> `ledger_issue_records`; `ledger_issue_lines` over them.
- [ ] `lib/cmd_status.sh` -> section records, notices, the terminal renderer.
- [ ] `lib/cmd_issue.sh` -> sources `lib/output.sh`.
- [ ] `lib/docs/verbs/status.md` -> the width rule and the new tests.
- [ ] `lib/docs/verbs/issue.md` -> the records and the new tests.
- [ ] `MANUAL.md` -> `aapp.statusOutputWidth`.
- [ ] `CHEATSHEET.md` -> the `aapp.statusOutputWidth` row.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `NEW FILE` -> `tests/output_test.sh`
- [ ] `tests/verbs/status.sh`
- [ ] `tests/issue_ledger_test.sh`
- [ ] `tests/verbs/issue.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `ARCHITECTURE.md` -> written from group P-91's sections at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> written from group P-91's sections at the group's `done`.
- [ ] `templates/skills/` -> the skills show the output as printed.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
*(None — design is fully specified; the group's open questions apply.)*

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-16:** Drafted as the first member of group P-91.
* **2026-10-16:** Pickup records: title, text, files.
