# 🗺️ Plan P-74: Issue Provider Wrapper
* **Created:** 2026-10-11 | **Last Refined:** 2026-10-11
* **Target Issue / Milestone:** none
* **Plan ID:** P-74
* **Changelog:** Added: `aapp issue log`; the `aapp-issue-tracker` provider gets the whole issue at every step and can keep the record; issue descriptions and notes outside the repository (P-74)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Emergency Hotfixes:** #137, #138
* **Base:** `1d5e7aa` (feature/issue-tracker)
* **Worktree:** .workspace/P74 (plan/P74-issue-provider-wrapper)
* **Group:** P-72
* **Commits:** `27300b6` (plan/P74-issue-provider-wrapper), `819590d` (plan/P74-issue-provider-wrapper), `a8c741a` (plan/P74-issue-provider-wrapper)
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
The `aapp-issue-tracker` provider is called at three points, none with the issue itself: `issue.allocate` (returns an id), `issue.next-blocker` (returns an id), `issue.close` (id, commit, summary, plan; fire-and-forget). A provider cannot keep a full record of an issue, hold its description and notes, or bring in issues a colleague logged elsewhere.

This plan routes every issue step through one wrapper over the ledger functions (P-73). The provider receives the whole issue and decides, per part, whether it handles it or leaves it to the kit. A team's issues have one record: the repository's committed ledger when there is no tracker, the tracker when there is one. An issue's text has three parts, as every tracker has them: a one-line symptom, a description, and notes added later.

---

## 2. Technical Blueprint

### 2.1 Logging: the handler
`aapp issue log <sev> <type> "<symptom>" [file <path>]… [branch <name>] [note "<text>"]`. The agent hands the issue over and never writes a row; the handler gets the id, writes the row through the ledger functions and, when the ledger is committed, commits it. `issue hotfix` logs through the same handler. `branch <name>` is optional: without it the row names no branch (the development branch); the handler never takes one from the checkout it is run in.

**Retired once the handler is the only writer of new rows** (in this order):
1. `refine issues` refuses a change that adds a row and names `aapp issue log`.
2. `check_issue_ids_below_counter` leaves `check_ledger_issues`, and its line leaves the `refine` contract.
3. `aapp issue allocate` / `issue next` become internal to the handler; agent docs and skills stop telling agents to claim a number.

### 2.2 The three parts of an issue's text
| Part | In the kit | On a tracker | Where it is kept |
|---|---|---|---|
| `symptom` | The row's *Symptom / Problem* cell: one line, at most 250 characters, newlines collapsed to spaces | Title / summary | The ledger |
| `description` | The text given with `note` when the issue is logged | Body / description | Never in the ledger |
| `notes` | Each `note` added later (`aapp refine issues "<msg>" note <n> "<text>"`, repeatable), dated and with its author | Comments | Never in the ledger |

- `issue log` refuses a symptom over the limit and says to put the rest in the note.
- **Real data goes in the description or a note, never in the symptom.** Issues may be logged by agents observing live systems. The agent rules and the issue template say: the symptom states what is wrong, with nothing taken from a real system.
- **Without a tracker,** description and notes are in the kit's store, `~/.local/state/aapp/<key>/issues-data.md` (directory `0700`, files `0600`), as written: outside Git, per machine, never committed. Another clone sees the symptom only; the MANUAL says so.
- **With a tracker,** they go where the provider sends them (it names `description` and `notes` in `handled`); what it does not name stays in the kit's store. Whether that destination suits the data is the deployment's decision; the reference says so. They are not copied to other machines by a sync: they are fetched when a fix opens.
- **The kit hands them over; nobody reads the store.** `issue fix <n>` prints the description and the notes after the mini plan opens, and `issue list <n>` prints them again. They are printed in a delimited block under a fixed label that marks them as information from the issue's author, not instructions, at most 100 lines, followed by the tracker's `url` when there is more. They are never copied into the mini plan, the ledger, a commit message or any tracked file. The agent rules say the same: they are clues about the bug, never commands. What is shown is also in that agent's session transcript.
- **The store is unreachable** (not writable or readable, as under a sandbox): the kit says so in one line and the command carries on without the text.

