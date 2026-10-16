# 🗺️ Plan P-98: Status Plan Progress
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Target Issue / Milestone:** none
* **Plan ID:** P-98
* **Changelog:** Added: the briefing and its JSON show a plan's task progress and a group's members done (P-98)
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
The briefing's Plans pillar shows a status label only. Two facts are missing:
- **A plan's progress.** `⚡ In Development` reads the same at the first task and at the last.
- **A group's progress.** Archived members drop off the list; nothing says how many are done.

Both derive from what the plans already record: ticked §3 boxes, and the group's `* **Members:**`
against the members archived. The JSON plan record (P-91 §2, shipped by P-94) carries the same facts
for a web interface. Independent of group P-91: it starts after the group lands, because every
member changes `lib/cmd_status.sh` and P-94 adds the JSON renderer this plan extends.

---

## 2. Technical Blueprint

### 2.1 One accessor
`plan_progress <plan-file>` (`lib/aapp-lib.sh`) -> `<done>\t<total>\t<unit>`, empty when nothing
counts. The briefing line and the JSON record both read it.
- **Plan** (`unit` = `tasks`): the `- [ ]` and `- [x]` boxes in `## 🔨 3.`, up to the next `## `
  heading; `[x]` and `[X]` count as done. §4 and §5 boxes do not count.
- **Group** (`unit` = `members`): `total` = the IDs in `* **Members:**` (`group_members`); `done` =
  those with a plan in `.plans/done/` and none in `.plans/current/`.

### 2.2 Briefing
The count joins the status label, after the worktree:
```
  • P-91: P91-readable-and-parsable-output.md  (⚡ In Development · members 3/5)
      ↳ P-93: P93-issue-list-layout.md  (⚡ In Development → .workspace/P93 · tasks 4/34)
```
Shown for a plan in `⚡ In Development` or `🟥 BLOCKED` with a non-zero total (Q2), and for a group
in any status.

### 2.3 JSON
The plan record gains `"progress": { "done", "total", "unit" }`, `null` when the accessor is empty
(Q1). Added to `docs/reference/08-output-json.md`; an added key, no change to existing fields.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Tests First (red)
- [ ] Task 1.1: `tests/verbs/status.sh`: plan task counts, group member counts, the shown/hidden cases (§2.2), the JSON `progress` record; confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: `lib/aapp-lib.sh`: `plan_progress` (§2.1).
- [ ] Task 2.2: `lib/cmd_status.sh`: the count in `plan_line` and `progress` in the JSON plan record.
- [ ] Task 2.3: `lib/docs/verbs/status.md`, `docs/reference/08-output-json.md`: the count, the field, the tests.

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
- [ ] `lib/aapp-lib.sh` -> `plan_progress`.
- [ ] `lib/cmd_status.sh` -> the count in the briefing line; `progress` in the JSON plan record.
- [ ] `lib/docs/verbs/status.md` -> the count and its tests.
- [ ] `docs/reference/08-output-json.md` -> the `progress` field.
- [ ] `tests/verbs/status.sh` -> the tests.
- [ ] `ARCHITECTURE.md` -> the accessor.
- [ ] `.agents/CODEMAP.md` -> the accessor.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.plans/current/P91-readable-and-parsable-output.md` -> group P-91 and its members are not amended by this plan.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1 — One `progress` shape or two?** Proposed: one object with `unit` (`tasks` | `members`), so a consumer reads plans and groups alike. Alternative: `tasks` on a plan, `members` on a group, as separate fields.
* [ ] **Question 2 — When is a plan's task count shown?** Proposed: in development or blocked only; a draft's `0/9` says nothing. Alternative: whenever the total is non-zero. The JSON carries it in every status either way.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-16:** Drafted: plan and group progress in the briefing and its JSON.
