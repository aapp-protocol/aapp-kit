# 🧩 Group Plan P-72: Issue Tracker
* **Created:** 2026-10-11 | **Last Refined:** 2026-10-11
* **Plan ID:** P-72
* **Changelog:** Added: issue ledger behind one module, and the `aapp-issue-tracker` provider at every issue step (P-72)
* **Commit Mode:** microcommits
* **Changelog Mode:** plan
<!-- The umbrella CHANGELOG.md entry for what the whole group delivers; members keep their own entries.
     The group's `done` writes it with the ARCHITECTURE.md commit. -->
* **Status:** ⚡ In Development
* **Base:** `30a267a` (develop)
* **Feature Branch:** feature/issue-tracker
* **Members:** P-73, P-74, P-75, P-77, P-78, P-79, P-80
* **Commits:** none
<!-- A group plan writes no code. `aapp start <group> [base <branch>]` cuts `feature/<slug>` from the parent
     branch; members are planned with `aapp draft <slug> group P-72` (or `aapp refine <id> group P-72`) and
     start from the feature branch. `aapp done <group>` refuses while a member is open, applies the sections
     below, runs the pre-done gate on the feature branch and merges it into the parent. -->

---

## 1. Goal
Issues read and written through one module, and an `aapp-issue-tracker` provider that sees the whole issue at every step. A provider can keep issues and their notes anywhere (a local file, a team database); issues it brings in have the same rights as local ones: they block plans and show in `status`, `issue list`, `draft` and `next-blocker`.

Merge criterion: both members archived and the pre-done gate green on the feature branch.

