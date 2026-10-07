# start <id>

## Ingress
- `id` (positional, required): the frozen plan to activate
    accepted forms: `P-<N>`, bare `<N>`, the filename stem, or a slug prefix
    constraints: must resolve to exactly one plan in `.plans/current/`
- reads: the plan file (Status line, §4 Target Files), every other plan in `.plans/current/` (Status and Target Files, for the disjointness gate)
- reads: `🧱 Plan Blockers` in `.plans/issues_road_map.md` and those rows' Location paths in `.plans/ISSUES.md` (P-58)
- reads: the active buffer `$(git rev-parse --git-path aapp_active_plan)`, to preserve its previous value
- reads config: `aapp.planState.*` (matrix re-derivation); the lifecycle hook registry for `on-start`

## Preconditions
- Inside a Git repository whose `.plans/current/` exists
- Invoked from a code worktree (refuses when cwd is inside `.plans/`, `.agents/`, or `.githooks/`)
- The plan is `🔷 Frozen` (or already `⚡ In Development`, which re-activates it)
- No other worktree holds this plan in its active buffer
- No other `⚡ In Development` plan declares an identical Target File
- No queued Plan Blocker (active, not `Planned`) names a Target File in its Location; shared docs excepted (P-48)

## Failure modes
- no `id` -> exit 1, stderr `You must specify a target plan for 'start'.`
- `id` resolves to no plan -> exit 1, stderr `Plan '<id>' not found`
- invoked from a planning worktree -> exit 1, stderr `Run start from a code worktree`
- plan bound in another worktree's active buffer -> exit 1, stderr naming holding worktree
- the plan is neither `🔷 Frozen` nor `⚡ In Development` -> exit 1, stderr `[Start Refusal] Plan is not frozen`, with the `freeze` / `freeze-start` hint; the plan is unchanged
- a Target File is shared with another `⚡ In Development` plan -> exit 1, stderr `[Activation Gate]` names the file and the other plan; the plan is unchanged
- a Target File is in a queued Plan Blocker's Location -> exit 1, stderr `[Activation Gate] <file> has a pending fix (#<n>); fix it first ('aapp issue fix next-blocker') or start another plan.`; nothing changed. A plan with a recorded `Base:` was started before (a `⚡` re-run, or re-frozen after a re-scope) and is not gated by this (P-58, #103)
- plans-worktree commit refused by a hook -> exit non-zero via `plans_commit` (loud failure, no `|| true`)

## Effects (happy path)
- the plan's Status line reads `⚡ In Development`
- `* **Base:**` header line records current worktree's HEAD SHA and branch (or `(detached)`); re-running on a `⚡` plan keeps the first base
- `## 📦 6. Change Log` gains a dated line: `Plan activated into ⚡ In Development via start.`
- `.plans/state_matrix.md` is re-derived and lists the plan under In Development
- the active buffer holds the plan ID; a different previous value moves to `aapp_active_plan.prev`
- one commit in the plans worktree, `plan(start): activate <id> into development`, holds the plan and the matrix via `plans_commit`
- the `on-start` lifecycle event is dispatched (a failing handler does not undo the start)
- the write-guard and pre-commit hook now enforce this plan's Target Files and Out of Bounds

## Exit
- 0 only when every effect above landed

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
