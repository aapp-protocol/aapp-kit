# issue [next | allocate | close <id> [sha <sha>] [summary "<text>"] | list [<n> | all]]

## Ingress
- positional forms:
    - `next` (default when no subcommand is given): prints the next issue ID without claiming it
    - `allocate`: claims the next issue ID and prints it (`#<n>`)
    - `close <id>`: relocates an active issue row to the archive
    - `list [<n> | all]`: prints active issues in road-map order
- `<id>`: bare number (`79`), `#79` (quoted: an unquoted `#79` is a shell comment) or `ISSUE-79`
- close tokens (bare, no `--`):
    - `sha <sha>`: commit recorded in the archive row (default: `HEAD` of the repository, short)
    - `summary "<text>"`: resolution summary (default: `Direct fix (no plan): <Target Plan / Fix cell>`); `|` is escaped
- list cap: bare `<n>` sets it, `all` removes it; default 20
- reads config: `aapp.issueId` (next ID to hand out; read by `next`, advanced by `allocate`); when unset (always in a fresh clone), seeded from both ledgers on first use, template example rows ignored
- reads: `.plans/ISSUES.md`, `.plans/done/000-issues-archive.md`, `.plans/issues_road_map.md`
- plugin: an installed `aapp-issue` provider (`.agents/skills/aapp-issue/`) serves `AAPP_ACTION=allocate` and receives `AAPP_ACTION=close` with `AAPP_ISSUE_ID`, `AAPP_COMMIT_SHA`, `AAPP_SUMMARY`

## Preconditions
- Inside a Git repository whose `.plans/` worktree exists

## Failure modes
- `aapp.issueId` set but not an integer -> `next` and `allocate` exit 1, stderr `aapp.issueId is not an integer` naming `git config --unset aapp.issueId`; the key is left untouched
- `aapp.issueId` unset, no ledger files, no provider -> `next` and `allocate` exit 1, stderr names the `aapp-issue` provider; nothing is written
- installed provider exits non-zero on `allocate` -> exit 1, stderr `Provider plugin failed; refusing to allocate locally`; no local fallback
- provider prints a non-integer id -> exit 1, stderr `Provider must return an integer id`
- `close` without an id -> exit 1, usage on stderr
- `close` with an unknown token -> exit 1, stderr `Unknown token`
- `close` id in neither ledger -> exit 1, stderr `not found in ISSUES.md or done/000-issues-archive.md`
- `close` id already archived -> no failure: exit 0, ledgers untouched, the provider is notified again
- provider exits non-zero on `close` -> no failure: exit 0, stderr warning; delivery and retry are the provider's responsibility
- `list` with a cap that is neither a number nor `all` -> exit 1, usage on stderr

## Effects (happy path)
- `next`: prints `Next available issue ID: #<n>`; `aapp.issueId` unchanged (an unset counter stays unset)
- first `allocate` with an unset counter: `#<highest ledger ID + 1>`, or `#1` in a new project
- `allocate`: prints `#<n>`; `aapp.issueId` becomes `<n>+1`, or the provider's id plus one when a provider issued a higher id
- `close`:
    - the row leaves `.plans/ISSUES.md` and is inserted at the top of `.plans/done/000-issues-archive.md` as `| #<n> | Sev | Type | Date Opened | <today> | \`<sha>\` | <summary> |`
    - the `#<n>` entry leaves `.plans/issues_road_map.md`
    - the three files land in one `plans` commit `issue(close): archive #<n>`; nothing else is staged
    - then the provider, if installed, is called once with `AAPP_ACTION=close`
- `list`: road-map entries in board order, the same selection as the `aapp status` Issues pillar; a truncated list ends with `… <k> more (aapp issue list all)`
- `aapp done` on a plan whose Target Issue is `#<n>` performs the same `close` in its own archive commit; a Target Issue in neither ledger refuses `done` before anything moves

## Exit
- 0 on success, including an already-archived `close` and a provider that fails on `close`
- non-zero on invalid arguments, a corrupt counter, a failing provider on `allocate`, or an unknown id

## Tests
Run: `aapp test verb issue`

- `tests/verbs/issue.sh::test_next_peeks_without_claiming` -> `next` prints the counter and leaves it unchanged
- `tests/verbs/issue.sh::test_allocate_claims_and_advances` -> `allocate` prints `#<n>` and advances the counter
- `tests/verbs/issue.sh::test_non_integer_counter_fails_closed` -> a corrupt counter refuses `next` and `allocate`
- `tests/verbs/issue.sh::test_provider_allocate_ratchets_counter` -> a provider's id is issued and the counter moves past it
- `tests/verbs/issue.sh::test_failing_provider_refuses_allocation` -> a failing provider is fatal, no local fallback
- `tests/verbs/issue.sh::test_close_relocates_prunes_and_commits` -> row archived at the top, road map pruned, one clean commit
- `tests/verbs/issue.sh::test_close_plugin_failure_only_warns` -> a failing provider on `close` warns, exit 0
- `tests/verbs/issue.sh::test_close_summary_escapes_pipes` -> `|` in the summary is escaped in the archive row
- `tests/verbs/issue.sh::test_close_archived_is_idempotent` -> closing an archived issue changes nothing, exit 0
- `tests/verbs/issue.sh::test_close_refuses_unknown_id_and_tokens` -> unknown id, unknown token and missing id exit non-zero
- `tests/verbs/issue.sh::test_list_default_cap_in_roadmap_order` -> 20 entries in board order plus the overflow line
- `tests/verbs/issue.sh::test_list_cap_tokens` -> `<n>` and `all` set the cap; `-n` is refused
- `tests/verbs/issue.sh::test_done_closes_target_issue` -> `aapp done` archives its Target Issue in the same commit
- `tests/verbs/issue.sh::test_done_refuses_dangling_target_issue` -> a Target Issue in neither ledger refuses `done`
- `tests/verbs/issue.sh::test_new_project_first_issue_is_1` -> template ledgers only: the first issue is `#1`
- `tests/verbs/issue.sh::test_clone_first_allocate_continues_ledgers` -> unset counter continues from the ledgers; `next` writes nothing
- `tests/verbs/issue.sh::test_no_ledgers_without_provider_refuses` -> no ledgers and no provider refuses, never `#1`
- `tests/verbs/issue.sh::test_no_ledgers_with_provider_allocates` -> no ledgers but a provider: the provider issues the ID
