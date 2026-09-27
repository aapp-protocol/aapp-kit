# start <id>

## Ingress
- `id` (positional, required): the frozen plan to activate
    accepted forms: `P-<N>`, bare `<N>`, the filename stem, or a slug prefix
    constraints: must resolve to exactly one plan in `.plans/current/`
- reads: the plan file (Status line, §4 Target Files), every other plan in `.plans/current/` (Status and Target Files, for the disjointness gate)
- reads: the active buffer `$(git rev-parse --git-path aapp_active_plan)`, to preserve its previous value
- reads config: `aapp.planState.*` (matrix re-derivation); the lifecycle hook registry for `on-start`

## Preconditions
- Inside a Git repository whose `.plans/current/` exists
- The plan is `🔷 Frozen` (or already `⚡ In Development`, which re-activates it)
- No other `⚡ In Development` plan declares an identical Target File

## Failure modes
- no `id` -> exit 1, stderr `You must specify a target plan for 'start'.`
- `id` resolves to no plan -> exit 1, stderr `Plan '<id>' not found`
- the plan is neither `🔷 Frozen` nor `⚡ In Development` -> exit 1, stderr `[Start Refusal] Plan is not frozen`, with the `freeze` / `freeze-start` hint; the plan is unchanged
- a Target File is shared with another `⚡ In Development` plan -> exit 1, stderr `[Activation Gate]` names the file and the other plan; the plan is unchanged
- plans-worktree commit refused by a hook -> exit non-zero, stderr names the refusal
    ⚠️ Divergence (#81): the commit runs under `|| true`; the verb exits 0 with the transition staged but uncommitted.

## Effects (happy path)
- the plan's Status line reads `⚡ In Development`
- `## 📦 6. Change Log` gains a dated line: `Plan activated into ⚡ In Development via start.`
- `.plans/state_matrix.md` is re-derived and lists the plan under In Development
- the active buffer holds the plan ID; a different previous value moves to `aapp_active_plan.prev`
- one commit in the plans worktree, `plan(start): activate <id> into development`, holds the plan and the matrix
- the `on-start` lifecycle event is dispatched (a failing handler does not undo the start)
- the write-guard and pre-commit hook now enforce this plan's Target Files and Out of Bounds

## Exit
- 0 only when every effect above landed

## Tests
Run: `aapp test verb start`

- `tests/verbs/start.sh::test_activates_frozen_plan` -> status, buffer, matrix and one commit
- `tests/verbs/start.sh::test_refuses_unfrozen_plan` -> a `🟣 Under Review` plan: exit 1, plan unchanged
- `tests/verbs/start.sh::test_refuses_shared_target` -> a Target File shared with an in-flight plan: exit 1
