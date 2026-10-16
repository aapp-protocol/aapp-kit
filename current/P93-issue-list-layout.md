# 🗺️ Plan P-93: Issue List Layout
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Target Issue / Milestone:** #155
* **Plan ID:** P-93
* **Changelog:** Changed: `aapp issue list` and the Issues pillar show each issue's facts on one line and its symptom wrapped below (P-93)
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
#155: `aapp issue list` prints each issue as one line of up to ~350 characters. In a terminal the symptom wraps under the id and severity columns, and an issue that is not queued pads a blank 27-character column. The Issues pillar of `aapp status` uses the same line, and offline issues are shown in an older form of their own (`- [ ] #<n> -> <symptom>  (offline: staged in .offline)`).

This member, the third of group P-91, gives every issue view one layout from the records of P-92: the facts on a line of their own, the symptom wrapped below.

---

## 2. Technical Blueprint

### 2.1 The layout (group P-91 §2.3)
```
  #155  Low  Planned  logged 2026-10-16  [P-93]
        `aapp issue list` prints each issue as one line of up to ~350 characters:
        in a terminal the symptom wraps under the id and severity columns, and an
        unqueued issue pads a blank 27-character column.
```
- Facts line at 2 spaces: `#<id>  <Severity>  <Status>  logged <date>`, then, only when present: `queued <date> (<Level>)`, `[<plan>]` (`[blocks <plan>]` for a hotfix), `(branch: <name>)`, `offline`. Two spaces between facts, no padding. A facts line wider than `aapp.statusOutputWidth` wraps at 8 spaces.
- Tracker: when a provider named it, a line of its own at 8 spaces before the symptom: `· <name> <url> (<release>)`, parts that are absent left out.
- Symptom: `out_wrap 8 8`, never longer than `aapp.statusOutputWidth`.
- `aapp issue list` shows the symptom whole; the Issues pillar cuts it with `out_cut` at `aapp.statusTextMax`.
- An offline issue is an issue like any other: same layout, the `offline` fact.
- No blank line between issues (group P-91 §2.3).

### 2.2 Unchanged
- What is listed and in which order: ledger order (a sorting plugin's otherwise), this branch's issues first once any names a branch, the cap and `… <k> more (aapp issue list all)`; the Issues pillar lists the work queue, then the count of the others.
- `aapp issue list note <num>` keeps its hand-over block.

### 2.3 Implementation
- One renderer, `issue_render_terminal [cut]` in `lib/aapp-lib.sh`, over `ledger_issue_records`; `ledger_issue_lines` and `_issue_offline_lines` are removed, their callers (`cmd_issue_list`, `roadmap_issue_lines`, `lib/cmd_status.sh`) use the renderer.
- The branch grouping (`_issue_lines_by_branch`) sorts records, not printed lines.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/issue.queue.sh::test_list_facts_line` -> asserts each issue's first line holds id, severity, status and logged date, and the queue date and level, plan and branch only when the issue has them, with no run of more than two spaces
- [ ] `tests/verbs/issue.queue.sh::test_list_symptom_wrapped` -> asserts a 250-character symptom is printed whole on lines indented by 8 spaces, none longer than `aapp.statusOutputWidth`
- [ ] `tests/verbs/issue.queue.sh::test_status_pillar_same_layout` -> asserts the Issues pillar shows a queued issue in the same layout, its symptom cut at `aapp.statusTextMax` with `…`
- [ ] `tests/verbs/offline.sh::test_offline_issue_same_layout` -> asserts an issue staged in `.offline` is shown in `issue list` and the Issues pillar in the same layout, with the `offline` fact
- [ ] `tests/verbs/issue.branch.sh::test_list_branch_fact` -> asserts an issue that names a branch shows `(branch: <name>)` on its facts line, and this branch's issues come first
- [ ] `tests/verbs/issue.tracker.sh::test_list_tracker_fact` -> asserts a provider's `tracker`, `url` and `release` appear on a `· ` line of their own between the facts line and the symptom

### Phase 1: Foundation & Setup
- [ ] Task 1.1: Write the tests of this section; update the tests that assert the one-line form; commit them red.

### Phase 2: Core Implementation
- [ ] Task 2.1: `lib/aapp-lib.sh`: `issue_render_terminal`; the branch grouping on records; `ledger_issue_lines` removed.
- [ ] Task 2.2: `lib/cmd_issue.sh`: `cmd_issue_list` on the renderer; `_issue_offline_lines` removed.
- [ ] Task 2.3: `lib/cmd_status.sh`: the Issues pillar on the renderer, cut.
- [ ] Task 2.4: `lib/docs/verbs/issue.md`, `lib/docs/verbs/status.md`: the layout and the tests.

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
- [ ] `lib/aapp-lib.sh` -> `issue_render_terminal`; branch grouping on records.
- [ ] `lib/cmd_issue.sh` -> `cmd_issue_list` on the renderer.
- [ ] `lib/cmd_status.sh` -> the Issues pillar on the renderer.
- [ ] `lib/docs/verbs/issue.md` -> the layout and the tests.
- [ ] `lib/docs/verbs/status.md` -> the Issues pillar layout.
- [ ] `MANUAL.md` -> how an issue is shown.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/issue.queue.sh`
- [ ] `tests/verbs/offline.sh`
- [ ] `tests/verbs/issue.branch.sh`
- [ ] `tests/verbs/issue.tracker.sh`
- [ ] `tests/verbs/issue.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `ARCHITECTURE.md` -> written from group P-91's sections at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> written from group P-91's sections at the group's `done`.
- [ ] `templates/skills/` -> the skills show the output as printed.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
*(None — design is fully specified.)*

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-16:** Drafted from #155 as the third member of group P-91.
