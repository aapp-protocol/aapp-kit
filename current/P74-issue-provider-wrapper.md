# 🗺️ Plan P-74: Issue Provider Wrapper
* **Created:** 2026-10-11 | **Last Refined:** 2026-10-11
* **Target Issue / Milestone:** none
* **Plan ID:** P-74
* **Changelog:** Added: the `aapp-issue-tracker` provider gets the whole issue at every issue step; issue notes; remote issues (P-74)
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
The `aapp-issue-tracker` provider is called at three points, none with the issue itself: `issue.allocate` (returns an id), `issue.next-blocker` (returns an id), `issue.close` (id, commit, summary, plan; fire-and-forget). A provider cannot keep a full record of an issue, hold notes for it, or bring in issues a colleague logged elsewhere.

This plan routes every issue step through one wrapper over the ledger functions (P-73). The provider receives the whole issue and decides, per part, whether it handles it or leaves it to the kit. Issues it lists have the same rights as local ones. Short notes (a few phrases of clue) get a home outside the repository.

---

## 2. Technical Blueprint
**Handler:** `aapp issue log <sev> <type> "<symptom>" [file <path>]… [note "<text>"]`. The agent hands the issue over and never writes a row; the handler picks the id, writes the row through the module and commits it. `issue hotfix` logs through the same handler.
- **Id:** with a provider, `issue.log` creates the issue and returns its id; without one, the kit's counter. When the provider fails, the id is the highest offline id plus 1, or, with no offline issues, the highest id registered locally (active and archive) plus 1000; the issue is then staged offline (P-75).

**Retired once the handler is the only writer of new rows** (in this order):
1. `refine issues` refuses a commit that adds a row and names `aapp issue log`.
2. `check_issue_ids_below_counter` leaves `check_ledger_issues`, and its line leaves the `refine` contract.
3. `aapp issue allocate` / `issue next` become internal to the handler; agent docs and skills stop telling agents to claim a number.

**Wrapper:** `issue_provider <step> <n> [<step data>…]` in `lib/cmd_issue.sh`, not in `lib/aapp-lib.sh`: the hooks never receive the code that calls a provider. The note store and remote-cache readers are ledger functions in `lib/aapp-lib.sh`. With a provider installed it builds the payload and calls `run_action_plugin`; without one it runs the kit's internals.

| Step | Called by | Action |
|---|---|---|
| log | `issue log`, `issue hotfix` | `issue.log` |
| refine | `refine issues` (rows changed against HEAD) | `issue.refine` |
| fix | `issue fix <n>`, `issue fix next-blocker` | `issue.fix` |
| abort | `issue fix <n> abort`, a plan abort (P-69) for its issues | `issue.abort` |
| close | `issue close`, `done` | `issue.close` |
| list | `issue list`, `status` | `issue.list` |

