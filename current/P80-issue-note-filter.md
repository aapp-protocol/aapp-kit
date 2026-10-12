# 🗺️ Plan P-80: Issue Note Filter
* **Created:** 2026-10-12 | **Last Refined:** 2026-10-12
* **Target Issue / Milestone:** none
* **Plan ID:** P-80
* **Changelog:** Added: `aapp-issue-note-filter`, a team-written text filter the kit runs on a note before showing it (P-80)
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
Issues and their notes may be written by agents observing live systems, so a note can hold real data: log lines, record contents, identifiers. Notes are kept outside the repository and never committed for that reason, and they are stored as written, which keeps them usable for audits. What an agent is shown is a separate matter: a team may not want every agent to see the stored text.

This plan reserves one plugin, `aapp-issue-note-filter`: a text filter the team writes, which the kit runs on a note before showing it to anyone. It is a text substitution mechanism and nothing else: text in, text out.

---

## 2. Technical Blueprint
- **Where it runs:** at the one point where the kit hands a note over (P-74): `issue fix <n>` and `issue list <n>`. Every note passes through it, whether the kit or a provider stored it.
- **What it never touches:** the stored note. The filter changes what is shown, not what is kept.
- **The exchange** (P-77 protocol), event `issue.note-show`: `data` carries the whole issue with its `note`; the answer carries the text to show.

  | Answer | The kit shows |
  |---|---|
  | `ok` with `note` | the returned text (it may be empty: nothing is shown) |
  | `declined` | the note unchanged |
  | `failed`, a timeout, `ok` without `note`, a malformed answer | nothing: the note is withheld, with one line saying the filter failed |

  A filter that breaks never lets unfiltered text through. The command it runs in (`issue fix`, `issue list`) continues.
- **No filter installed:** the note is shown as stored.
- **Shipped:** the reserved name in `lib/plugins.tsv`, the event in the issue reference, and a sample (`examples/plugins/aapp-issue-note-filter/run.sample`) that applies a list of substitutions. What counts as sensitive is the team's code.
- **Documented as** a text filter and substitution mechanism: the reference states its input, its output, that the stored note is untouched, and the withhold-on-failure rule.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/issue.notefilter.sh::test_filtered_text_is_shown` -> asserts `issue fix` shows the filter's returned text in the labelled block, not the stored note
- [ ] `tests/verbs/issue.notefilter.sh::test_stored_note_untouched` -> asserts the note in the store is byte-identical after a filtered show
- [ ] `tests/verbs/issue.notefilter.sh::test_declined_shows_note_unchanged` -> asserts `declined` shows the stored note
- [ ] `tests/verbs/issue.notefilter.sh::test_failure_withholds_note` -> asserts a failing filter, a timeout, and `ok` without `note` each show no note text, print one line saying the filter failed, and `issue fix` still opens the fix
- [ ] `tests/verbs/issue.notefilter.sh::test_filter_runs_for_issue_list` -> asserts `issue list <n>` shows the filtered text
- [ ] `tests/verbs/issue.notefilter.sh::test_filter_runs_for_provider_note` -> asserts a note a provider keeps is filtered the same way
- [ ] `tests/verbs/issue.notefilter.sh::test_no_filter_shows_stored_note` -> asserts with no filter installed the note is shown as stored

### Phase 1: Tests First (red)
- [ ] Task 1.1: Write `tests/verbs/issue.notefilter.sh` with a scripted filter fixture; confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: Run the filter at the note hand-over in `lib/cmd_issue.sh`; withhold on failure.
- [ ] Task 2.2: Registry row, sample, reference.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update `MANUAL.md` and the issue contract.
- [ ] Task 3.3: Architecture and Codemap sections live in group P-72.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_issue.sh` -> The filter call at the note hand-over.
- [ ] `lib/plugins.tsv` -> Reserved name `aapp-issue-note-filter`.
- [ ] `NEW FILE` -> `examples/plugins/aapp-issue-note-filter/run.sample` -> Sample: a list of substitutions.
- [ ] `docs/reference/07-issue-protocol.md` -> Event `issue.note-show`; the filter as a text substitution mechanism.
- [ ] `lib/docs/verbs/issue.md` -> Contract.
- [ ] `MANUAL.md` -> Note filter.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/issue.notefilter.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/hook_dispatcher.sh` -> The protocol is P-77's; this plan only uses it.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-12:** Drafted as a member of P-72.
