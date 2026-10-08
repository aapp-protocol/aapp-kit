# start <id> [worktree <path> [branch <name>]]

## Ingress
- `id` (positional, required): the frozen plan to activate
    accepted forms: `P-<N>`, bare `<N>`, the filename stem, or a slug prefix
    constraints: must resolve to exactly one plan in `.plans/current/`
- `worktree <path>` (bare token, optional, P-54): create the plan's worktree at `<path>` (relative to the primary checkout) for this start, even with `aapp.planWorktrees = off`; wins over `aapp.planWorktreePath`
- `branch <name>` (bare token, optional, P-54): the plan branch's name; wins over `aapp.planBranch`; needs a plan worktree (config `on` or `worktree`)
- reads: the plan file (Status line, §4 Target Files), every other plan in `.plans/current/` (Status and Target Files, for the disjointness gate)
- reads: `🧱 Plan Blockers` in `.plans/issues_road_map.md` and those rows' Location paths in `.plans/ISSUES.md` (P-58)
- reads: the active buffer `$(git rev-parse --git-path aapp_active_plan)`, to preserve its previous value
- reads config: `aapp.planState.*` (matrix re-derivation); the lifecycle hook registry for `pre-start`, `on-start`, `post-start` (P-23)
- reads config (P-54): `aapp.planWorktrees` (`on`/`off`), `aapp.planBranch` (default `plan/{id}-{slug}`), `aapp.planWorktreePath` (default `../{repo}-{id}`), `aapp.devBranch` (candidate list, default `develop dev development`), `aapp.planSession` (personal, optional). Placeholders: `{id}` (`P51`), `{num}` (`51`), `{slug}`, `{repo}` (the primary checkout's directory name)

## Preconditions
- Inside a Git repository whose `.plans/current/` exists
- Invoked from a code worktree (refuses when cwd is inside `.plans/`, `.agents/`, or `.githooks/`)
- The plan is `🔷 Frozen` (or already `⚡ In Development`, which re-activates it)
- No other worktree holds this plan in its active buffer
- No other `⚡ In Development` plan declares an identical Target File
- No queued Plan Blocker (active, not `Planned`) names a Target File in its Location; shared docs excepted (P-48)
- Plan worktree (P-54): the rendered branch and path do not exist; a base branch resolves (the first `aapp.devBranch` candidate present locally or on a remote, else the default branch: `origin/HEAD`, `main` or `master`)

## Failure modes
- no `id` -> exit 1, stderr `You must specify a target plan for 'start'.`
- `id` resolves to no plan -> exit 1, stderr `Plan '<id>' not found`
- an unknown token, or `branch` without a plan worktree -> exit 1; nothing changed
- invoked from a planning worktree -> exit 1, stderr `Run start from a code worktree`
- plan bound in another worktree's active buffer -> exit 1, stderr naming holding worktree
- the plan is neither `🔷 Frozen` nor `⚡ In Development` -> exit 1, stderr `[Start Refusal] Plan is not frozen`, with the `freeze` / `freeze-start` hint; the plan is unchanged
- a Target File is shared with another `⚡ In Development` plan -> exit 1, stderr `[Activation Gate]` names the file and the other plan; the plan is unchanged
- a Target File is in a queued Plan Blocker's Location -> exit 1, stderr `[Activation Gate] <file> has a pending fix (#<n>); fix it first ('aapp issue fix next-blocker') or start another plan.`; nothing changed. A plan with a recorded `Base:` was started before (a `⚡` re-run, or re-frozen after a re-scope) and is not gated by this (P-58, #103)
- a `pre-start` hook vetoes (exit != 0, except 2) -> exit 1; pre-mutation quality gate halts with zero disk modifications, zero buffer writes, and zero commits (P-23)
- plan worktree (P-54): the branch or path already exists (`never reuses`), or no base branch (`No base branch`) -> exit 1; nothing changed. `worktree <path>` on a plan started before -> exit 1 (its worktree is chosen at its first start)
- in-transaction `on-start` action delegate or the start commit fails -> exit 1, stderr `rolled back`: mutations (worktree, links, branch, buffer, plan file) are rolled back and restored from snapshot (P-23, P-54)
- plans-worktree commit refused by a hook -> exit non-zero via `plans_commit` (loud failure, no `|| true`)

## Effects (happy path)
- the `pre-start` gating hook executes before any mutation (payload carries plan ID, plan file, and Target Files)
- the plan's Status line reads `⚡ In Development`
- `* **Base:**` header line records current worktree's HEAD SHA and branch (or `(detached)`); re-running on a `⚡` plan keeps the first base
- `## 📦 6. Change Log` gains a dated line: `Plan activated into ⚡ In Development via start.`
- `.plans/state_matrix.md` is re-derived and lists the plan under In Development
- the active buffer holds the plan ID; a different previous value moves to `aapp_active_plan.prev`
- `on-start` action delegate runs inside the transaction (failing handler rolls back the start)
- one commit in the plans worktree, `plan(start): activate <id> into development`, holds the plan and the matrix via `plans_commit`
- the `post-start` observer lifecycle event is dispatched after commit (P-23)
- the write-guard and pre-commit hook now enforce this plan's Target Files and Out of Bounds

### With a plan worktree (P-54: `aapp.planWorktrees = on`, or `worktree <path>`; only on a plan's first start, i.e. no Base recorded)
- `git worktree add --no-track -b <branch> <path> <base>`: the branch has no upstream; uncommitted changes in the primary stay there (a notice says so)
- `.githooks`, `.agents`, `.plans`, `.claude` (when present in the primary) are relative symlinks to the primary checkout; `/.githooks`, `/.agents`, `/.plans`, `/.claude` are in `$(git rev-parse --git-common-dir)/info/exclude` once; the worktree's `git status` is clean
- the plan is bound in the new worktree's buffer; the primary's buffer is untouched
- `on-start` is dispatched before the record with `worktree` and `branch` in its `data`; a registered gate handler may rename the branch or move the worktree, and a refusal rolls everything back
- the header records `* **Worktree:** <path> (<branch>)` as read back after `on-start`, with the path relative to the primary checkout, and `* **Base:** \`<sha>\` (<base branch>)`: the commit the worktree came from and the base branch, not the plan branch
- stdout prints the worktree's path and branch; then `aapp.planSession`, when set, runs detached in the worktree (placeholders `{path}`, `{id}`, `{branch}`, `{slug}`, `{plan_file}` shell-quoted; env `AAPP_PLAN_ID`, `AAPP_WORKTREE`, `AAPP_BRANCH`, `AAPP_SLUG`, `AAPP_PLAN_FILE`; output to the worktree's `aapp_session.log`), never waited on; a launch failure only warns. Without it, stdout prints `cd <path>`

