# 🗺️ Plan P-109: Lifecycle Event Coverage
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** none
* **Plan ID:** P-109
* **Changelog:** Added: a hook event per action for issue, note and companion; post events on every writing verb; pre/on gates for abort, commit, freeze, done, land (P-109)
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
- `issue` has one general `post-issue` for six of its actions; `fix <num> abort` fires nothing; no pre or on phase exists.
- `note`, `companion`, `matrix`, `offline`, `ai`, `init`, `upgrade`, `commit adopt` and a separate `done <id> integrate` fire no event: holes in flat logging coverage.
- Destructive or branch-moving actions have no team gate: `plan abort`, `commit`, `land`; `freeze` and `done` have no in-transaction phase.

Goal:
1. **One event per action** for `issue`, `note` and `companion`: `<phase>-<verb>-<action>` (e.g. `pre-issue-close`), never one general event per verb.
2. **A post event on every writing action** of every verb run inside a repository.
3. **The pre/on gates proposed in review**: `pre-abort`, `pre-commit`, `on-freeze`, `on-done`, `pre-land`, `pre-draft`, `pre-tdd`, `pre-companion-push`, `pre-offline-sync`.

---

## 2. Technical Blueprint

### 2.1 Phases and naming
| Phase | Fires | Default mode | A refusal |
|---|---|---|---|
| `pre-*` | first step, before anything is taken, asked or written | `gate` | nothing changes |
| `on-*` | after the kit's local writes, just before the commit that records them | `gate` | the action is rolled back; nothing committed |
| `post-*` | after that commit | `notify` | ignored |

- Event names: `<phase>-<verb>` for a verb with one action, `<phase>-<verb>-<action>` for a verb with several. The action names follow the CLI.
- Every `data` keeps the 2-key invariant: `command` (the verb) and `event` (the action).
- Default modes come from the dispatcher's rule (`post-*` notify, others gate); `lib/hook_dispatcher.sh` is unchanged.

### 2.2 Issue: three phases per action
`pre-issue-<a>`, `on-issue-<a>`, `post-issue-<a>` for each action `<a>`:

| `<a>` | CLI | Commit `on-issue-<a>` precedes |
|---|---|---|
| `log` | `issue log` | `issue(log)` |
| `hotfix` | `issue hotfix` (both forms) | `issue(hotfix)` |
| `queue` | `issue queue <num> [urgent \| low]` | `issue(queue)` |
| `unqueue` | `issue queue <num> remove` | `issue(queue)` |
| `fix` | `issue fix <num>`, `fix next-blocker`, `fix <num> file …` on an open fix | `fix(start)` / `fix(files)` |
| `fix-abort` | `issue fix <num> abort` | `fix(abort)` |
| `close` | `issue close` | §5 Q1 |
| `abort` | `issue abort` | the withdraw commit |

- **Clean break:** `post-issue` leaves the kit; `post-issue-<a>` replaces it, and `data.event` for `issue abort` becomes `abort` (was `withdraw`).
- `pre-issue-log` and `pre-issue-hotfix` carry `issue_id: ""` (no id yet), as `pre-refine` carries an empty `plan_id`. `on-issue-<a>` adds `files`, the paths about to be committed.
- One helper, `_issue_event <phase> <action> <data>` in `lib/cmd_issue.sh`, replaces `_issue_dispatch_hook`; it runs in a subshell like `_refine_event`.
- The tracker plugin keeps its place in each action; the hooks never call it. `pre-issue-<a>` runs before the tracker is asked.
- Read-only `issue list` and `list note` fire nothing; `refine issues` keeps the `refine` events.

### 2.3 Note and companion: one post event per action
| Event | Fires after | `data` |
|---|---|---|
| `post-note-stage` | the note buffer is written | `command: "note"`, `event: "stage"`, `msg_sha` |
| `post-note-push` | notes refs pushed | `event: "push"`, `remote`, `refs` |
| `post-note-pull` | notes refs merged | `event: "pull"`, `remote`, `refs` |
| `pre-companion-push` | before the push (gate, goal 3) | `command: "companion"`, `event: "push"`, `name`, `mode`, `path` |
| `post-companion-add` | a companion registered | `event: "add"`, `name`, `mode`, `path` |
| `post-companion-push` | the push succeeded | `event: "push"`, `name`, `mode`, `path` |
| `post-companion-remove` | a companion unlinked | `event: "remove"`, `name`, `mode`, `path` |

