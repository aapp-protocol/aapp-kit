# status [short]

## Ingress
- `short` (positional, optional; alias `summary`): print the one-line pulse instead of the briefing
    constraints: any other value is refused
    ⚠️ Divergence: any other argument is ignored silently and the full briefing prints.
- reads: `.plans/ISSUES.md`, `.plans/issues_road_map.md`, `.plans/current/`, `.plans/state_matrix.md`, `.plans/pickup.md`, `.plans/adoption.md`, `CHANGELOG.md` (or `.plans/CHANGELOG.md`), `.plans/PAUSED.md`, the active buffer
- reads config: `aapp.planState.*` (plan lane bucketing), `aapp.devBranch` (the branch of an issue that names none), `aapp.issueSyncWindow`, `aapp.issueCacheMax`, `aapp.statusOutputWidth` (the briefing's width, default 85, P-92)
- reads: the branches, here and on the remotes, and whether a fix commit is reachable from a plan's parent branch (P-78)

## Preconditions
- Inside a Git repository (asserted by the dispatcher)

## Failure modes
- outside a Git repository -> exit 1, stderr names the missing repository
- a missing pillar file -> no failure: the pillar reports it as absent
- `aapp.statusOutputWidth` not a whole number of at least 40 -> exit 1, stderr names the key; `short` is not affected (P-92)

## Effects (happy path)
- `.plans/state_matrix.md` is re-derived from the plans before it is read, so the briefing reports the real board; the write is not committed
- `short`: stdout is exactly one line beginning `📊 Overview:` with issue, plan and pickup counts; appends ` | <N> adoption` when `.plans/adoption.md` has open tasks (P-63)
- no argument: stdout carries the four pillars (Shipped, Issues, Plans, Pickup), open adoption tasks after pickup when present (`📋 Adoption: <N> open task(s) in .plans/adoption.md`), and one `➡️  Next Action:` line
- Issues pillar (P-89): the work queue (plan blockers, then the queued issues level by level), one line per issue in the display form of `aapp issue list` (severity, status, logged date, queue date and level, symptom, plan), then `ℹ️  <N> more issue(s) logged, not queued for work: aapp issue list` when other issues are open; `(Nothing queued for work: …)` when only those exist, `(No open issues)` when there are none
- Issues pillar (P-78): once an open issue names a branch, each line ends with `(branch: <name>)` and the issues of the current branch (in a plan's worktree: of the plan's parent branch) come first, as in `aapp issue list`; an issue whose branch exists neither here nor on a remote is reported, with the development branch its fix will land on
- where a tracker keeps the issues (P-74): the briefing first brings them up to date through the `aapp-issue-tracker` provider's `issue.list`, at most once per `aapp.issueSyncWindow` minutes (default 15) counted from the last attempt, successful or not; a failing provider warns and changes nothing. Not done by `short`, nor while a plugin step runs
- an issue the tracker reports closed is closed here by the sync, at once (#142); a plan that waited on it is unblocked or named under Plans by the rule below
- a plan left blocked on a closed issue is unblocked once the fix commit is reachable from its parent branch (P-78): the plan and the re-derived matrix land in one `plans` commit `issue(unblock): fix reached the parent branch`, and the Plans pillar says `<plan> no longer waits for #<n>`; a plan still waiting gets a line naming the commit, the branch it was fixed on, the parent branch it is not in yet and `aapp refine <plan> unblocked <num>`. Not done by `short`, nor while a plugin step runs
- a plan with its own worktree shows it next to its status, from the header's `* **Worktree:**`: `• P-51: P51-….md  (⚡ In Development → ../repo-P51)` (P-54)
- records first (P-92): every section is collected into records (tab-separated lines, raw values) before anything is printed, and the terminal renderer prints them; side effects (sync, unblock, matrix) run first, and what they said is printed as notices of their section
- width (P-92): the `=` frame is `aapp.statusOutputWidth` characters wide; the header lines, the Plans pillar, the notices, the state lines, the adoption and offline lines and `➡️  Next Action:` keep to it, wrapped at spaces with the continuation indented under the text (counted in characters, not bytes; a word longer than the width stands on a line of its own). The lines of Shipped, the issue lines and the pickup ideas print as written
- the template advisory names the action first: `📑 Templates:  1 template drifted -> run 'aapp init' (<file> <reason>)`
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
- `tests/verbs/status.sh::test_briefing_unchanged_for_pillars` -> Shipped, Issues and Pickup of a fixture's briefing print as before the records (P-92)
- `tests/verbs/status.sh::test_briefing_lines_within_width` -> at a width of 60, no header, plan, notice or next-action line is longer (P-92)
- `tests/verbs/status.sh::test_pickup_records` -> pickup records split title and text, list the named files that exist, and a missing file is a warning notice (P-92)
