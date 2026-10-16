# 🗺️ Plan P-88: Status Recent And Bounded
* **Created:** 2026-10-13 | **Last Refined:** 2026-10-15
* **Target Issue / Milestone:** #147
* **Plan ID:** P-88
* **Changelog:** Changed: `aapp status` shows recently landed changelog entries and wrapped pickup ideas
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `9dc184e` (feature/readable-and-parsable-output)
* **Worktree:** .workspace/P88 (plan/P88-status-recent-and-bounded)
* **Group:** P-91
* **Commits:** `e754635` (plan/P88-status-recent-and-bounded), `28992d5` (plan/P88-status-recent-and-bounded)
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
`aapp status` is the briefing an agent shows unchanged at session start (`/aapp`, `/aapp-status`). Two of its four pillars do not show what their titles say.

- **Shipped (#147).** It prints the first five lines under `[Unreleased]` of `CHANGELOG.md`: the `### Added` heading and four entries. `Changed` and `Fixed` are never reached, and the order is the section's, not the order of landing. What landed today does not appear.
- **Pickup.** Each idea is printed whole on one line of up to 900 characters. Shown in a markdown code block, preformatted text cannot soft-wrap in Claude or standard terminals, forcing severe horizontal scrolling. Only five ideas are listed; the rest are "... and N more".

The pillars should give a clear, instantly readable idea of what is there without horizontal scrolling in narrow/split viewports; full details live where they belong (`CHANGELOG.md`, `.plans/pickup.md`).

---

## 2. Technical Blueprint
### 2.1 Shipped: the last entries that landed

The order of landing is in Git, not in the changelog's layout: every plan and fix adds its entry to `CHANGELOG.md` in a commit. The pillar reads the entries added by the latest commits of the current branch that touched the file, bounded by `-n 15` to ensure fast, O(1) execution:

```
git log -n 15 --first-parent -m -p --unified=0 -- <changelog>     # added lines starting "- "
```

- Newest first, up to `aapp.statusItemsMax` unique entries (default 5), from any section (`Added`, `Changed`, `Fixed`).
- An entry that is no longer in the file (reworded or removed later) is skipped; each entry is printed once.
- Each entry is cut with `out_cut` at `aapp.statusTextMax` (default 220) and wrapped with `out_wrap 2 4` (`  - ` and continuation under the text), within `aapp.statusOutputWidth` (group P-91 §2.3).
- The record (P-92) carries the entry's section, its text as written, the plan or issue it is tagged with, and the commit and date it landed with (empty from the fallback), for P-94's `shipped.entries`.
- Section headings (`### Added`, etc.) are not printed. A footer line names the file: `  (more in CHANGELOG.md)`, when the file holds more entries than shown.
- Fallback, when history gives nothing (no commits yet, shallow clone, changelog outside Git): the first five entries under `[Unreleased]` without section headings.
- `.plans/CHANGELOG.md` is read from the plans worktree's history when that is where the changelog is.

### 2.2 Pickup: bounded ideas with hanging indent and cap

- Up to `aapp.statusItemsMax` ideas (default 5), followed by `  ... and N more (see .plans/pickup.md)`.
- Each idea from its record (P-92: `title`, `text`, `files`), laid out as group P-91 §2.3 says: `  - [ ] <title>`, then the text cut with `out_cut` at `aapp.statusTextMax` (default 220) and wrapped with `out_wrap 8 8`, then `        files: <path>` per file; all within `aapp.statusOutputWidth`. An idea with no title starts its text on the `- [ ] ` line, wrapped at 8 spaces. A title wider than the line wraps with `out_wrap 2 8`.
- Full unworked text remains in `.plans/pickup.md`; `/aapp-digest <idea>` reads it there.

### 2.3 Formatting helpers

The helpers are group P-91's, in `lib/output.sh` (P-92): `out_cut`, `out_wrap`, `out_width`. This plan adds none of its own.

### 2.4 Not in this plan

- The Issues pillar (P-93) and the Plans pillar (P-92).
- `aapp status short`.
- The JSON output (P-94).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [x] `tests/verbs/status.sh::test_shipped_shows_latest_landed` -> asserts an entry committed last under `### Fixed`, below thirty `Added` entries, is the first line of the Shipped pillar
- [x] `tests/verbs/status.sh::test_shipped_newest_first_across_sections` -> asserts three entries committed in turn to `Added`, `Fixed`, `Changed` print in reverse order of their commits
- [x] `tests/verbs/status.sh::test_shipped_skips_removed_entry` -> asserts an entry later removed from the file is not printed, and a reworded one prints once, in its current wording
- [x] `tests/verbs/status.sh::test_shipped_fallback_without_history` -> asserts an uncommitted `CHANGELOG.md` prints its first entries under `[Unreleased]`, without a heading line
- [x] `tests/verbs/status.sh::test_shipped_points_to_changelog` -> asserts more than five entries end the pillar with a line naming `CHANGELOG.md`
- [x] `tests/verbs/status.sh::test_shipped_entry_wrapped` -> asserts a 300-character changelog entry is cut at `aapp.statusTextMax` with `…` and wrapped under its text, no line over `aapp.statusOutputWidth`
- [x] `tests/verbs/status.sh::test_shipped_record_fields` -> asserts the Shipped records carry section, text, plan or issue, commit and date, and empty commit and date from the fallback
- [x] `tests/verbs/status.sh::test_pickup_capped_with_more` -> asserts pickup queue keeps a cap of 5 ideas and prints `... and N more`
- [x] `tests/verbs/status.sh::test_pickup_bounded_and_wrapped` -> asserts a 900-character idea shows its title on the `- [ ] ` line and its text bounded to <= 220 chars, wrapped at 8 spaces under 85 columns
- [x] `tests/verbs/status.sh::test_pickup_long_title_wraps` -> asserts with `aapp.pickupTitleMax` 150 a 140-character title wraps at 8 spaces, no line over `aapp.statusOutputWidth`
- [x] `tests/verbs/status.sh::test_pickup_files_line` -> asserts an idea naming an existing `.plans/pickup/` file ends with a `files: <path>` line, and an idea without a title starts its text on the `- [ ] ` line
- [x] `tests/verbs/status.sh::test_status_limit_settings` -> asserts `aapp.statusItemsMax` and `aapp.statusTextMax` change the caps of Shipped and Pickup, and a value that is not a positive number is refused naming the key

### Phase 1: Foundation & Setup
- [x] Task 1.1: Write the tests of this section in `tests/verbs/status.sh`; commit them red.

### Phase 2: Core Implementation
- [x] Task 2.1: `lib/cmd_status.sh`: the Shipped records from a bounded `git log -n 15`, with their fallback; rendered through `out_cut` and `out_wrap`.
- [x] Task 2.2: `lib/cmd_status.sh`: the Pickup pillar through `out_cut` and `out_wrap`, capped at `aapp.statusItemsMax` with `... and N more`.
- [x] Task 2.3: `lib/docs/verbs/status.md`: document the two pillars, `aapp.statusTextMax`, `aapp.statusItemsMax`, and contracts.

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
- [ ] `lib/cmd_status.sh` -> the Shipped records and the Shipped and Pickup pillars.
- [ ] `lib/docs/verbs/status.md` -> the contract of the two pillars and the new tests.
- [ ] `tests/verbs/status.sh` -> the tests of §3.
- [ ] `MANUAL.md` -> the briefing's pillars; `aapp.statusTextMax`, `aapp.statusItemsMax`.
- [ ] `CHEATSHEET.md` -> `aapp.statusTextMax`, `aapp.statusItemsMax`.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/status.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/skills/` -> the skills show the output as printed; they do not change.
- [ ] `lib/output.sh` -> group P-91's helpers, written by P-92.
- [ ] `ARCHITECTURE.md` -> written from group P-91's sections at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> written from group P-91's sections at the group's `done`.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-16:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-13:** Plan initialized from `pickup.md`.
* **2026-10-13:** Refined blast radius and locked module boundaries.
* **2026-10-15:** Refined blueprint: bounded git log history (-n 15) for Shipped; bounded Pickup to 220 chars with 8-space hanging indent line wrapping and 5-idea cap; resolved open questions.
* **2026-10-16:** Member of group P-91: the group's settings (`aapp.statusOutputWidth`, `aapp.statusTextMax`, `aapp.statusItemsMax`) and `lib/output.sh` helpers; Shipped wraps like Pickup; Shipped records carry commit and date.
* **2026-10-16:** Pickup ideas: title line, wrapped text, `files:` lines.
* **2026-10-16:** A long title wraps at 8 spaces.
* **2026-10-16:** Implementation: the readers `status_items_max` and `status_text_max` are in `lib/cmd_status.sh` (`lib/output.sh` is out of bounds); a value below 1 is refused naming the key. `more` counts the entries under `## [Unreleased]` not shown. P-92's `test_briefing_unchanged_for_pillars` now compares the Issues pillar only. CODEMAP in group P-91.