- **Payload:** the Plugin Payload Standard envelope; `data` carries the whole issue: id, severity, type, date, location, symptom, link, status, note, and the step's own fields (commit, summary, plan). Sent after the step's commit lands, so a refused row never reaches the provider.
- **Tracker keys:** the kit's `#<num>` stays the kit's id. The payload and the provider's issues carry an optional `ref` (the tracker's own key or URL, e.g. `PROJ-101`); the provider keeps its own mapping, and `issue list` shows `ref` next to the id.
- **Answer:** `{"status": …, "kit": [<part>…]}`. `kit` names what the kit still handles (`note`, `cache`); no `kit` field means the kit handles everything, so current providers keep working.
- **Notes:** a bare `note` token on `issue log` and `issue hotfix`; on an existing issue, `aapp refine issues "<msg>" note <n> "<text>"` (repeatable; with only `note` tokens and no ledger change it still runs the wrapper). Never written to the ledger. Kit store: `~/.local/state/aapp/<key>/issues-data.md`. `issue fix` prints the note as the fix opens.
- **Remote issues:** `issue.list` answers `{"issues": [{…}, …]}` in the payload's issue shape. The kit writes them to `~/.local/state/aapp/<key>/remote-issues.tsv`; `ledger_rows` and `ledger_locate` merge it (`remote`), so they block plans and show in `status`, `issue list`, `draft` and `next-blocker`. On an id present on both sides, the local lifecycle cells win, except a closure: an issue the provider lists as closed is reconciled (Question 5); `status` marks it.
- **Notes are per machine without a provider:** the kit's store is outside Git, so another clone sees a note only through a provider; the MANUAL says so.
- **Acting on a remote issue:** `issue fix`, `draft … issue` and `next-blocker` first write its row into `ISSUES.md` through the log step, then proceed as for a local row.
- **Id clash** (same id, different issue): both shown and marked; `fix` and `draft … issue` refuse that id. A provider that answers `issue.list` must return the id from `issue.log`.
- **Sync:** only at `issue list` and `status`, within a refresh window; hooks read the ledger and the cache, never the network.
- **Failures:** the step falls back to the kit and warns; numbering falls back as in **Id** above; `issue.next-blocker` stays authoritative and refuses, as today. P-75 builds its offline fallback on this failure path.
- **Sample:** `examples/plugins/aapp-issue-tracker/run.sample` handles every step and stores into a local file; `lib/plugins.tsv` lists the new actions.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/issue.provider.sh::test_log_writes_row_with_kit_id` -> asserts with no provider `issue log` writes and commits the row under the counter's next id
- [ ] `tests/verbs/issue.provider.sh::test_log_takes_provider_id` -> asserts the row carries the id `issue.log` returned
- [ ] `tests/verbs/issue.provider.sh::test_log_failure_offset_id` -> asserts on provider failure the id is the highest local id plus 1000, or the highest offline id plus 1 when offline issues exist
- [ ] `tests/verbs/issue.provider.sh::test_refine_refuses_added_row` -> asserts `refine issues` refuses a commit that adds a row and names `aapp issue log`
- [ ] `tests/verbs/issue.provider.sh::test_no_counter_check` -> asserts `refine issues` no longer refuses an id at or above `aapp.issueId`
- [ ] `tests/verbs/issue.provider.sh::test_agent_docs_name_no_allocate` -> asserts `templates/AGENTS.md` and the shipped skills name no `issue allocate` / `issue next` step
- [ ] `tests/verbs/issue.provider.sh::test_log_sends_whole_row` -> asserts a new row reaches the provider with every cell and its note
- [ ] `tests/verbs/issue.provider.sh::test_refine_sends_changed_rows_only` -> asserts unchanged rows are not sent
- [ ] `tests/verbs/issue.provider.sh::test_refused_row_never_sent` -> asserts a ledger commit refused by its checks calls no provider
- [ ] `tests/verbs/issue.provider.sh::test_fix_prints_note` -> asserts `issue fix` prints the issue's note
- [ ] `tests/verbs/issue.provider.sh::test_close_sends_whole_issue` -> asserts `issue.close` data carries the row cells as well as commit and summary
- [ ] `tests/verbs/issue.provider.sh::test_kit_answer_keeps_note_local` -> asserts `"kit": ["note"]` stores the note in the kit store
- [ ] `tests/verbs/issue.provider.sh::test_note_without_provider` -> asserts with no provider the note lands in the state directory, not the repository
- [ ] `tests/verbs/issue.provider.sh::test_remote_issue_blocks_plan` -> asserts a listed remote issue named in a plan's `Blocked On` counts as open in `next-blocker` and `status`
- [ ] `tests/verbs/issue.provider.sh::test_fix_remote_issue_imports_row` -> asserts fixing a remote-only id writes its row into `ISSUES.md` first
- [ ] `tests/verbs/issue.provider.sh::test_id_clash_refuses_fix` -> asserts a clashing id is marked in `issue list` and `fix` refuses it
- [ ] `tests/verbs/issue.provider.sh::test_abort_sends_abort_step` -> asserts `issue fix <n> abort` sends `issue.abort` with the whole issue
- [ ] `tests/verbs/issue.provider.sh::test_ref_shown_in_list` -> asserts a provider's `ref` shows next to the id in `issue list`
- [ ] `tests/verbs/issue.provider.sh::test_remote_closure_reconciled` -> asserts an issue the provider lists as closed is marked in `status` and reconciled per Question 5
- [ ] `tests/verbs/issue.provider.sh::test_failure_falls_back_and_warns` -> asserts a failing provider on log/refine/fix/close/list warns and the kit completes the step
- [ ] `tests/verbs/issue.provider.sh::test_hooks_never_call_provider` -> asserts a commit through the hooks runs no provider

### Phase 1: Tests First (red)
- [ ] Task 1.1: Write `tests/verbs/issue.provider.sh` with a recording provider fixture; confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: Payload builder and `issue_provider` wrapper in `lib/cmd_issue.sh`; move `allocate`, `next-blocker` and `close` onto it.
- [ ] Task 2.2: `issue log` handler (id, row, commit) and the log step; `issue hotfix` onto it; the refine step from `refine issues`; the `note` token; the kit's note store.
- [ ] Task 2.2b: Retire in order: `refine issues` refuses added rows; drop `check_issue_ids_below_counter`; `allocate`/`next` internal, agent docs and skills updated (`.agents/AGENTS.md` alongside on its branch).
- [ ] Task 2.3: fix and abort steps: note printed; remote rows imported.
- [ ] Task 2.4: list step: cache, merge in `ledger_rows`/`ledger_locate`, id clashes, sync at `issue list` and `status`.
- [ ] Task 2.5: Sample provider and `lib/plugins.tsv`.

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
- [ ] `lib/aapp-lib.sh` -> Ledger functions: note store and remote cache as read sources, merge.
- [ ] `lib/cmd_issue.sh` -> The wrapper and payload; `issue log`; fix, close, hotfix, list call the wrapper; `note` token on hotfix.
- [ ] `lib/cmd_plan.sh` -> `refine issues` refine step, `note` token, refuses added rows; `draft … issue` imports remote rows.
- [ ] `lib/planning_health.sh` -> `check_issue_ids_below_counter` retired; added-row refusal.
- [ ] `lib/plan_resolver.sh` -> Id allocation behind the handler; offset fallback on provider failure.
- [ ] `templates/AGENTS.md` -> Log issues with `aapp issue log`; no number claiming.
- [ ] `templates/skills/aapp-plan/SKILL.md` -> Same.
- [ ] `templates/skills/aapp-pause/SKILL.md` -> Same.
- [ ] `templates/skills/aapp-digest/SKILL.md` -> Same.
- [ ] `lib/cmd_status.sh` -> list step at briefing.
- [ ] `lib/plugins.tsv` -> New actions for `aapp-issue-tracker`.
- [ ] `examples/plugins/aapp-issue-tracker/run.sample` -> Handles every step.
- [ ] `lib/docs/verbs/issue.md` -> Contract.
- [ ] `lib/docs/verbs/refine.md` -> Contract: `note` token; added rows refused; counter check gone.
- [ ] `lib/docs/verbs/status.md` -> Contract: remote issues.
- [ ] `MANUAL.md` -> Provider steps, notes, remote issues.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/issue.provider.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/aapp-pre-commit` -> Hooks never call the provider.
- [ ] `templates/blast-radius-guard.sh` -> Same.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — The state directory's `<key>`? → RESOLVED (developer, 2026-10-11):** derived from the remote URL (two clones of one project share notes; two projects with the same folder name do not collide); a repository with no remote uses its folder name.
* [ ] **Question 2:** A second `note` for the same issue: appended, or replaces the first?
* [ ] **Question 3:** Who writes notes: people only, or also the agent that logs the issue?
* [ ] **Question 4:** The sync refresh window: a fixed length, or a config key?
* [ ] **Question 5:** An issue the provider lists as closed while the local row is open: `issue list` closes it locally with the provider's summary, or only marks it until someone runs `issue close`?

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-11:** Drafted as a member of P-72.
