# active [id | swap | clear]

## Ingress
- first argument (positional, optional):
    omitted: show the buffer, or auto-discover the single `⚡ In Development` plan
    `swap`: exchange the buffer with the previous value
    `clear`: empty the buffer
    any other value: a plan to bind — `P-<N>`, bare `<N>`, the filename stem, or a slug prefix; must resolve to one plan in `.plans/current/`
- reads: the active buffer `$(git rev-parse --git-path aapp_active_plan)` and `aapp_active_plan.prev`, `.plans/current/*.md` (Plan ID, Status, Target Files)

## Preconditions
- Inside a Git repository
- To bind: the plan is `⚡ In Development`
    ⚠️ Divergence: any status binds; a `🟣 Under Review` plan can become the enforced plan.

## Failure modes
- a plan argument that resolves to no plan -> exit 1, stderr `Plan '<id>' not found`; the buffer is unchanged
- `swap` with no previous value -> exit 0, stdout `No previous active plan found to swap to.`; nothing changes
- `clear` with an empty buffer -> exit 0, stdout `Active plan buffer is already empty.`

## Effects (happy path)
- bind: the buffer holds the plan ID; a different previous value moves to `.prev`; stdout lists the plan's Target Files
- `swap`: the buffer and `.prev` exchange values
- `clear`: the buffer file is removed and its value moves to `.prev`; enforcement reverts to auto-discovery
- show: stdout names the bound plan with its Status and Target Files, or the single auto-discovered `⚡` plan, or lists several and asks for a choice
- the buffer lives in `.git/` per worktree: never committed

## Exit
- 0 whenever the requested buffer state holds afterwards

## Tests
Run: `aapp test verb active`

- `tests/verbs/active.sh::test_bind_then_show` -> binding writes the ID; showing names it and its Target Files
- `tests/verbs/active.sh::test_swap_exchanges_previous` -> two binds then `swap` restores the first
- `tests/verbs/active.sh::test_clear_empties_buffer` -> `clear` removes the buffer file and keeps the value in `.prev`
- `tests/verbs/active.sh::test_refuses_unknown_plan` -> an unresolvable plan: exit 1, buffer unchanged
