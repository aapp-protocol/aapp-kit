# 🗺️ Plan P-89: Issue Work Queue
* **Created:** 2026-10-15 | **Last Refined:** 2026-10-15
* **Target Issue / Milestone:** none
* **Plan ID:** P-89
* **Changelog:** Changed: issues road map becomes a lean work queue; fixes require human queueing via `aapp issue queue` (P-89)
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
<!-- Queued explicitly by a person via 'aapp issue queue <num>'. Only queued issues may be fixed. -->
```

- When an issue is logged (`aapp issue log`), it is recorded solely in `ISSUES.md`. It no longer appends a line to `issues_road_map.md`.
- Legacy priority bands (`User Priority`, `High Priority`, `Medium Priority`, `Low Priority`, `Triage`) are eliminated as a clean break.

### 2.2 CLI Verb: `aapp issue queue <num> [remove]`
A dedicated verb under `aapp issue` allows humans to manage the work queue:
- `aapp issue queue <num>`:
  - Verifies `#<num>` is an active issue in `ISSUES.md` (`🟠 Incubated` or `🔵 Planned`).
  - Refuses if `#<num>` is already in `📋 Queued` or `🧱 Plan Blockers`.
  - Appends `- [ ] #<num> -> <symptom>` under `## 📋 Queued` in `issues_road_map.md`.
  - Commits the change in the `.plans` worktree as `issue(queue): #<num> queued`.
  - Emits plugin hook if `aapp-issue-tracker` is configured.
- `aapp issue queue <num> remove`:
  - Removes `#<num>` from `## 📋 Queued`.
  - Commits in `.plans` as `issue(queue): #<num> unqueued`.
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
  - If no blockers exist, claims the first available issue from `## 📋 Queued`.
  - If neither exists, refuses closed with diagnostic.

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
  - Active `📋 Queued` issues ready for work.
  - A summary count of unqueued issues remaining in `ISSUES.md`.
- **Planning Health (`lib/planning_health.sh`)**:
  - Validates `issues_road_map.md` against the two-section specification.
  - Refuses legacy section headings.
  - Validates that every entry in `issues_road_map.md` exists as an active issue in `ISSUES.md`.

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
- [ ] `tests/verbs/issue.queue.sh::test_planning_health_validates_queue_format` -> asserts health check passes on two-section road map and refuses legacy bands

### Phase 1: Tests First (red)
- [ ] Task 1.1: Author `tests/verbs/issue.queue.sh` covering queue verb and fix gate assertions; confirm red.

### Phase 2: Core Implementation
- [ ] Task 2.1: `lib/ledger.sh`: Implement `roadmap_queue_add`, `roadmap_queue_remove`, update roadmap querying helpers for two-section layout.
- [ ] Task 2.2: `lib/cmd_issue.sh`: Implement `aapp issue queue <num> [remove]`; enforce queue check in `cmd_issue_fix`; decouple `cmd_issue_log` from road map appending.
- [ ] Task 2.3: `lib/cmd_status.sh`: Update Issues pillar of briefing to show blockers, queued issues, and count of unqueued issues.
- [ ] Task 2.4: `lib/planning_health.sh`: Update roadmap verification rules for the two-section queue format.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run automated test suites across all verbs.
- [ ] Task 3.2: Update `templates/issues_road_map.md`, `templates/AGENTS.md`, `templates/skills/aapp-fix/SKILL.md`.
- [ ] Task 3.3: Update `MANUAL.md`, `CHEATSHEET.md`, `ARCHITECTURE.md`, `lib/docs/verbs/issue.md`.
- [ ] Task 3.4: Migrate active `.plans/issues_road_map.md`.
- [ ] Task 3.5: Run syntax, build, and test verification before plan completion.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_issue.sh` -> `aapp issue queue` command, `cmd_issue_fix` queue gate, decouple `cmd_issue_log`.
- [ ] `lib/ledger.sh` -> Road map queue helpers, two-section parsing.
- [ ] `lib/cmd_status.sh` -> Update briefing Issues pillar for queued layout.
- [ ] `lib/planning_health.sh` -> Validate two-section road map structure.
- [ ] `lib/docs/verbs/issue.md` -> Document `aapp issue queue` and queue gate.
- [ ] `templates/issues_road_map.md` -> Two-section template (`Blockers`, `Queued`).
- [ ] `templates/AGENTS.md` -> Human queue gate invariant; agents cannot self-queue.
- [ ] `templates/skills/aapp-fix/SKILL.md` -> Updated fix skill reflecting queue gate.
- [ ] `MANUAL.md` -> Issue lifecycle, work queue specification, `aapp issue queue`.
- [ ] `CHEATSHEET.md` -> `aapp issue queue <num> [remove]` CLI reference.
- [ ] `ARCHITECTURE.md` -> Two-lane queue architecture and human-in-the-loop gate.
- [ ] `NEW FILE` -> `tests/verbs/issue.queue.sh` -> Failure and boundary tests.

### 🧪 Required Test Files
- [ ] `tests/verbs/issue.queue.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Write guard operates on active mini plans; does not touch road map parsing.
- [ ] `lib/cmd_plan.sh` -> Plan lifecycle is unaffected except for issue link maintenance.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-10-15:** Drafted blueprint: transformed `issues_road_map.md` into an active work queue (`🧱 Plan Blockers` + `📋 Queued`), introduced `aapp issue queue <num>`, and gated `aapp issue fix` against unqueued execution.
