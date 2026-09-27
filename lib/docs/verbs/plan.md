# plan [query]

## Ingress
- `query` (positional, optional): a plan the user is asking about
    effect when given: the switchboard adds the exact `plan-status` and `active` commands for it
    constraints: none; the query is echoed into hints, not resolved
    ⚠️ Divergence: an unknown plan still produces hints; nothing tells the user it does not exist.
- reads: nothing on disk

## Preconditions
- Inside a Git repository (asserted by the dispatcher)

## Failure modes
- none: the switchboard is static guidance

## Effects (happy path)
- stdout prints the planning switchboard: how to inspect plans (`plan-status`), manage the buffer (`active`), and draft via the `/plan` skill
- no file changes; no commit

## Exit
- 0 always

## Tests
Run: `aapp test verb plan`

- `tests/verbs/plan.sh::test_prints_switchboard` -> the switchboard names `plan-status` and `active`, exit 0
- `tests/verbs/plan.sh::test_changes_nothing` -> the working trees and the plans worktree are byte-identical afterwards
