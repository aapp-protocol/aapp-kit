# 🗺️ Plan P-74: Issue Provider Wrapper
* **Created:** 2026-10-11 | **Last Refined:** 2026-10-11
* **Target Issue / Milestone:** none
* **Plan ID:** P-74
* **Changelog:** Added: the `aapp-issue-tracker` provider gets the whole issue at log, refine, fix, close and list; issue notes; remote issues (P-74)
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

This plan routes every issue step through one wrapper inside `lib/issue_ledger.sh` (P-73). The provider receives the whole issue and decides, per part, whether it handles it or leaves it to the kit. Issues it lists have the same rights as local ones. Short notes (a few phrases of clue) get a home outside the repository.

---

## 2. Technical Blueprint
**Wrapper:** `issue_provider <step> <n> [<step data>…]` in `lib/issue_ledger.sh`. With a provider installed it builds the payload and calls `run_action_plugin`; without one it runs the kit's internals.

| Step | Called by | Action |
|---|---|---|
| log | `refine issues` (new rows), `issue hotfix` | `issue.log` |
| refine | `refine issues` (rows changed against HEAD) | `issue.refine` |
| fix | `issue fix <n>`, `issue fix next-blocker` | `issue.fix` |
| close | `issue close`, `done` | `issue.close` |
| list | `issue list`, `status` | `issue.list` |

- **Payload:** the Plugin Payload Standard envelope; `data` carries the whole issue: id, severity, type, date, location, symptom, link, status, note, and the step's own fields (commit, summary, plan). Sent after the step's commit lands, so a refused row never reaches the provider.
- **Answer:** `{"status": …, "kit": [<part>…]}`. `kit` names what the kit still handles (`note`, `cache`); no `kit` field means the kit handles everything, so current providers keep working.
- **Notes:** a bare `note` token. `aapp refine issues "<msg>" note <n> "<text>"` (repeatable; with only `note` tokens and no ledger change it still runs the wrapper) and `aapp issue hotfix "<text>" … note "<text>"`. Never written to the ledger. Kit store: `~/.local/state/aapp/<key>/issues-data.md`. `issue fix` prints the note as the fix opens.
- **Remote issues:** `issue.list` answers `{"issues": [{…}, …]}` in the payload's issue shape. The kit writes them to `~/.local/state/aapp/<key>/remote-issues.tsv`; `ledger_rows` and `ledger_locate` merge it (`remote`), so they block plans and show in `status`, `issue list`, `draft` and `next-blocker`. On an id present on both sides, the local lifecycle cells win.
- **Acting on a remote issue:** `issue fix`, `draft … issue` and `next-blocker` first write its row into `ISSUES.md` through the log step, then proceed as for a local row.
- **Id clash** (same id, different issue): both shown and marked; `fix` and `draft … issue` refuse that id. A provider that answers `issue.list` must also answer `issue.allocate`.
- **Sync:** only at `issue list` and `status`, within a refresh window; hooks read the ledger and the cache, never the network.
- **Failures:** the step falls back to the kit and warns; `issue.allocate` and `issue.next-blocker` stay authoritative and refuse, as today.
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
- [ ] `tests/verbs/issue.provider.sh::test_failure_falls_back_and_warns` -> asserts a failing provider on log/refine/fix/close/list warns and the kit completes the step
- [ ] `tests/verbs/issue.provider.sh::test_hooks_never_call_provider` -> asserts a commit through the hooks runs no provider

### Phase 1: Tests First (red)
- [ ] Task 1.1: Write `tests/verbs/issue.provider.sh` with a recording provider fixture; confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: Payload builder and `issue_provider` wrapper in `lib/issue_ledger.sh`; move `allocate`, `next-blocker` and `close` onto it.
- [ ] Task 2.2: log and refine steps from `refine issues` and `issue hotfix`; the `note` token; the kit's note store.
- [ ] Task 2.3: fix step: note printed; remote rows imported.
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
- [ ] `lib/issue_ledger.sh` -> Wrapper, payload, note store, remote cache and merge.
- [ ] `lib/cmd_issue.sh` -> fix, close, hotfix, list call the wrapper; `note` token on hotfix.
- [ ] `lib/cmd_plan.sh` -> `refine issues` log/refine steps and `note` token; `draft … issue` imports remote rows.
- [ ] `lib/cmd_status.sh` -> list step at briefing.
- [ ] `lib/plugins.tsv` -> New actions for `aapp-issue-tracker`.
- [ ] `examples/plugins/aapp-issue-tracker/run.sample` -> Handles every step.
- [ ] `lib/docs/verbs/issue.md` -> Contract.
- [ ] `lib/docs/verbs/refine.md` -> Contract: `note` token.
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
* [ ] **Question 1:** The state directory's `<key>`: the remote URL (two clones of one project share notes; two projects with the same folder name don't collide), or the project name?
* [ ] **Question 2:** A second `note` for the same issue: appended, or replaces the first?
* [ ] **Question 3:** Who writes notes: people only, or also the agent that logs the issue?
* [ ] **Question 4:** The sync refresh window: a fixed length, or a config key?

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-11:** Drafted as a member of P-72.
