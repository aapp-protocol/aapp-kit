# plan [query] | plan conflict-check <id> <id>… [json] | plan conflict-free [<id> | <group>] [json] | plan abort <id> [reason "<text>"] [keep-branch] [force] [force-cleanup] [confirm]

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
- `abort <id>` (P-69): abandon a plan in `.plans/current/`, any status (`P-47`, `47`, slug or filename)
    - `reason "<text>"`: one line (default `Abandoned`)
    - `keep-branch`: the plan branch, or a group's feature branch and member branches, is kept
    - `force`: uncommitted work in the plan's worktree is discarded
    - `force-cleanup`: sensitive ignored files in the plan's worktree are deleted with it
    - `confirm`: a group plan's abort proceeds without the terminal prompt
- reads: the switchboard nothing; the audits each plan's Status and §4 Target Files, and a group's `* **Members:**`
- `abort` reads: the plan's header (`Worktree`, `Commits`, `Target Issue`, `Group`, `Blocked On`, a group's `Members` and `Feature Branch`), `ISSUES.md`, the worktree's `git status`
- `abort` reads config: `aapp.quarantineIgnored`; the lifecycle hook registry for `post-abort`

## Preconditions
- Inside a Git repository (asserted by the dispatcher)

## Failure modes
- switchboard: none, it is static guidance
- `conflict-check` with fewer than two plans after group expansion -> exit 1, `needs two or more plans`
- an `id` resolving to no plan in `current/` -> exit 1, `Plan '<id>' not found`
- `abort`, every refusal before any change (exit 1):
    - an unknown token, or `reason` without a text -> the usage line
    - a plan in `done/` or `aborted/` -> `Plan '<id>' not found`
    - a mini plan (`fix-<num>`) -> points to `aapp issue fix <num> abort`
    - run from inside the plan's own worktree -> names the main checkout
    - the plan's worktree has tracked or untracked changes, without `force` -> lists them
    - the plan's worktree holds sensitive ignored files, without `force-cleanup` or `aapp.quarantineIgnored true` -> lists them
    - a Target Issue found in neither `ISSUES.md` nor the issues archive
    - a group plan without `confirm` and without a terminal, or a prompt answered anything but `y` -> lists what it would remove, `Nothing changed`
- `abort`: the plans commit fails -> exit 1; the plan, ledgers and matrix are restored; no worktree or branch is removed

## Effects (happy path)
- switchboard: stdout prints the planning switchboard: how to inspect plans (`plan-status`), manage the buffer (`active`), and draft via the `/plan` skill
- targets compare exactly, as the activation gate does; shared docs (`CHANGELOG.md`, `MANUAL.md`, … per P-48) never collide
- `conflict-check`: disjoint -> `✔ Plans <ids> are disjoint …` plus `ℹ️  [Shared Doc] <file>` for docs two plans share; else one `✘ Collision between <a> and <b>: <file>` per colliding file. JSON: `{"clean", "plans", "collisions": [{plan_a, plan_b, target}], "shared_docs"}`
- `conflict-free` / `conflict-free <id>`: two lists, conflict-free (or compatible) IDs, and conflicting ones as `<id>: <file> with <other>`. JSON: `{"conflict_free": [...], "conflicting": [{plan, collides_with, target}]}`
- `conflict-free <group>`: archived (✅) members are left out; ⚡ plans (members or not) are listed `In flight`; pending members are placed in their listed order, each into the first wave it fits: a wave is pairwise disjoint, and wave 1 is also disjoint from every ⚡ plan. A member held back names the file and the plan that pushed it: `Wave 2: P-y  (P-y held back: src/x.sh with P-x)`. JSON: `{"group", "in_flight", "waves": [{wave, plans, held_back?: [{plan, collides_with, target}]}]}`
- switchboard and audits: no file changes; no commit
- `abort`: one commit in the plans worktree, `plan(abort): archive <id> to aborted/`:
    - the plan moves to `aborted/` with `* **Status:** ❌ Aborted`, `* **Aborted:** <date> | **Reason:** <reason>` and a change log line
    - `aborted/000-aborted-ledger.md` (created when missing) gains `| Date Aborted | Plan ID | Plan File | Target Issue / Milestone | Reason | Commits |`
    - its Target Issue is **not closed**: the row goes back to 🟡 `Incubated`, its *Target Plan / Fix* cell `[P-<id>](aborted/<file>)`; other rows and road-map lines linking the plan are repointed to `aborted/`
    - a group member leaves its group's `* **Members:**`; the matrix row is gone
