# issue_ledger

## Tests
Run: `t/test-run issue_ledger`

- `t/core/issue_ledger.t::test_rows_keep_escaped_pipes` -> `ledger_rows` gives each row as nine cells with escaped pipes kept and the row's source; a status filter selects rows
- `t/core/issue_ledger.t::test_locate_active_archive_unknown` -> `ledger_locate` names the ledger holding an id: `active`, `archive`, or nothing
- `t/core/issue_ledger.t::test_locate_finds_release_bundles` -> an id archived in a release bundle is located as `archive`
- `t/core/issue_ledger.t::test_set_cell_changes_lifecycle_only` -> `ledger_set_cell` rewrites the link and status cells of one row; observation cells and unknown ids are refused, the file unchanged
- `t/core/issue_ledger.t::test_archive_row_moves_and_prunes` -> `ledger_archive_row` moves a row to the top of the archive with today's date, commit and summary, and prunes its road map line; an unknown id is refused
- `t/core/issue_ledger.t::test_archive_row_aborted` -> an aborted issue is archived with `aborted` as its commit
- `t/core/issue_ledger.t::test_archive_commit_corrected` -> `ledger_set_archive_commit` rewrites an archived row's commit; an unknown id exits 3
- `t/core/issue_ledger.t::test_archive_overflow_bound` -> past `aapp.issueArchiveMax` rows the oldest move to the overflow archive, still located and listed as archived
- `t/core/issue_ledger.t::test_relink_ledger_and_roadmap` -> `ledger_relink` rewrites a plan link in the ledger and the road map and counts the lines, leaving other links alone
- `t/core/issue_ledger.t::test_path_resolves_in_each_place` -> `ledger_path` finds each ledger in `.plans/`, in a plans worktree, at the repository root, under a root the caller names, and as a file the caller names (`AAPP_LEDGER_*`); a missing road map still gets its path
- `t/core/issue_ledger.t::test_roadmap_entries_and_blockers` -> `roadmap_entries` lists the open road map lines (capped on request) and `roadmap_blockers` the plan blockers' ids
- `t/core/issue_ledger.t::test_roadmap_prune` -> `roadmap_prune <id>` removes one line and `roadmap_prune resolved` the ticked ones
- `t/core/issue_ledger.t::test_issue_records_fields` -> `issue_records` gives each issue's 18 fields: severity, status and queue slugs, plan, blocks, branch, offline flag, tracker and note count (none with a tracker provider)
- `t/core/issue_ledger.t::test_note_count_holds_no_text` -> the records carry a note count, never a description's or note's text
