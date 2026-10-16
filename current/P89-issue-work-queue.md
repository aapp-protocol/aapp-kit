# 🗺️ Plan P-89: Issue Work Queue
* **Created:** 2026-10-15 | **Last Refined:** 2026-10-15
* **Target Issue / Milestone:** none
* **Plan ID:** P-89
* **Changelog:** Changed: the road map is a work queue in three levels; `aapp issue queue`; fixes only for queued issues; lists show severity and dates (P-89)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** ⚡ In Development
* **Base:** `6cf5dba` (develop)
* **Worktree:** .workspace/P89 (plan/P89-issue-work-queue)
* **Commits:** `f450ec8` (plan/P89-issue-work-queue), `a8ece7e` (plan/P89-issue-work-queue), `048c0a2` (plan/P89-issue-work-queue), `2d0feb8` (plan/P89-issue-work-queue)
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
`ISSUES.md` is the single flat ledger holding every active issue; `aapp issue list` lists them in recorded sequence (with sorting/filtering the domain of plugins). 

Currently, `issues_road_map.md` duplicates the entire issue ledger across hand-curated bands (`User Priority`, `High`, `Medium`, `Low`, `Triage`), adding redundant ledger-maintenance overhead without providing an execution gate.

Crucially, **the lack of an execution gate creates a severe governance flaw**: autonomous agents can log an issue and immediately start implementing it (`aapp issue fix <num>`), opening an un-gated back-door to cover mistakes or perform un-reviewed refactoring. While plans must pass human review into the Greenlight Zone (`aapp freeze`) before execution, issues currently have no equivalent gate.

This plan transforms `issues_road_map.md` into a lean **Active Work Queue** and establishes human-in-the-loop queueing:
1. `issues_road_map.md` retains only two sections:
   - `## 🧱 Plan Blockers`: emergency hotfixes from active plans (`aapp issue hotfix`), capped by `aapp.maxEmergencyHotfixes`.
   - `## 📋 Queued`: issues explicitly approved and queued for agent work by a human via `aapp issue queue <num>`.
2. All other issues exist solely in `ISSUES.md` (and display via `aapp issue list`). The legacy priority bands (`User Priority`, `High`, `Medium`, `Low`, `Triage`) are removed cleanly.
3. `aapp issue fix <num>` enforces the gate: it **refuses closed** unless `#<num>` is in `🧱 Plan Blockers` or `📋 Queued`.

---

## 2. Technical Blueprint

### 2.1 The Active Work Queue Structure (`issues_road_map.md`)
`issues_road_map.md` is reduced to two execution sections:

```markdown
# 🗺️ Issue Work Queue

## 🧱 Plan Blockers
<!-- Written automatically by 'aapp issue hotfix'. Capped per plan by aapp.maxEmergencyHotfixes. -->

## 📋 Queued
### 🔺 Urgent
- [ ] #12 -> Login fails on Safari (queued 2026-10-16)
### Normal
- [ ] #7 -> Slow export (queued 2026-10-02)
- [ ] #19 -> Wrong rounding (queued 2026-10-11)
### Low
- [ ] #4 -> Typo in help (queued 2026-09-20)
```

- `## 📋 Queued` holds three levels, `### 🔺 Urgent`, `### Normal` and `### Low`, always in that order. Inside a level the oldest entry comes first (an entry is appended), so an issue that waits rises as the ones above it are done.
- A queued line carries the date it was queued: `- [ ] #<num> -> <symptom> (queued <YYYY-MM-DD>)`; the work queue is the only place that date is known. Severity and the date an issue was logged stay in its row and are read from there for display (2.9), never copied.

- When an issue is logged (`aapp issue log`), it is recorded solely in `ISSUES.md`. It no longer appends a line to `issues_road_map.md`.
- Legacy priority bands (`User Priority`, `High Priority`, `Medium Priority`, `Low Priority`, `Triage`) are eliminated as a clean break.
- `ISSUES.md` keeps its format: every column stays, the `Sev` cell included.

