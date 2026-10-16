# 🗺️ Code Map & Interface Registry: Agent Planning Kit (AAPP)

> **Rule for All Agents:** Before creating a new file, script, function, or wrapper, you MUST scan this map. If a module exists that covers the concern, you must extend or import it. Maintain single sources of truth for path resolution, state transitions, and configuration.
>
> **The Callable Contract Standard:** For each component, record the callable contract: invocation forms (arguments, stdin), outputs (stdout, stderr), exit codes, environment variables read, and files touched. An agent must be able to call or test it without reading the source.

---

## 🏗️ 1. Core Executables & CLI Switchboard

### 🚀 Primary Dispatcher (`aapp`)
* **Purpose:** Single source of truth for CLI entrypoint, base resolution, and command routing.
* **Key Functions:**
  * `has_kit_signature(dir)` -> Validates presence of essential kit structures (`templates/`, `pre-commit`, `AGENTS.md`, `lib/`, `cmd_init.sh`).
  * `is_safe_to_consume_kit_dir(dir, keep)` -> Content-based signature, file manifest audit, and clean git working tree check protecting non-kit assets and development checkouts from self-consumption.
* **Responsibilities:** Resolves runtime environment (`AAPP_RUNTIME=installed|local`, `AAPP_BASE`), exports core environment variables, enforces front-door repository membership assertions, and delegates to `lib/` modules.
* **Anti-Wrapper Warning:** Never write wrapper shell scripts around `aapp` commands; invoke `aapp` directly.

---

## ⚙️ 2. Operational Modules & Command Libraries (`lib/`)

### 📦 Workspace Initializer & Worktree Manager (`lib/cmd_init.sh`)
* **Purpose:** Single source of truth for target repository resolution, multi-orphan worktree mounting, delimited block synchronization, and Claude Code settings bridging.
* **Key Functions / Blocks:**
  * `mount_or_create_worktree(branch, dir)` -> Safely provisions or mounts orphan worktrees (`plans`, `agents`, `githooks`).
  * `sync_agent_rules()` -> Delimited block updater (`<!-- AAPP-PROTOCOL:START -->` ... `<!-- AAPP-PROTOCOL:END -->`) preserving custom user rules in `AGENTS.md`.
  * `copy_guarded(src, target, msg)` -> Non-destructive file copy that never overwrites existing user content.
  * Canonical Physical Fast-Fail -> Asserts `[ "$AAPP_RUNTIME" = "installed" ] || [ "$AAPP_BASE_PHYSICAL" = "$REPO_ROOT_PHYSICAL" ]`, fast-failing any attempt to run `init` from an uninstalled clone against an external repository.
* **Anti-Wrapper Warning:** Do not implement ad-hoc worktree creation or rule-sync logic outside this module.

### 🌐 Global Installer & Self-Consumption Manager (`lib/cmd_install.sh`)
* **Purpose:** Installs binary to `~/.local/bin/aapp` and shared libraries/templates to `${XDG_DATA_HOME:-~/.local/share}/aapp-kit/`.
* **Key Behaviors:**
  * Evaluates `is_safe_to_consume_kit_dir` before unlinking temporary installer clones.
  * Preserves development checkouts and existing projects automatically with zero-flag minimalism.
* **Anti-Wrapper Warning:** Do not alter PATH or rc files destructively.

