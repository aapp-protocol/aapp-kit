# issue_ledger

## Tests
Run: `aapp test issue_ledger`

- `tests/issue_ledger_test.sh::test_rows_keep_escaped_pipes` -> `ledger_rows` prints each row as tab-separated cells with escaped pipes kept and the row's source; a status filter selects rows
- `tests/issue_ledger_test.sh::test_locate_active_archive_unknown` -> `ledger_locate` names the ledger holding an id: `active`, `archive`, or nothing
- `tests/issue_ledger_test.sh::test_locate_finds_release_bundles` -> an id archived in a release bundle is located as `archive`
- `tests/issue_ledger_test.sh::test_set_cell_changes_lifecycle_only` -> `ledger_set_cell` rewrites the link and status cells of one row; observation cells and unknown ids are refused, the file unchanged
- `tests/issue_ledger_test.sh::test_archive_row_moves_and_prunes` -> `ledger_archive_row` moves a row to the top of the archive with today's date, commit and summary, and prunes its road map line; an unknown id is refused
- `tests/issue_ledger_test.sh::test_archive_row_aborted` -> an aborted issue is archived with `aborted` as its commit
- `tests/issue_ledger_test.sh::test_archive_commit_corrected` -> `ledger_set_archive_commit` rewrites an archived row's commit; an unknown id exits 3
- `tests/issue_ledger_test.sh::test_archive_overflow_bound` -> past `aapp.issueArchiveMax` rows the oldest move to the overflow archive, still located and listed as archived
- `tests/issue_ledger_test.sh::test_relink_ledger_and_roadmap` -> `ledger_relink` rewrites a plan link in the ledger and the road map and counts the lines, leaving other links alone
- `tests/issue_ledger_test.sh::test_path_resolves_in_each_place` -> `ledger_path` finds each ledger in `.plans/`, in a plans worktree, at the repository root, and under `PLANS_DIR`; a missing road map still gets its path
- `tests/issue_ledger_test.sh::test_roadmap_entries_and_blockers` -> `roadmap_entries` lists the open road map lines (capped on request) and `roadmap_blockers` the plan blockers' ids
- `tests/issue_ledger_test.sh::test_roadmap_prune` -> `roadmap_prune <id>` removes one line and `roadmap_prune resolved` the ticked ones
- `tests/issue_ledger_test.sh::test_issue_records_fields` -> `ledger_issue_records` prints each issue's 18 fields: severity, status and queue slugs, plan, blocks, branch, offline flag, tracker and note count
- `tests/issue_ledger_test.sh::test_note_count_holds_no_text` -> the records carry a note count, never a description's or note's text
