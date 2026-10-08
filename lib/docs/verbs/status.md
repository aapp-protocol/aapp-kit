# status [short]

## Ingress
- `short` (positional, optional; alias `summary`): print the one-line pulse instead of the briefing
    constraints: any other value is refused
    ⚠️ Divergence: any other argument is ignored silently and the full briefing prints.
- reads: `.plans/ISSUES.md`, `.plans/issues_road_map.md`, `.plans/current/`, `.plans/state_matrix.md`, `.plans/pickup.md`, `CHANGELOG.md` (or `.plans/CHANGELOG.md`), `.plans/PAUSED.md`, the active buffer
- reads config: `aapp.planState.*` (plan lane bucketing)

## Preconditions
- Inside a Git repository (asserted by the dispatcher)

## Failure modes
- outside a Git repository -> exit 1, stderr names the missing repository
- a missing pillar file -> no failure: the pillar reports it as absent

## Effects (happy path)
- `.plans/state_matrix.md` is re-derived from the plans before it is read, so the briefing reports the real board; the write is not committed
- `short`: stdout is exactly one line beginning `📊 Overview:` with issue, plan and pickup counts
- no argument: stdout carries the four pillars (Shipped, Issues, Plans, Pickup) and one `➡️  Next Action:` line
- a plan with its own worktree shows it next to its status, from the header's `* **Worktree:**`: `• P-51: P51-….md  (⚡ In Development → ../repo-P51)` (P-54)
- no other file changes

## Exit
- 0 whenever a briefing was printed

## Tests
Run: `aapp test verb status`

- `tests/verbs/status.sh::test_short_is_one_line` -> `status short` prints exactly one `📊 Overview:` line
- `tests/verbs/status.sh::test_briefing_has_next_action` -> the full briefing ends with a `Next Action` line and exits 0
- `tests/verbs/status.sh::test_plan_worktree_shown_next_to_plan` -> a plan's worktree path follows its status (P-54)