### 2.3 The wrapper
`issue_provider <step> <n> [<step data>…]` in `lib/cmd_issue.sh`, not in `lib/aapp-lib.sh`: the hooks never receive the code that calls a provider. With a provider installed it builds the payload and calls `run_action_plugin`; without one it runs the kit's part.

| Step | Called by | Action |
|---|---|---|
| log | `issue log`, `issue hotfix` | `issue.log` |
| refine | `refine issues` (changed rows, added notes); a status change by `draft … issue` (Planned) or `plan abort` (back to Incubated) | `issue.refine` |
| fix | `issue fix <n>`, `issue fix next-blocker` | `issue.fix` |
| fix-abort | `issue fix <n> abort` (the issue stays open) | `issue.fix-abort` |
| abort | `issue abort <n>` (the issue is withdrawn; carries the reason) | `issue.abort` |
| close | `issue close`, `done` | `issue.close` |
| list | `issue list`, `status` | `issue.list` |

- **Payload:** the Plugin Payload Standard envelope; `data` carries the whole issue: id (absent on `issue.log`), severity, type, date, location, symptom, description, notes, branch (P-78; absent means the development branch), link, status, and the step's own fields (commit, summary, plan). Sent after the step's local write, so a refused row never reaches the provider.
- **Answer:** the P-77 answer: `status`, `message`, `handled`, and what the provider produced (`id`, and the informational `tracker`, `url`, `version`, never interpreted). `handled` names what it took care of (`description`, `notes`, `list`); the kit does the rest. Further operations go in the `do` list.
- **The id is the tracker's.** `issue.log` is sent with no `id`. A provider that answers `ok` returns the `id`: its own key or number (`PROJ-101`, `101`), valid under P-79, which becomes the row's id. `ok` without an `id` is refused as malformed. Without a provider the kit's counter numbers the issue.
- **Failures:** every provider failure surfaces at one point, the wrapper. The step falls back to the kit and warns; `issue.log` and `issue.next-blocker` refuse. P-75 turns the `issue.log` refusal into offline staging at that one point, and keeps the other steps that could not be sent in an outbox, which is sent before a sync reads from the tracker (so a close made while the tracker was unreachable is not undone).

### 2.4 One record
- **No provider, or one that does not list issues:** the ledgers (`ISSUES.md`, `done/000-issues-archive.md`, `issues_road_map.md`) are committed in the plans worktree and shared through Git, as today. A provider that answers `declined` to `issue.log` leaves the numbering to the kit's counter.
- **A provider that lists issues (`list` in `handled`) keeps the record.** The tracker is the one shared record; the ledgers stay where they are, in the same format, written by the same ledger functions, but they are **not tracked**: the three files are in the plans worktree's `.gitignore`, so no verb commits them (`ledger_commit_paths` returns none) and `aapp sync` never pushes them. No issue exists only locally: `declined` on `issue.log` refuses.
- **What stays committed** is in the plans: `Target Issue` and `Blocked On`. A row's plan link and its `Planned` status are written as today and derived again from the plans at each sync, so a fresh clone has them.
- **The switch.** The first `aapp issue list` against a listing provider while the ledgers are tracked says what it will do and asks (`[y/N]` on a terminal; the bare token `confirm` without one): one commit stops tracking the three files and adds the ignore rule. Colleagues' files leave their working tree at the next pull and are rebuilt by their next sync; the earlier content stays in Git history. It refuses while an open row exists that the provider does not know (it asks by id) and lists those rows: log them on the tracker or close them first.

