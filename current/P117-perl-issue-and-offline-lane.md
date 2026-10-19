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
Plan `P-117` is the fifth member of group `P-111` (*Perl Port Of The Kit*). It ports the entire issue lane (`lib/cmd_issue.sh`, 1,701 lines across 33 functions) and offline queue (`lib/cmd_offline.sh`, 512 lines across 6 functions) into `lib/AAPP/Issue.pm`, `lib/AAPP/Cmd/Issue.pm`, and `lib/AAPP/Cmd/Offline.pm`, and routes `aapp issue` and `aapp offline` through Perl CLI dispatch.

In bash, `cmd_issue_list` and `cmd_issue_close` spawn multiple `awk` passes and per-issue `git notes` subprocesses across `ISSUES.md`, `issues_road_map.md`, and `000-issues-archive.md`. In Perl, `AAPP::State` (built in `P-115`) loads the issue ledger, work queue, archive, and `refs/notes/issues` in one pass, and `AAPP::Issue` / `AAPP::Cmd::Issue` manipulate rows in memory before committing atomically via `AAPP::Repo`.

**Strict Tests-vs-Code Boundary:** This plan touches **only** kit code (`lib/AAPP/*.pm`, `lib/cmd_issue.sh`, `lib/cmd_offline.sh`, `aapp`). `lib/AAPP/Tests*` and `lib/docs/verbs/*.md` are out of bounds and must pass unchanged.

---

## 2. Technical Blueprint

### 2.1 `AAPP::Issue` (`lib/AAPP/Issue.pm`) — Shared Issue Domain & Fix-Worktree Helpers
Provides reusable issue domain primitives shared by `AAPP::Cmd::Issue`, `AAPP::Cmd::Done`, `AAPP::Cmd::Refine`, and `AAPP::Cmd::Commit`:
- **Counter & ID allocation**: `next_issue_id($state)` reads/increments `.plans/.issue-counter` (or delegates to the configured external tracker backend when online) and formats `#<num>` or `#<KEY>`.
- **Row construction & validation**: `build_issue_row(%args)`, `validate_symptom($text)`, `parse_location_files($loc_cell)`, and `format_archive_row($row, $resolution_summary)`.
- **Road-map queue manipulation**: `add_roadmap_blocker($state, $id, $blocking_plans, $summary)`, `add_roadmap_queued($state, $id, $tier, $summary)`, and `prune_roadmap_entry($state, $id)` preserving human ordering in `.plans/issues_road_map.md`.
- **Issue notes (`refs/notes/issues`)**: `read_issue_notes($state, $id)` and `append_issue_note($state, $id, $kind, $text)` storing descriptions and notes on the anchor commit of `#<id>` in `refs/notes/issues` without leaking note content into tracked files. Uses a single `git log --format="%H %B" refs/notes/issues` bulk load for `issue list`.
- **Fix-worktree lifecycle helpers**:
  - `active_fix_plan($state)`: detects `.plans/current/.fix-<num>.md` mini-plan in a `.workspace/fix-<num>` worktree or main checkout.
  - `wait_for_active_fix($state)`: implements the `aapp.issueFixWait` polling/lock loop when another fix is open.
  - `create_fix_worktree_and_miniplan($state, $id, \@extra_files)`: creates `.workspace/fix-<num>` on branch `fix/issue-<num>`, writes the temporary mini-plan `.plans/current/.fix-<num>.md` whose `### 📂 Target Files` come from the issue's `Location` cell plus `file <path>` extras, and binds `.git/aapp-active-plan`.
  - `relocate_issue_to_archive($state, $id, $resolution_summary)`: removes `#<id>` from `ISSUES.md`, appends to `.plans/done/000-issues-archive.md` (preserving historical Location and Symptom verbatim), and prunes `.plans/issues_road_map.md`.

### 2.2 `AAPP::Cmd::Issue` (`lib/AAPP/Cmd/Issue.pm`) — `aapp issue` Subverbs
Implements all `aapp issue` subverbs with identical CLI flags, exit codes, human output, and `--json` output (`AAPP::Output` + `AAPP::JSON`):
- `log <sev> <type> "<symptom>" [file <path>]... [note "<text>"]`: validates severity (`HIGH|MED|LOW` or `P0..P4`), type token (`^[A-Z0-9_-]+$`), and single-line symptom (`<= 250` chars); when an external tracker is configured and reachable (or falls back to offline queue when unreachable and offline fallback applies), allocates ID, appends to `ISSUES.md`, commits `issue(triage): log #<id> in .plans/ISSUES.md` in `.plans`, and attaches optional `description` note to `refs/notes/issues`.
- `queue <num> [urgent | normal | low | remove]`: adds, moves, or removes `#<num>` under `## 📋 Queued` (`### 🔴 Urgent`, `### 🟡 Normal`, `### 🟢 Low`) in `.plans/issues_road_map.md` and commits in `.plans`.
- `hotfix ["<symptom>"] [sev <sev>] [type <type>] [file <path>...] [issue <num>] [plan] [note "<text>"]`: logs a new issue or promotes an existing `#<num>` into `## 🧱 Plan Blockers` in `issues_road_map.md`, records `* **Blocked On:** #<num>` and appends `* **Emergency Hotfixes:** #<num>` on the active plan (transitioning to `🟥 BLOCKED` when exceeding `aapp.maxEmergencyHotfixes`), and in single-checkout mode stashes uncommitted overlapping target files.
- `fix [<num> | next-blocker] [file <path>...]`: verifies `#<num>` is cleared in `issues_road_map.md` (`Plan Blockers` or `Queued`), waits up to `aapp.issueFixWait` if another fix is open, creates `.workspace/fix-<num>` and the `.fix-<num>.md` mini-plan, marks the issue `🟠 In Progress`, and prints any author description/notes block with the non-instruction safety banner.
- `close <num> [sha <sha>] [summary "<text>"]`: verifies the fix commit and changelog entry, integrates `.workspace/fix-<num>` onto the base branch as one commit (and removes the worktree and mini-plan), relocates `#<num>` to `.plans/done/000-issues-archive.md`, prunes `issues_road_map.md`, and unblocks any plans waiting on `* **Blocked On:** #<num>`.
- `abort [<num>]`: aborts an in-progress fix worktree, removes `.workspace/fix-<num>` and `.fix-<num>.md`, and restores the issue status to `🟠 Incubated`.
- `reopen <num> [reason "<text>"]`: moves `#<num>` back from `000-issues-archive.md` to `ISSUES.md` as `🟠 Incubated` without altering original historical prose.
- `list [open | planned | in-progress | queued | blockers | done | all] [sev <sev>] [type <type>] [note <num>] [--json]`: renders filtered issue tables or single-issue note block, or structured JSON via `AAPP::Output`.
- `tracker [status | set <kind> ... | clear]` and `import` / `sync`: ports external tracker configuration and synchronization helpers.