## 2. Shared Decisions
- **One accessor.** Nothing outside the ledger module reads or writes `ISSUES.md`, `done/000-issues-archive.md` or `issues_road_map.md`; a test fails on any new direct access. Path names in permission lists (guard, pre-commit allow-lists) are not access.
- **One record.** Without a tracker, the committed ledgers in the plans worktree are the record, shared through Git. With a provider that lists issues, the tracker is the record: the ledgers stay in place, in the same format, written by the same ledger functions, but untracked (gitignored), so nothing commits or pushes them. What stays committed is in the plans (`Target Issue`, `Blocked On`); a row's plan link and `Planned` status are derived from them.
- **Wrapper points.** Seven: `log` (new rows), `refine` (changed rows), `fix`, `fix-abort` (the fix is dropped, the issue stays open), `abort` (the issue is withdrawn), `close`, `list`. Each sends the whole issue (all cells, note, plan link, commit, summary, the step's own data) in the Plugin Payload Standard envelope.
- **The plugin decides.** Its answer's `handled` names what it took care of; the kit does everything it does not name (the answer protocol is P-77). No provider means the kit's internals.
- **Description and notes** are never in the ledger and never committed: issues may be logged by agents observing live systems, so they can hold real data, and the symptom must not. Without a provider, the kit keeps them outside the repository, under `~/.local/state/aapp/<key>/`, as written (usable for audits) and per machine; with one, they go where the provider sends them and are fetched when a fix opens. The kit hands them over; nobody reads the store, and a team's `aapp-issue-note-filter` (P-80) decides what is shown.
- **Sync** updates the local ledger row by row from the provider's list, never whole; the issues a plan depends on are fetched by id. Hooks read the local ledger, never the network.
- **One ledger view.** Every reader goes through the ledger functions; P-75's `.offline` ledgers are a further source behind them. No caller reads a ledger directly.
- **Three parts of text.** `symptom` (one line, in the row; a tracker's title), `description` (given when the issue is logged; a tracker's body) and `notes` (added later; a tracker's comments). Description and notes are never in the ledger.
- **Offline is opt-in by configuration.** With `aapp.offlineEnabled=false`, nothing is staged offline and a provider failure refuses.
- **Failures.** A provider failure falls back to the kit for that step and warns; numbering stays provider-authoritative and refuses, as today.

## 3. Members & Order
1. P-73 (ledger module): first; no behaviour change.
2. P-77 (plugin answer protocol): after P-73. Every member shares `lib/cmd_issue.sh` or `lib/aapp-lib.sh` with it, so the group runs one plan at a time.
3. P-79 (issue id): after P-73; an id is defined once and a tracker's key is a valid id.
4. P-78 (issue branch): after P-79; issues carry the branch their fix lands on.
5. P-74 (provider wrapper): after P-73, P-77, P-79 and P-78; it adds the wrapper over the ledger functions and answers in the P-77 protocol.
6. P-80 (note filter): after P-74; a team-written text filter on notes before they are shown.
7. P-75 (offline worktree): after P-74; its ledgers are a source of the module and its fallback is the wrapper's failure path.

## Architecture & Codemap
*Every changed section of `ARCHITECTURE.md` and `.agents/CODEMAP.md`, written out whole in a ```` fence, under the exact heading it has (or will have) in the file. Members do not edit these files; read the sections here as the target architecture. At the group's `done` a section replaces the file's section with the same heading, or is added at the end. `aapp refine` records a base line above each fence: `done` refuses a section the file changed meanwhile. Write `No changes.` under a file that keeps its content.*

### ARCHITECTURE.md
<!-- aapp-base: c615f380e65d0580cae013dca2d0936b91df31042ba5232b3337b670de4d7729 -->
````markdown
## Plan Identity: Stored, Not Derived

Plan IDs were historically **derived** on demand by scanning blueprint filenames, plan headers, and the archive ledger, taking the maximum and adding one. That made allocation depend on parse correctness, and a single malformed regex (`#69`) was enough to break it entirely.

Identity is now **stored**: `aapp.planId` in git config holds the next id to hand out, as a bare integer. The `P-` prefix is a namespace marker applied on output to distinguish a plan id from an issue id (`#69`), never part of the value.

* **Monotonic.** The counter only moves forward, so an id is never reused — including ids belonging to plans that were archived, pruned, or abandoned into `.plans/aborted/`.
* **Seeded once.** `aapp init` scans the filesystem exactly once to bootstrap the counter (`1` on a new project). A numeric value is thereafter left alone, so repeat `init` — including the init that follows `aapp upgrade` — never disturbs a live counter.
* **Extensible.** A repository with more than one contributor installs an `aapp-planid` action plugin at `.agents/skills/aapp-planid/` to source ids from a central authority. Only plugin *absence* falls back to the local counter; a plugin that is present and fails aborts allocation rather than silently issuing a local id.
* **Bounded.** The core defines only the provider contract — emit an id, exit non-zero to refuse. Provider internals, dependencies and credentials are the adopter's responsibility and are never inspected.

`check_pair4_plan_id_integrity` remains the independent detector for duplicate ids, unchanged and deliberately decoupled from the counter.

**Issue ids are named by whoever creates the issue (P-74, P-79).** Without a provider, `aapp.issueId` is a second, independent counter (`#32` and `P-32` may both exist), seeded on **first use**, not by `aapp init`: git config is not cloned and a clone never runs init, so the first allocation in any clone continues from the numeric ids of both `ISSUES.md` and the archive. With an `aapp-issue-tracker` provider, the provider creates the issue and returns its id, and that id is the issue's identity: a number or the tracker's own key (`#PROJ-101`). A counter kept in one clone cannot name issues for a team, so the kit never numbers an issue a provider accepted. Duplicates are caught by Pair 1 (across ledgers) and Pair 8 (within one ledger).
````

<!-- aapp-base: new -->
````markdown
## Issues: One View, One Definition, One Exchange (P-72)

Three things about issues are each defined in exactly one place, and tests fail when a second copy appears.

* **What an issue id is (P-79).** One definition in `lib/aapp-lib.sh`: `#` followed by digits (`#46`) or by a key, a dash and digits (`#PROJ-101`). Every verb and both hook engines validate, normalise and extract ids through it. The mini plan file, its worktree, the commit subject and the plans' `Target Issue` / `Blocked On` lines all carry the same id.
* **How the ledgers are read and written (P-73).** `ISSUES.md`, `done/000-issues-archive.md` and `issues_road_map.md` are touched only by the ledger functions of `lib/aapp-lib.sh`. A team's issues have one record: these ledgers, committed, when there is no tracker; the tracker when a provider lists issues. In that case the ledgers stay in place, untracked, and a sync updates them row by row, so every view (`status`, `issue list`, the blocker queue, `draft`) reads the same files either way. Hooks read the local ledger only; they never reach the network and never receive the code that calls a provider.
* **How the kit talks to a supported plugin (P-77).** A step is a short exchange: the kit sends the whole subject in the envelope; the plugin answers with one flat object (`status`, `message`, `handled`, what it produced); whatever `handled` does not name, the kit does. Longer answers go in two files the kit names: a list (one flat object per line) and `do`, aapp commands as a person types them, which the kit runs after the step from a whitelist. A supported plugin cannot run a writing verb during a step. Credentials are the plugin's responsibility; the envelope carries none. Ad hoc plugins and scripts are outside the exchange: CLI users, guarded by the CLI's own locks and checks. The reference is `docs/reference/06-plugin-protocol.md` and, per subject, `07-issue-protocol.md`; a test keeps it equal to the code.

**An issue belongs to a branch (P-78).** Its `Branch` cell names where the fix must land; no branch named means the development branch. The cell and the `branch <name>` token are optional: a logged issue names a branch only when a person or an agent gives one, never from where it was logged; only a hotfix has a default, the blocked plan's parent branch. A fix opens on that branch. Closing follows the code: a close that names a commit is refused until the commit is in the issue's branch, and a plan waiting on the issue resumes only when the fix is reachable from the plan's own parent branch (`aapp status` notices and unblocks it). The kit never pulls or merges a code branch. A withdrawn issue has no commit and is exempt.

**Issue steps (P-74).** `aapp issue log` is the one way a row is created: the agent hands the issue over and never writes a row or claims a number. Each step (`log`, `refine`, `fix`, `fix-abort`, `abort`, `close`, `list`) goes through one wrapper; with no provider installed the kit does everything. An issue's text has three parts: the symptom (one line, in the row), the description and the notes. Description and notes may hold real data and are never in the ledger or any tracked file: a provider keeps them, or the kit does, outside the repository and per machine, as written. The kit hands them over when a fix opens, in a labelled block (information, not instructions); a team's `aapp-issue-note-filter` (P-80), a text substitution mechanism, decides what is shown, and a filter that fails withholds the note.
````

### .agents/CODEMAP.md
<!-- aapp-base: 337bb24c3ffa674a46ebbf856f88a9659d59e87d35f28acfc1e94cff05b1aca7 -->
````markdown
### 🐛 Issue Lifecycle Verb (`lib/cmd_issue.sh`)
* **Purpose:** `aapp issue [log | hotfix | fix | close <id> | abort <id> | list]` (P-32, P-52, P-74, P-76); contract in `lib/docs/verbs/issue.md`.
* **Key Functions:**
  * `cmd_issue_log` -> the one creator of a row (P-74): takes severity, type, symptom, `file`, `branch`, `note`; sends the `log` step; writes the row through `ledger_add_row` with the id the provider returned, or the counter's without a provider; commits. `refine issues` refuses a commit that adds a row. `cmd_issue_hotfix` logs through it.
  * `issue_provider(step, n, …)` -> the one wrapper for provider calls (P-74), steps `log`, `refine`, `fix`, `fix-abort`, `abort`, `close`, `list`: builds the whole-issue payload, calls `run_action_plugin`, applies the answer (§5), and without a provider runs the kit's part. It lives here, not in `lib/aapp-lib.sh`, so the hooks never receive it. A failing provider falls back to the kit with a warning; `log` and `next-blocker` refuse.
  * `cmd_issue_hotfix` / `cmd_issue_fix` / `_issue_fix_abort` -> P-52 hotfix (row, 🧱 Plan Blockers queue, `Emergency Hotfixes:`, block via `plan_block_on`, one commit) and temporary mini plans `current/fix-<num>.md` (one at a time; verbose wait up to `aapp.issueFixWait`, also for files with uncommitted changes, via `_issue_roll`; the timeout message `_issue_busy_refusal` names `hotfix` when the bound plan owns the file, P-58).
  * `issue_location_paths(row)` -> the path tokens of a row's Location cell (exists, or has `/` or an extension; `:lines` stripped); `issue_queued_blockers(plans)` -> 🧱 Plan Blockers that are active and not Planned. Shared with the start gate (P-58).
  * `_issue_notice_listing_plans(plans, files…)` -> at close, `<plan> also lists <file>` for other ⚡/BLOCKED plans; output only (P-58).
  * `_issue_reapply_stash(n)` -> single-checkout hotfix stash (recorded by SHA in `aapp_hotfix_stash`) re-applied at close; a conflict keeps it (P-52).
  * `_issue_lock_acquire` / `_issue_lock_release` -> the shared issue lock `$(git rev-parse --git-common-dir)/aapp_issue.lock` (PID-based stale takeover).
  * `issue_unblock_plans(n, [sha])` -> drops `#n` from a plan's `Blocked On:` (`plan_unblock` in `cmd_plan.sh`) when the fix commit is reachable from that plan's parent branch (`_issue_fix_in_parent`; always for a withdrawn issue, which has no sha); used by `issue close` and `cmd_done`. `issue_unblock_landed([quiet])` -> the later sweep, in one commit: plans still blocked on an archived issue resume once its commit is in their parent branch; run by `aapp status` and by `done` after it integrates (P-52, P-78).
  * `issue_branch(n)` / `_issue_branch_state(n)` / `_issue_fix_worktree(n, branch)` / `_issue_land_fix(n, mini)` -> a fix opens on the issue's branch: in the main checkout when it is on that branch, otherwise in `.workspace/fix-<id>` cut from it (the mini plan's `Base` names the branch) and landed by fast-forward at `close`; a group's feature branch is one such branch; a branch that is gone falls back to the development branch (`_issue_clear_gone_branch`). `issue_view_branch` -> the branch issues are seen from, for the views (a plan's or fix's worktree: the plan's parent, `issue_plan_parent`); it never decides an issue's branch: a row names one only when given, and a hotfix names the blocked plan's parent branch; `issue_move_branch(old, new)` retargets the issues of a branch the kit removed (P-64, P-78).
  * `cmd_issue_abort(n, …)` -> withdraws an active issue (P-76): its promoted plan through `cmd_plan_abort` (subshell), its open mini plan through `_issue_fix_abort`, then the row through `_issue_archive_active(n, cell, summary, subject, [mini, entry])`, the one archive commit `issue close` also uses (unblock, `ledger_archive_row`, stash re-apply, matrix); `_issue_report_unblocked` prints which plans resumed.
  * `issue_drop_stash_records(root, n…)` -> removes an aborted plan's lines from `aapp_hotfix_stash`; the stashes stay (P-69).
