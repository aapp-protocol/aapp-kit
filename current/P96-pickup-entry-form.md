# 🗺️ Plan P-96: Pickup Entry Form
* **Created:** 2026-10-16 | **Last Refined:** 2026-10-16
* **Target Issue / Milestone:** none
* **Plan ID:** P-96
* **Changelog:** Changed: a pickup entry is `- [ ] <title>: <text>`, its title no longer than `aapp.subjectMaxLen`; `aapp refine pickup` refuses any other form (P-96)
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
Group P-91 reads each pickup entry as a title, a text and the files it names (§2.5), for the briefing and for `aapp status json`. Nothing defines how an entry is written: `check_pickup_entries` (`lib/planning_health.sh`), the gate of `aapp refine pickup`, only checks that it starts with `- [ ] `. An agent writing a note from a prompt may use one form today and another tomorrow, and the title cannot then be read reliably.

This member, the first of the group, makes the form a rule: stated where entries are written, checked by the gate every pickup commit passes. `pickup.md` stays a file people edit by hand; only the commit insists on the form.

---

## 2. Technical Blueprint

### 2.1 The form
One line per entry:
```
- [ ] <title>: <text>
```
- **Title:** everything before the first `: ` outside backticks; required; at most `aapp.subjectMaxLen` characters (the commit subject limit, default 72), read through `aapp_subject_max_len` (`lib/aapp-lib.sh`, new: the setting, or 72 when unset or not a number).
- **Text:** everything after it; required, not empty.
- **Files:** every path under `.plans/pickup/` the entry names exists.
- A digested entry (`- [x] `) is not checked: it is history.

### 2.2 The gate (`check_pickup_entries`)
- Refuses, per line, naming the line number and the line, and showing the form:
  - a list line that is not `- [ ] ` / `- [x] ` (as today);
  - an entry with no `: ` outside backticks: `no title`;
  - a title longer than the limit: `title is <n> characters; at most <max> (aapp.subjectMaxLen)`;
  - an empty text: `no text after the title`;
  - a named `.plans/pickup/` path that does not exist: `names <path>, which does not exist`.
- One title rule for gate and reader: the split is one function, `pickup_entry_split` (`lib/aapp-lib.sh`), used by the gate and by P-92's `status_records_pickup`.
- Runs where it runs today: `aapp refine pickup`, nothing committed on a refusal.

### 2.3 Where the form is stated
- `templates/pickup.md`: the protocol block (kept current by `aapp init`) states the form with one example.
- `templates/AGENTS.md`: the line that says ideas are committed with `aapp refine pickup` states the form.

### 2.4 Existing entries
Four titles in this repository's `pickup.md` are longer than 72 characters (this repository's `aapp.subjectMaxLen`). Before this member lands they are rewritten with `aapp refine pickup`, the bracketed part moved into the text, and nothing else changed:

| Today | Title after |
| :--- | :--- |
| `Work Dispatch Queue for Multi-Agent Execution (\`aapp dispatch\` / \`aapp queue\`)` (78) | `Work Dispatch Queue for Multi-Agent Execution` |
| `Layer-0 Enforcement Practice & Unsupervised Agent Security Manual (docs only, not kit code)` (91) | `Layer-0 Enforcement Practice & Unsupervised Agent Security Manual` |
| `AI Attribution Integrity & Model Introspection Enforcement (Bare-Word & Placeholder Refusal)` (92) | `AI Attribution Integrity & Model Introspection Enforcement` |
| `Cookbook recipe "Planning a Plan Group" (\`docs/recipes/workflows/planning-a-plan-group.md\`, listed in P-56 Task 1.4)` (116) | `Cookbook recipe "Planning a Plan Group"` |

The text of each starts with the moved part, e.g. `- [ ] Cookbook recipe "Planning a Plan Group": (\`docs/recipes/workflows/planning-a-plan-group.md\`, listed in P-56 Task 1.4) how related plans …`.

### 2.5 Not in this member
- A writer token (`aapp refine pickup add "<title>" "<text>" [file <path>]`): the gate makes the form reliable, and the file stays easy to edit by hand. It can follow if agents keep being refused.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/refine.sh::test_refine_pickup_refuses_untitled_entry` -> asserts an entry with no `: ` outside backticks is refused naming its line, and nothing is committed
- [ ] `tests/verbs/refine.sh::test_refine_pickup_refuses_long_title` -> asserts a title one character over `aapp.subjectMaxLen` is refused with its length and the limit, one at the limit is accepted, under the default 72 and under a set value of 50
- [ ] `tests/verbs/refine.sh::test_refine_pickup_refuses_empty_text` -> asserts `- [ ] Title:` with nothing after it is refused
- [ ] `tests/verbs/refine.sh::test_refine_pickup_refuses_missing_file` -> asserts an entry naming a `.plans/pickup/` file that does not exist is refused naming the path, and one naming an existing file is accepted
- [ ] `tests/verbs/refine.sh::test_refine_pickup_skips_digested` -> asserts a `- [x] ` entry without a title is not refused
- [ ] `tests/aapp_lib_test.sh::test_pickup_entry_split` -> asserts the split at the first `: ` outside backticks (a `: ` inside backticks in the title stays in it), and an empty title for a line without one

### Phase 1: Foundation & Setup
- [ ] Task 1.1: Write the tests of this section; commit them red.
- [ ] Task 1.2: Rewrite the four titles of §2.4 in `.plans/pickup.md` with `aapp refine pickup`.

### Phase 2: Core Implementation
- [ ] Task 2.1: `lib/aapp-lib.sh`: `pickup_entry_split`; `aapp_subject_max_len`.
- [ ] Task 2.2: `lib/planning_health.sh`: `check_pickup_entries` with the refusals of §2.2.
- [ ] Task 2.3: `templates/pickup.md`, `templates/AGENTS.md`: the form.
- [ ] Task 2.4: `lib/docs/verbs/refine.md`: the refusals and the tests.

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
- [ ] `lib/aapp-lib.sh` -> `pickup_entry_split`; `aapp_subject_max_len`.
- [ ] `lib/planning_health.sh` -> `check_pickup_entries`: the form.
- [ ] `templates/pickup.md` -> the form in the protocol block.
- [ ] `templates/AGENTS.md` -> the form where pickup commits are named.
- [ ] `lib/docs/verbs/refine.md` -> the refusals and the tests.
- [ ] `MANUAL.md` -> how a pickup idea is written.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/refine.sh`
- [ ] `tests/aapp_lib_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `ARCHITECTURE.md` -> written from group P-91's sections at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> written from group P-91's sections at the group's `done`.
- [ ] `lib/cmd_status.sh` -> the briefing reads entries in P-92 and P-88.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1 — The four new titles (§2.4).** They are the developer's notes: confirm the titles, or give others, before Task 1.2.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-16:** Drafted as the first member of group P-91.
* **2026-10-16:** Title limit is `aapp.subjectMaxLen`, not a fixed 72.
