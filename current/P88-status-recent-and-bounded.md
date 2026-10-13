# 🗺️ Plan P-88: Status Recent And Bounded
* **Created:** 2026-10-13 | **Last Refined:** 2026-10-13
* **Target Issue / Milestone:** #147
* **Plan ID:** P-88
* **Changelog:** Changed: `aapp status` shows what landed last, and one bounded line per pickup idea
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
`aapp status` is the briefing an agent shows unchanged at session start (`/aapp`, `/aapp-status`). Two of its four pillars do not show what their titles say.

- **Shipped (#147).** It prints the first five lines under `[Unreleased]` of `CHANGELOG.md`: the `### Added` heading and four entries. `Changed` and `Fixed` are never reached, and the order is the section's, not the order of landing. What landed today does not appear.
- **Pickup.** Each idea is printed whole, on one line of up to 900 characters. Shown in a code block it cannot wrap, so the briefing scrolls far sideways. Only five ideas are listed; the rest are "... and N more".

The pillars should give an idea of what is there; the detail is read where it lives (`CHANGELOG.md`, `.plans/pickup.md`).

---

## 2. Technical Blueprint
### 2.1 Shipped: the last entries that landed

The order of landing is in Git, not in the changelog's layout: every plan and fix adds its entry to `CHANGELOG.md` in a commit. The pillar reads the entries added by the latest commits of the current branch that touched the file:

```
git log --first-parent -m -p --unified=0 -- <changelog>     # added lines starting "- "
```

- Newest first, five entries, from any section (`Added`, `Changed`, `Fixed`).
- An entry that is no longer in the file (reworded or removed later) is skipped; an entry is printed once.
- Each entry is one bounded line (2.3).
- The section headings are not printed. A last line names the file: `(more in CHANGELOG.md)`, when the file holds more entries than shown.
- Fallback, when the history gives nothing (no commits yet, a shallow clone, a changelog outside Git): the first five entries under `[Unreleased]`, as today, without the heading.
- `.plans/CHANGELOG.md` is read from the plans worktree's history when that is where the changelog is.

### 2.2 Pickup: every idea, one line each

- Every unworked idea is listed; the cap of five and "... and N more" go.
- Each idea is one bounded line (2.3). The full text stays in `.plans/pickup.md`; `/aapp-digest <idea>` reads it there.

### 2.3 One bounded line (`status_line_cut`)

One function in `lib/cmd_status.sh`, used by both pillars: a line longer than the limit is cut at the last space before the limit and ends in `…`; a shorter line is unchanged. The limit is 160 characters, counted without the two-space indent; `aapp.statusLineMax` overrides it.

### 2.4 Not in this plan

- The Issues and Plans pillars.
- `aapp status short`.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/status.sh::test_shipped_shows_latest_landed` -> asserts an entry committed last under `### Fixed`, below thirty `Added` entries, is the first line of the Shipped pillar
- [ ] `tests/verbs/status.sh::test_shipped_newest_first_across_sections` -> asserts three entries committed in turn to `Added`, `Fixed`, `Changed` print in reverse order of their commits
- [ ] `tests/verbs/status.sh::test_shipped_skips_removed_entry` -> asserts an entry later removed from the file is not printed, and a reworded one prints once, in its current wording
- [ ] `tests/verbs/status.sh::test_shipped_fallback_without_history` -> asserts an uncommitted `CHANGELOG.md` prints its first entries under `[Unreleased]`, without a heading line
- [ ] `tests/verbs/status.sh::test_shipped_points_to_changelog` -> asserts more than five entries end the pillar with a line naming `CHANGELOG.md`
- [ ] `tests/verbs/status.sh::test_pickup_lists_every_idea` -> asserts eight unworked ideas print eight lines and no "more" line
- [ ] `tests/verbs/status.sh::test_pickup_line_is_bounded` -> asserts a 900-character idea prints as one line of at most 160 characters, cut at a space, ending in `…`, starting with its title
- [ ] `tests/verbs/status.sh::test_short_line_unchanged` -> asserts an idea and a changelog entry under the limit print whole, without `…`
- [ ] `tests/verbs/status.sh::test_status_line_max_setting` -> asserts `aapp.statusLineMax 80` bounds both pillars' lines at 80

### Phase 1: Foundation & Setup
- [ ] Task 1.1: Write the tests of this section in `tests/verbs/status.sh`; commit them red.

### Phase 2: Core Implementation
- [ ] Task 2.1: `lib/cmd_status.sh`: `status_line_cut`; the Shipped pillar from the changelog's history, with its fallback.
- [ ] Task 2.2: `lib/cmd_status.sh`: the Pickup pillar lists every idea, one bounded line each.
- [ ] Task 2.3: `lib/docs/verbs/status.md`: the two pillars, `aapp.statusLineMax`, the new tests.

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
- [ ] `lib/cmd_status.sh` -> the Shipped and Pickup pillars; `status_line_cut`.
- [ ] `lib/docs/verbs/status.md` -> the contract of the two pillars and the new tests.
- [ ] `tests/verbs/status.sh` -> the tests of §3.
- [ ] `MANUAL.md` -> the briefing's pillars; `aapp.statusLineMax`.
- [ ] `CHEATSHEET.md` -> `aapp.statusLineMax`.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/status.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/skills/` -> the skills show the output as printed; they do not change.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1:** Is the limit 160 characters? The issue lines of the same briefing run 100 to 150.
* [ ] **Question 2:** Does the Pickup pillar list every idea, or keep a cap (five today)? With bounded lines, ten ideas are ten lines.
* [ ] **Question 3:** Is the changelog's Git history the source of "what landed last"? The alternative is the two archive ledgers (`done/000-archive-ledger.md`, `done/000-issues-archive.md`), which name plans and fixes but not changes committed without either.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-13:** Plan initialized from `pickup.md`.
* **2026-10-13:** Refined blast radius and locked module boundaries.