* **Consumers:** `aapp issue`, and `lib/cmd_plan.sh`: `cmd_done` closes a plan's Target Issue and repairs links inside its archive commit; `refine … slug` repairs links; `draft … issue` and `plan abort` change the row's status and send the `refine` step.
* **Anti-Wrapper Warning:** Never hand-write or hand-move a row; use `aapp issue log`, `aapp issue close`, `aapp issue abort` or `aapp done`. Never call a provider outside `issue_provider`.
````

<!-- aapp-base: 8c45b6dafe4a86dca21280df0440d4121f979e2fb5bee58532387117afb64c95 -->
````markdown
### 📚 Shared Hook Library (`lib/aapp-lib.sh`)
* **Purpose:** Single owner of plan-section parsing, glob matching and platform detection, sourced by the CLI and both hook engines (P-37).
* **Public Interface:**
  * `parse_plan_target_paths(file)` -> Write targets from `Target Files`, `Emergency Hotfix Extensions`, `Required Test Files` inside §4.
  * `parse_plan_oob_paths(file)` -> Vetoed paths from `Out of Bounds` inside §4.
  * `parse_plan_required_test_files(file)` -> Declared test file paths under `### 🧪 Required Test Files` inside §4 (Option A single-entry semantics).
  * `parse_plan_required_tests(file)` -> Declared test items under `### 🧪 Required Tests` inside §3 (isolates path prefix).
  * `plan_has_required_test_files(file)` -> True when §4 carries `### 🧪 Required Test Files`.
  * `validate_plan_tdd_correspondence(file, [prefix])` -> Validates non-empty sections and bidirectional correspondence between §3 and §4.
  * `aapp_shared_docs_regex()` / `aapp_is_shared_doc(path)` -> The one definition of shared docs (CHANGELOG, README, MANUAL, CHEATSHEET, CODEMAP, ARCHITECTURE, ISSUES): exempt from the `aapp start` gate and Pair 7, and the base of the pre-commit always-allowed list (P-48).
  * `aapp_plan_changelog_decl(file)` / `aapp_render_changelog_bullet(text, id)` / `aapp_changelog_plan_line(id)` -> The plan's `**Changelog:**` declaration, its rendered bullet, and the plan's bullet under `## [Unreleased]` (P-48). Used by `aapp commit` (writes it), `aapp freeze` (validates it) and the pre-commit hook (`plan` mode check).
  * `parse_plan_commits(file)` -> Parses recorded `sha (branch)` and `sha (detached)` commits from blueprint header.
  * `write_plan_commits(file, commits...)` -> Replaces or inserts `* **Commits:**` line in blueprint header.
  * `write_plan_base(file, sha, branch)` -> Records `* **Base:** <sha> (<branch>)` if currently `none`.
  * `find_worktree_holding_plan(plan_file)` -> Finds if a plan is bound in another worktree's execution buffer (the primary's relative buffer path is resolved against it, so it works from a plan worktree, P-54).
  * `parse_plan_base(plan_file)` -> the recorded Base SHA, empty when never started (#103). `parse_plan_worktree` / `write_plan_worktree` -> the header's `* **Worktree:** <path> (<branch>)` (P-54).
  * `resolve_plan_integrate_target(plan_file)` / `count_plan_emergency_hotfixes(plan_file)` / `check_worktree_ignored_files(worktree)` -> P-55 read-only helpers: the integration target per `aapp.integrateTarget`, the hotfix count, and the sensitive ignored files a removal would delete.
  * `aapp_dev_branch` / `aapp_branch_ref(name)` -> first `aapp.devBranch` candidate present locally or on a remote, and the ref to branch from; `aapp_render_plan_template`, `aapp_abs_path`, `aapp_rel_path` -> name templates and lexical path math for plan worktrees (P-54).
  * `aapp_held_plans` / `aapp_plan_held_by(plan_file, held)` -> one-pass list of plans held by other worktrees' buffers, and the match used by the five single-plan discovery sites (guard, hook plan and changelog checks, `aapp commit`, `aapp active`) so an unbound checkout neither adopts a held plan nor edits its files (P-52).
  * `extract_plan_section(n)` -> Stdin filter printing numbered section `## … n.` (design lock).
  * `glob_to_regex(pattern)` / `match_pattern_list(target, patterns…)` -> Exact, directory-prefix and glob matching.
  * `aapp_os([uname_s] [proc_version])` -> `linux|darwin|windows|wsl|bsd|unknown`; `wsl` is a GNU userland.
  * `aapp_lib_loaded()` -> Load sentinel every consumer asserts.
  * **Issue ids (P-79), the one definition:** `issue_id_valid(text)`, `issue_id_normalize(text)` (`46`, `#46`, `PROJ-101` -> `#…`), `issue_id_refs(text)` (the ids named in a line), `issue_id_is_numeric(id)` (the counter looks at these only), `issue_fix_name(id)` / `issue_fix_id(name)` (the mini plan's file name and back).
  * **Issue ledgers (P-73), the one accessor:** `ledger_path(issues|archive|roadmap)` (the plans worktree when inside one, then `.plans/`, then the repository root), `ledger_commit_paths`, `ledger_row(n)`, `ledger_rows([status])` (tab-separated cells by column name, with `Branch`; link and `Planned` status derived from the plans when the ledgers are untracked), `ledger_ids(which)`, `ledger_locate(n)`, `ledger_add_row(row)`, `ledger_cell(n, link|status|branch|commit, [issues|archive])`, `ledger_set_cell(n, link|status|branch, value)` (cells found by the header's column names; the `Branch` column is added by the first write that names a branch), `ledger_branch(n)`, `ledger_branch_map`, `ledger_move_branch(old, new-cell)`, `ledger_archive_row(n, sha|aborted, summary)`, `ledger_relink(old, new)`, `roadmap_entries([cap])`, `roadmap_entries_by_branch(current, dev, [cap])`, `roadmap_blockers`, `roadmap_add_blocker(n, text, plan)`, `roadmap_prune(n|resolved)`; the description and notes store under `~/.local/state/aapp/<key>/` is read and written here too (P-74).
* **Consumers:** `lib/cmd_plan.sh`, `lib/cmd_commit.sh`, `lib/planning_health.sh` (Pair 7), `.githooks/aapp-pre-commit`, `.githooks/blast-radius-guard`.
* **Anti-Wrapper Warning:** Never add an inline section parser, an issue id pattern or a ledger read elsewhere; extend this library and its tests (`tests/aapp_lib_test.sh`, `tests/issue_id_test.sh`, `tests/issue_ledger_test.sh`). Edit `lib/aapp-lib.sh`, never `templates/aapp-lib.sh` (a symlink) or `.githooks/aapp-lib.sh` (installed by `aapp init`).
````

<!-- aapp-base: 0337e6d58c5ee1a15d986a4e171f942feb6f3c3f08efee6ebf503fe5cfdfcb5f -->
````markdown
### 🛡️ Planning Health Integrity Engine (`lib/planning_health.sh`)
* **Purpose:** Automated mechanical integrity validator running 8 orthogonal verification pairs:
  * **Pair 1:** Disjointness between active `ISSUES.md` and `000-issues-archive.md`.
  * **Pair 2:** Referential integrity between `issues_road_map.md` and active `ISSUES.md`.
  * **Pair 3:** Pickup queue routing hygiene (`.plans/pickup.md`).
  * **Pair 4:** Plan ID uniqueness, header agreement, and reference integrity.
  * **Pair 5:** Self-protection safety (blocks Section 2 targets in blueprint `Target Files`).
  * **Pair 6:** Recorded hexadecimal commit SHA existence in git object database.
  * **Pair 7:** Concurrent boundary collision detection for multiple `⚡ In Development` plans.
  * **Pair 8:** Issue ID repeated within `ISSUES.md` or within the archive (cross-ledger collisions are Pair 1).
* **Ledger checks** read rows through the ledger functions of `lib/aapp-lib.sh` (P-73): `check_fix_cells` (the fix cell holds verb-written links only, P-66), `check_issues_table_shape`, and `check_ledger_issues`, which `aapp refine issues` runs and which refuses a commit that adds a row (P-74).
* **Anti-Wrapper Warning:** Keep health checks mechanical, fast, and free of external runtime dependencies.
````

<!-- aapp-base: efb596089c14e498c645eb0d49dff78613755944cb54e25bb0ccf4182ebb9107 -->
````markdown
### 🪝 Lifecycle Hooks & Action Plugins Engine (`lib/hook_dispatcher.sh`, `lib/cmd_hook.sh`)
* **Purpose:** Zero-dependency lifecycle hook dispatch, SHA-256 cryptographic integrity verification, process watchdog timeout gating, and dynamic action plugin discovery.
* **Key Functions:**
  * `dispatch_hook(event, data_json, repo_root)` -> Dual Delivery dispatcher streaming JSON on `stdin` alongside exported `AAPP_*` environment variables with process watchdog timeout enforcement (exit 124 on timeout).
  * `execute_with_watchdog(cmd, timeout)` -> Process watchdog isolating execution with configurable timeout (`aapp.hookTimeout`, default 10s) and terminating runaway handlers; every plugin call runs under it too, with its own limit `aapp.pluginTimeout` (default 10s, P-77).
  * `build_event_envelope(event, data_json)` / `run_action_plugin(entry, root, action, event, data_json)` / `json_field(json, key)` / `json_escape(text)` -> The shared envelope (with `repository.remote` and reserved `extra`), the plugin call, and flat-answer parsing: see §5 **Plugin Payload Standard**.
  * Answer handling (P-77): reads `status`, `message`, `handled` and `version`; delivers each line of the list file; runs the `do` list after the plugin exits and the step has released its lock (whitelist `lib/plugin_do.tsv`, in order, each command under its own lock, each result reported, the asking plugin not called again); marks the plugin's environment so a writing verb run during a step refuses.
  * `resolve_plugin_entrypoint(pdir, name)` -> Extension-agnostic plugin resolution (`run`, `$name`, `scripts/run`, `scripts/$name`, pattern match) with `.sample` exclusion filtering.
  * `cmd_plugins_status()` -> `aapp plugins`: **Kit Plugins** (every row of `lib/plugins.tsv`, installed or not, incl. `RESERVED (planned, …)`), a `==========================` delimiter, then **Your Plugins** (any other executable plugin in `.agents/skills/`, with a warning for unregistered `aapp-*` names). Fails closed when the registry is missing (P-46).
  * `cmd_hooks_status()` / `cmd_hook_hash()` -> Validates executable bits and live SHA-256 integrity against `.agents/skills/aapp-hooks/registry.tsv`. Refuses execution on hash mismatches in `mode=gate`.
* **Test gate (P-60):** `examples/hooks/test-gate.sh.sample`, a `pre-done` gate running the handler's `TEST_CMD` in the payload's `worktree` (else the repository root); dogfooded as `.agents/hooks/test-gate.sh`.
* **Anti-Wrapper Warning:** Never bypass `registry.tsv` hash verification or run unhashed handlers in `mode=gate`.
````

<!-- aapp-base: f2c0615c23f8a44b80896157365d2ce7a08329234665fcc90d677b405f1918d8 -->
````markdown
## 🔌 5. Canonical Extension Points & Action Plugins Registry

To prevent naming drift across development, blueprint authoring, and runtime tooling, standard plugin extension points are cataloged here. The runtime switchboard and `aapp plugins` inspect these standard names directly:

| Plugin Name | Namespace / Role | Invocation Trigger | Input / Output Contract | Shipped Sample Source | Installed Target |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`aapp-issue-tracker`** | Issues | `issue_provider` (`lib/cmd_issue.sh`) | Payload Standard: `issue.log`, `issue.refine`, `issue.fix`, `issue.fix-abort`, `issue.abort`, `issue.close`, `issue.list`, `issue.next-blocker`; reference `docs/reference/07-issue-protocol.md` | `examples/plugins/aapp-issue-tracker/run.sample` | `.agents/skills/aapp-issue-tracker/run` |
| **`aapp-issue-note-filter`** *(P-80)* | Issues | The note hand-over of `issue fix` and `issue list <n>` (`lib/cmd_issue.sh`) | Payload Standard: `issue.note-show` → `{"status": "ok", "note": "<text to show>"}`; a failure withholds the note; the stored note is untouched | `examples/plugins/aapp-issue-note-filter/run.sample` | `.agents/skills/aapp-issue-note-filter/run` |
| **`aapp-issue-tracker`** | Core Identity | `allocate_issue_id` (`lib/plan_resolver.sh`), `issue_notify_close` (`lib/cmd_issue.sh`) | Payload Standard: `issue.allocate` → `{"id": "#<int>"}`; `issue.close` → `{"status": …}`, fire-and-forget | `examples/plugins/aapp-issue-tracker/run.sample` | `.agents/skills/aapp-issue-tracker/run` |
| **`aapp-review`** *(P-15)* | Code Quality | `/aapp-review` / CLI dispatch | Review Packet JSON on `stdin` → Markdown findings on `stdout` | `examples/plugins/aapp-review/run.sample` | `.agents/skills/aapp-review/run` |
| **`kit-on-release`** *(P-59)* | Kit Lifecycle | `on-release` hook (`scripts/kit-on-release.sh`) | Triggered during `aapp release` -> synchronizes `templates/` delimiters with `.agents/AGENTS.md` and verifies test suite | In-repo script | `scripts/kit-on-release.sh` |
| **`hello-tool`** | Showcase / Demo | `aapp hello-tool` | CLI arguments → stdout greeting | `examples/plugins/hello-tool/run.sample` | `.agents/skills/hello-tool/run` |
### 📨 Plugin Payload Standard (P-32, P-77)
The issue plugins the kit calls (`aapp-issue-tracker`, `aapp-issue-note-filter`) speak one exchange; `aapp-planid` keeps its present contract (`plan.allocate` → `{"id": "P-<int>"}` or a bare number) until plans get their own chapter. Built by `build_event_envelope`, sent by `run_action_plugin`, answers read by `json_field` (all in `lib/hook_dispatcher.sh`). The full reference, kept equal to the code by a test, is `docs/reference/06-plugin-protocol.md` and `docs/reference/07-issue-protocol.md`.

**The kit asks: JSON envelope on stdin**
```json
{
  "version": "1.0",
  "event": "issue.log",
  "timestamp": "2026-10-12T09:14:03Z",
  "actor": "lorand",
  "repository": {
    "root": "/path/to/project",
    "branch": "develop",
    "remote": { "name": "origin", "url": "git@github.com:acme/app.git" }
  },
  "data": { "severity": "High", "type": "CORE", "date": "2026-10-12", "location": "lib/auth.sh",
            "symptom": "login fails on Safari", "branch": "develop", "status": "Incubated", "link": "", "description": "seen by QA on Safari 17" },
  "extra": {}
}
```
* **`event`:** the step. `data` carries the whole subject; `issue.log` has no `id`, every later issue step has one.
* **`repository.remote`:** `aapp.remote` (default `origin`) via `git remote get-url`; credentials stripped; `null` without a remote. The envelope carries no secret; credentials are the plugin's responsibility.
* **`extra`:** reserved for arbitrary data, `{}` by default; the kit never interprets it.
* **env:** `AAPP_ACTION`, `AAPP_REPO_ROOT`, the step's ids, and the two answer files `AAPP_PLUGIN_LIST` and `AAPP_PLUGIN_DO`.

**The plugin answers: one flat JSON object on stdout; the exit code decides**
```json
{ "status": "ok", "message": "Created PROJ-101 on the tracker", "handled": "description, notes", "id": "PROJ-101", "tracker": "jira" }
```
* **`status`:** `ok`, `declined` (the kit does everything) or `failed`. **`message`:** one sentence shown to the user.
* **`handled`:** what the plugin took care of; whatever it does not name, the kit does.
* **`id`:** required on `ok` for `issue.log`: the plugin's own key or number becomes the id. `tracker` and `url` are informational and never interpreted.
* **`AAPP_PLUGIN_LIST`:** one flat object per line in the shape of `data` (the issues of `issue.list`).
* **`AAPP_PLUGIN_DO`:** aapp commands as a person types them, one per line, run after the step from the whitelist `lib/plugin_do.tsv`; a refused line is reported and the rest still run.
* A plugin running a writing `aapp` verb during a step is refused and pointed to `do`; reading verbs work. An answer echoing a newer `version` is refused. Plain-text output is rejected.
* Plugin **absence** means the kit does everything. A failing plugin: each step defines the outcome (`issue.log` and `issue.next-blocker` refuse; the others fall back to the kit with a warning).

### 📋 Extension Point Rules
1. **Verbatim Naming Invariant:** Shipped sample directories in `examples/plugins/<name>/` match the canonical installed plugin directory in `.agents/skills/<name>/` **verbatim**. No rename translation mapping is permitted.
2. **The `.sample` Inactive Suffix:** Reference examples carry the `.sample` suffix (`run.sample`, `.sample/` directories). The execution engine and resolver strictly ignore `.sample` assets until an adopter explicitly activates them.
3. **Runtime Source of Truth:** `lib/plugins.tsv` (P-46) is the shipped registry of kit-reserved names (`name`, `role`, `state` = `shipped` | `planned:<plan-id>`, `events`, `counter`, `sample`); this table documents it. It is kit-owned and replaced on every install/upgrade — adopters never edit it, and their own plugins need no row. A new kit plugin is one registry row; a test fails when a sample directory or a plugin-name literal in `lib/` has no row.
4. **Supported and ad hoc:** the exchange above binds the plugins the kit calls by reserved name. Any other plugin or script is a CLI user: the CLI's locks and checks are its only safeguard.
````

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `ARCHITECTURE.md` -> Sections from `## Architecture & Codemap`, applied at the group's `done`.
- [ ] `.agents/CODEMAP.md` -> Sections from `## Architecture & Codemap`, applied after the merge.

### 🛑 Out of Bounds (Do Not Touch)

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*

---

## 📦 6. Change Log & Refinement History
* **2026-10-12:** Group started: `feature/issue-tracker` from `develop`.
* **2026-10-12:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-10-11:** Group drafted.
