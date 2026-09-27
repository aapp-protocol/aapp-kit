# plan-status [id]

## Ingress
- `id` (positional, optional): the plan to inspect
    accepted forms: `P-<N>`, bare `<N>`, the filename stem, or a slug prefix
    source when omitted: the lane overview of every plan in `.plans/current/`
    constraints: when given, must resolve to exactly one plan
- reads: `.plans/current/*.md` (Plan ID, title, Status, §5 Open Questions, §4 Target Files via `lib/aapp-lib.sh`), the active buffer
- reads config: `aapp.planState.*` (lane bucketing)

## Preconditions
- Inside a Git repository

## Failure modes
- `id` given but resolves to no plan -> exit 1, stderr `Plan '<id>' not found`
- `.plans/current/` missing, no `id` -> exit 0, stdout `(no .plans/current directory found)`

## Effects (happy path)
- with `id`: stdout names the plan, title, Status, blueprint path, unresolved Open Questions (or `All resolved`) and the declared Target Files, one per line
- without `id`: stdout counts and lists plans per lane — `⚡ In Development`, `🔷 Frozen Backlog`, `🟣 Incubator`, and `❓ Unrecognized` for a Status no registry entry matches — then the active buffer when one is set
- read-only: no file changes, no commit

## Exit
- 0 whenever the inspection printed

## Tests
Run: `aapp test verb plan-status`

- `tests/verbs/plan-status.sh::test_overview_buckets_by_status` -> each lane counts the plans carrying its Status
- `tests/verbs/plan-status.sh::test_single_plan_lists_targets` -> a plan's detail lists its Target Files and no blockquote prose
- `tests/verbs/plan-status.sh::test_refuses_unknown_plan` -> an unresolvable `id`: exit 1
