# refine <id> "<what changed>" | refine <id> blocked <num> | refine <id> slug <new-slug> | refine pickup|issues "<msg>"

## Ingress
- `id` (positional, required): an active plan in `.plans/current/` (`P-47`, `47`, slug or filename)
- `"<what changed>"` (positional, required): one line; becomes the commit subject `plan(refine): <id> <what changed>`
- `blocked <num>` (tokens, in place of the message): block the plan on active issue `#<num>` (bare number, e.g. `101`)
- `slug <new-slug>` (tokens, in place of the message): rename the plan file to `current/P<N>-<new-slug>.md`; normalised like `aapp draft` (P-50)
- `pickup` / `issues` (in place of `id`, reserved words checked before plan resolution): commit a hand-made edit of `pickup.md`, or of `ISSUES.md` + `issues_road_map.md` (P-50). A plan whose file name contains them stays reachable by its ID
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
- `slug`: new slug empty after normalisation, target file exists, same name, or the plan file has uncommitted edits -> exit 1 naming the cause; nothing moves
- `pickup` / `issues`: ledger unchanged -> exit 1, `Nothing to commit`; a validation failure -> exit 1, each failing line named, `Nothing committed`. Issues: an empty line inside the table, a row without 8 cells, a repeated ID (Pairs 8, 1), an active ID at or above `aapp.issueId`, a road-map line without a row (Pair 2), an active issue missing from the road map. Pickup: an entry that is not a `- [ ] ` line
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
- `slug`: the file is renamed, its change log gains `File renamed from <old> to <new>`, issue and road-map links to it are repaired (observation cells untouched), the matrix is re-derived and the active buffer follows; one commit `plan(refine): <id> renamed to <new>`; stdout `📝 [Refine] <id> renamed to <new> (<sha>); <n> issue links repaired`
- `pickup` / `issues`: one commit of only the ledger files, `pickup: <msg>` or `issue(triage): <msg>`, subject checked like any refine
- `state_matrix.md` is not touched by the message and `blocked` forms: `aapp matrix` re-derives it (`aapp refine <id> blocked <num> && aapp matrix`)
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
- `tests/verbs/refine.sh::test_refine_slug_renames_and_repairs_links` -> rename, issue and road-map links repaired, observation cell untouched, matrix, change-log line, one clean commit (P-50)
- `tests/verbs/refine.sh::test_refine_slug_refusals` -> empty slug, existing target, dirty plan, unknown plan: nothing moves (P-50)
- `tests/verbs/refine.sh::test_refine_pickup_commits_only_pickup` -> the reserved word wins over a plan named *pickup*; only `pickup.md` committed (P-50)
- `tests/verbs/refine.sh::test_refine_pickup_refuses_malformed_entry` -> a non-checkbox entry is refused with its line (P-50)
- `tests/verbs/refine.sh::test_refine_issues_commits_ledgers` -> `issue(triage): <msg>`, ledger files only (P-50)
- `tests/verbs/refine.sh::test_refine_issues_validation_refuses` -> blank line, cell count, duplicate, ID above the counter, missing road-map line: each refused, nothing committed (P-50)
