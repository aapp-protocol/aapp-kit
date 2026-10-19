# 🗺️ Plan P-117: Perl Issue And Offline Lane
* **Created:** 2026-10-19 | **Last Refined:** 2026-10-19
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(`aapp draft <slug> issue <num>` writes the issue ID here and links this plan in the issue's `Target Plan / Fix` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-117
* **Changelog:** Changed: Port the issue lane (`aapp issue` all subverbs and fix-worktree helpers) and offline queue (`aapp offline`) to `AAPP::Issue`, `AAPP::Cmd::Issue`, and `AAPP::Cmd::Offline`, eliminating multi-pass `awk`/`git notes` subprocess loops.
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
>    - *Non-blocking* (a bug, gap or stale text, including outside your Target Files): do not fix it; log it as an issue (`aapp refine issues`) and continue your plan.
>    - *Blocking and unrelated to this plan's change* (even in one of your own Target Files): run `aapp issue hotfix "<text>" file <path>…` (add `plan` when it clearly needs its own plan) and stop; it logs the issue, queues it and blocks this plan (in a single checkout it also stashes your uncommitted work in those files). The fix runs in the main checkout (`aapp issue fix next-blocker`).
>    - *Caused by this plan's change, or in code it must rewrite anyway*: that is plan work; fix it here.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants. A group member (`* **Group:**`) leaves both to its group plan's `## Architecture & Codemap` section, which the group's `done` applies.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.
<!-- AAPP-PROTOCOL:END -->

---

## 1. Context & Architectural Goal
Plan `P-117` is the fifth member of group `P-111` (*Perl Port Of The Kit*). It ports the entire issue lane (`lib/cmd_issue.sh`, 2,471 lines) and offline worktree sync (`lib/cmd_offline.sh`, 352 lines) into `lib/AAPP/Issue.pm`, `lib/AAPP/Cmd/Issue.pm`, and `lib/AAPP/Cmd/Offline.pm`, and routes `aapp issue` and `aapp offline` through Perl CLI dispatch.

In bash, `cmd_issue` spawns multiple `awk`/`sed` passes across `.plans/ISSUES.md`, `.plans/issues_road_map.md`, `.plans/done/000-issues-archive.md`, `.plans/aborted/000-aborted-ledger.md`, and `${AAPP_STATE_DIR:-~/.local/state}/aapp/<key>/issues-data.md`. In Perl, `AAPP::State` (`P-115`) and `AAPP::Issue` load and manipulate the issue ledger, work queue, archive, and external `issues-data.md` store in memory before committing atomically via `AAPP::CommitEngine`.

**Strict Tests-vs-Code Boundary:** This plan touches **only** kit code (`lib/AAPP/Issue.pm`, `lib/AAPP/Cmd/Issue.pm`, `lib/AAPP/Cmd/Offline.pm`, `lib/cmd_issue.sh`, `lib/cmd_offline.sh`, `aapp`). `tests/AAPP/*` and `lib/docs/verbs/*.md` are out of bounds and must pass unchanged.

---

## 2. Technical Blueprint

### 2.1 `AAPP::Issue` (`lib/AAPP/Issue.pm`) — Shared Issue Domain & Fix-Worktree Helpers
Provides reusable issue domain primitives shared by `AAPP::Cmd::Issue`, `AAPP::Cmd::Plan` (`draft`, `refine`, `done`, `abort`), and `AAPP::Cmd::Status`:
- **Counter & ID allocation**: `next_issue_id()` queries the `aapp-issue-tracker` plugin (`create`) when enabled, or reads/increments `git config aapp.issueId` seeded on first use from the highest `#<num>` across `.plans/ISSUES.md` and `.plans/done/000-issues-archive.md`.
- **Row construction & validation**: `build_issue_row(%args)`, `validate_symptom($text)`, `parse_location_files($loc_cell)`, and `format_archive_row($row, $resolution_summary)` for `.plans/ISSUES.md` (`| #<id> | <Sev> | <Type> | <YYYY-MM-DD> | <Location> | <Symptom> | <Target Plan / Fix> | <Status> |`), with severities `Critical`, `High`, `Medium`, `Low`, uppercase `Type` (`^[A-Z0-9_-]+$`), single-line symptom `<= 250` chars, and statuses `` 🟡 `Incubated` ``, `` 🔵 `Planned` ``, `` 🟠 `In Progress` ``.
- **Road-map queue manipulation**: `add_roadmap_blocker`, `add_roadmap_queued`, and `prune_roadmap_entry` over `.plans/issues_road_map.md` (`## 🧱 Plan Blockers` and `## 📋 Queued` with `### 🔺 Urgent`, `### Normal`, `### Low`), preserving human ordering.
- **External description & notes store (`issues-data.md`)**: `issue_data_path()`, `issue_note_append($id, $kind, $text)`, and `issue_notes_print($id)` storing descriptions and notes outside Git in `${AAPP_STATE_DIR:-~/.local/state}/aapp/<key>/issues-data.md`, running optional `aapp-issue-note-filter` plugin inspection (`log` / `note` / `show`), and printing the non-instruction framing banner.
- **External tracker bridge**: `issue_provider()`, `issue_sync()`, `aapp-issue-tracker` plugin (`get`, `create`, `status`, `close`), and `.plans/.tracker-sync` cache TTL (`aapp.issueSyncTtl`).
- **Cross-lane plan-unblocking & fix helpers**:
  - `issue_unblock_plans($id, $fix_sha, $plans_wt)` and `issue_unblock_landed($plans_wt)`: scan `.plans/current/P*.md` for `* **Blocked By:**` containing `#<id>`, remove `#<id>`, restore pre-block status when no blockers remain, and clear `.plans/state_matrix.md` blocker annotations.
  - `issue_bring_fix_to_groups($fix_sha)`: cherry-pick or merge the landed fix commit into active group integration branches waiting on the blocker.

### 2.2 `AAPP::Cmd::Issue` (`lib/AAPP/Cmd/Issue.pm`) — `aapp issue` Subverbs (`lib/docs/verbs/issue.md`)
Implements all `aapp issue` subverbs with identical CLI tokens, exit codes, human output, and bare `json` token output (`AAPP::Output` + `AAPP::JSON`):
- `aapp issue log <sev> <type> "<symptom>" [file <path>]… [note "<text>"]` (also accepting `severity`/`category`/`description`/`location` keyword aliases): validates severity (`Critical`, `High`, `Medium`, `Low`), uppercase `Type`, and single-line symptom (`<= 250` chars); allocates `#<id>`; appends row to `.plans/ISSUES.md`; writes optional description to `issues-data.md`; commits `issue(triage): log #<id> in .plans/ISSUES.md`.
- `aapp issue hotfix [<id> | <sev> <type> "<symptom>" [file <path>]… [note "<text>"]] [plan <P-num>]`: logs a new issue or claims an existing `#<id>`, adds `#<id>` under `## 🧱 Plan Blockers` in `.plans/issues_road_map.md`, records `* **Blocked By:** #<id>` and `* **Emergency Hotfixes:**` on the active plan (transitioning to `🟥 BLOCKED`), and stashes dirty overlapping target files in `aapp_hotfix_stash`.
- `aapp issue fix next-blocker | fix <num> [file <path> ["<why>"]]… [group <group>] [force] | fix <num> abort`:
  - Verifies `#<num>` is cleared in `.plans/issues_road_map.md` (`## 🧱 Plan Blockers` or `## 📋 Queued`), acquires the shared single-fix lock `$(git rev-parse --git-common-dir)/aapp_issue.lock` (waiting up to `aapp.issueFixWait` minutes while another fix is open), creates `.workspace/fix-<num>` on branch `fix/<num>` (or `aapp-issue-branch` plugin name), scaffolds the temporary mini-plan `.plans/current/fix-<num>.md`, sets status to `` 🟠 `In Progress` ``, binds `$(git rev-parse --git-path aapp_active_plan)` inside `.workspace/fix-<num>`, and prints any author description/notes from `issues-data.md`.
- `aapp issue queue <num> [urgent | low | remove]`: adds, moves, or removes `#<num>` under `## 📋 Queued` (`### 🔺 Urgent`, `### Normal`, `### Low`) in `.plans/issues_road_map.md` and commits.
- `aapp issue close <id> [sha <sha>] [summary "<text>"]`: squashes (`_issue_squash_fix`) and lands (`_issue_land_fix`) the fix branch from `.workspace/fix-<id>` onto the target branch as one commit, removes `.plans/current/fix-<id>.md` and `.workspace/fix-<id>`, relocates `#<id>` to `.plans/done/000-issues-archive.md` (`✅ Resolved (<sha>)`), prunes `.plans/issues_road_map.md`, unblocks waiting plans via `issue_unblock_plans` and `issue_bring_fix_to_groups`, pops `aapp_hotfix_stash` if recorded, and notifies `aapp-issue-tracker` / offline outbox.
- `aapp issue abort <num> [reason "<text>"] [keep-branch] [force] [force-cleanup] [confirm]`: tears down `.workspace/fix-<num>` and `.plans/current/fix-<num>.md`, relocates the issue row to `.plans/aborted/000-aborted-ledger.md` when confirmed (or reverts in-progress fix state via `fix <num> abort`), and prunes `.plans/issues_road_map.md`.
- `aapp issue list [<n> | all] [confirm] [json]` and `aapp issue list note <num>`: lists active rows from `.plans/ISSUES.md` (with bare `json` token output or interactive `confirm` pagination) or prints external notes for `#<num>` from `issues-data.md`.

### 2.3 `AAPP::Cmd::Offline` (`lib/AAPP/Cmd/Offline.pm`) — `aapp offline` Subverbs (`lib/docs/verbs/offline.md`)
Ports `lib/cmd_offline.sh` (352 lines) into `lib/AAPP/Cmd/Offline.pm`:
- Manages the `.offline/` worktree on orphan branch `offline`: `aapp offline mount`, `aapp offline unmount [force]`, `aapp offline on`, `aapp offline off`, `aapp offline status`, and `aapp offline sync`.
- Records offline tracker operations in `.offline/outbox` and closed issue rows in `.offline/closed.rows` when `aapp.offline=true`, replaying them against `aapp-issue-tracker` on `aapp offline sync`.

### 🔄 Migration & Compatibility Strategy
- **Transitional Coexistence (`P-117` → `P-122`):** While `aapp issue` and `aapp offline` dispatch to `AAPP::Cmd::Issue` and `AAPP::Cmd::Offline`, `lib/cmd_plan.sh` (`aapp done` and `aapp refine issues`, ported in `P-119`) and `lib/cmd_status.sh` (`aapp status`, ported in `P-118`) still call bash helpers in `lib/cmd_issue.sh` (`issue_unblock_plans`, `issue_unblock_landed`, `issue_sync`, `issue_provider`, `issue_data_path`, `issue_note_append`) and `lib/cmd_offline.sh` (`offline_enabled`, `offline_record_close`). Either `lib/cmd_issue.sh` and `lib/cmd_offline.sh` remain intact for bash callers until `P-119` completes, or their shared functions delegate to `perl -I"$AAPP_DIR/lib" -MAAPP::Issue` until `P-122` deletes both `.sh` files.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Issue Domain Module (`AAPP::Issue`)
- [ ] Task 1.1: Implement `lib/AAPP/Issue.pm` with `aapp.issueId` / `aapp-issue-tracker` ID allocation, `.plans/ISSUES.md` / `.plans/done/000-issues-archive.md` / `.plans/aborted/000-aborted-ledger.md` / `.plans/issues_road_map.md` manipulation, external `issues-data.md` reader/writer, and `issue_unblock_plans` / `issue_unblock_landed` / `issue_bring_fix_to_groups`.

### Phase 2: `AAPP::Cmd::Issue` & `AAPP::Cmd::Offline`
- [ ] Task 2.1: Implement `lib/AAPP/Cmd/Issue.pm` covering `log`, `hotfix`, `fix` (`next-blocker`, `<num>`, `abort`), `queue`, `close`, `abort`, `list`, and `list note`.
- [ ] Task 2.2: Implement `lib/AAPP/Cmd/Offline.pm` covering `mount`, `unmount`, `on`, `off`, `status`, and `sync` over the `.offline/` worktree.
- [ ] Task 2.3: Route `issue` and `offline` in `./aapp` to `AAPP::Cmd::Issue` and `AAPP::Cmd::Offline`, preserving bash helper availability in `lib/cmd_issue.sh` and `lib/cmd_offline.sh` until `P-119`/`P-122`.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run `./aapp test issue` and full `./aapp test` (`tests/verb_issue_test.sh`) to verify 100% pass rate against the locked test suites.
- [ ] Task 3.2: Verify `CHANGELOG.md` updates and run `perl -c` syntax checks on all new `.pm` files.
- [ ] Task 3.3: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/Issue.pm` -> Shared issue domain logic, ledger/roadmap/archive mutation, `issues-data.md` store, tracker bridge, and plan-unblocking helpers.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Issue.pm` -> `aapp issue` subverb implementations (`log`, `hotfix`, `fix`, `queue`, `close`, `abort`, `list`, `list note`).
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Offline.pm` -> `aapp offline` subverb implementations (`mount`, `unmount`, `on`, `off`, `status`, `sync`).
- [ ] `aapp` -> Dispatch `issue` and `offline` verbs directly to `AAPP::Cmd::Issue` and `AAPP::Cmd::Offline`.
- [ ] `lib/cmd_issue.sh` -> Transitional shim delegating remaining bash helper calls to `AAPP::Issue` until `P-122` deletes `lib/*.sh`.
- [ ] `lib/cmd_offline.sh` -> Transitional shim delegating remaining bash helper calls to `AAPP::Cmd::Offline` until `P-122` deletes `lib/*.sh`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `tests/AAPP/Tests.pm` -> Test harness and all `tests/AAPP/*` modules are locked in `P-114` and strictly out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` are locked in `P-114`.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Refined technical blueprint and blast radius per `§5.1.4` to match `lib/cmd_issue.sh` and `lib/cmd_offline.sh` contracts.

