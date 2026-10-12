# status [short]

## Ingress
- `short` (positional, optional; alias `summary`): print the one-line pulse instead of the briefing
    constraints: any other value is refused
    ⚠️ Divergence: any other argument is ignored silently and the full briefing prints.
- reads: `.plans/ISSUES.md`, `.plans/issues_road_map.md`, `.plans/current/`, `.plans/state_matrix.md`, `.plans/pickup.md`, `.plans/adoption.md`, `CHANGELOG.md` (or `.plans/CHANGELOG.md`), `.plans/PAUSED.md`, the active buffer
- reads config: `aapp.planState.*` (plan lane bucketing), `aapp.devBranch` (the branch of an issue that names none), `aapp.issueSyncWindow`, `aapp.issueCacheMax`
- reads: the branches, here and on the remotes, and whether a fix commit is reachable from a plan's parent branch (P-78)

## Preconditions
- Inside a Git repository (asserted by the dispatcher)

## Failure modes
- outside a Git repository -> exit 1, stderr names the missing repository
- a missing pillar file -> no failure: the pillar reports it as absent

## Effects (happy path)
- `.plans/state_matrix.md` is re-derived from the plans before it is read, so the briefing reports the real board; the write is not committed
- `short`: stdout is exactly one line beginning `📊 Overview:` with issue, plan and pickup counts; appends ` | <N> adoption` when `.plans/adoption.md` has open tasks (P-63)
- no argument: stdout carries the four pillars (Shipped, Issues, Plans, Pickup), open adoption tasks after pickup when present (`📋 Adoption: <N> open task(s) in .plans/adoption.md`), and one `➡️  Next Action:` line
- Issues pillar (P-78): once an open issue names a branch, each line ends with `(branch: <name>)` and the issues of the current branch (in a plan's worktree: of the plan's parent branch) come first, as in `aapp issue list`; an issue whose branch exists neither here nor on a remote is reported, with the development branch its fix will land on
- where a tracker keeps the issues (P-74): the briefing first brings them up to date through the `aapp-issue-tracker` provider's `issue.list`, at most once per `aapp.issueSyncWindow` minutes (default 15) counted from the last attempt, successful or not; a failing provider warns and changes nothing. Not done by `short`, nor while a plugin step runs
- an issue the tracker reports closed is closed here by the sync, at once (#142); a plan that waited on it is unblocked or named under Plans by the rule below
- a plan left blocked on a closed issue is unblocked once the fix commit is reachable from its parent branch (P-78): the plan and the re-derived matrix land in one `plans` commit `issue(unblock): fix reached the parent branch`, and the Plans pillar says `<plan> no longer waits for #<n>`; a plan still waiting gets a line naming the commit, the branch it was fixed on, the parent branch it is not in yet and `aapp refine <plan> unblocked <num>`. Not done by `short`, nor while a plugin step runs
- a plan with its own worktree shows it next to its status, from the header's `* **Worktree:**`: `• P-51: P51-….md  (⚡ In Development → ../repo-P51)` (P-54)
- no other file changes

## Exit
- 0 whenever a briefing was printed

## Tests
Run: `aapp test verb status`

- `tests/verbs/status.sh::test_short_is_one_line` -> `status short` prints exactly one `📊 Overview:` line
- `tests/verbs/status.sh::test_briefing_has_next_action` -> the full briefing ends with a `Next Action` line and exits 0
- `tests/verbs/status.sh::test_plan_worktree_shown_next_to_plan` -> a plan's worktree path follows its status (P-54)
- `tests/verbs/status.sh::test_overview_counts_open_adoption_tasks` -> open adoption tasks show in overview and briefing (P-63)
- `tests/verbs/status.sh::test_no_adoption_output_when_none_open` -> nothing printed when no open adoption tasks (P-63)
- `tests/verbs/status.sh::test_members_listed_under_group` -> a group's members are listed, indented, on the lines after it (P-64)
