# 🗺️ Plan P-109: Issue Note Companion Lifecycle Events
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** none
* **Plan ID:** P-109
* **Changelog:** Added: pre-issue, on-issue and post-issue on every issue action; post-note and post-companion events (P-109)
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
Hooks are the light extension point: a small script at an exact moment, stackable in `registry.tsv`. Today:
- `issue` has only `post-issue`, and not on every action (`fix <num> abort` fires nothing). Its `aapp-issue-tracker` plugin is a full provider protocol, not a hook.
- `note` and `companion` fire no event at all, a hole in flat logging coverage.

Goal:
- every writing `issue` action fires `pre-issue`, `on-issue` and `post-issue`, mirroring P-99's `refine` (one event per phase, the action in `data.event`);
- `note` and `companion` fire `post-note` and `post-companion`.

Not in this plan: `pre-abort`, an aapp `pre-commit` event, `on-freeze`, `on-done`, `pre-land`, and post events for the other silent actions (see §5 Q1).

---

## 2. Technical Blueprint

### 2.1 Phases (as `refine`, P-99)

| Event | Fires | Default mode | A refusal |
|---|---|---|---|
| `pre-issue` | after arguments are parsed; before the id is taken, the tracker is asked or any ledger, worktree or plan is written | `gate` | nothing changes |
| `on-issue` | after the kit's local writes; just before the commit that records the action | `gate` | the action is rolled back; nothing committed |
| `post-issue` | after that commit (where it fires today) | `notify` | ignored |

Default modes come from the dispatcher's existing rule (`post-*` notify, others gate); `hook_dispatcher.sh` is unchanged.

### 2.2 Issue actions covered

| Action | `data.event` | Commit `on-issue` precedes |
|---|---|---|
| `issue log` | `log` | `issue(log)` |
| `issue hotfix` (both forms) | `hotfix` | `issue(hotfix)` |
| `issue queue <num> [urgent \| low]` | `queue` | `issue(queue)` |
| `issue queue <num> remove` | `unqueue` | `issue(queue)` |
| `issue fix <num>`, `fix next-blocker`, `fix <num> file …` on an open fix | `fix` | `fix(start)` / `fix(files)` |
| `issue fix <num> abort` | `fix-abort` | `fix(abort)` |
| `issue close` | `close` | the archive commit (§5 Q2 for the code landing) |
| `issue abort` | `withdraw` | the withdraw commit |

Read-only `issue list` and `list note` fire nothing. `refine issues` keeps its `refine` events.

### 2.3 Payload
- The `data` object `post-issue` sends today, per action, unchanged: `command: "issue"`, `event`, `issue_id` and the action's fields.
- `pre-issue` of `log` and `hotfix` carries `issue_id: ""` (no id yet), as `pre-refine` carries an empty `plan_id`.
- `on-issue` carries the id and the paths about to be committed (`files`).
- One helper in `lib/cmd_issue.sh`, `_issue_event <phase> <data>`, replaces `_issue_dispatch_hook`. It runs in a subshell like `_refine_event`; `pre`/`on` failures refuse, `post` returns 0.

### 2.4 Order against the tracker plugin
The tracker step (`issue.<step>`) and its `do` list keep their current place in each action. `pre-issue` is the action's first step, before the tracker is asked; `on-issue` sits just before the action's commit; `post-issue` stays where it fires today. The hooks never call the plugin; the plugin is unchanged.

### 2.5 `post-note` and `post-companion`

| Event | Fires after | `data` |
|---|---|---|
| `post-note` | `note stage` (buffer written), `note push`, `note pull` (refs updated) | `command: "note"`, `event: stage \| push \| pull`, `remote`, `refs` |
| `post-companion` | `companion add`, `push`, `remove` succeed | `command: "companion"`, `event: add \| push \| remove`, `name`, `mode`, `path` |

Read-only `note status`, `companion status` and `list` fire nothing.