### 2.2 CLI Verb: `aapp issue queue <num> [remove]`
A dedicated verb under `aapp issue` allows humans to manage the work queue:
- `aapp issue queue <num> [urgent | low]`:
  - Verifies `#<num>` is an active issue in `ISSUES.md` (its status cell holds `Incubated` or `Planned`; matched on the word, not the emoji).
  - Refuses if `#<num>` is a plan blocker, or already queued at that level.
  - Appends `- [ ] #<num> -> <symptom> (queued <today>)` at the end of the level: `### Normal` by default, `### 🔺 Urgent` with `urgent`, `### Low` with `low`.
  - An issue already queued at another level moves there, keeping its queue date, at the end of its new level: `issue(queue): #<num> moved to <level>`.
  - Commits the change in the `.plans` worktree as `issue(queue): #<num> queued (<level>)`.
  - Sends the provider step `issue.queue` (see 2.6).
- `aapp issue queue <num> remove`:
  - Removes `#<num>` from `## 📋 Queued`.
  - Commits in `.plans` as `issue(queue): #<num> unqueued`.
  - Sends the provider step `issue.unqueue` (see 2.6).
- **Agent Rule Invariant**: Only a person may run `aapp issue queue`. Autonomous agents are strictly forbidden from self-queueing issues.

### 2.3 Enforcement Gate on `aapp issue fix`
`aapp issue fix [next-blocker | <num>]` validates the queue status before opening any fix:
- If `<num>` is provided:
  - Checks if `#<num>` is present in `## 🧱 Plan Blockers` or `## 📋 Queued` of `issues_road_map.md`.
  - If NOT present: **refuses closed**:
    ```text
    ❌ [Issue] #<num> is not queued for work.
       A human must queue it first: 'aapp issue queue <num>'.
    ```
- If invoked without arguments or as `next-blocker`:
  - Claims the first available issue from `## 🧱 Plan Blockers`.
  - If no blockers exist, claims the first available issue from `## 📋 Queued`: Urgent, then Normal, then Low, oldest first in each.
  - If neither exists, refuses closed with diagnostic.
- `next-blocker` keeps its name; the contract, the fix skill and the agent rules say it takes a queued issue once no blocker is left.

### 2.4 Promotion & Lifecycle Integration
- When an issue is promoted to a plan (`aapp draft <slug> issue <num>`):
  - Its entry in `## 📋 Queued` is updated to reflect its plan link: `- [ ] #<num> -> <symptom> [P-XX](...)`.
  - It remains in `## 📋 Queued` until the plan ships.
  - When the plan is archived (`aapp done`), the issue row is relocated to `000-issues-archive.md` and pruned from `issues_road_map.md`.
- When an issue is aborted (`aapp issue abort <num>`):
  - Pruned from `issues_road_map.md` (blocker or queued) and archived as aborted.

### 2.5 Briefing & Planning Health
- **Briefing (`aapp status`)**: The `🐛 [2/4] ISSUES` pillar displays:
  - Active `🧱 Plan Blockers`.
  - Active `📋 Queued` issues ready for work, by level.
  - A summary count of unqueued issues remaining in `ISSUES.md`.
  - Each issue in the display form of 2.9.
- **Planning Health (`lib/planning_health.sh`)**:
  - Validates `issues_road_map.md` against the two-section specification.
  - Knows only the two sections and the three levels under `## 📋 Queued` (`### 🔺 Urgent`, `### Normal`, `### Low`): any other `##` or `###` heading is refused as not part of the work queue, naming the valid ones. No code, template, document or test of the kit names the former bands; after this plan they exist only in history.
  - Validates that every entry in `issues_road_map.md` exists as an active issue in `ISSUES.md`.

### 2.9 What the displays show
Deciding what to queue, at which level, needs the issue's facts in front of whoever decides: a person, an orchestrating agent, an agent. `aapp issue list` and the Issues pillar of `aapp status` show one line per issue:
```
  #12  High    Incubated  logged 2026-10-01  queued 2026-10-16 (Urgent)  Login fails on Safari
  #7   Medium  Planned    logged 2026-09-28  queued 2026-10-02 (Normal)  Slow export  [P-91]
  #33  Low     Incubated  logged 2026-10-14                              Typo in the manual
```
- Severity, status and the logged date come from the issue's row; the queue date and level from the work queue; a `Planned` issue names its plan.
- `aapp issue list` keeps the recorded order and its caps; once issues name branches each line ends with `(branch: <name>)`, as now.
- Severity is shown, never used to order: ordering is the queue's levels, and anything else a sorting plugin's.

