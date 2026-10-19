# pre-commit

## Tests
Run: `aapp test pre-commit`

- `tests/pre-commit_test.sh::test_spaced_target_path` -> a target path with spaces commits
- `tests/pre-commit_test.sh::test_target_line_parsing` -> a path named only in a target's prose stays blocked; `NEW FILE` and `MODIFY` markers, backticked or not, resolve to the path after them
- `tests/pre-commit_test.sh::test_concurrent_plans_and_shared_docs` -> invariant anchors and shared docs commit without being targets; the bound plan's targets commit despite another plan's Out of Bounds; a file in no plan, or two plans in development with no binding, is refused
- `tests/pre-commit_test.sh::test_own_out_of_bounds_wins` -> a plan's own Out of Bounds wins over its broad target
- `tests/pre-commit_test.sh::test_out_of_bounds_only_plan` -> with no targets, Out of Bounds still refuses and other files commit
- `tests/pre-commit_test.sh::test_blocked_plan_refused` -> a blocked plan's own target is refused
- `tests/pre-commit_test.sh::test_hook_follows_adopter_statuses` -> adopter statuses from `aapp.planState.*` block or grant as the kit's do
- `tests/pre-commit_test.sh::test_syntax_check_spaced_path` -> broken Python in a spaced path is refused by the syntax check
- `tests/pre-commit_test.sh::test_deleting_out_of_bounds_file_refused` -> deleting an Out of Bounds file is refused
- `tests/pre-commit_test.sh::test_skip_blast_radius_escape` -> `SKIP_BLAST_RADIUS=1` commits code without a changelog line
- `tests/pre-commit_test.sh::test_plans_changelog_satisfies_rule` -> a staged `.plans/CHANGELOG.md`, or one changed in the `.plans` worktree, satisfies the changelog rule
- `tests/pre-commit_test.sh::test_hook_runs_without_exec_bit` -> the dispatcher runs `aapp-pre-commit` even without its exec bit and reports the violation
- `tests/pre-commit_test.sh::test_branch_protection` -> with a development branch present, commits to `main` are refused unless `ALLOW_MAIN_COMMIT=1` or `aapp.protectStable false`; `aapp.devBranch` names the development branch
- `tests/pre-commit_test.sh::test_roadmap_auto_prune` -> a commit prunes resolved road map lines and keeps open lines and prose
- `tests/pre-commit_test.sh::test_resolved_issue_row_refused` -> a resolved row left in the active `ISSUES.md` is refused
- `tests/pre-commit_test.sh::test_glob_targets` -> `*`, `**`, `?`, bracket classes and directory prefixes match as globs, in targets and Out of Bounds
- `tests/pre-commit_test.sh::test_frozen_design_lock` -> a frozen plan takes ticks, change log lines and answered questions, refuses §2 and §4 edits, unfreezes only with the design unchanged; a draft plan takes any edit
- `tests/pre-commit_test.sh::test_group_and_amendments_lock` -> a group's Architecture & Codemap section changes only with a decision naming its heading; an amendments member may add targets but not change them or its blueprint; no other plan in development gains targets
- `tests/pre-commit_test.sh::test_active_plan_buffer` -> a kit repository without `.plans/current` is quarantined; a frozen plan restricts nothing; the binding, auto-discovery, `active <id>` and `active swap` decide which plan's targets commit
- `tests/pre-commit_test.sh::test_portability_paths` -> a `file:///` URI or a home path in a staged file is refused; relative links and `file://` named in prose commit
- `tests/pre-commit_test.sh::test_pause_blocks_code_commits` -> while paused, code, `.agents` and `.plans/done` commits are refused and pickup commits pass; pause is refused during a merge; after resume code commits again
- `tests/pre-commit_test.sh::test_pause_quarantines_every_worktree` -> pause leaves every worktree clean, and resume restores each one's changes
- `tests/pre-commit_test.sh::test_resume_conflict_loses_nothing` -> a conflicting resume fails and keeps both the pause buffer and the stash
- `tests/pre-commit_test.sh::test_runtime_reachability` -> with no reachable `aapp` the hook refuses in inspection-only mode, even with `SKIP_BLAST_RADIUS=1`; `aapp` on the path or in `~/.local/bin` commits; `--no-verify` always does
- `tests/pre-commit_test.sh::test_parser_boundaries` -> quoted and foreign-section paths are refused; Required Test Files commit
- `tests/pre-commit_test.sh::test_missing_library_refuses_commit` -> without `aapp-lib.sh` or `plan_states.sh` beside it the hook refuses every commit and names what is missing
- `tests/pre-commit_test.sh::test_failure_test_declaration` -> a plan without required tests commits freely; §3 and §4 test lists that differ, or a declared test file missing in development, refuse; a refining plan tolerates unwritten tests
- `tests/pre-commit_test.sh::test_reminder_outside_helper_is_warning_only` -> a raw commit for a plan passes with a reminder to record it; the helper's commit prints none
- `tests/pre-commit_test.sh::test_changelog_bullet_rules` -> a changelog bullet over 300 characters (or `aapp.changelogMaxLen`) or an unbulleted continuation line is refused
- `tests/pre-commit_test.sh::test_plan_declared_changelog_entry` -> in `plan` mode code commits pass once the plan's entry is in the changelog, naming `aapp commit` otherwise; `commit` mode and a commit with no plan need a changelog change
- `tests/pre-commit_test.sh::test_plans_held_by_another_worktree` -> an unbound checkout cannot commit a plan held elsewhere and commits other files freely
- `tests/pre-commit_test.sh::test_gitattributes_always_allowed` -> `.gitattributes` commits while a plan is in development
- `tests/pre-commit_test.sh::test_atomic_commit_mode` -> in `atomic` mode a raw commit is refused once the plan has a commit, the helper's passes, and nothing changes without a plan; `microcommits` allows more
- `tests/pre-commit_test.sh::test_member_leaves_architecture_to_group` -> a group member's commit touching `ARCHITECTURE.md` is refused naming the group; a plan without a group commits it
