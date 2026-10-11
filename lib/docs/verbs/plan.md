# plan [query] | plan conflict-check <id> <id>… [json] | plan conflict-free [<id> | <group>] [json]

## Ingress
- `query` (positional, optional): a plan the user is asking about
    effect when given: the switchboard adds the exact `plan-status` and `active` commands for it
    constraints: none; the query is echoed into hints, not resolved
    ⚠️ Divergence: an unknown plan still produces hints; nothing tells the user it does not exist.
- `conflict-check <id> <id>…` (P-65): two or more plans, any status; a group plan ID expands to its members in `current/`
- `conflict-free` (P-65): every pending plan (🟣/📝/🔷, not a group plan or mini plan) against the ⚡ plans
- `conflict-free <id>` (P-65): every other plan in `current/` against plan `<id>`
- `conflict-free <group>` (P-65): the group's members in waves
- `json` (bare token, optional, with `conflict-check` / `conflict-free`): structured output on stdout, same exit codes
- reads: the switchboard nothing; the audits each plan's Status and §4 Target Files, and a group's `* **Members:**`

## Preconditions
- Inside a Git repository (asserted by the dispatcher)

## Failure modes
- switchboard: none, it is static guidance
- `conflict-check` with fewer than two plans after group expansion -> exit 1, `needs two or more plans`
- an `id` resolving to no plan in `current/` -> exit 1, `Plan '<id>' not found`

## Effects (happy path)
- switchboard: stdout prints the planning switchboard: how to inspect plans (`plan-status`), manage the buffer (`active`), and draft via the `/plan` skill
- targets compare exactly, as the activation gate does; shared docs (`CHANGELOG.md`, `MANUAL.md`, … per P-48) never collide
- `conflict-check`: disjoint -> `✔ Plans <ids> are disjoint …` plus `ℹ️  [Shared Doc] <file>` for docs two plans share; else one `✘ Collision between <a> and <b>: <file>` per colliding file. JSON: `{"clean", "plans", "collisions": [{plan_a, plan_b, target}], "shared_docs"}`
- `conflict-free` / `conflict-free <id>`: two lists, conflict-free (or compatible) IDs, and conflicting ones as `<id>: <file> with <other>`. JSON: `{"conflict_free": [...], "conflicting": [{plan, collides_with, target}]}`
- `conflict-free <group>`: archived (✅) members are left out; ⚡ plans (members or not) are listed `In flight`; pending members are placed in their listed order, each into the first wave it fits: a wave is pairwise disjoint, and wave 1 is also disjoint from every ⚡ plan. A member held back names the file and the plan that pushed it: `Wave 2: P-y  (P-y held back: src/x.sh with P-x)`. JSON: `{"group", "in_flight", "waves": [{wave, plans, held_back?: [{plan, collides_with, target}]}]}`
- no file changes; no commit

## Exit
- 0, except `conflict-check` with a collision -> 1

## Tests
Run: `aapp test verb plan`

- `tests/verbs/plan.sh::test_prints_switchboard` -> the switchboard names `plan-status` and `active`, exit 0
- `tests/verbs/plan.sh::test_changes_nothing` -> the working trees and the plans worktree are byte-identical afterwards
- `tests/verbs/plan.sh::test_conflict_check_disjoint_plans_exit_zero` -> two disjoint plans: exit 0 (P-65)
- `tests/verbs/plan.sh::test_conflict_check_overlapping_plans_exit_one_and_names_target` -> an overlap: exit 1 naming the file and both plans (P-65)
- `tests/verbs/plan.sh::test_conflict_check_exempts_shared_docs` -> a shared doc alone: exit 0, noted (P-65)
- `tests/verbs/plan.sh::test_conflict_free_against_active_in_flight_plans` -> pending plans split by the ⚡ plan (P-65)
- `tests/verbs/plan.sh::test_conflict_free_with_reference_plan` -> compatible and incompatible against `<id>` (P-65)
- `tests/verbs/plan.sh::test_conflict_check_many_plans_and_group_expands` -> three plans pairwise; a group ID checks its members (P-65)
- `tests/verbs/plan.sh::test_conflict_free_group_orders_members_in_waves` -> two waves, the held-back member names the file and member (P-65)
- `tests/verbs/plan.sh::test_group_waves_respect_in_flight_plans` -> a member colliding with a ⚡ plan outside the group waits for wave 2 (P-65)
- `tests/verbs/plan.sh::test_group_waves_filters_done_and_inflight_members` -> archived members left out, ⚡ members in flight (P-65)
- `tests/verbs/plan.sh::test_conflict_subcommands_json_token_output` -> valid JSON, same exit codes (P-65)