### 2.4 Post coverage of the other silent actions
| Event | Fires after |
|---|---|
| `post-commit-adopt` | `commit adopt` recorded the commits in the plan |
| `post-done-integrate` | a separate `done <id> integrate` integrated an archived plan |
| `post-matrix` | `matrix` rewrote `state_matrix.md` (not `matrix check`) |
| `post-offline-mount`, `post-offline-unmount`, `post-offline-on`, `post-offline-off`, `post-offline-sync` | the matching `offline` action |
| `post-ai-mode` | `ai none \| lax \| strict \| notes` switched the mode |
| `post-ai-notes` | `ai notes on \| off` |
| `post-ai-credits` | `ai credits` wrote the contributors block |
| `post-init` | `init` finished in the repository |
| `post-upgrade` | `upgrade` finished, when run inside a repository |

`install`, `develop` and `uninstall` act on the global install, outside any repository: no registry, no event.

### 2.5 New pre/on gates
| Event | Verb | Fires | A refusal |
|---|---|---|---|
| `pre-abort` | `plan abort` (and `issue abort` for its plan) | before anything is archived or removed | nothing removed |
| `pre-commit` | `aapp commit` (commit, `amend`) | before `git commit`; `data`: plan id, Target Files, staged files, message | nothing committed |
| `on-freeze` | `freeze`, `freeze-start` | after the lock is written, before the freeze commit | plan file restored |
| `on-done` | `done` | after archive and ledger writes, before the done commit; beside `on-integrate` | archive restored |
| `pre-land` | `commit land` | before the feature branch moves | branch unmoved |
| `pre-draft` | `draft` | before the id is taken | no id spent, no file |
| `pre-tdd` | `tdd` | before the plan is changed | nothing written |
| `pre-offline-sync` | `offline sync` | before anything is published | nothing published |

`pause` and `resume` get no gate: a gate must never stop the brake, and a refused resume would strand work in stashes.

