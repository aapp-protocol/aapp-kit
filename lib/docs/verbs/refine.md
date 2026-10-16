# refine <id> "<what changed>" | refine <id> blocked <num> | refine <id> unblocked <num> | refine <id> slug <new-slug> | refine <id> closes <num> [remove] | refine <id> group <group>|none | refine pickup "<msg>" | refine issues "<msg>" [branch <num> <name>] [note <num> "<text>"]…

## Ingress
- `id` (positional, required): an active plan in `.plans/current/` (`P-47`, `47`, slug or filename)
- `"<what changed>"` (positional, required): one line; becomes the commit subject `plan(refine): <id> <what changed>`
- `blocked <num>` (tokens, in place of the message): block the plan on active issue `#<num>` (the issue's id without the `#`: a number or a tracker's key, e.g. `101`, `PROJ-101`)
- `unblocked <num>` (tokens, in place of the message): remove closed issue `#<num>` from the plan's `Blocked On:` (P-78). The manual unblock, for a fix that reached the plan's parent branch as another commit (a squash merge, a cherry-pick, a rebase), which `aapp issue close` and `aapp status` do not recognise
- `closes <num> [remove]` (tokens, in place of the message, P-86): add active issue `#<num>` to the plan's `* **Also Closes:** #<n>, #<m>` header line (written after `Target Issue / Milestone`), or take it off with `remove`; the line goes when the list is empty. `aapp done` closes the listed issues with the plan's recorded commit
- `slug <new-slug>` (tokens, in place of the message): rename the plan file to `current/P<N>-<new-slug>.md`; normalised like `aapp draft` (P-50)
- `group <group>` / `group none` (tokens, in place of the message): the plan joins group plan `<group>`, or leaves its group (P-64)
- `pickup` / `issues` (in place of `id`, reserved words checked before plan resolution): commit a hand-made edit of `pickup.md`, or a change to existing rows of `ISSUES.md` + `issues_road_map.md` (P-50); a row is never added here: `aapp issue log` is the one writer of new rows (P-74). A plan whose file name contains them stays reachable by its ID
- `issues "<msg>" branch <num> <name>` (P-78): names the branch active issue `#<num>`'s fix must land on, then commits the ledgers as `issues "<msg>"` does; the development branch clears the cell
- `issues "<msg>" note <num> "<text>"` (P-74, repeatable): adds a note to active issue `#<num>`, dated, with its author. Notes are never in the ledger or in Git: a provider that names `notes` in `handled` keeps them, otherwise the kit's store on this machine does. With no other change nothing is committed
- reads: the plan file and the `plans` worktree status; with `blocked`, `.plans/ISSUES.md`
- reads config: `aapp.pickupTitleMax` (default 72: the longest pickup title, `refine pickup`, P-96); `aapp.subjectMaxLen` (default 72, the `commit-msg` gate's limit); `aapp.aiAttribution` and the `AAPP_AGENT_*` identity, applied by the plans commit engine (`plans_commit`)

## Preconditions
- Inside a Git repository whose `.plans/` worktree exists
- Message form: the plan file has uncommitted changes
- `blocked` form: `#<num>` is an active row in `ISSUES.md`; no prior edit needed

## Failure modes
- missing `id` or message -> exit 1, stderr `Usage: aapp refine <plan-id> "<what changed>" | aapp refine <plan-id> blocked <num>`
- `blocked` with a non-numeric issue -> exit 1, stderr `Usage: aapp refine <plan-id> blocked <num>`
- `id` resolves to no active plan -> exit 1, stderr `Plan '<id>' not found`
- `slug`: new slug empty after normalisation, target file exists, same name, or the plan file has uncommitted edits -> exit 1 naming the cause; nothing moves
- `pickup` / `issues`: ledger unchanged -> exit 1, `Nothing to commit`; a validation failure -> exit 1, each failing line named, `Nothing committed`. Issues: an empty line inside the table, a row without as many cells as the header (8, or 9 with `Branch`), a *Target Plan / Fix* cell holding anything but empty or a verb-written link (`[P-xx](…)`, `blocks [P-xx](…)`, P-66), a repeated ID (Pairs 8, 1), a row added by hand (each named, with `aapp issue log`, P-74), a road-map line without a row (Pair 2), an active issue missing from the road map. Pickup: an entry that is not a `- [ ] ` line; an unworked entry not in the form `- [ ] <title>: <text>` (P-96): no title (no `: ` outside backticks), a title longer than `aapp.pickupTitleMax` characters (`title is <n> characters; at most <max> (aapp.pickupTitleMax)`), no text after the title, or a named `.plans/pickup/` path that does not exist, checked for the entries the commit adds or changes only (`.plans/pickup/` is gitignored: its files are on the writer's machine); a digested `- [x] ` entry is not checked. An `aapp.pickupTitleMax` that is not a whole number of at least 10 -> exit 1 naming the key, nothing committed
- the message contains a line break -> exit 1, stderr `The message must be a single line (it becomes the commit subject).`; nothing staged or committed
- the subject `plan(refine): <id> <msg>` is longer than `aapp.subjectMaxLen` -> exit 1, stderr `Commit subject is <n> characters; the limit is <max> (aapp.subjectMaxLen).` and `Shorten the message by <n-max> characters: "<msg>"`; nothing staged or committed
- `blocked <num>` with `#<num>` not active in `ISSUES.md` (unknown or archived) -> exit 1, stderr `#<num> is not an active issue in ISSUES.md.`; the plan file is unchanged
- `unblocked <num>` with `#<num>` still an active row -> exit 1, stderr `#<num> is still open`; with `#<num>` not in the plan's `Blocked On:` -> exit 1, `<id> is not blocked on #<num>`; the plan file is unchanged (P-78)
- `closes <num>` with `#<num>` not an active row, or the plan's own `Target Issue` -> exit 1, nothing changed; already listed -> exit 0, `already closes`, nothing committed; `remove` of an issue not listed -> exit 1; an unknown token after it -> exit 1 (P-86)
- `issues … branch`: tokens other than `branch <num> <name>` -> exit 1, usage; `#<num>` not an active row, or `<name>` a branch that exists neither here nor on a remote -> exit 1; nothing written (P-78)
- `issues` where a tracker keeps the record (the ledgers are not tracked) with neither `branch` nor `note` -> exit 1: the issues are changed on the tracker, or here with those tokens (P-74)
- message form, the plan file has no changes -> exit 1, stderr `Nothing to commit`
- `group`: the plan is a group plan (`groups do not nest`), already started (`⚡`/`🟥`), or `<group>` is not a group plan in `current/` -> exit 1; nothing changes
- a frozen plan's §2 or §4 changed -> exit non-zero: the pre-commit design lock refuses the commit
- plans-worktree commit refused by a hook -> exit non-zero via `plans_commit` (loud failure)

## Effects (happy path)
- one commit in the plans worktree, subject `plan(refine): <id> <what changed>`, containing only `current/<plan file>`; other staged paths stay staged
- `blocked <num>`: the Status line becomes `🟥 BLOCKED` and `#<num>` is appended to `* **Blocked On:**` (a list); the first block records the previous status, `* **Blocked On:** #<num> (was <status>)`; the commit subject is `plan(refine): <id> blocked on #<num>`
- `blocked <num>` with `#<num>` already listed -> exit 0, stdout `already blocked on #<num>; nothing changed`; no commit
- `unblocked <num>`: `#<num>` leaves `* **Blocked On:**`; when it was the last and the block is not permanent, the line goes and the recorded status returns; one commit `plan(refine): <id> unblocked from #<num>` with the plan only; stdout names what still blocks it (P-78)
- `closes <num> [remove]`: one commit `plan(refine): <id> closes #<num>` (or `no longer closes #<num>`) holding only the plan; the issue's row is not touched (P-86)
- `issues`: a new row's `Branch` cell is left as written, whichever checkout the command is run from; a row names a branch only through `branch <num> <name>` (or `aapp issue hotfix`), and none named means the development branch (#136)
- `issues … branch <num> <name>`: the row's `Branch` cell names `<name>` (the column is added, last, when the ledger lacks it; empty for the development branch); already so and nothing else changed -> exit 0, `already targets`, no commit (P-78)
- `slug`: the file is renamed, its change log gains `File renamed from <old> to <new>`, issue and road-map links to it are repaired (observation cells untouched), the matrix is re-derived and the active buffer follows; one commit `plan(refine): <id> renamed to <new>`; stdout `📝 [Refine] <id> renamed to <new> (<sha>); <n> issue links repaired`
- `group <group>`: the plan's header gains `* **Group:** <group>`, the group's `* **Members:**` lists it (and a previous group drops it); one commit `plan(refine): <id> joins group <group>` with the plan and the group(s). `group none`: the field goes, the group drops it, `plan(refine): <id> leaves group <group>`. Already so -> exit 0, nothing changed
- `issues` (P-74): after the commit the installed `aapp-issue-tracker` provider receives one `issue.refine` per row that changed, with the whole issue and the notes just added; a failing provider only warns. Where a tracker keeps the record nothing is committed: the change is made in the untracked ledger and sent
- `pickup` / `issues`: one commit of only the ledger files, `pickup: <msg>` or `issue(triage): <msg>`, subject checked like any refine
- `state_matrix.md` is not touched by the message, `blocked` and `unblocked` forms: `aapp matrix` re-derives it (`aapp refine <id> blocked <num> && aapp matrix`)
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
- `tests/verbs/refine.sh::test_refine_pickup_refuses_untitled_entry` -> an entry with no `: ` outside backticks is refused naming its line; nothing committed (P-96)
- `tests/verbs/refine.sh::test_refine_pickup_refuses_long_title` -> a title one character over `aapp.pickupTitleMax` is refused with its length and the limit, one at the limit accepted, under 72 and 50 (P-96)
- `tests/verbs/refine.sh::test_refine_pickup_title_max_invalid` -> an `aapp.pickupTitleMax` that is not a whole number of at least 10 is refused naming the key (P-96)
- `tests/verbs/refine.sh::test_refine_pickup_refuses_empty_text` -> `- [ ] Title:` with no text is refused (P-96)
- `tests/verbs/refine.sh::test_refine_pickup_refuses_missing_file` -> a named `.plans/pickup/` file that does not exist is refused naming the path; an existing one accepted (P-96)
- `tests/verbs/refine.sh::test_refine_pickup_committed_file_elsewhere` -> a committed entry whose `.plans/pickup/` file this machine lacks does not block a commit of another entry (P-96)
- `tests/verbs/refine.sh::test_refine_pickup_skips_digested` -> a `- [x] ` entry without a title is not refused (P-96)
- `tests/verbs/refine.sh::test_refine_issues_commits_ledgers` -> `issue(triage): <msg>`, ledger files only (P-50)
- `tests/verbs/refine.sh::test_refine_issues_validation_refuses` -> blank line, cell count, duplicate, a row renumbered by hand, a heading that is not one of the work queue's: each refused, nothing committed (P-50, P-89)
- `tests/verbs/refine.sh::test_refine_joins_and_leaves_group` -> join and leave each in one commit; refused once the plan is started (P-64)
- `tests/verbs/refine.sh::test_issues_refuses_text_in_fix_cell` -> notes in a fix cell: refused, naming the row, nothing committed (P-66)
- `tests/verbs/refine.sh::test_issues_accepts_plan_and_blocks_links` -> an empty cell and a `blocks [P-xx](…)` link pass (P-66)