### 2.3 `AAPP::Cmd::Offline` (`lib/AAPP/Cmd/Offline.pm`) — `aapp offline` Subverbs
Ports `lib/cmd_offline.sh` into `lib/AAPP/Cmd/Offline.pm`:
- Manages `.plans/.offline-queue` (or `.git/aapp-offline-queue` per state model) for queued tracker operations when offline.
- Implements `aapp offline status`, `aapp offline list`, `aapp offline replay` / `flush`, and `aapp offline drop` / `clear`, preserving `--json` output and exact error diagnostics.

### 2.4 CLI Dispatch & Transitional Bash Shim (`aapp`, `lib/cmd_issue.sh`, `lib/cmd_offline.sh`)
- Wire `issue` -> `AAPP::Cmd::Issue::run` and `offline` -> `AAPP::Cmd::Offline::run` in `./aapp`.
- Replace any cross-calls from unported bash scripts (`cmd_done.sh`, `cmd_refine.sh`) into `cmd_issue.sh` with thin delegates invoking `perl -I"$SCRIPT_DIR/lib" -MAAPP::Issue ...` until `P-119` and `P-122` complete.

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Issue Domain Module (`AAPP::Issue`)
- [ ] Task 1.1: Implement `lib/AAPP/Issue.pm` with ID allocation, `ISSUES.md` / `000-issues-archive.md` / `issues_road_map.md` manipulation, bulk `refs/notes/issues` reader/writer, and `.workspace/fix-<num>` mini-plan lifecycle helpers.

### Phase 2: `AAPP::Cmd::Issue` & `AAPP::Cmd::Offline`
- [ ] Task 2.1: Implement `lib/AAPP/Cmd/Issue.pm` covering `log`, `queue`, `hotfix`, `fix`, `close`, `abort`, `reopen`, `list`, `tracker`, `import`, and `sync` with full `--json` support via `AAPP::Output` and `AAPP::JSON`.
- [ ] Task 2.2: Implement `lib/AAPP/Cmd/Offline.pm` covering all `aapp offline` subverbs and queue replay mechanics.
- [ ] Task 2.3: Route `issue` and `offline` in `./aapp` to `AAPP::Cmd::Issue` and `AAPP::Cmd::Offline`, and slim `lib/cmd_issue.sh` / `lib/cmd_offline.sh` to thin transitional shims for any remaining bash callers.

### Phase 3: Verification & Documentation
- [ ] Task 3.1: Run `./aapp test issue offline` and full `./aapp test` to verify 100% pass rate against the locked `lib/AAPP/Tests/Verb/Issue.pm` and `lib/AAPP/Tests/Verb/Offline.pm` suites.
- [ ] Task 3.2: Verify `CHANGELOG.md` updates and run `perl -c` syntax checks on all new `.pm` files.
- [ ] Task 3.3: Log every finding outside the Target Files as an issue (`aapp refine issues`); none stays in chat only.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/AAPP/Issue.pm` -> Shared issue domain logic, ledger/roadmap/archive mutation, `refs/notes/issues` bulk reader/writer, and fix-worktree helpers.
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Issue.pm` -> `aapp issue` subverb implementations (`log`, `queue`, `hotfix`, `fix`, `close`, `abort`, `reopen`, `list`, `tracker`, `import`, `sync`).
- [ ] `NEW FILE` -> `lib/AAPP/Cmd/Offline.pm` -> `aapp offline` subverb implementations and offline tracker queue management.
- [ ] `aapp` -> Dispatch `issue` and `offline` verbs directly to `AAPP::Cmd::Issue` and `AAPP::Cmd::Offline`.
- [ ] `lib/cmd_issue.sh` -> Transitional shim delegating remaining bash helper calls to `AAPP::Issue` / `AAPP::Cmd::Issue` until `P-122` deletes `lib/*.sh`.
- [ ] `lib/cmd_offline.sh` -> Transitional shim delegating remaining bash helper calls to `AAPP::Cmd::Offline` until `P-122` deletes `lib/*.sh`.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/AAPP/Tests.pm` -> Test harness and all `lib/AAPP/Tests/*` modules are locked in `P-114` and strictly out of bounds during code plans.
- [ ] `lib/docs/` -> Spec contracts in `lib/docs/verbs/*.md` are locked in `P-114`.

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-19:** Plan initialized from `pickup.md` and `.plans/pickup/perl-port-rfc.md`.
* **2026-10-19:** Authored technical blueprint and locked blast radius for `P-117`.

