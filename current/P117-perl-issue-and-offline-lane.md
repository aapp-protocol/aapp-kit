# 🗺️ Plan P-117: Perl Issue And Offline Lane
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-28
* **Target Issue / Milestone:** none
* **Plan ID:** P-117
* **Changelog:** Changed: port `aapp issue` and `aapp offline` to `lib/AAPP/Runner/Issue/` (absorbing P-144 ledger words commit, branch, note) and `lib/AAPP/Runner/Offline.pm` with structured log event telemetry
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The plan's single CHANGELOG.md entry: `<Added|Changed|Fixed>: <one line>`. `aapp draft` pre-fills it
     from the title; reword it and pick the section while refining. `aapp commit` writes it into
     CHANGELOG.md on the plan's first code commit; `aapp freeze` refuses a missing or malformed field. -->
* **Status:** 🟣 Under Review
* **Base:** none
* **Group:** P-111
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp issue log`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
Plan `P-117` is the twelfth member of group `P-111` (*Perl Port Of The Kit*), absorbing `P-144` (*Issue Ledger Words*). It ports the entire issue lane (`lib/cmd_issue.sh`, 2,471 lines) and offline worktree sync (`lib/cmd_offline.sh`, 352 lines) into the noun-first CLI command hierarchy under `lib/AAPP/Runner/Issue.pm`, `lib/AAPP/Runner/Issue/<Word>.pm`, and `lib/AAPP/Runner/Offline.pm`, supported by the shared domain module `lib/AAPP/Issue.pm`.

In bash, `cmd_issue` spawns multiple `awk`/`sed` passes across `.plans/ISSUES.md`, `.plans/issues_road_map.md`, `.plans/done/000-issues-archive.md`, `.plans/aborted/000-aborted-ledger.md`, and `${AAPP_STATE_DIR:-~/.local/state}/aapp/<key>/issues-data.md`. In Perl, `AAPP::State` (`P-115`) and `AAPP::Issue` load and manipulate the issue ledger, work queue, archive, and external `issues-data.md` store in memory before committing atomically via `AAPP::CommitEngine`.

**Strict Noun-First Clean Break & Ledger Words (absorbing P-144):** The legacy `aapp refine issues` forms leave the kit. Each action becomes a dedicated word under `aapp issue`:
- `aapp refine issues "<msg>"` → `aapp issue commit "<msg>"` (`Commit.pm`)
- `aapp refine issues "<msg>" branch <num> <name>` → `aapp issue branch <num> <name>` (`Branch.pm`)
- `aapp refine issues "<msg>" note <num> "<text>"` → `aapp issue note <num> "<text>"` (`Note.pm`)

**Strict Tests-vs-Code Boundary:** This plan touches **only** kit code (`lib/AAPP/Issue.pm`, `lib/AAPP/Runner/Issue.pm`, `lib/AAPP/Runner/Issue/*.pm`, `lib/AAPP/Runner/Offline.pm`, `lib/cmd_issue.sh`, `lib/cmd_offline.sh`, `aapp`). `tests/`, `t/` and `lib/docs/verbs/*.md` are out of bounds and must pass unchanged.

**Strict Implementation References (`D7`):**
- **Logging Events Spec (§4.2 `issue`, §4.3 `offline`):** `.plans/pickup/perl-port-logging-events-spec.md`
- **Tabular Verification Matrix (Epoch E5 `issue.t` & `offline.t`):** `.plans/pickup/perl-port-test-matrix-tabular-check.md`
- **Single Prepared Repository Schema (Epoch E5 Issue Lane, `Pool I`):** `.plans/pickup/perl-port-single-repo-schema.md`

---

## 2. Technical Blueprint

### 2.1 `AAPP::Issue` (`lib/AAPP/Issue.pm`) — Shared Issue Domain & Fix-Worktree Helpers
Provides reusable issue domain primitives shared across `AAPP::Runner::Issue::*`, `AAPP::Runner::Plan::*` (`draft`, `done`, `abort`), and `AAPP::Runner::Status`:
- **Counter & ID allocation**: `next_issue_id()` queries the `aapp-issue-tracker` plugin (`create`) when enabled, or reads/increments `git config aapp.issueId` seeded on first use from the highest `#<num>` across `.plans/ISSUES.md` and `.plans/done/000-issues-archive.md`.
- **Row construction & validation**: `build_issue_row(%args)`, `validate_symptom($text)`, `parse_location_files($loc_cell)`, and `format_archive_row($row, $resolution_summary)` for `.plans/ISSUES.md` (`| #<id> | <Sev> | <Type> | <YYYY-MM-DD> | <Location> | <Symptom> | <Target Plan / Fix> | <Status> |`), with severities `Critical`, `High`, `Medium`, `Low`, uppercase `Type` (`^[A-Z0-9_-]+$`), single-line symptom `<= 250` chars, and statuses `` 🟡 `Incubated` ``, `` 🔵 `Planned` ``, `` 🟠 `In Progress` ``.
- **Road-map queue manipulation**: `add_roadmap_blocker`, `add_roadmap_queued`, and `prune_roadmap_entry` over `.plans/issues_road_map.md` (`## 🧱 Plan Blockers` and `## 📋 Queued` with `### 🔺 Urgent`, `### Normal`, `### Low`), preserving human ordering.
- **External description & notes store (`issues-data.md`)**: `issue_data_path()`, `issue_note_append($id, $kind, $text)`, and `issue_notes_print($id)` storing descriptions and notes outside Git in `${AAPP_STATE_DIR:-~/.local/state}/aapp/<key>/issues-data.md`, running optional `aapp-issue-note-filter` plugin inspection (`log` / `note` / `show`), and printing the non-instruction framing banner.
- **External tracker bridge**: `issue_provider()`, `issue_sync()`, `aapp-issue-tracker` plugin (`get`, `create`, `status`, `close`), and `.plans/.tracker-sync` cache TTL (`aapp.issueSyncTtl`).
- **Cross-lane plan-unblocking & fix helpers**:
  - `issue_unblock_plans($id, $fix_sha, $plans_wt)` and `issue_unblock_landed($plans_wt)`: scan `.plans/current/P*.md` for `* **Blocked On:**` containing `#<id>`, remove `#<id>`, restore pre-block status when no blockers remain, and clear `.plans/state_matrix.md` blocker annotations.
  - `issue_bring_fix_to_groups($fix_sha)`: cherry-pick or merge the landed fix commit into active group integration branches waiting on the blocker.

### 2.2 `AAPP::Runner::Issue` (`lib/AAPP/Runner/Issue.pm`) & Word Modules
Dispatches subcommands to `lib/AAPP/Runner/Issue/<Word>.pm`:
- **`Log.pm`** (`aapp issue log`): logs issue in `ISSUES.md`, seeds external note, commits `issue(triage): log #<id>`.
- **`Hotfix.pm`** (`aapp issue hotfix`): logs blocker, stashes uncommitted files, queues as blocker in road-map, blocks calling plan.
- **`Fix.pm`** (`aapp issue fix`): claims queued issue or next blocker, spins `.workspace/fix-<num>` worktree with temporary mini-plan.
- **`Queue.pm`** (`aapp issue queue` / `unqueue`): moves issue between Incubated and Queued sections in `issues_road_map.md`.
- **`Close.pm`** (`aapp issue close`): squashes fix, lands single commit, unblocks dependent plans, relocates issue row to `done/000-issues-archive.md`.
- **`Abort.pm`** (`aapp issue abort`): aborts in-progress fix worktree and restores road-map state.
- **`List.pm`** (`aapp issue list [note <num>]`): renders formatted issue tables or prints external notes with disclaimer.
- **`Commit.pm`** (`aapp issue commit "<msg>"`): commits hand edits of `ISSUES.md` and `issues_road_map.md` with `issue(triage): <msg>`.
- **`Branch.pm`** (`aapp issue branch <num> <name>`): names target landing branch for issue `#<num>`.
- **`Note.pm`** (`aapp issue note <num> "<text>"`): appends external out-of-band note to `#<num>`.

### 2.3 `AAPP::Runner::Offline` (`lib/AAPP/Runner/Offline.pm`) — `aapp offline`
Ports `cmd_offline` from `lib/cmd_offline.sh`:
- Authoritative syntax, flags, failure modes, and effects: `aapp help offline full` and `lib/docs/verbs/offline.md` (`mount`, `unmount`, `on`, `off`, `status`, `sync`).
- Manages the `.offline/` worktree on orphan branch `offline`, recording offline tracker operations in `.offline/outbox` and closed issue rows in `.offline/closed.rows` when `aapp.offline=true`, and replaying them against `aapp-issue-tracker` on `sync`.

### 2.4 Logging Telemetry (`AAPP::Logger::log_event`)
Per `.plans/pickup/perl-port-logging-events-spec.md` §4.2 & §4.3, each mutating action emits structured telemetry to `.git/aapp.log`:
- `post-issue-<action>` (for `log`, `hotfix`, `queue`, `unqueue`, `fix`, `fix-abort`, `close`, `abort`, `switch`, `limit-refused`, `commit`, `branch`, `note`).
- `post-offline-<action>` (for `mount`, `unmount`, `on`, `off`, `sync`, `status`).

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 0: One ID Counter Writer (amendment for P-115)
- [ ] Task 0.1: Ensure ID allocation uses `AAPP::State::allocate_plan_id` / `next_issue_id` backed by repository git config (`--local`).

### Phase 1: Issue Domain Module (`AAPP::Issue`)
- [ ] Task 1.1: Implement `lib/AAPP/Issue.pm` with `aapp.issueId` / `aapp-issue-tracker` ID allocation, ledger manipulation, external `issues-data.md` reader/writer, and plan-unblocking helpers.

### Phase 2: `AAPP::Runner::Issue` & Word Modules with Event Telemetry
- [ ] Task 2.1: Implement `lib/AAPP/Runner/Issue.pm` router and word modules: `Log.pm`, `Hotfix.pm`, `Fix.pm`, `Queue.pm`, `Close.pm`, `Abort.pm`, `List.pm`.
- [ ] Task 2.2: Implement ledger words (absorbing P-144): `Commit.pm`, `Branch.pm`, `Note.pm`.
- [ ] Task 2.3: Implement `lib/AAPP/Runner/Offline.pm` covering `mount`, `unmount`, `on`, `off`, `status`, and `sync` over `.offline/`.
- [ ] Task 2.4: Route `issue` and `offline` in `./aapp` to `AAPP::Runner::Issue` and `AAPP::Runner::Offline`.

### Phase 3: Verification & Clean Break
- [ ] Task 3.1: Run `prove -l` and syntax check `perl -c` across all new `lib/AAPP/Runner/Issue/*.pm` modules.
- [ ] Task 3.2: Verify `CHANGELOG.md` updates.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/Issue.pm` -> Shared issue domain logic, ledger/roadmap/archive mutation, `issues-data.md` store, tracker bridge, and plan-unblocking helpers.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue.pm` -> Noun router for `aapp issue`.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue/Log.pm` -> `aapp issue log` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue/Hotfix.pm` -> `aapp issue hotfix` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue/Fix.pm` -> `aapp issue fix` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue/Queue.pm` -> `aapp issue queue` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue/Close.pm` -> `aapp issue close` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue/Abort.pm` -> `aapp issue abort` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue/List.pm` -> `aapp issue list` word runner.
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue/Commit.pm` -> `aapp issue commit` word runner (absorbed from P-144).
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue/Branch.pm` -> `aapp issue branch` word runner (absorbed from P-144).
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Issue/Note.pm` -> `aapp issue note` word runner (absorbed from P-144).
- [ ] `NEW FILE` -> `lib/AAPP/Runner/Offline.pm` -> `aapp offline` command runner.
- [ ] `aapp` -> Dispatch `issue` and `offline` verbs directly to `AAPP::Runner::Issue` and `AAPP::Runner::Offline`.
- [ ] `lib/cmd_issue.sh` -> Transitional shim delegating remaining bash helper calls to `AAPP::Issue` until `P-122` deletes `lib/*.sh`.
- [ ] `lib/cmd_offline.sh` -> Transitional shim delegating remaining bash helper calls to `AAPP::Runner::Offline` until `P-122` deletes `lib/*.sh`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> The test engine (P-126) and every test file in `t/` stay out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` remain out of bounds during code port.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-28:** Absorbed P-144 (Issue Ledger Words: `commit`, `branch`, `note`); restructured commands under `lib/AAPP/Runner/Issue/` and `lib/AAPP/Runner/Offline.pm` with clean-break noun-first syntax.
* **2026-10-24:** Aligned technical blueprint, logging telemetry (`post-issue-*`, `post-offline-*`), and execution steps with `.plans/pickup/perl-port-logging-events-spec.md` and `.plans/pickup/perl-port-test-matrix-tabular-check.md`.
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Refined technical blueprint and blast radius per `§5.1.4` to match `lib/cmd_issue.sh` and `lib/cmd_offline.sh` contracts.
