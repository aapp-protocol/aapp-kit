# refine <id> "<what changed>"

## Ingress
- `id` (positional, required): an active plan in `.plans/current/` (`P-47`, `47`, slug or filename)
- `"<what changed>"` (positional, required): one short line; becomes the commit subject `plan(refine): <id> <what changed>`
- reads: the plan file and the `plans` worktree status
- reads config: `aapp.aiAttribution` and the `AAPP_AGENT_*` identity, applied by the plans commit engine (`plans_commit`)

## Preconditions
- Inside a Git repository whose `.plans/` worktree exists
- The plan file has uncommitted changes

## Failure modes
- missing `id` or message -> exit 1, stderr `Usage: aapp refine <plan-id> "<what changed>"`
- `id` resolves to no active plan -> exit 1, stderr `Plan '<id>' not found`
- the plan file has no changes -> exit 1, stderr `Nothing to commit`
- a frozen plan's §2 or §4 changed -> exit non-zero: the pre-commit design lock refuses the commit
- plans-worktree commit refused by a hook -> exit non-zero via `plans_commit` (loud failure)

## Effects (happy path)
- one commit in the plans worktree, subject `plan(refine): <id> <what changed>`, containing only `current/<plan file>`; other staged paths stay staged
- the configured attribution is applied to the commit
- stdout ends with `📝 [Refine] <id> committed (<sha>): <what changed>`

## Exit
- 0 only when the commit landed

## Tests
Run: `aapp test verb refine`

- `tests/verbs/refine.sh::test_refine_commits_only_the_plan` -> subject, single-file commit, confirmation line
- `tests/verbs/refine.sh::test_refine_leaves_other_staged_paths` -> another staged `.plans` path is not swept in
- `tests/verbs/refine.sh::test_refine_refuses_bad_input_and_no_change` -> missing args, unknown plan and no changes exit non-zero without committing