### 2.6 Documentation
- `aapp hook help`, its "Available events" line and the registry template list every event (and the missing `on-integrate`), grouped by phase.
- MANUAL.md's Lifecycle Event Matrix lists every event; the "all 14 lifecycle events" count goes.
- CHEATSHEET.md's hook-tier rows drop the non-existent `on-pickup` / `on-digest` and name real examples.
- `docs/reference/09-event-telemetry.md`: every event's payload. `docs/reference/07-issue-protocol.md`: the hooks' order against the tracker.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`: `post-issue` and `data.event: "withdraw"` leave the kit.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Failing tests
- [ ] Task 1.1: `tests/hooks_test.sh`: each §2.5 gate and `pre-issue-<a>` refusing leaves nothing changed; each `on-*` refusal rolls back; a `post-*` failure leaves the action standing.
- [ ] Task 1.2: `tests/event_telemetry_test.sh`: one dispatch per event of §2.2–§2.4 with its `command` and `event`; no `post-issue` is dispatched.

### Phase 2: Core Implementation
- [ ] Task 2.1: `_issue_event` in `lib/cmd_issue.sh`; three phases on every §2.2 action; `post-issue` removed.
- [ ] Task 2.2: §2.3 in `lib/cmd_note.sh` and `lib/cmd_companion.sh`.
- [ ] Task 2.3: §2.4 posts in `lib/cmd_commit.sh`, `lib/cmd_plan.sh`, `lib/cmd_matrix.sh`, `lib/cmd_offline.sh`, `lib/cmd_ai.sh`, `lib/cmd_init.sh`, `lib/cmd_upgrade.sh`.
- [ ] Task 2.4: §2.5 gates in `lib/cmd_plan.sh`, `lib/cmd_commit.sh`, `lib/cmd_offline.sh`, `lib/cmd_companion.sh`.
- [ ] Task 2.5: event lists in `lib/cmd_hook.sh` and `templates/skills/aapp-hooks/registry.tsv`.
- [ ] Task 2.6: verb contracts in `lib/docs/verbs/`: effects, refusals and test names for every verb touched.

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
- [ ] `lib/cmd_issue.sh` -> `_issue_event`; three phases per action.
- [ ] `lib/cmd_note.sh` -> post events per action.
- [ ] `lib/cmd_companion.sh` -> post events per action, `pre-companion-push`.
- [ ] `lib/cmd_commit.sh` -> `pre-commit`, `pre-land`, `post-commit-adopt`.
- [ ] `lib/cmd_plan.sh` -> `pre-abort`, `on-freeze`, `on-done`, `pre-draft`, `pre-tdd`, `post-done-integrate`.
- [ ] `lib/cmd_matrix.sh` -> `post-matrix`.
- [ ] `lib/cmd_offline.sh` -> post events per action, `pre-offline-sync`.
- [ ] `lib/cmd_ai.sh` -> post events per action.
- [ ] `lib/cmd_init.sh` -> `post-init`.
- [ ] `lib/cmd_upgrade.sh` -> `post-upgrade`.
- [ ] `lib/cmd_hook.sh` -> help and "Available events" list.
- [ ] `templates/skills/aapp-hooks/registry.tsv` -> event comment.
- [ ] `lib/docs/verbs/issue.md` -> effects, refusals, tests.
- [ ] `lib/docs/verbs/note.md` -> effects, tests.
- [ ] `lib/docs/verbs/companion.md` -> effects, refusals, tests.
- [ ] `lib/docs/verbs/commit.md` -> effects, refusals, tests.
- [ ] `lib/docs/verbs/plan.md` -> `pre-abort`.
- [ ] `lib/docs/verbs/freeze.md` -> `on-freeze`.
- [ ] `lib/docs/verbs/freeze-start.md` -> `on-freeze`.
- [ ] `lib/docs/verbs/done.md` -> `on-done`, `post-done-integrate`.
- [ ] `lib/docs/verbs/draft.md` -> `pre-draft`.
- [ ] `lib/docs/verbs/tdd.md` -> `pre-tdd`.
- [ ] `lib/docs/verbs/matrix.md` -> `post-matrix`.
- [ ] `lib/docs/verbs/offline.md` -> events.
- [ ] `lib/docs/verbs/ai.md` -> events.
- [ ] `tests/hooks_test.sh` -> gate and on-refusal cases.
- [ ] `tests/event_telemetry_test.sh` -> coverage of every new dispatch.
- [ ] `docs/reference/09-event-telemetry.md` -> every event and payload.
- [ ] `docs/reference/07-issue-protocol.md` -> hook order against the tracker.
- [ ] `examples/hooks/event-logger.sample` -> only if it names `post-issue`.
- [ ] `MANUAL.md` -> Lifecycle Event Matrix.
- [ ] `CHEATSHEET.md` -> hook-tier rows.
- [ ] `ARCHITECTURE.md` -> event naming and coverage entry.
- [ ] `.agents/CODEMAP.md` -> Events list.
- [ ] `CHANGELOG.md` -> the plan's entry.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/hook_dispatcher.sh` -> dispatch and default modes stay as they are.
- [ ] `.agents/skills/aapp-hooks/registry.tsv` -> protected; the template is the source.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1:** `issue close` lands the fix commit on the issue's branch before the archive commit. Default: `on-issue-close` fires before the landing, so a refusal leaves the fix unlanded and the issue open. Alternative: after the landing, before the archive commit only.
* [ ] **Question 2:** Issues closed by `aapp done` (Target Issue, Also Closes). Default: `post-issue-close` only; `pre-done` and `on-done` already gate them. Alternative: all three phases there too.
* [ ] **Question 3:** An issue staged offline (`.offline`). Default: the hooks fire as online, with `"offline": true` in `data`.
* [ ] **Question 4:** The name `pre-commit` is also git's hook in `.githooks/`. Default: keep it (registry events are the kit's own namespace). Alternative: `pre-record`.
* [ ] **Question 5:** Split per-event naming to the verbs that already have one general event (`post-commit` for commit and amend, `refine`'s three events with `kind`)? Default: no; they keep their names.
* [ ] **Question 6:** Size: about 35 files across ten command modules. Default: one plan, phased. Alternative: a group (issue events; note/companion; posts; gates).

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-19:** Drafted.
* **2026-10-19:** Per-action events for issue, note, companion; all review proposals added.