### 2.6 The tracker has priority (P-74)
- `aapp issue queue <num>` and `queue <num> remove` are provider steps, `issue.queue` and `issue.unqueue`, sent through `issue_provider` with the whole issue as data, like every other step.
- **Where a provider keeps the record** (it lists issues, P-74): the tracker's queue is the queue. A failing or refusing `issue.queue` / `issue.unqueue` refuses the command and nothing changes locally. The listing reports each issue's `queued` field (`true` or `false`) and, for a queued issue, `priority` (`urgent`, `normal` or `low`; `normal` when absent) and `queued_at` (a date), and the sync rebuilds the three levels from them, in the listing's order inside each level; `issue.queue` carries the level as `priority`; the fix gate reads the rebuilt section, so every clone sees the same queue.
- **Without a provider, or one that does not list:** the local `## 📋 Queued` is the record, committed to the plans branch; a failing step only warns.
- The steps join `aapp-issue-tracker` in `lib/plugins.tsv`, `docs/reference/07-issue-protocol.md` and the sample provider.

### 2.7 Every reader of the road map
- The road map is read and written only through the ledger functions in `lib/aapp-lib.sh` (P-73): `roadmap_add_entry` and the Triage section go; `roadmap_queue_add` / `roadmap_queue_remove` / `roadmap_queued` are added; `roadmap_blockers` and `roadmap_prune` keep working on the two sections.
- `aapp issue log` adds no line; the tracker sync adds none for a row it brings; `aapp offline sync` (P-75) rewrites a former id in both sections.
- The start gate in `lib/cmd_plan.sh` reads the blockers through `issue_queued_blockers`, which stays; `lib/cmd_plan.sh` is not changed.
- The digest and status skills stop telling agents to read the board's priority order; the order of `aapp issue list` is the recorded order, and a plugin may sort it.

### 2.8 The Clean Break Invariant, stated in full
`templates/AGENTS.md`, *Clean Break Invariant & Fallback Governance*, gains one bullet: **No trace of the old form.** After a clean break nothing in the codebase detects, names, refuses by name, converts or explains the old form: no migration message, no list of former names, no test that mentions them. The new code knows only the new form; anything else is invalid because it is unknown. The old form lives on only in Git history and in the plan that replaced it.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break`
- **Fallback Inventory**: `None (Clean Break)`
- Existing `.plans/issues_road_map.md` in this repository and template `templates/issues_road_map.md` are migrated directly to the two-section layout.

---

## 🔨 3. Implementation Steps & Execution Checklist

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [ ] `tests/verbs/issue.queue.sh::test_queue_appends_to_road_map` -> asserts `aapp issue queue <num>` adds issue to `## 📋 Queued` in `issues_road_map.md` and commits in `.plans`
- [ ] `tests/verbs/issue.queue.sh::test_queue_remove` -> asserts `aapp issue queue <num> remove` removes the entry and commits
- [ ] `tests/verbs/issue.queue.sh::test_queue_refuses_invalid_or_resolved` -> asserts queueing a non-existent or resolved issue fails closed
- [ ] `tests/verbs/issue.queue.sh::test_fix_refuses_unqueued_issue` -> asserts `aapp issue fix <num>` fails closed with error when issue is not in blockers or queued
- [ ] `tests/verbs/issue.queue.sh::test_fix_accepts_queued_issue` -> asserts `aapp issue fix <num>` opens cleanly when issue is in `## 📋 Queued`
- [ ] `tests/verbs/issue.queue.sh::test_fix_next_blocker_falls_back_to_queued` -> asserts `aapp issue fix` with no blockers claims the top queued issue
- [ ] `tests/verbs/issue.queue.sh::test_log_does_not_append_to_road_map` -> asserts `aapp issue log` writes solely to `ISSUES.md` without touching `issues_road_map.md`
- [ ] `tests/verbs/issue.queue.sh::test_planning_health_validates_queue_format` -> asserts health check passes on the two-section road map and refuses any other section (a fixture heading such as `## Other`)
- [ ] `tests/verbs/issue.queue.sh::test_queue_sends_provider_steps` -> asserts `queue` and `queue remove` send `issue.queue` / `issue.unqueue` with the issue
- [ ] `tests/verbs/issue.queue.sh::test_listing_provider_owns_the_queue` -> asserts with a listing provider a refused `issue.queue` changes nothing locally, and the sync rebuilds `## 📋 Queued` from the listing's `queued` field
- [ ] `tests/verbs/issue.queue.sh::test_queue_levels` -> asserts `queue <num>` lands in `### Normal`, `urgent` in `### 🔺 Urgent`, `low` in `### Low`, each line ending `(queued <today>)`
- [ ] `tests/verbs/issue.queue.sh::test_queue_moves_between_levels` -> asserts queueing a queued issue at another level moves it with its queue date, one commit
- [ ] `tests/verbs/issue.queue.sh::test_next_blocker_takes_levels_in_order` -> asserts with no blocker `fix next-blocker` takes Urgent before Normal before Low, oldest first in a level
- [ ] `tests/verbs/issue.queue.sh::test_health_knows_the_levels` -> asserts the three levels pass and another `###` heading under the work queue is refused
- [ ] `tests/verbs/issue.queue.sh::test_list_shows_severity_dates_status` -> asserts `aapp issue list` shows each issue's severity, status, logged date, and for a queued one its queue date and level
- [ ] `tests/verbs/issue.queue.sh::test_status_shows_queue_with_facts` -> asserts the Issues pillar shows the queue by level with severity and dates
- [ ] `tests/verbs/issue.queue.sh::test_listing_priority_rebuilds_levels` -> asserts a listing's `priority` and `queued_at` place the issues in their levels
- [ ] `tests/verbs/issue.queue.sh::test_offline_sync_rewrites_queued_id` -> asserts `aapp offline sync` rewrites a former id in `## 📋 Queued`

