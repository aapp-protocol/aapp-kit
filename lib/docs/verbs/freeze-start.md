# freeze-start <id> [worktree <path> [branch <name>]]

## Ingress
- `id` (positional, required): the incubator plan to freeze and activate in one step
    accepted forms: `P-<N>`, bare `<N>`, the filename stem, or a slug prefix
    constraints: must resolve to exactly one plan in `.plans/current/`
- `worktree <path>`, `branch <name>` (bare tokens, optional, P-54): as for `start`; with `aapp.planWorktrees = on` (or `worktree`), freeze-start creates the plan's branch and worktree exactly as `start` does (see `aapp help start`)
- reads: the plan file (§5 Open Questions, §4 Target Files), every other plan in `.plans/current/` (disjointness gate), the queued `🧱 Plan Blockers` and their Location paths (P-58), the active buffer
- reads config: `aapp.planState.*` (matrix re-derivation); the lifecycle hook registry for `on-freeze` and `on-start`

## Preconditions
- Inside a Git repository whose `.plans/current/` exists
- Invoked from a code worktree (refuses when cwd is inside `.plans/`, `.agents/`, or `.githooks/`)
- The plan is in the incubator (`🟣 Under Review`, `📝 Refining`, or a custom status from `aapp.planState.*`)
- No other worktree holds this plan in its active buffer
- No other `⚡ In Development` plan declares an identical Target File
- No queued Plan Blocker (active, not `Planned`) names a Target File in its Location; shared docs excepted (P-48)

## Failure modes
- no `id` -> exit 1, stderr `You must specify a target plan for 'freeze-start'.`
- `id` resolves to no plan -> exit 1, stderr `Plan '<id>' not found`
- invoked from a planning worktree -> exit 1, stderr `Run freeze-start from a code worktree`
- plan bound in another worktree's active buffer -> exit 1, stderr naming holding worktree
- the plan is `🔷 Frozen`, `⚡ In Development`, `🟥 BLOCKED`, or carries an unrecognised status -> exit 1, stderr `[Freeze-Start Refusal] Plan is not in the incubator`; the plan and buffer are unchanged (#89)
- an unchecked `* [ ]` item under `## ❓ 5. Open Questions` -> exit 1, stderr `[Freeze-Start Refusal]` lists each unresolved question; the plan is unchanged
- no path under `### 📂 Target Files` in §4 -> exit 1, stderr `[Freeze-Start Refusal] Plan declares no Target Files`; the plan is unchanged
- a Target File is shared with another `⚡ In Development` plan -> exit 1, stderr `[Activation Gate]`; the plan is unchanged
- a Target File is in a queued Plan Blocker's Location -> exit 1, stderr `[Activation Gate] <file> has a pending fix (#<n>)`; the plan is unchanged. A plan with a recorded `Base:` (started before, re-scoped) is not gated by this (P-58, #103)
- an `on-freeze` hook vetoes -> exit 1 and the plan stays unactivated
- plan worktree (P-54): the refusals and the all-or-nothing rollback of `start`; there `on-freeze` and `on-start` both run before the record, and a refusal by either rolls back
- plans-worktree commit refused by a hook -> exit non-zero via `plans_commit` (loud failure, no `|| true`)

## Effects (happy path)
- the plan's Status line reads `⚡ In Development`
- a `PROPOSED` marker, when present, reads `LOCKED`
- `* **Base:**` header line records current worktree's HEAD SHA and branch (or `(detached)`); with a plan worktree, the base commit and the **base branch** it came from (P-54), plus `* **Worktree:** <path> (<branch>)`
- `## 📦 6. Change Log` gains a dated line: `Plan frozen and activated into ⚡ In Development via freeze-start.`
- `.plans/state_matrix.md` is re-derived and lists the plan under In Development
- the active buffer holds the plan ID; a different previous value moves to `aapp_active_plan.prev`
- one commit in the plans worktree, `plan(start): freeze and activate <id> into development`, via `plans_commit`
- `on-freeze` then `on-start` are dispatched

## Exit
- 0 only when every effect above landed

## Tests
Run: `aapp test verb freeze-start`

- `tests/verbs/freeze-start.sh::test_freezes_and_activates` -> status, buffer, matrix and one commit
- `tests/verbs/freeze-start.sh::test_refuses_unresolved_questions` -> an unchecked §5 item: exit 1, plan unchanged, buffer untouched
- `tests/verbs/freeze-start.sh::test_refuses_non_incubator_plan` -> a plan already `⚡ In Development`: exit 1, plan unchanged (#89)
- `tests/verbs/freeze-start.sh::test_records_base_sha_and_branch` -> freeze-start fills Base the same way
- `tests/verbs/freeze-start.sh::test_refuses_target_with_pending_fix` -> a Target File in a queued Plan Blocker: exit 1, plan unchanged (P-58)
- `tests/verbs/freeze-start.sh::test_worktree_freeze_start_creates_and_records` -> with `on`, the worktree and links are created, Worktree and Base (develop) recorded, the plan bound there (P-54)