### 2.6 Documentation
- `aapp hook help`, its "Available events" line and the registry template comment list the new events (and the missing `on-integrate`).
- MANUAL.md's Lifecycle Event Matrix gains the new rows and the six post events it lacks; its "all 14 lifecycle events" count is corrected.
- CHEATSHEET.md's hook-tier row drops the non-existent `on-pickup` / `on-digest` examples.
- `docs/reference/09-event-telemetry.md` gains the new events' payloads; `docs/reference/07-issue-protocol.md` states the order of §2.4.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default) | `Backwards Compatible`
- **Fallback Inventory**: `None (Clean Break)`
  <!-- If Backwards Compatible, list every legacy alias, schema shim, or fallback retained, along with its explicit deprecation/retirement date. Unlisted fallbacks are forbidden. -->

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Failing tests
- [ ] Task 1.1: `tests/hooks_test.sh`: a `pre-issue` gate refusing `log` leaves no id taken and no row; an `on-issue` handler refusing `fix` leaves no worktree, branch or mini plan; a `post-issue` failure leaves the action standing.
- [ ] Task 1.2: `tests/event_telemetry_test.sh`: one `pre-issue`, `on-issue`, `post-issue` per §2.2 action with its `data.event`; `post-note` for stage, push, pull; `post-companion` for add, push, remove.

### Phase 2: Core Implementation
- [ ] Task 2.1: `_issue_event` in `lib/cmd_issue.sh`; wire the three phases into every §2.2 action, rollback on an `on-issue` refusal.
- [ ] Task 2.2: `post-note` in `lib/cmd_note.sh`; `post-companion` in `lib/cmd_companion.sh`.
- [ ] Task 2.3: event lists in `lib/cmd_hook.sh` and `templates/skills/aapp-hooks/registry.tsv`.
- [ ] Task 2.4: verb contracts `issue.md`, `note.md`, `companion.md`: effects and test names.

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
- [ ] `lib/cmd_issue.sh` -> `_issue_event`; three phases on every writing action.
- [ ] `lib/cmd_note.sh` -> `post-note`.
- [ ] `lib/cmd_companion.sh` -> `post-companion`.
- [ ] `lib/cmd_hook.sh` -> help and "Available events" list.
- [ ] `templates/skills/aapp-hooks/registry.tsv` -> event comment.
- [ ] `lib/docs/verbs/issue.md` -> effects, refusals, tests.
- [ ] `lib/docs/verbs/note.md` -> effects, tests.
- [ ] `lib/docs/verbs/companion.md` -> effects, tests.
- [ ] `tests/hooks_test.sh` -> gate and on-refusal cases.
- [ ] `tests/event_telemetry_test.sh` -> coverage of every new dispatch.
- [ ] `docs/reference/09-event-telemetry.md` -> new events and payloads.
- [ ] `docs/reference/07-issue-protocol.md` -> hook order against the tracker.
- [ ] `MANUAL.md` -> Lifecycle Event Matrix.
- [ ] `CHEATSHEET.md` -> hook-tier rows.
- [ ] `ARCHITECTURE.md` -> issue events entry.
- [ ] `.agents/CODEMAP.md` -> Events list.
- [ ] `CHANGELOG.md` -> the plan's entry.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/hook_dispatcher.sh` -> dispatch and default modes stay as they are.
- [ ] `.agents/skills/aapp-hooks/registry.tsv` -> protected; the template is the source.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1:** Post coverage beyond note and companion. Still silent: `commit adopt`, `done <id> integrate` (separate run), `matrix` (writing), `offline` (mount, unmount, on/off, sync), `ai` (mode, notes, credits), `init`, `upgrade`. Default: left to an independent plan; adding them here widens the Target Files by six command files.
* [ ] **Question 2:** `issue close` lands the fix commit on the issue's branch before the archive commit. Default: `on-issue` fires before the landing, so a refusal leaves the fix unlanded and the issue open. Alternative: after the landing, before the archive commit only.
* [ ] **Question 3:** Issues closed by `aapp done` (Target Issue, Also Closes). Default: `post-issue` only, as today; `pre-done` already gates them. Alternative: all three phases there too.
* [ ] **Question 4:** An issue staged offline (`.offline`). Default: the hooks fire as online, with `"offline": true` in `data`.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-19:** Drafted.