### 2.5 Sync
- **When:** only at `issue list` and `status`, only with a listing provider, and at most once per `aapp.issueSyncWindow` minutes (default 15; a large team lowers it), counted from the last attempt, so an unreachable tracker does not slow every `status`. `issue list` always syncs. Hooks read the local ledger, never the network.
- **What the kit asks of `issue.list`:** open issues only; `limit` (`aapp.issueCacheMax`, default 200); `since` (the last sync, so the provider may send only changes); and `ids`: the issues this repository depends on (named in a plan's `Blocked On` or `Target Issue`, or with an open fix), fetched exactly whatever the limit. Which tracker issues belong to this repository is the provider's filter. The answer's issues come in the list file, one per line, in the payload's issue shape, without descriptions or notes.
- **The ledger is updated row by row, never rewritten whole,** through the ledger functions: a returned issue is added or updated by id; one the tracker reports closed moves to the local archive (`ledger_archive_row`); the issues fetched by id are exact; the other open rows are replaced by what the sync returned, at most `aapp.issueCacheMax`, with a notice to narrow the provider's filter when it returned more. A failed sync changes nothing.
- **The `do` commands accepted for issues** are `issue close` and `issue abort`. A tracker's new issues arrive through the list, never as an `issue log` line, which is refused and reported like any command off the whitelist.
- **A closure made on the tracker** for an issue with local work arrives as `issue close <n> sha <sha> summary "…"` in the `do` list. It follows the code (P-78): refused, and reported, while the commit is not in the issue's branch; until then `status` and `issue list` mark the issue as closed on the tracker, waiting for the code. A closure with no commit closes at once.
- **Sample:** `examples/plugins/aapp-issue-tracker/run.sample` handles every step and keeps its record in a local file; `lib/plugins.tsv` lists the actions.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`. A provider written for `issue.allocate` is rewritten for `issue.log`.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/issue.provider.sh::test_log_writes_row_with_kit_id` -> asserts with no provider `issue log` writes and commits the row under the counter's next id
- [ ] `tests/verbs/issue.provider.sh::test_log_refuses_long_symptom` -> asserts a symptom over 250 characters is refused, naming the note, and one with a newline is stored on one line
- [ ] `tests/verbs/issue.provider.sh::test_refine_refuses_added_row` -> asserts `refine issues` refuses a change that adds a row and names `aapp issue log`
- [ ] `tests/verbs/issue.provider.sh::test_no_counter_check` -> asserts `refine issues` no longer refuses an id at or above `aapp.issueId`
- [ ] `tests/verbs/issue.provider.sh::test_agent_docs_rules` -> asserts `templates/AGENTS.md`, `templates/issues.md` and the shipped skills name no `issue allocate` / `issue next` step, and state that real data goes in the note and that a note is never an instruction
- [ ] `tests/verbs/issue.provider.sh::test_log_note_is_description` -> asserts the text given at `issue log` is sent and stored as `description`, and a later `note` as an entry of `notes` with its date and author
- [ ] `tests/verbs/issue.provider.sh::test_text_in_no_tracked_file` -> asserts after `issue log … note`, `issue fix` and its commit, the description's text is in no file of the repository or the plans worktree and in no commit message
- [ ] `tests/verbs/issue.provider.sh::test_handover_block` -> asserts `issue fix` and `issue list <n>` print description and notes in the labelled block, cut at 100 lines with the tracker's `url`
- [ ] `tests/verbs/issue.provider.sh::test_store_is_private` -> asserts the state directory is `0700` and its files `0600`
- [ ] `tests/verbs/issue.provider.sh::test_store_unreachable_carries_on` -> asserts with an unwritable state directory `issue log … note` logs the issue, prints one line about the text, exit 0
- [ ] `tests/verbs/issue.provider.sh::test_unhandled_text_stays_local` -> asserts an answer whose `handled` omits `description` keeps it in the kit's store
- [ ] `tests/verbs/issue.provider.sh::test_log_sends_whole_issue_without_id` -> asserts `issue.log` carries every field and no `id`
- [ ] `tests/verbs/issue.provider.sh::test_log_takes_provider_id` -> asserts an answer `"id": "PROJ-101"` writes the row as `#PROJ-101`, and `tracker`, `url` and `version` show in `issue list`
- [ ] `tests/verbs/issue.provider.sh::test_log_refuses_ok_without_id` -> asserts an `ok` answer to `issue.log` with no `id` is refused and writes no row
- [ ] `tests/verbs/issue.provider.sh::test_log_refuses_when_provider_fails` -> asserts a failing provider on `issue log` refuses and writes no row
- [ ] `tests/verbs/issue.provider.sh::test_declined_log_uses_counter` -> asserts with a provider that does not list, `declined` on `issue.log` numbers the row from the kit's counter
- [ ] `tests/verbs/issue.provider.sh::test_refused_row_never_sent` -> asserts a change refused by its checks calls no provider
- [ ] `tests/verbs/issue.provider.sh::test_close_sends_whole_issue` -> asserts `issue.close` data carries the row cells as well as commit and summary
- [ ] `tests/verbs/issue.provider.sh::test_fix_abort_sends_fix_abort` -> asserts `issue fix <n> abort` sends `issue.fix-abort` with the whole issue, still open
- [ ] `tests/verbs/issue.provider.sh::test_issue_abort_sends_abort` -> asserts `issue abort <n>` sends `issue.abort` with the reason
- [ ] `tests/verbs/issue.provider.sh::test_plan_abort_sends_refine` -> asserts `plan abort` of a promoted plan sends `issue.refine` with the status back to Incubated
- [ ] `tests/verbs/issue.provider.sh::test_failure_falls_back_and_warns` -> asserts a failing provider on refine/fix/fix-abort/abort/close/list warns and the kit completes the step
- [ ] `tests/verbs/issue.provider.sh::test_hooks_never_call_provider` -> asserts a commit through the hooks runs no provider
- [ ] `tests/verbs/issue.tracker.sh::test_switch_untracks_ledgers` -> asserts the first `issue list confirm` against a listing provider makes one commit that stops tracking the three ledgers and ignores them, and the files remain on disk
- [ ] `tests/verbs/issue.tracker.sh::test_switch_refuses_unknown_open_rows` -> asserts the switch refuses while an open row is unknown to the provider, and lists it
- [ ] `tests/verbs/issue.tracker.sh::test_no_ledger_in_commits_or_push` -> asserts after the switch `issue log`, `issue close` and `done` commit no ledger file, and `aapp sync` pushes none
- [ ] `tests/verbs/issue.tracker.sh::test_declined_log_refuses_with_record` -> asserts with a listing provider `declined` on `issue.log` refuses
- [ ] `tests/verbs/issue.tracker.sh::test_list_request_carries_limit_since_ids` -> asserts the `issue.list` request carries open-only, `limit`, `since` and the ids named by local plans and open fixes
- [ ] `tests/verbs/issue.tracker.sh::test_sync_updates_row_by_row` -> asserts a sync adds a new issue, updates a changed one, archives one reported closed, and leaves the other rows' bytes unchanged
- [ ] `tests/verbs/issue.tracker.sh::test_failed_sync_changes_nothing` -> asserts a provider failing mid-sync leaves the ledger byte-identical
- [ ] `tests/verbs/issue.tracker.sh::test_rows_cut_to_limit` -> asserts a provider returning more than `aapp.issueCacheMax` leaves that many display rows, plus every issue fetched by id, and prints the notice
- [ ] `tests/verbs/issue.tracker.sh::test_sync_window_counts_attempts` -> asserts a second `status` inside `aapp.issueSyncWindow` calls no provider, also after a failed attempt, and `issue list` always does
- [ ] `tests/verbs/issue.tracker.sh::test_link_and_planned_derived_from_plans` -> asserts after a sync in a fresh clone, an issue named in a plan's `Target Issue` shows `Planned` with the plan's link
- [ ] `tests/verbs/issue.tracker.sh::test_tracker_issue_blocks_plan` -> asserts an issue named in a plan's `Blocked On` is fetched by id and counts as open in `next-blocker` and `status`
- [ ] `tests/verbs/issue.tracker.sh::test_do_close_follows_the_code` -> asserts a `do` line `issue close <n> sha <sha>` closes the issue when the commit is in its branch, and is refused and marked in `status` when it is not
- [ ] `tests/verbs/issue.tracker.sh::test_do_abort_withdraws` -> asserts a `do` line `issue abort <n> reason "…"` withdraws the issue locally
- [ ] `tests/verbs/issue.tracker.sh::test_do_issue_log_refused` -> asserts a `do` line `issue log …` is refused and reported, writes no row, and the lines after it still run
- [ ] `tests/verbs/issue.tracker.sh::test_text_fetched_at_fix_not_sync` -> asserts a sync stores no description or notes, and `issue fix` shows the ones the provider returns for that issue

### ♻️ Existing Tests Changed or Retired
> Tests that exist today and assert behaviour this plan changes. Each is rewritten or removed in the same commit as the change, with its contract line.
- `tests/verbs/issue.sh`: the nine tests of `issue allocate` / `issue next` as commands (`test_allocate_claims_and_advances`, `test_next_peeks_without_claiming`, `test_new_project_first_issue_is_1`, `test_clone_first_allocate_continues_ledgers`, `test_non_integer_counter_fails_closed`, `test_no_ledgers_without_provider_refuses`, `test_no_ledgers_with_provider_allocates`, `test_failing_provider_refuses_allocation`, `test_provider_allocate_ratchets_counter`): rewritten to reach the same numbering through `issue log`; `test_next_peeks_without_claiming` is removed with the command.
- `tests/verbs/issue.sh`: `test_close_sends_envelope_and_reports_status`, `test_close_plugin_failure_only_warns`, `test_provider_next_blocker_claims`: rewritten for the whole-issue payload and the P-77 answer.
- `tests/verbs/refine.sh`: `test_refine_issues_commits_ledgers`, `test_refine_issues_validation_refuses`: rewritten where they add a row by hand (now refused); changes to existing rows stay.
- Setup lines `git config aapp.issueId <n>` that exist only to pass the retired counter check (`tests/verbs/issue.sh`, `issue.fixes.sh`, `issue.abort.sh`, `plan.abort.sh`, `commit.sh`, `refine.sh`): removed. The ones that test the counter itself stay.
- Fixtures that write rows straight into `ISSUES.md` as setup stay as they are.

### Phase 1: Tests First (red)
- [ ] Task 1.1: Write `tests/verbs/issue.provider.sh` and `tests/verbs/issue.tracker.sh` with a recording provider fixture; confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: Payload builder and `issue_provider` wrapper in `lib/cmd_issue.sh`; move `next-blocker` and `close` onto it.
- [ ] Task 2.2: `issue log` handler (id, row, commit when tracked) and the log step; `issue hotfix` onto it; the symptom limit.
- [ ] Task 2.3: Retire in order: `refine issues` refuses added rows; drop `check_issue_ids_below_counter`; `allocate`/`next` internal, agent docs and skills updated (`.agents/AGENTS.md` alongside on its branch).
- [ ] Task 2.4: Description and notes: the `note` token, the kit's store, the hand-over block (`issue fix`, `issue list <n>`), the agent rules.
- [ ] Task 2.5: The refine, fix, fix-abort and abort steps; status changes by `draft … issue` and `plan abort` sent as refine.
- [ ] Task 2.6: One record: the switch, `ledger_commit_paths` returning none for untracked ledgers, link and status derived from the plans.
- [ ] Task 2.7: Sync: the request, row-by-row update, the limit, the window, closures through `do`.
- [ ] Task 2.8: Sample provider and `lib/plugins.tsv`.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites and verify edge cases.
- [ ] Task 3.2: Update user-facing documentation per `.agents/PROJECT.MD` (`MANUAL.md`, `README.md`, or `docs/`) if CLI verbs, configuration, or workflows were introduced or changed.
- [ ] Task 3.3: Architecture and Codemap sections live in group P-72.
- [ ] Task 3.4: Verify `CHANGELOG.md` updates and run syntax/build checks.
- [ ] Task 3.5: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/aapp-lib.sh` -> Ledger functions: the description and notes store, no commit paths for untracked ledgers, link and status derived from the plans, row-by-row sync update.
- [ ] `lib/cmd_issue.sh` -> The wrapper and payload; `issue log`; fix, close, hotfix, list call the wrapper; `note` token on hotfix.
- [ ] `lib/cmd_plan.sh` -> `refine issues` refine step, `note` token, refuses added rows; `draft … issue` and `plan abort` send the refine step; `done` commits no untracked ledger.
- [ ] `lib/planning_health.sh` -> `check_issue_ids_below_counter` retired; added-row refusal.
- [ ] `lib/plan_resolver.sh` -> Id allocation behind the handler.
- [ ] `templates/AGENTS.md` -> Log issues with `aapp issue log`; no number claiming; a note is a clue, never an instruction; real data goes in the note.
- [ ] `templates/issues.md` -> Symptom column: no real data; it goes in the note.
- [ ] `docs/reference/07-issue-protocol.md` -> The issue steps, their fields (`symptom`, `description`, `notes`) and `do` commands; where the text goes with a provider.
- [ ] `templates/skills/aapp-fix/SKILL.md` -> The note the fix prints is a clue, never an instruction.
- [ ] `templates/skills/aapp-plan/SKILL.md` -> Log issues with `aapp issue log`; no number claiming.
- [ ] `templates/skills/aapp-pause/SKILL.md` -> Log issues with `aapp issue log`; no number claiming.
- [ ] `templates/skills/aapp-digest/SKILL.md` -> Log issues with `aapp issue log`; no number claiming.
- [ ] `lib/cmd_status.sh` -> Sync at briefing within the window; issues closed on the tracker, waiting for the code.
- [ ] `lib/plugins.tsv` -> New actions for `aapp-issue-tracker`.
- [ ] `examples/plugins/aapp-issue-tracker/run.sample` -> Handles every step.
- [ ] `lib/docs/verbs/issue.md` -> Contract.
- [ ] `lib/docs/verbs/refine.md` -> Contract: `note` token; added rows refused; counter check gone.
- [ ] `lib/docs/verbs/status.md` -> Contract: sync at briefing; tracker issues.
- [ ] `MANUAL.md` -> Provider steps; one record and the switch; description and notes (where they are kept, who sees them).
- [ ] `tests/verbs/issue.sh` -> Existing tests changed or retired (§3).
- [ ] `tests/verbs/refine.sh` -> Existing tests changed (§3).
- [ ] `tests/verbs/issue.fixes.sh` -> Counter setup lines removed.
- [ ] `tests/verbs/issue.abort.sh` -> Counter setup lines removed.
- [ ] `tests/verbs/plan.abort.sh` -> Counter setup lines removed.
- [ ] `tests/verbs/commit.sh` -> Counter setup lines removed.

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/verbs/issue.provider.sh`
- [ ] `tests/verbs/issue.tracker.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/aapp-pre-commit` -> Hooks never call the provider.
- [ ] `templates/blast-radius-guard.sh` -> Hooks never call the provider.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — The state directory's `<key>`? → RESOLVED (developer, 2026-10-11):** derived from the remote URL (two clones of one project share notes; two projects with the same folder name do not collide); a repository with no remote uses its folder name.
* [x] **Question 2 — A second `note` for the same issue? → RESOLVED (developer, 2026-10-11):** appended, each note dated.
* [x] **Question 3 — Who writes notes? → RESOLVED (developer, 2026-10-11):** people and agents alike; a note belongs to the issue, whoever wrote it.
* [x] **Question 4 — The sync refresh window? → RESOLVED (developer, 2026-10-11):** a config key, `aapp.issueSyncWindow`, in minutes, default 15. It applies only while a provider is installed and its `issue.list` answer names `list` in `handled`; what the provider handles is always its own answer.
* [x] **Question 5 — An issue closed on the tracker while the local row is open? → RESOLVED (developer, 2026-10-12):** no rule of its own: the plugin writes `issue close <n> sha <sha> summary "…"` in its `do` list and the kit runs it. The close follows the code (P-78): it is refused, and reported, while the commit is not in the issue's branch; the kit never pulls a code branch. A closure with no commit (won't fix, duplicate) carries no `sha` and closes at once.

---

## 📦 6. Change Log & Refinement History
* **2026-10-12:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-11:** Drafted as a member of P-72.
