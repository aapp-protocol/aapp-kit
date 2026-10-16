# 🗺️ Plan P-97: Draft From Pickup Title
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Target Issue / Milestone:** #160
* **Plan ID:** P-97
* **Changelog:** Fixed: a bare `aapp draft` names the plan after the pickup entry's title and writes its text into §1, with a bounded slug and a draft subject within `aapp.subjectMaxLen` (P-97)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `59e5399` (develop)
* **Worktree:** .workspace/P97 (plan/P97-draft-from-pickup-title)
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
#160: a bare `aapp draft` (no slug) takes the first unworked pickup entry, or the one chosen from the list, and uses the **whole line** as the plan's title and slug (`lib/cmd_plan.sh:1240`). An entry runs to hundreds of characters, so the plan file name and title are as long, and the draft commit subject `plan(draft): scaffold P-<N> <slug>` goes far over `aapp.subjectMaxLen`.

P-96 (group P-91) defines the entry form `- [ ] <title>: <text>` and the one function that splits it, `pickup_entry_split`. This plan uses that split: it starts after P-96 has landed, and is not part of the group.

---

## 2. Technical Blueprint

### 2.1 The title
- A bare `aapp draft` takes the plan's title and slug from the entry's **title** only (`pickup_entry_split`); the text is not part of either.
- The interactive list shows each entry by its title.

### 2.2 The slug
- A slug made from a title is cut at its last `-` before 60 characters (the longest plan file name today is 60), so a high `aapp.pickupTitleMax` never makes a file name too long for the file system or for Windows paths. The plan's title keeps the whole title.
- A slug the user gives (`aapp draft <slug>`) is taken as given.

### 2.3 The draft commit subject
- `plan(draft): scaffold P-<N> <slug>` is fitted to `aapp.subjectMaxLen`: the slug in the subject is cut at its last `-` before the limit; the file name keeps the whole slug.
- The limit is read through `aapp_subject_max_len` (`lib/aapp-lib.sh`, new: the setting, or 72 when unset or not a number), the one reader the other subject builders move to under #99.

### 2.4 The entry's text
- A bare `aapp draft` writes the entry's text, verbatim, into the new plan's `## 1. Context & Architectural Goal`, in place of the template's placeholder line, so the idea is not lost when the entry is digested. The `.plans/pickup/` files the entry names (`pickup_entry_files`) follow it, one `- \`<path>\`` line each, under `Notes from pickup:`.
- An entry without text (a title only, refused by the pickup gate but possible in an uncommitted edit) leaves the placeholder as it is.
- A draft with a slug the user gives (`aapp draft <slug>`) takes nothing from pickup, as today.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/draft.sh::test_bare_draft_takes_title_only` -> asserts a bare `aapp draft` from `- [ ] Short Title: a long text …` names the plan `Short Title` with slug `short-title`, no word of the text in either
- [ ] `tests/verbs/draft.sh::test_bare_draft_slug_bounded` -> asserts a 150-character title gives a slug of at most 60 characters cut at a `-`, and the plan's title line holds the whole title
- [ ] `tests/verbs/draft.sh::test_bare_draft_copies_text` -> asserts a bare `aapp draft` from `- [ ] Short Title: a text naming \`.plans/pickup/x.md\`` writes the text, verbatim, as §1 of the new plan with the placeholder gone, and the named file on a `Notes from pickup:` line
- [ ] `tests/verbs/draft.sh::test_draft_subject_fits_limit` -> asserts a draft whose slug would make `plan(draft): scaffold P-<N> <slug>` longer than `aapp.subjectMaxLen` commits with the subject cut at a `-` to fit, the file name keeping the whole slug
- [ ] `tests/aapp_lib_test.sh::test_subject_max_len` -> asserts `aapp_subject_max_len` gives the setting, and 72 when it is unset or not a number

### Phase 1: Foundation & Setup
- [ ] Task 1.1: Write the tests of this section; commit them red.

### Phase 2: Core Implementation
- [ ] Task 2.1: `lib/aapp-lib.sh`: `aapp_subject_max_len`.
- [ ] Task 2.2: `lib/cmd_plan.sh`: bare `aapp draft` takes the title through `pickup_entry_split` and writes the text into §1; the slug bounded; the draft subject fitted.
- [ ] Task 2.3: `lib/docs/verbs/draft.md`: the bare draft's title, slug and subject; the tests.

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
- [ ] `lib/aapp-lib.sh` -> `aapp_subject_max_len`.
- [ ] `lib/cmd_plan.sh` -> bare `aapp draft`: the title only, the slug bounded, the subject fitted.
- [ ] `lib/docs/verbs/draft.md` -> the bare draft's behaviour and its tests.
- [ ] `CHEATSHEET.md` -> the `aapp.subjectMaxLen` row also bounds the draft subject.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/draft.sh`
- [ ] `tests/aapp_lib_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/planning_health.sh` -> the pickup gate is P-96's.
- [ ] `lib/cmd_ai.sh` -> its subject limit read moves under #99.
- [ ] `lib/cmd_issue.sh` -> its subject limit read moves under #99.
- [ ] `templates/aapp-commit-msg` -> its subject limit read moves under #99.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — The entry's text in the drafted plan. → RESOLVED (developer, 2026-10-16):** copied, verbatim, into the new plan's §1, with the `.plans/pickup/` files it names (§2.4).

---

## 📦 6. Change Log & Refinement History
* **2026-10-16:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-16:** Drafted from #160; the `aapp draft` part taken out of P-96. Starts after P-96 lands.
* **2026-10-16:** Q1 resolved: the entry's text goes into §1 of the drafted plan.