### ♻️ Existing Tests Changed or Retired
> Tests that exist today and assert behaviour this plan changes. Each is rewritten or removed in the same commit as the change, with its contract line.
- Fixtures writing road maps with the legacy bands, and assertions that `aapp issue log` or the sync adds a road-map line: `tests/issue_ledger_test.sh`, `tests/plugin_protocol_test.sh`, `tests/pre-commit_test.sh`, `tests/write-guard_test.sh`, and in `tests/verbs/`: `issue.sh`, `issue.provider.sh`, `issue.tracker.sh`, `issue.keyid.sh`, `issue.branch.sh`, `issue.branchplugin.sh`, `issue.fixes.sh`, `issue.abort.sh`, `issue.notefilter.sh`, `offline.sh`, `commit.sh`, `draft.sh`, `refine.sh`, `start.sh`, `freeze-start.sh`, `plan.abort.sh`: rewritten to the two sections.

### Phase 1: Tests First (red)
- [ ] Task 1.1: Author `tests/verbs/issue.queue.sh` covering queue verb and fix gate assertions; confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: `lib/aapp-lib.sh` (ledger section): `roadmap_queue_add`, `roadmap_queue_remove`, `roadmap_queued`; the road map helpers on the two-section layout; `roadmap_add_entry` and Triage retired.
- [ ] Task 2.2: `lib/cmd_issue.sh`: Implement `aapp issue queue <num> [remove]`; enforce queue check in `cmd_issue_fix`; decouple `cmd_issue_log` from road map appending.
- [ ] Task 2.3: `lib/cmd_status.sh`: Update Issues pillar of briefing to show blockers, queued issues, and count of unqueued issues.
- [ ] Task 2.4: `lib/planning_health.sh`: Update roadmap verification rules for the two-section queue format.
- [ ] Task 2.5: The provider steps `issue.queue` / `issue.unqueue`, the listing's `queued` field and the rebuild of `## 📋 Queued` at sync (`lib/cmd_issue.sh`, `lib/plugins.tsv`, `docs/reference/07-issue-protocol.md`, the sample provider).
- [ ] Task 2.6: `lib/cmd_offline.sh`: the offline road map in the two sections; `aapp offline sync` rewrites ids in both.
- [ ] Task 2.7: Rewrite the existing tests listed above.
- [ ] Task 2.8: `templates/AGENTS.md`: the *No trace of the old form* bullet of the Clean Break Invariant.
- [ ] Task 2.9: The three levels: `queue <num> [urgent | low]`, moving between levels, the queue date, `next-blocker`'s order, the health check, the tracker's `priority` and `queued_at`.
- [ ] Task 2.10: The display form of 2.9 in `aapp issue list` and the Issues pillar.
- [ ] Task 2.11: `lib/hook_dispatcher.sh`: `json_field` also reads `true` and `false`.
- [ ] Task 2.12: `tests/verbs/issue.onecommit.sh`: its issues are queued before they are fixed.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites across all verbs.
- [ ] Task 3.2: Update `templates/issues_road_map.md`, `templates/issues.md`, `templates/state_matrix.md`, `templates/architecture.md`, `templates/AGENTS.md`, the fix, digest and status skills.
- [ ] Task 3.3: Update `MANUAL.md`, `CHEATSHEET.md`, `ARCHITECTURE.md`, `README.md`, `lib/docs/verbs/issue.md`, `lib/docs/verbs/status.md`.
- [ ] Task 3.4: Migrate active `.plans/issues_road_map.md`.
- [ ] Task 3.5: Run syntax, build, and test verification before plan completion.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_issue.sh` -> `aapp issue queue` command, `cmd_issue_fix` queue gate, decouple `cmd_issue_log`.
- [ ] `lib/aapp-lib.sh` -> Road map queue helpers, two-section parsing (ledger section).
- [ ] `lib/cmd_offline.sh` -> The offline road map in two sections; id rewrite in both.
- [ ] `lib/plugins.tsv` -> `issue.queue`, `issue.unqueue` in the provider's events.
- [ ] `lib/docs/verbs/offline.md` -> Contract: the offline road map.
- [ ] `docs/reference/07-issue-protocol.md` -> The two steps and the listing's `queued` field.
- [ ] `examples/plugins/aapp-issue-tracker/run.sample` -> The sample answers the two steps.
- [ ] `templates/issues.md` -> The ledger's note on the road map.
- [ ] `templates/state_matrix.md` -> The note on where issues are sequenced.
- [ ] `templates/architecture.md` -> The road map's line in the layout.
- [ ] `templates/skills/aapp-digest/SKILL.md` -> No board order to follow.
- [ ] `templates/skills/aapp-status/SKILL.md` -> The Issues pillar: blockers, queued, count of the rest.
- [ ] `lib/cmd_status.sh` -> Update briefing Issues pillar for queued layout.
- [ ] `lib/planning_health.sh` -> Validate two-section road map structure.
- [ ] `lib/docs/verbs/issue.md` -> Document `aapp issue queue` and queue gate.
- [ ] `templates/issues_road_map.md` -> Two-section template (`Blockers`, `Queued`).
- [ ] `templates/AGENTS.md` -> Human queue gate invariant; agents cannot self-queue; the Clean Break Invariant states that no trace of the old form remains.
- [ ] `templates/skills/aapp-fix/SKILL.md` -> Updated fix skill reflecting queue gate.
- [ ] `MANUAL.md` -> Issue lifecycle, work queue specification, `aapp issue queue`.
- [ ] `CHEATSHEET.md` -> `aapp issue queue <num> [remove]` CLI reference.
- [ ] `ARCHITECTURE.md` -> Two-lane queue architecture and human-in-the-loop gate.
- [ ] `README.md` -> The road map's line in the layout and in the hook's hygiene.
- [ ] `lib/hook_dispatcher.sh` -> `json_field` reads `true` and `false` (the listing's `queued`).
- [ ] `lib/docs/verbs/refine.md` -> Contract: the ledger validation names a work-queue section other than the known ones.
- [ ] `tests/verbs/issue.onecommit.sh` -> Existing tests: issues queued before they are fixed.
- [ ] `lib/docs/verbs/status.md` -> Contract: the Issues pillar shows blockers, queued issues and a count of the rest.
- [ ] `NEW FILE` -> `tests/verbs/issue.queue.sh` -> Failure and boundary tests.
- [ ] `tests/issue_ledger_test.sh` -> Existing tests (§3).
- [ ] `tests/plugin_protocol_test.sh` -> Existing tests (§3).
- [ ] `tests/pre-commit_test.sh` -> Existing tests (§3).
- [ ] `tests/write-guard_test.sh` -> Existing tests (§3).
- [ ] `tests/verbs/issue.sh` -> Existing tests (§3).
- [ ] `tests/verbs/issue.provider.sh` -> Existing tests (§3).
- [ ] `tests/verbs/issue.tracker.sh` -> Existing tests (§3).
- [ ] `tests/verbs/issue.keyid.sh` -> Existing tests (§3).
- [ ] `tests/verbs/issue.branch.sh` -> Existing tests (§3).
- [ ] `tests/verbs/issue.branchplugin.sh` -> Existing tests (§3).
- [ ] `tests/verbs/issue.fixes.sh` -> Existing tests (§3).
- [ ] `tests/verbs/issue.abort.sh` -> Existing tests (§3).
- [ ] `tests/verbs/issue.notefilter.sh` -> Existing tests (§3).
- [ ] `tests/verbs/offline.sh` -> Existing tests (§3).
- [ ] `tests/verbs/commit.sh` -> Existing tests (§3).
- [ ] `tests/verbs/draft.sh` -> Existing tests (§3).
- [ ] `tests/verbs/refine.sh` -> Existing tests (§3).
- [ ] `tests/verbs/start.sh` -> Existing tests (§3).
- [ ] `tests/verbs/freeze-start.sh` -> Existing tests (§3).
- [ ] `tests/verbs/plan.abort.sh` -> Existing tests (§3).

### 🧪 Required Test Files
- [ ] `tests/verbs/issue.queue.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Write guard operates on active mini plans; does not touch road map parsing.
- [ ] `lib/cmd_plan.sh` -> The start gate reads blockers through `issue_queued_blockers`, which stays; issue links are kept by the ledger functions.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
* [x] **Question 1 — A tracker that keeps the record. → RESOLVED (developer, 2026-10-15):** the tracker has priority; `aapp issue queue` and its `remove` send provider steps on adding and on removing (2.6).
* [x] **Question 3 — Priority inside the queue. → RESOLVED (developer, 2026-10-16):** three levels under `## 📋 Queued`, Urgent, Normal and Low, oldest first in each, so an issue waits its way up; `aapp issue queue <num> urgent` puts a pressing one on top easily. Issues need it (a bottleneck, a security risk); plans keep their own order and may get priorities later, in a plan of their own.
* [x] **Question 4 — What the displays show. → RESOLVED (developer, 2026-10-16):** `aapp issue list` and the Issues pillar show severity, status, the logged date, and for a queued issue its queue date and level, so a person, an orchestrator or an agent can decide from the list itself (2.9).
* [x] **Question 2 — Legacy bands at the health check. → RESOLVED (developer, 2026-10-15):** a clean break. The health check knows only the two sections and refuses any other heading; the kit keeps no list of the former bands. The refusal names the way on: issues stay in `ISSUES.md`; queue them with `aapp issue queue <num>`.

---

## 📦 6. Change Log & Refinement History
* **2026-10-16:** Plan frozen and activated into ⚡ In Development via freeze-start.
* **2026-10-15:** Plan frozen and activated into ⚡ In Development via freeze-start.
*Tracks how the plan evolved across sessions.*
* **2026-10-16:** Levels Urgent/Normal/Low with queue dates; displays show severity, status and dates; `hook_dispatcher.sh`, `refine.md` and `issue.onecommit.sh` added to the targets.
* **2026-10-15:** Review: the ledger functions live in `lib/aapp-lib.sh`; offline road map, provider steps for the queue, every road-map reader and the existing tests added; the tracker has priority.
* **2026-10-15:** Drafted blueprint: transformed `issues_road_map.md` into an active work queue (`🧱 Plan Blockers` + `📋 Queued`), introduced `aapp issue queue <num>`, and gated `aapp issue fix` against unqueued execution.