## Exit
- 0 only when every effect above landed (a session launch failure only warns)

## Tests
Run: `aapp test verb start`

- `tests/verbs/start.sh::test_activates_frozen_plan` -> status, buffer, matrix and one commit
- `tests/verbs/start.sh::test_refuses_unfrozen_plan` -> a `🟣 Under Review` plan: exit 1, plan unchanged
- `tests/verbs/start.sh::test_refuses_shared_target` -> a Target File shared with an in-flight plan: exit 1
- `tests/verbs/start.sh::test_records_base_sha_and_branch` -> start fills `* **Base:**` with the worktree's `HEAD` and branch
- `tests/verbs/start.sh::test_refuses_from_planning_worktree` -> start run inside `.plans/`: exit 1, no buffer bound, plan unchanged
- `tests/verbs/start.sh::test_restart_keeps_first_base` -> re-running start on a `⚡` plan leaves Base unchanged
- `tests/verbs/start.sh::test_refuses_plan_bound_in_other_worktree` -> start on a plan bound elsewhere: exit 1, plan and buffer unchanged
- `tests/verbs/start.sh::test_refuses_target_with_pending_fix` -> a Target File in a queued Plan Blocker: exit 1, nothing changed (P-58)
- `tests/verbs/start.sh::test_starts_once_blocker_promoted_shared_docs_never_gate` -> a promoted blocker no longer gates; a queued blocker on a shared doc never does (P-58)
- `tests/verbs/start.sh::test_restart_of_started_plan_not_gated_by_blocker` -> a started plan sent back to Refining and re-frozen starts despite a blocker on its file (#103)
- `tests/verbs/start.sh::test_worktree_start_creates_branch_links_and_records` -> templated branch from develop without upstream, four relative links and excludes, clean status, bound there only, Worktree and Base recorded (P-54)
- `tests/verbs/start.sh::test_worktree_start_refuses_existing_branch_or_path` -> existing branch or path: exit 1, nothing changed (P-54)
- `tests/verbs/start.sh::test_worktree_start_dirty_primary_only_notice` -> a dirty primary only prints a notice (P-54)
- `tests/verbs/start.sh::test_worktree_tokens_override_templates` -> `worktree`/`branch` tokens win, also with the config `off` (P-54)
- `tests/verbs/start.sh::test_worktree_off_changes_nothing` -> with `off` and no token, start is unchanged (P-54)
- `tests/verbs/start.sh::test_worktree_on_start_rename_is_recorded` -> an `on-start` hook that renames the branch and moves the worktree is reflected in the record and output (P-54)
- `tests/verbs/start.sh::test_worktree_failing_on_start_rolls_back` -> a refusing `on-start` leaves no worktree, branch, commit or plan change; prior uncommitted plan edits kept (P-54)
- `tests/verbs/start.sh::test_worktree_failing_link_or_commit_rolls_back` -> a link that cannot be made, or a failing start commit, rolls back the same way (P-54)
- `tests/verbs/start.sh::test_worktree_session_runs_detached_with_placeholders` -> `aapp.planSession` runs in the background with quoted placeholders and the environment (P-54)
- `tests/verbs/start.sh::test_worktree_session_failure_only_warns` -> a session command that cannot launch warns; the start stands (P-54)
- `tests/verbs/start.sh::test_worktree_base_remote_only_no_track` -> a remote-only development branch is the base; the plan branch tracks nothing (P-54)
- `tests/verbs/start.sh::test_worktree_base_falls_back_to_default_branch` -> no `aapp.devBranch` candidate: the default branch is the base (P-54)
- `tests/verbs/start.sh::test_worktree_refuses_without_base_branch` -> no candidate and no default branch: exit 1, plan unchanged (P-54)
