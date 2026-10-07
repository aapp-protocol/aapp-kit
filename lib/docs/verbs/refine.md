# refine <id> "<what changed>" | refine <id> blocked <num>

## Ingress
- `id` (positional, required): an active plan in `.plans/current/` (`P-47`, `47`, slug or filename)
- `"<what changed>"` (positional, required): one line; becomes the commit subject `plan(refine): <id> <what changed>`
- `blocked <num>` (tokens, in place of the message): block the plan on active issue `#<num>` (bare number, e.g. `101`)
- reads: the plan file and the `plans` worktree status; with `blocked`, `.plans/ISSUES.md`
- reads config: `aapp.subjectMaxLen` (default 72, the `commit-msg` gate's limit); `aapp.aiAttribution` and the `AAPP_AGENT_*` identity, applied by the plans commit engine (`plans_commit`)

## Preconditions
- Inside a Git repository whose `.plans/` worktree exists
- Message form: the plan file has uncommitted changes
- `blocked` form: `#<num>` is an active row in `ISSUES.md`; no prior edit needed

## Failure modes
- missing `id` or message -> exit 1, stderr `Usage: aapp refine <plan-id> "<what changed>" | aapp refine <plan-id> blocked <num>`
- `blocked` with a non-numeric issue -> exit 1, stderr `Usage: aapp refine <plan-id> blocked <num>`
- `id` resolves to no active plan -> exit 1, stderr `Plan '<id>' not found`
- the message contains a line break -> exit 1, stderr `The message must be a single line (it becomes the commit subject).`; nothing staged or committed
- the subject `plan(refine): <id> <msg>` is longer than `aapp.subjectMaxLen` -> exit 1, stderr `Commit subject is <n> characters; the limit is <max> (aapp.subjectMaxLen).` and `Shorten the message by <n-max> characters: "<msg>"`; nothing staged or committed
- `blocked <num>` with `#<num>` not active in `ISSUES.md` (unknown or archived) -> exit 1, stderr `#<num> is not an active issue in ISSUES.md.`; the plan file is unchanged
- message form, the plan file has no changes -> exit 1, stderr `Nothing to commit`
- a frozen plan's §2 or §4 changed -> exit non-zero: the pre-commit design lock refuses the commit
- plans-worktree commit refused by a hook -> exit non-zero via `plans_commit` (loud failure)

## Effects (happy path)
- one commit in the plans worktree, subject `plan(refine): <id> <what changed>`, containing only `current/<plan file>`; other staged paths stay staged
- `blocked <num>`: the Status line becomes `🟥 BLOCKED` and `#<num>` is appended to `* **Blocked On:**` (a list); the first block records the previous status, `* **Blocked On:** #<num> (was <status>)`; the commit subject is `plan(refine): <id> blocked on #<num>`
- `blocked <num>` with `#<num>` already listed -> exit 0, stdout `already blocked on #<num>; nothing changed`; no commit
- `state_matrix.md` is not touched: `aapp matrix` re-derives it (`aapp refine <id> blocked <num> && aapp matrix`)
- the configured attribution is applied to the commit
- stdout ends with `📝 [Refine] <id> committed (<sha>): <what changed>`
- sourcing `lib/cmd_plan.sh` with `AAPP_PLAN_LIB_ONLY=1` defines `plan_block_on <plan_file> <num>` (write-only: no commit, no matrix) without running a command

## Exit
- 0 when the commit landed, or when `blocked <num>` found the issue already listed

## Tests
Run: `aapp test verb refine`

- `tests/verbs/refine.sh::test_refine_commits_only_the_plan` -> subject, single-file commit, confirmation line
- `tests/verbs/refine.sh::test_refine_leaves_other_staged_paths` -> another staged `.plans` path is not swept in
- `tests/verbs/refine.sh::test_refine_refuses_bad_input_and_no_change` -> missing args, unknown plan and no changes exit non-zero without committing
- `tests/verbs/refine.sh::test_refine_refuses_overlong_subject` -> length, limit and characters to cut are named; HEAD unchanged
- `tests/verbs/refine.sh::test_refine_honours_subject_max_len` -> a lowered `aapp.subjectMaxLen` is applied
- `tests/verbs/refine.sh::test_refine_refuses_multiline_message` -> a message with a line break exits 1; HEAD unchanged
- `tests/verbs/refine.sh::test_refine_blocked_sets_status_and_blocked_on` -> Status, `Blocked On:` with the previous status, subject, plan-only commit, matrix untouched
- `tests/verbs/refine.sh::test_refine_blocked_appends_to_list` -> a second issue is appended to the one `Blocked On:` line
- `tests/verbs/refine.sh::test_refine_blocked_same_issue_is_noop` -> the same issue again changes nothing and commits nothing
- `tests/verbs/refine.sh::test_refine_blocked_refuses_unknown_or_closed_issue` -> unknown and archived issues exit non-zero; the plan is unchanged
- `tests/verbs/refine.sh::test_plan_block_on_is_write_only_and_lib_loadable` -> `AAPP_PLAN_LIB_ONLY=1` loads `plan_block_on`, which writes without committing