- `abort`, after the commit: buffers naming the plan are cleared; the plan's worktree is removed (ignored files quarantined when configured) and its branch deleted with a warning naming its SHA (`keep-branch` keeps it). A failure here warns with the command to run; the abort stands
- `abort` of a plan without a worktree: its commits and `CHANGELOG.md` entry stay, nothing is reverted; the commits are listed. A blocked plan's hotfix issues stay open; their lines leave `aapp_hotfix_stash`, the stashes stay
- `abort` of a group plan: every member in `current/` is aborted with it (reason `Group <id> aborted: <reason>`) in one commit `plan(abort): archive group <id> to aborted/`; member worktrees and branches and the feature branch go; archived members stay in `done/` and are listed
- `abort` dispatches `post-abort` (`plan_id`, `plan_file`, `reason`, `worktree`, `branch`, `commits`) once per aborted plan

## Exit
- 0, except `conflict-check` with a collision -> 1, and an `abort` refusal or failed archive commit -> 1

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
- `tests/verbs/plan.abort.sh::test_abort_draft_moves_to_aborted_and_cleans_matrix` -> a draft lands in `aborted/` as `❌ Aborted` with its reason; no matrix row (P-69)
- `tests/verbs/plan.abort.sh::test_abort_writes_ledger_row` -> the ledger is created and gains the row, `|` escaped (P-69)
- `tests/verbs/plan.abort.sh::test_abort_frozen_plan` -> one `plan(abort)` commit, default reason (P-69)
- `tests/verbs/plan.abort.sh::test_abort_refuses_archived_plan` -> a plan outside `current/` is not found (P-69)
- `tests/verbs/plan.abort.sh::test_abort_refuses_mini_plan` -> `fix-<num>` points to `issue fix <num> abort` (P-69)
- `tests/verbs/plan.abort.sh::test_abort_single_checkout_keeps_commits` -> commits stay, are listed and reach the ledger (P-69)
- `tests/verbs/plan.abort.sh::test_abort_clears_buffers` -> no buffer names the plan (P-69)
- `tests/verbs/plan.abort.sh::test_abort_target_issue_incubated_with_aborted_link` -> the issue row is `Incubated` and links `aborted/` (P-69)
- `tests/verbs/plan.abort.sh::test_abort_relinks_other_issue_rows` -> other rows and road-map lines point at `aborted/` (P-69)
- `tests/verbs/plan.abort.sh::test_abort_blocked_plan_drops_stash_record` -> the hotfix issue stays; its stash record goes, the stash stays (P-69)
- `tests/verbs/plan.abort.sh::test_abort_dispatches_post_abort` -> the handler receives the payload (P-69)
- `tests/verbs/plan.abort.sh::test_abort_refuses_dirty_worktree_without_force` -> tracked or untracked changes refuse; `force` proceeds (P-69)
- `tests/verbs/plan.abort.sh::test_abort_removes_worktree_and_branch` -> worktree and branch gone, the SHA named (P-69)
- `tests/verbs/plan.abort.sh::test_abort_keep_branch_preserves_ref` -> `keep-branch` leaves the branch (P-69)
- `tests/verbs/plan.abort.sh::test_abort_refuses_sensitive_ignored_files` -> `.env` refuses; quarantined with `aapp.quarantineIgnored` (P-69)
- `tests/verbs/plan.abort.sh::test_abort_refuses_inside_plan_worktree` -> refused from the plan's own worktree (P-69)
- `tests/verbs/plan.abort.sh::test_abort_commit_failure_restores` -> a failed commit restores everything and removes nothing (P-69)
- `tests/verbs/plan.abort.sh::test_abort_group_member_unlinked` -> the group's `Members` drops the plan (P-69)
- `tests/verbs/plan.abort.sh::test_abort_group_member_with_commits` -> a member's branch goes; the feature branch is unchanged (P-69)
- `tests/verbs/plan.abort.sh::test_abort_group_needs_confirm` -> no terminal and no `confirm`: listed, nothing changed (P-69)
- `tests/verbs/plan.abort.sh::test_abort_group_aborts_open_members` -> group and open members in one commit, a ledger row each (P-69)
- `tests/verbs/plan.abort.sh::test_abort_group_lists_archived_members` -> archived members stay in `done/` and are named (P-69)
- `tests/verbs/plan.abort.sh::test_abort_group_removes_feature_branch` -> feature and member branches go, or stay with `keep-branch` (P-69)