### 🎯 Plan Lifecycle Switchboard (`lib/cmd_plan.sh`)
* **Purpose:** Single source of truth for in-flight plan execution state and worktree context buffers.
* **Key Commands:**
  * `aapp refine <plan> "<msg>"` -> Commits an edit to an active plan's content (only the plan file, through `plans_commit`); the agents' path for plan edits, so nothing runs raw git on `.plans` (P-47). Tokens: `blocked <num>` (`plan_block_on`, P-49); `slug <new-slug>` renames the file and repairs links (`_refine_slug`, P-50). Reserved targets `pickup` / `issues` commit validated ledger edits (`_refine_ledger` + `check_ledger_issues` / `check_pickup_entries` in `planning_health.sh`, P-50).
  * `aapp draft <slug> issue <num>` -> promotion: Target Issue, `issue_mark_planned`, one commit (P-50).
  * `aapp tdd <plan>` -> Injects failure test declaration sections (`### 🧪 Required Tests` in §3, `### 🧪 Required Test Files` in §4) into an incubator blueprint before freeze.
  * `aapp freeze-start <plan>` -> Atomic validator, disjointness check, status update (`⚡`), and buffer binding.
  * `aapp freeze <plan>` -> Locks blueprint into 🔷 Frozen backlog specification, verifying TDD correspondence if present.
  * `aapp start <plan>` -> Activates frozen specification (`🔷`) into development (`⚡`).
  * Plan worktrees (P-54) -> `_wt_parse_tokens` (`worktree`/`branch`), `_wt_prepare` (render, refuse, base), `_wt_create` (worktree, kit links, `info/exclude`, bind), `_wt_locate` (read back after `on-start`), `_wt_rollback` (snapshot restore), `_wt_session` (`aapp.planSession`, detached); `_wt_start` runs them as one transaction for `start` and `freeze-start` on a plan's first start. `done` refuses a dirty plan worktree, clears the holding worktree's buffer and prints the removal advice.
  * `aapp done <plan>` -> Archives implemented plan to `done/`, enforcing mechanical TDD completion gate (`tdd (N/N)` recorded in archive ledger).
  * Plan branch integration (P-55) -> `_ig_parse_tokens`, `_ig_decide` (worktree plans only; `aapp.integrate`), `_ig_preflight` (every check before the archive; issue lock), `_ig_run` (squash / ff / `on-integrate` after the archive; retry-safe), `_ig_message` (lineage + attribution trailers), `_ig_cleanup` (ignored-file refusal, quarantine), `_ig_resolve_done` / `_ig_standalone` (`done <id> integrate` on an archived plan).
  * Further issues a plan closes (P-86) -> `plan_also_closes(plan_file)` (the ids of `* **Also Closes:**`), `_refine_closes(plan, num, [remove])` (`refine <plan> closes <num> [remove]`: active issue, not the plan's own Target Issue; the row is not touched); `cmd_done` archives each listed issue with the recorded commit after the Target Issue, skipping an archived one and leaving open one whose branch neither is the plan's parent nor holds the commit; `_issue_dependent_ids` in `cmd_issue.sh` counts them.
  * The squash on the plan branch (P-84) -> `plan_made_for_issue(plan_file)` (the plan's `Target Issue` and the issue's `Planned` row linking the plan agree; used by `start` / `freeze-start` to give such a plan its own worktree, and by `done`), `_sq_decide` (every plan under `squash`; a plan made for an issue under any setup; never a group), `_sq_run` (one commit on the plan branch with `_ig_message` and the last commit's `AI-*` trailers; sets `SQ_OLD`, `SQ_NEW`), `_sq_restore` (the former tip, when the archive fails), `_sq_label`, `_sq_correct_records` (a plan archived earlier and squashed by `done <id> integrate squash`: `Commits:`, archive ledger line, `ledger_set_archive_commit`, one `plan(record)` commit). `cmd_done` records `SQ_NEW`; `_ig_run` fast-forwards in every mode.
  * Group plans (P-64) -> a plan whose title is `# 🧩 Group Plan P-<n>:` (`aapp_is_group_plan`, `templates/group-template.md`): `draft … group [<id>]`, `_refine_group` (join/leave until started), `_group_start` (feature branch from the parent, no worktree), `_member_group_check` / `_wt_prepare` (members start from the feature branch), `_group_done_prepare` (open members, section dry runs, `.workspace/P<n>`, parent merge, ARCHITECTURE sections and umbrella changelog via `aapp commit`; then the normal `done` path with `IG_MODE=ff`), `_group_done_codemap` (CODEMAP sections after the merge), `_group_stamp_sections` (base lines at `refine`). `_wt_link_kit` is shared with plan worktrees.
  * Plan conflict audit (P-65, read-only) -> `plan_compare_targets(a, b)` (exact non-shared target intersection, as the activation gate), `cmd_plan_conflict_check` (pairwise, groups expand, exit 1 on collision), `cmd_plan_conflict_free` (pending vs ⚡; `_pc_against` for one plan; `_pc_waves` for a group: members in listed order into the first disjoint wave, wave 1 also clear of ⚡ plans), `json` token; dispatched from `cmd_plan_switchboard`.
  * Plan abort (P-69) -> `cmd_plan_abort` (routed by `cmd_plan_switchboard`): `_ab_parse_tokens`, `_ab_check_worktree` / `_ab_check_issue` (every refusal before any change), `_ab_archive_one` (move to `aborted/`, header, `000-aborted-ledger.md`, issue row, group member), `_ab_restore` (snapshot on a failed commit), then `_ab_teardown` / `_ab_drop_branch` (worktree, branch) and `_ab_hook` (`post-abort`). A group plan archives its open members in the same commit. `_wt_quarantine` is shared with `_ig_cleanup`.
  * `aapp active [id]` -> Displays or sets active plan pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`).
  * `aapp active swap` / `aapp active clear` -> Toggles between current and previous buffer or clears context.
  * `aapp plan-status [id]` -> Deterministic read-only inspector for plan matrix or specific blueprint.
  * `aapp plan [query]` -> Educational planning switchboard guiding users and agents.
  * Disjointness Activation Gate -> Shared docs only print a `[Shared Doc]` notice (P-48); otherwise enforces non-overlapping target file sets between concurrent `⚡ In Development` plans, and refuses a start on a file named by a queued 🧱 Plan Blocker (`issue_queued_blockers` + `issue_location_paths`, P-58).
* **Anti-Wrapper Warning:** Never manually write to `.git/aapp_active_plan` without going through `cmd_plan.sh`.

### 🎨 Plan Status Registry (`lib/plan_states.sh`)
* **Purpose:** Single source of truth for which plan statuses exist and how each one renders. Pure module with no top-level side effects; safe to source anywhere.
* **Key Functions:**
  * `plan_states_load()` -> Loads kit defaults, then merges adopter overrides from `git config aapp.planState.*`. Idempotent.
  * `plan_state_for_status_line(line)` -> Resolves a raw `**Status:**` line to a slug, or empty if unrecognized. Matches by **canonical name, not emoji**.
  * `plan_state_field(slug, field)` -> Accessor for `emoji` / `name` / `heading` / `rank`.
  * `plan_state_sections()` -> Unique matrix headings in rank order, deduplicated (`under-review` and `refining` deliberately share one).
  * `plan_state_emoji_class()` -> Alternation of live status glyphs, for callers that must match any status.
* **Adopter Extension:** `git config aapp.planState.<slug> "<emoji>|<name>|<heading>|<rank>"`. A slug matching a kit default overrides it in place; a new slug is appended. Malformed tuples warn to stderr and are skipped — never fatal.
* **Accessibility Invariant:** The shipped glyph set (`🟣 📝 🔷 ⚡ 🟥`) is colour-blind friendly and is a hard design constraint. The retired `🔴`/`🟡` pair is the red/green-family combination that fails common colour-vision deficiency and carries **no alias**; a plan still using one resolves as unrecognized so it gets cleaned up. Adopter-defined glyphs should be shape- or symbol-distinct rather than hue-distinct.
* **Anti-Wrapper Warning:** Never hardcode a status emoji alternation (`🟣|🔷|📝`) or an `In Development` / `Frozen` regex. Source this module and use the accessors.

### 🔄 State Matrix Derivation Engine (`lib/cmd_matrix.sh`)
* **Purpose:** Derives `.plans/state_matrix.md` from the `**Status:**` lines in `.plans/current/*.md`. The matrix is a generated view, never a record.
* **Key Commands:**
  * `aapp matrix` -> Checks and syncs in one pass. Reports what changed; silent when already in sync.
  * `aapp matrix --check` -> Read-only audit. Exits `0` in sync, `1` on drift. Never writes.
* **Callers:** `aapp status` (before reading the matrix, so the briefing reports the real board) and `draft` / `freeze` / `freeze-start` / `start` via `sync_state_matrix()` in `cmd_plan.sh` (before staging, so each lifecycle commit carries a correct matrix).
* **Library Mode:** Source with `AAPP_MATRIX_LIB_ONLY=1` to load `cmd_matrix()` without executing it.
* **Derivation Contract:**
  * Population is strictly `.plans/current/*.md`. A row with no backing plan file disappears; the archive ledger is terminal.
  * Sections and their order come from the status registry — **no code anchors on heading text.**
  * Human-owned content is preserved: the Roadmap block verbatim, and each row's annotation after the **first** ` — `, keyed by Plan ID so it follows a plan across sections.
  * A status matching no registry entry lands in a visible *Unrecognized Status* section rather than being folded into the Incubator.
* **Pause Behaviour:** The pause allowlist excludes `state_matrix.md`, so a sync while paused cannot be committed. It writes anyway and reports the commit as deferred until `aapp resume` — the uncommitted diff is the record of how the board moved during the pause.
* **Anti-Wrapper Warning:** Never patch a matrix row with `sed`. That was the previous approach and it could recolour a row but never relocate it, leaving frozen plans under the Incubator. Call `sync_state_matrix` (or `aapp matrix`) instead.

### 🧭 Plan ID Standards & Shorthand Resolver (`lib/plan_resolver.sh`)
* **Purpose:** Canonical resolver for ADR-style Plan IDs (`P-<num>`), filenames, and slugs.
* **Key Functions:**
  * `resolve_plan_path(query)` -> Maps `P-13`, `13`, `guard-path`, or `P13-*.md` to absolute blueprint path.
  * `get_plan_id(path)` -> Extracts the declared unpadded Plan ID from a blueprint header.
  * `get_next_plan_id()` -> **Read-only peek** at the next Plan ID from the `aapp.planId` counter. Never mutates; claims nothing.
  * `allocate_plan_id()` -> **Claims** a Plan ID and persists the increment. Delegates to an optional `aapp-planid` provider plugin (`.agents/skills/aapp-planid/`); only plugin *absence* falls back to the local counter, a present-but-failing provider is fatal.
  * `normalize_plan_id(raw)` -> Accepts `P-42` or bare `42`; anything not a plain integer is an error.
  * `get_next_issue_id()` / `allocate_issue_id()` -> Same contract for issue IDs (`#<n>`, `aapp.issueId`, optional `aapp-issue-tracker` provider), except an unset counter is seeded on first use by `seed_issue_id` (both ledgers, template rows skipped; no ledgers and no provider refuses). Both ID kinds share `_next_id` / `_allocate_id` / `_normalize_id` (P-32).
  * `verify_transition_target(cmd, target)` -> Rejects empty queries and `#`-prefixed issue collisions.
* **Anti-Wrapper Warning:** Do not parse plan filenames using raw ad-hoc `grep` or `cut`; use `resolve_plan_path`.
* **Allocation Warning:** Plan IDs are **stored, not derived**. Never reconstruct an ID by scanning filenames or the archive ledger — that approach was removed (issue `#69`). Use `allocate_plan_id` to claim, `get_next_plan_id` to display.

### 🐛 Issue Lifecycle Verb (`lib/cmd_issue.sh`)
* **Purpose:** `aapp issue [log | hotfix | fix | close <id> | abort <id> | list]` (P-32, P-52, P-74, P-76); contract in `lib/docs/verbs/issue.md`.
* **Key Functions:**
  * `cmd_issue_log` -> the one creator of a row (P-74): takes severity, type, symptom, `file`, `branch`, `note`; sends the `log` step; writes the row through `ledger_add_row` with the id the provider returned, or the counter's without a provider; commits. `refine issues` refuses a commit that adds a row. `cmd_issue_hotfix` logs through it.
  * `issue_provider(step, members)` -> the one wrapper for provider calls (P-74), steps `log`, `refine`, `fix`, `fix-abort`, `abort`, `close`, `list`, `next-blocker`: sends event `issue.<step>` with the members as `data` through `plugin_step` and leaves the answer in `PLUGIN_*`; without a provider it does nothing and the caller does the kit's part. It lives here, not in `lib/aapp-lib.sh`, so the hooks never receive it. `_issue_step(step, n, members)` is the form for a step already done locally: a failing provider only warns. `log` and `next-blocker` refuse on failure. `issue_payload(n)` -> the whole issue as members. P-75 hooks in here: `log` returns `ISSUE_GO_OFFLINE` when the provider fails or is not to be asked, and any other step is kept in `.offline/outbox` (`_issue_outbox_add`, sent by `issue_outbox_flush`); `_issue_enter_offline(n)` points the rest of a command at the offline ledgers for an issue staged there.
  * `_issue_log_row(sev, type, symptom, location, link, branch, description, board)` -> the one writer of new rows, behind `cmd_issue_log` and `cmd_issue_hotfix`: the id is the provider's (`issue.log` is sent with none) or the kit's counter's; staged in `.offline` when the provider is unreachable. `_issue_symptom` holds the one-line, 250-character rule.
  * `issue_sync([force] [confirm])` -> brings the ledgers up to date from a provider that lists issues: the outbox first; the window (`aapp.issueSyncWindow`); the request (`open`, `limit`, `since`, `ids` from `_issue_dependent_ids`); `_issue_record_switch` the first time (one commit stops tracking the ledgers); `_issue_sync_apply` row by row (added, updated, archived when reported closed, cut to `aapp.issueCacheMax`, plan link and `Planned` derived from the plans); then the `do` list and `issue_unblock_landed`. Called by `cmd_issue_list` and `lib/cmd_status.sh`; never inside a plugin step.
  * `issue_show_text(n, [provider's text], [url])` -> the hand-over of an issue's description and notes at `fix` (`_issue_fix_handover`) and `issue list note <num>`: a labelled block, at most 100 lines, never copied anywhere. `_issue_filter_note(n, text)` runs the team's `aapp-issue-note-filter` first (P-80): its text is shown, `declined` shows the text unchanged, a failure withholds it. `issue_refine_step(n, notes…)` sends a row's change and its new notes; `_issue_keep_text` puts what no provider took into the kit's store.
  * `cmd_issue_hotfix` / `cmd_issue_fix` / `_issue_fix_abort` -> P-52 hotfix (row, 🧱 Plan Blockers queue, `Emergency Hotfixes:`, block via `plan_block_on`, one commit) and temporary mini plans `current/fix-<num>.md` (one at a time; verbose wait up to `aapp.issueFixWait` for an open fix, via `_issue_roll`).
  * `issue_location_paths(row)` -> the path tokens of a row's Location cell (exists, or has `/` or an extension; `:lines` stripped); `issue_queued_blockers(plans)` -> 🧱 Plan Blockers that are active and not Planned. Shared with the start gate (P-58). `issue_queued_work(plans)` -> 📋 Queued issues that are active and not Planned (P-89). `cmd_issue_queue(num, [remove])` -> `aapp issue queue`: a person's decision; the provider steps `issue.queue` / `issue.unqueue`, refused where the tracker keeps the record and does not take them; `cmd_issue_fix` opens only a blocker or a queued issue; `_issue_sync_apply` rebuilds 📋 Queued from the listing's `queued` field.
  * `_issue_notice_listing_plans(plans, files…)` -> at close, `<plan> also lists <file>` for other ⚡/BLOCKED plans; output only (P-58).
  * `_issue_reapply_stash(n)` -> single-checkout hotfix stash (recorded by SHA in `aapp_hotfix_stash`) re-applied at close; a conflict keeps it (P-52).
  * `_issue_lock_acquire` / `_issue_lock_release` -> the shared issue lock `$(git rev-parse --git-common-dir)/aapp_issue.lock` (PID-based stale takeover).
  * `issue_unblock_plans(n, [sha])` -> drops `#n` from a plan's `Blocked On:` (`plan_unblock` in `cmd_plan.sh`) when the fix commit is reachable from that plan's parent branch (`_issue_fix_in_parent`; always for a withdrawn issue, which has no sha); used by `issue close` and `cmd_done`. `issue_unblock_landed([quiet])` -> the later sweep, in one commit: plans still blocked on an archived issue resume once its commit is in their parent branch; run by `aapp status` and by `done` after it integrates (P-52, P-78).
  * `issue_branch(n)` / `_issue_branch_state(n)` / `_issue_fix_worktree(n, branch)` / `_issue_land_fix(n, mini)` -> every fix opens in `.workspace/fix-<id>`, cut from the issue's branch (the mini plan's `Base` names the branch; the main checkout is never bound, P-85), and lands at `close`: a refusal over uncommitted changes in the fixed files where the branch is checked out, the rebase, `_issue_squash_fix(n, mini, worktree, branch, base)` (a fix of several commits becomes one, subject `_issue_fix_subject(n, entry)` within `aapp.subjectMaxLen`, the last commit's trailers, notes through `_sq_carry_notes` of `cmd_plan.sh`; `_issue_unsquash_fix` undoes it when the fast-forward fails), then the fast-forward (`ISSUE_LANDED` is the commit recorded); a group's feature branch is one such branch; a branch that is gone falls back to the development branch (`_issue_clear_gone_branch`). `issue_view_branch` -> the branch issues are seen from, for the views (a plan's or fix's worktree: the plan's parent, `issue_plan_parent`); it never decides an issue's branch: a row names one only when given, and a hotfix names the blocked plan's parent branch only when every file it names is one of that plan's Target Files; `_issue_ask_branch(plans, n, files…)` -> for a row that names no branch, `fix` and a direct `close` put the issue and its files to the team's `aapp-issue-branch` plugin (event `issue.branch`): the answered branch is taken and written to the cell, `declined` or no plugin is the development branch, any failure refuses; `issue_bring_fix_to_groups(n, sha)` -> at `close` and after a plan's `done` integrates, a group's parent is merged into its feature branch (`group_merge_parent` in `cmd_plan.sh`, the merge the group's `done` makes) when a member waits for a fix that landed on that parent (P-83); `issue_move_branch(old, new)` retargets the issues of a branch the kit removed (P-64, P-78).
  * `cmd_issue_abort(n, …)` -> withdraws an active issue (P-76): its promoted plan through `cmd_plan_abort` (subshell), its open mini plan through `_issue_fix_abort`, then the row through `_issue_archive_active(n, cell, summary, subject, [mini, entry])`, the one archive commit `issue close` also uses (unblock, `ledger_archive_row`, stash re-apply, matrix); `_issue_report_unblocked` prints which plans resumed.
  * `issue_drop_stash_records(root, n…)` -> removes an aborted plan's lines from `aapp_hotfix_stash`; the stashes stay (P-69).
* **Consumers:** `aapp issue`, and `lib/cmd_plan.sh`: `cmd_done` closes a plan's Target Issue and repairs links inside its archive commit; `refine … slug` repairs links; `draft … issue` and `plan abort` change the row's status and send the `refine` step.
* **Anti-Wrapper Warning:** Never hand-write or hand-move a row; use `aapp issue log`, `aapp issue close`, `aapp issue abort` or `aapp done`. Never call a provider outside `issue_provider`.
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
  * **The work queue (P-89):** `issues_road_map.md` has two sections; `roadmap_blockers` / `roadmap_queued` (ids, via `_roadmap_section_ids`), `roadmap_queue_entries` / `roadmap_queue_set` (📋 Queued as `<level>\t<line>`, written under `### 🔺 Urgent`, `### Normal`, `### Low` in that order), `roadmap_queue_add` (queue or move, with the queue date), `roadmap_queue_level` / `roadmap_queue_date`, `roadmap_level_heading`, `roadmap_sections` (for `check_roadmap_sections` in planning health); `ledger_issue_lines [<n>…]` / `ledger_issue_lines_by_branch` -> issues in the display form (severity, status, logged date from the row; queue date and level; symptom; plan), every active issue in recorded order for `aapp issue list`; `roadmap_issue_lines` -> the work queue in that form for `aapp status` (`_issue_lines_by_branch` groups by branch, shared with `roadmap_entries_by_branch`).
* **Issue ledgers (P-73), the one accessor:** `ledger_path(issues|archive|roadmap)` (the plans worktree when inside one, then `.plans/`, then the repository root), `ledger_commit_paths`, `ledger_row(n)`, `ledger_rows([status])` (tab-separated cells by column name, with `Branch`; link and `Planned` status derived from the plans when the ledgers are untracked), `ledger_ids(which)`, `ledger_locate(n)`, `ledger_add_row(row)`, `ledger_cell(n, link|status|branch|commit, [issues|archive])`, `ledger_set_cell(n, link|status|branch, value)` (cells found by the header's column names; the `Branch` column is added by the first write that names a branch), `ledger_branch(n)`, `ledger_branch_map`, `ledger_move_branch(old, new-cell)`, `ledger_archive_row(n, sha|aborted, summary)`, `ledger_relink(old, new)`, `roadmap_entries([cap])`, `roadmap_entries_by_branch(current, dev, [cap])`, `roadmap_blockers`, `roadmap_add_blocker(n, text, plan)`, `roadmap_prune(n|resolved)`; the description and notes store under `~/.local/state/aapp/<key>/` is read and written here too (P-74). The record and its text (P-74): `ledger_rel`, `ledger_record_external` (the ledgers are ignored: a tracker keeps the record, and `ledger_commit_paths` names none), `ledger_ensure_files`, `ledger_replace_row`, `ledger_drop_row`, and the text store `issue_text_file` / `issue_text_add` / `issue_text_get` / `issue_text_rename`. The offline ledgers, a second source (P-75): `offline_dir`, `offline_mounted`, `ledger_in_offline`, `ledger_use_offline`, `ledger_offline_rows`, `ledger_offline_ids`, and former ids `ledger_alias` / `ledger_alias_add`; `ledger_row` and `ledger_locate` look in the offline ledgers and resolve a former id.
* **Consumers:** `lib/cmd_plan.sh`, `lib/cmd_commit.sh`, `lib/planning_health.sh` (Pair 7), `.githooks/aapp-pre-commit`, `.githooks/blast-radius-guard`.
* **Anti-Wrapper Warning:** Never add an inline section parser, an issue id pattern or a ledger read elsewhere; extend this library and its tests (`tests/aapp_lib_test.sh`, `tests/issue_id_test.sh`, `tests/issue_ledger_test.sh`). Edit `lib/aapp-lib.sh`, never `templates/aapp-lib.sh` (a symlink) or `.githooks/aapp-lib.sh` (installed by `aapp init`).
### 📝 Plan-Bound Commit Helper (`lib/cmd_commit.sh`)
* **Commit mode (P-51):** `aapp_commit_mode` / `aapp_changelog_mode` / `aapp_plan_stamp_modes` (`lib/aapp-lib.sh`): `atomic` refuses a second standard commit (helper) and a raw code commit (pre-commit hook); every commit and `draft` stamp `Commit Mode:` / `Changelog Mode:` in the plan header, logging a switch in §6.
* **Purpose:** Single source of truth for committing staged implementation code, attaching attribution via P-40, and recording commit SHAs in the active plan.
* **Key Commands:**
  * `aapp commit "<msg>" [agent <A> vendor <V> model <M>] [note "<text>"]` -> Commits staged files in worktree, decorates attribution, and records SHA and branch in active plan.
  * `aapp commit amend ["<msg>"]` -> Amends last commit, preserving message if omitted without duplicate trailers, and updates recorded SHA in active plan.
  * `aapp commit adopt <sha>...` -> Adopts existing commits made outside the helper and records them into active plan with a warning.
* **Anti-Wrapper Warning:** Never bypass `aapp commit` during an active plan; it ensures trailer compliance, lock resilience, and plan ledger integrity.

### 🚂 Unified Plans Commit Engine (`lib/commit_engine.sh`)
* **Purpose:** Single authoritative engine for all `.plans` worktree commits, eliminating ad-hoc `git commit || true` patterns.
* **Key Functions:**
  * `plans_commit(subject, path...)` -> Commits specified paths in `.plans` with explicit pathspec limiting (`git commit -- <paths>`), lock-retry resilience, attribution decoration, and loud failures.
* **Consumers:** `lib/cmd_commit.sh`, `lib/cmd_plan.sh` (`draft`, `freeze`, `start`, `freeze-start`, `done`).
* **Anti-Wrapper Warning:** Never use `git add ... || true; git commit ... || true` in `.plans`. Always use `plans_commit`.

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
* **Ledger checks** read rows through the ledger functions of `lib/aapp-lib.sh` (P-73): `check_fix_cells` (the fix cell holds verb-written links only, P-66), `check_issues_table_shape`, and `check_ledger_issues`, which `aapp refine issues` runs and which refuses a commit that adds a row (P-74). `check_issues_added_rows` refuses a row added by hand (rows come from `aapp issue log`, P-74).
* **Anti-Wrapper Warning:** Keep health checks mechanical, fast, and free of external runtime dependencies.
### 🏷️ AI Attribution Switchboard & Identity Layer (`lib/cmd_ai.sh`, `lib/attribution.sh`)
* **Purpose:** Governs AI attribution modes (`none`, `lax`, `strict`, `notes`), single identity resolution layer, commit decoration, and credits roster generation.
* **Key Commands & Behaviors:**
  * `aapp ai-lax` / `aapp ai-strict` / `aapp ai-notes` / `aapp ai-off` -> Switchboard state machine.
  * `aapp.aiAttribution=commit` is retired and refused loudly at commit time.
  * `lib/attribution.sh` -> Shared functions: `resolve_ai_identity`, `attribution_decorate`, `attribution_note`, `apply_agent_aliases`, `normalize_agent_identity`.
  * `aapp ai-note --stage` -> Pre-stages Option C note buffer keyed by commit message SHA-256.
  * `aapp ai-credits` -> Append-only union generator updating `AI Contributors` roster in `README.md`.
* **Anti-Wrapper Warning:** Never emit fake email addresses (`Co-authored-by: Agent <email>`).

### 🛑 Master Emergency Brake & Multi-Worktree State Preserver (`lib/cmd_pause.sh`)
* **Purpose:** Freezes codebase modifications and quarantines in-flight uncommitted work across all worktrees into SHA-addressed stashes ("Hibernate & Wake").
* **Key Commands & Behaviors:**
  * `aapp pause [reason]` -> Discovers worktrees dynamically via `git worktree list --porcelain`, pre-checks no in-flight merges/rebases (`git rev-parse --git-path MERGE_HEAD`, `rebase-merge`, `CHERRY_PICK_HEAD`), stashes with `--include-untracked`, validates 40-char commit SHA with atomic rollback on failure, and records snapshot to `$(git rev-parse --git-common-dir)/aapp_paused`. Acts as idempotent inspector if already paused.
  * `aapp pause --shared [reason]` -> Team-wide freeze committed to `.plans/PAUSED.md`.
  * `aapp resume` (or `aapp unpause`) -> Compares current HEAD SHAs against snapshot (forensic drift detection without auto-rebase), restores stashes by commit SHA, permanently preserves stashes on conflict while keeping pause buffer intact (No-Loss Conflict Invariant), conditionally drops stashes on success, verifies planning health, and removes pause buffer.
* **Anti-Wrapper Warning:** Never address stashes by index (`stash@{0}`); use 40-character commit SHAs exclusively. Never use `--all` (preserves `.gitignore` air-gaps).

### 📊 Context Recovery Briefing (`lib/cmd_status.sh`)
* **Purpose:** Read-only four-pillar context recovery agent inspecting Shipped (`CHANGELOG.md`), Issues (`ISSUES.md`), Plans (`state_matrix.md`), and Pickup (`pickup.md`). Surfaces prominent pause banner and quarantined worktrees when paused, and reports open adoption tasks (`.plans/adoption.md`, P-63) in overview and briefing.
* **Anti-Wrapper Warning:** Must remain strictly non-destructive and idempotent.

### 📋 Adoption Advisories & Setup Checklist (`lib/adoption.sh`)
* **Purpose:** Single source of truth for repository adoption rules catalogue, sync engine, and open task inspection for `.plans/adoption.md` (P-63).
* **Key Functions:**
  * `get_all_adoption_manual_headings()` -> Emits all unique manual section headings linked from adoption rules.
  * `adoption_open_count(target)` -> Counts open unticked tasks (`^- \[ \] \`\[`) in `.plans/adoption.md`. Returns 0 if missing.
  * `sync_adoption_checklist(root, plans_dir)` -> Evaluates rule triggers and checks; adds missing tasks and auto-ticks satisfied tasks (`- [ ]` → `- [x]`) while strictly preserving existing ticks, hand-edits, and user text.
* **Consumers:** `lib/cmd_init.sh` (seeds `.plans/adoption.md`, maintains `.plans/.gitignore`, executes sync, reports open count), `lib/cmd_status.sh` (includes open task count in overview and briefing).

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
### 🧩 Group Documentation Sections (`lib/group_docs.sh`)
* **Purpose:** A group plan's `## Architecture & Codemap` holds whole sections of `ARCHITECTURE.md` and `.agents/CODEMAP.md` (one ```` fence each, under `### <file>`), applied at the group's `done` (P-64 §2.6).
* **Key Functions:** `group_docs_stamp(plan, file, doc)` -> base line `<!-- aapp-base: <sha256> | new -->` above each fence without one; `group_docs_apply(plan, file, doc)` -> checks every section against its base line (all or nothing), then replaces the section with the same heading (up to the next heading of the same or a higher level) or adds it at the end; prints `replaced:` / `added:` / `unchanged:`.
* **Consumers:** `lib/cmd_plan.sh` (`refine` stamps, `done` applies). Tests: `tests/group_docs_test.sh`.

### 📜 Verb Behaviour Contracts (`lib/docs/verbs/`)
* **Purpose:** Canonical owner of each daily verb's behaviour: ingress, preconditions, failure modes, effects, exit and derived tests (P-34). Resolve a verb's contract through the fifth column of `lib/verbs.tsv`.
* **Tests:** `tests/verbs/<verb>.sh` (run with `aapp test verb <verb>`); correspondence in `tests/verb_contracts_test.sh`, both ways: every test a contract names exists, and every test a verb suite reports is named by its verb's contract, so a test whose behaviour left the contract fails (P-81).
* **Develop hook:** `templates/aapp-pre-commit-develop`, seeded into `.githooks/` by `aapp develop` only; removed by `aapp uninstall` inside the repository.
* **Anti-Wrapper Warning:** Never describe verb behaviour in skill prose that disagrees with the contract. Change the contract first, then the code and its verb suite. Mark current code that violates a contract line as `⚠️ Divergence`, not as intended behaviour.

### 🧪 Unified Test Runner Orchestrator (`lib/cmd_test.sh`)
* **Purpose:** Single entrypoint for automated test discovery, selective filtering, subshell isolation, execution timing, and assertion metric aggregation across all kit components.
* **Key Behaviors:**
  * Zero double-dash invariant: bare positional tokens (`list`, `strict`, `quiet`, `bail`, `jobs <n>`).
  * Parallel scheduling (P-67): up to N suites at once, N from `jobs <n>` or the CPU count rounded down to a multiple of 4; each suite's output captured in its own file and flushed in one write when it finishes; summary rows in selection order; one `trap` stops running suites and removes the files on exit or interrupt.
  * Suite parts (P-68): `tests/verbs/<verb>.<part>.sh` belongs to `<verb>`; `verb <verb>` runs it with all its parts, each scheduled as its own suite.
  * Fail-closed sandbox propagation (`AAPP_TEST_SANDBOX_STRICT=1`).
  * Adopter mode fallback: delegates to `aapp.testCommand` / auto-detected project runner (`npm`, `cargo`, etc.) or performs non-destructive AAPP protocol environment health audit.
* **Anti-Wrapper Warning:** Never bypass subshell sandboxing or alter suite exit codes.
### 📝 Dedicated Git Notes Engine (`lib/cmd_note.sh`)
* **Purpose:** First-class developer CLI handler and lifecycle manager for git notes (`aapp note [status | stage | push | pull]`, P-44).
* **Key Behaviors:**
  * Operates across two isolated namespaces: developer notes (`refs/notes/commits`) and AI traces (`refs/notes/ai`).
  * `aapp note stage "<text>"` pre-stages a note buffer for the next commit.
  * Supports non-destructive append on amend and remote push/pull with `union` merge strategy.
* **Anti-Wrapper Warning:** Keep notes decoupled from commit messages; never use raw unnamespaced `git notes` commands.

### 🚀 Milestone Release Orchestrator (`lib/cmd_release.sh`)
* **Purpose:** Single source of truth for milestone release bundling, baseline tag resolution, archive rollups, and release lifecycle hook triggers (P-38).
* **Key Behaviors:**
  * Validates semver version tags (`1.0.0`, `1.n`) with optional alphanumeric suffixes (`-beta.1`).
  * Evaluates baseline resolution ladder: explicit base -> active development branch (`aapp_dev_branch`) -> latest release tag -> initial commit.
  * Dispatches lifecycle hook events: `pre-release` (validation/veto), `on-release` (artifact generation/template sync), `post-release` (publication/notification).
  * Bundles completed plans into `.plans/release/<tag>/` and generates single-line milestone rollups in `000-archive-ledger.md`.
* **Anti-Wrapper Warning:** Never hand-roll release tag bundling or bypass release hook verification.

### 🔧 Auxiliary Commands
* `lib/cmd_develop.sh`: Symlinks local development checkout to global bin/share for live editing.
* `lib/cmd_upgrade.sh`: Upgrades global installation in-place from upstream repository.
* `lib/cmd_uninstall.sh`: Uninstalls binary and share data, cleaning dangling symlinks safely.
* `lib/cmd_help.sh`: Command catalog and usage instructions; `aapp help <verb>` prints that verb's synopsis and `## Ingress` lines from its contract in the installed kit, `aapp help <verb> full` the whole contract (the agents' syntax reference, P-47, P-87). `aapp <verb> help` is routed here by the dispatcher (`aapp`) before the verb runs.

---

## 🔒 3. Enforcement Engines & Hook Templates (`templates/`)

### 🛡️ Layer 1 Write-Time Interceptor (`templates/blast-radius-guard.sh`)
* **Purpose:** PreToolUse hook intercepting file-writing tools (`Write`, `Edit`, `MultiEdit`) before disk touches.
* **Evaluation Pipeline:**
  1. Section 1: Argument validation & lexical path canonicalization.
  2. Section 2: Repository self-protection (`.git/*`, `.githooks/*`, `.agents/skills/*`, `.claude/settings*`).
  3. Section 2b: External hard-deny (credentials, SSH/GPG keys, shell configs, system binaries).
  4. Section 2c: External path allowlists (agent scratchpads, temp dirs, `aapp.allowPath`).
  5. Section 2d: Project Circuit Breaker (emergency pause check; allows `.plans/*` and `.agents/*` only).
  6. Section 3: Workspace invariant allowlists (`.plans/*`, `.agents/*`, documentation anchors).
  7. Section 4: Blueprint Blast Radius matching (3-tier fast path: exact, prefix, pure-Bash glob).
  8. Section 5: Single-active-plan isolation (evaluates designated `⚡` buffer or single active plan).

### 🛑 Layer 2 Commit-Time Gate (`templates/aapp-pre-commit`)
* **Purpose:** Authoritative git pre-commit gate verifying staged changes before recording commit objects.
* **Enforcement Gates:**
  1. Section 0b: Project Circuit Breaker (refuses code commits while project is paused; allows `.plans/*` and `.agents/*`).
  2. Blast Radius compliance across non-bypass staged files.
  3. Frozen Plan Immutability: Rejects edits to `## 2. Technical Blueprint` and `## 4. Blast Radius` on `🔷 Frozen` plans.
  4. Changelog verification: Enforces `CHANGELOG.md` entry for any code changes.
  5. Issue roadmap hygiene: Auto-prunes resolved issues (`✅`/`Resolved`) in <5ms.
  6. Relocation Invariant: Detects and blocks active `ISSUES.md` if resolved rows are committed.
  7. Worktree isolation & Fail-Closed Quarantine: Refuses execution if `.plans/` is missing or unmounted.

### ✍️ Commit Message & Note Hooks
* `templates/commit-msg` / `templates/aapp-commit-msg`: Enforces <=72 char subject line conciseness, validates semantic trailers (`AI-Agent:`, etc.), permits git reverts.
* `templates/post-commit` / `templates/aapp-post-commit`: Attaches Option C staged notes to `refs/notes/commits`, cleans buffer with `&&`, reaps expired buffers.
* `templates/post-rewrite` / `templates/aapp-post-rewrite` (P-54): after a rebase or amend, maps the bound plan's `Commits:` to the new SHAs (prefix match), dedupes squashes, drops commits the rebase dropped, and commits the plan via `plans_commit` (`aapp init` copies `commit_engine.sh` and `attribution.sh` into `.githooks` for it; `GIT_DIR`/`GIT_INDEX_FILE` are cleared for that commit). Skips `aapp commit amend` (`AAPP_COMMIT_HELPER=1`); warns, never fails.

---

## 🚦 4. Interface Contracts & Architectural Invariants

1. **Path Resolution:** Always resolve repository root via `git rev-parse --show-toplevel` or git common directory. Do NOT use fragile relative assumptions like `../../`.
2. **Never Edit Generated Artifacts Directly:** Never edit `.githooks/*` directly; edit `templates/` and run `aapp init` to synchronize.
3. **Two-Lane Boundary:** Never merge bugs into `state_matrix.md` or raw feature blueprints into `issues_road_map.md`. Large bug fixes are promoted to blueprints via `digest ISSUE-00X`.
4. **Relocation Invariant:** Active `ISSUES.md` holds ONLY unresolved items (`🟠 Incubated`, `🔵 Planned`, `🟠 In Progress`). Resolved issues belong exclusively in `.plans/done/000-issues-archive.md`.

---

## 🔌 5. Canonical Extension Points & Action Plugins Registry

To prevent naming drift across development, blueprint authoring, and runtime tooling, standard plugin extension points are cataloged here. The runtime switchboard and `aapp plugins` inspect these standard names directly:

| Plugin Name | Namespace / Role | Invocation Trigger | Input / Output Contract | Shipped Sample Source | Installed Target |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`aapp-issue-tracker`** | Issues | `issue_provider` (`lib/cmd_issue.sh`) | Payload Standard: `issue.log`, `issue.refine`, `issue.fix`, `issue.fix-abort`, `issue.abort`, `issue.close`, `issue.list`, `issue.next-blocker`; reference `docs/reference/07-issue-protocol.md` | `examples/plugins/aapp-issue-tracker/run.sample` | `.agents/skills/aapp-issue-tracker/run` |
| **`aapp-issue-note-filter`** *(P-80)* | Issues | The note hand-over of `issue fix` and `issue list note <num>` (`lib/cmd_issue.sh`) | Payload Standard: `issue.note-show` → `{"status": "ok", "note": "<text to show>"}`; a failure withholds the note; the stored note is untouched | `examples/plugins/aapp-issue-note-filter/run.sample` | `.agents/skills/aapp-issue-note-filter/run` |
| **`aapp-issue-branch`** *(P-83)* | Issues | `_issue_ask_branch` at `issue fix` and a direct `issue close`, for a row that names no branch (`lib/cmd_issue.sh`) | Payload Standard: `issue.branch` (the issue and its `files`) → `{"status": "ok", "branch": "<name>"}`; `declined` is the development branch; a failure refuses the fix | `examples/plugins/aapp-issue-branch/run.sample` | `.agents/skills/aapp-issue-branch/run` |
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
