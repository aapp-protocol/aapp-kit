# integrate

## Tests
Run: `aapp test integrate`

- `tests/integrate_test.sh::test_manual_default_archives_without_integrating` -> with the seeded `manual` setting, `done` archives a worktree plan and integrates nothing
- `tests/integrate_test.sh::test_squash_integrates_with_trailers_and_cleans_up` -> `squash` lands the plan as one commit with its trailers on the parent and removes the worktree and branch
- `tests/integrate_test.sh::test_integrates_into_module_parent_not_develop` -> a plan started from a module branch integrates into that branch, not the development branch
- `tests/integrate_test.sh::test_ff_keeps_microcommits_and_deletes_branch` -> `ff` fast-forwards the parent, keeping each commit, and deletes the plan branch
- `tests/integrate_test.sh::test_preflight_failure_archives_nothing` -> a failing pre-flight check archives nothing
- `tests/integrate_test.sh::test_hotfix_cap_vetoes_without_override` -> a plan past the hotfix cap is refused until `override-hotfix-cap`
- `tests/integrate_test.sh::test_ignored_files_refuse_cleanup_then_quarantine` -> an ignored file in the worktree integrates but keeps the worktree, naming `force-cleanup`; with `aapp.quarantineIgnored` a retry moves the file to quarantine and cleans up
- `tests/integrate_test.sh::test_no_integrate_token_archives_only` -> `no-integrate` archives and leaves the parent and the worktree
- `tests/integrate_test.sh::test_plan_without_worktree_never_integrated` -> a plan worked in the main checkout is archived without any integration
- `tests/integrate_test.sh::test_hook_strategy_refuses_without_handler_then_delegates` -> `aapp.integrate hook` without an on-integrate handler refuses before archiving; a handler gets the plan and target branches, and a failed handler is retried with `integrate`
- `tests/integrate_test.sh::test_member_integrates_into_feature_branch` -> a group member's `done` integrates into the group's feature branch
- `tests/integrate_test.sh::test_group_done_refuses_open_member` -> a group's `done` with a member still open is refused, changing nothing
- `tests/integrate_test.sh::test_group_done_gates_merges_and_writes_docs` -> a group's `done` merges the moved parent in, runs the gate on the feature branch, commits the group's ARCHITECTURE.md and CODEMAP.md sections after it, merges into the parent, writes the umbrella changelog entry and cleans up last
- `tests/integrate_test.sh::test_group_done_conflict_refuses_unchanged` -> a section changed in the file meanwhile refuses the group's `done`, changing nothing
- `tests/integrate_test.sh::test_group_done_commits_nothing_before_every_check_passed` -> a gate veto or a refused docs commit leaves no commit and a clean worktree; the next run lands it
- `tests/integrate_test.sh::test_auto_rebase_setting_refuses_or_rebases` -> a plan behind its parent is refused with `aapp.autoRebase false` and rebased and integrated with `true`
- `tests/integrate_test.sh::test_auto_rebase_conflict_aborts_cleanly` -> an automated rebase that conflicts aborts, leaving the worktree clean and the plan open
- `tests/integrate_test.sh::test_named_lock_acquire_and_release` -> `aapp_lock_acquire` creates the named lock with its PID and `aapp_lock_release` removes it
- `tests/integrate_test.sh::test_named_lock_reentrancy` -> the holder may acquire its lock again
- `tests/integrate_test.sh::test_named_lock_stale_pid_takeover` -> a lock held by a dead PID is taken over, with a notice
- `tests/integrate_test.sh::test_concurrent_integrations_different_parents_proceed` -> a lock on one parent does not hold up integration into another
- `tests/integrate_test.sh::test_precommit_rejects_raw_commit_on_locked_parent` -> a raw commit on a parent locked for integration is refused
- `tests/integrate_test.sh::test_parent_lock_contended_wait_and_integration` -> `done` waits for a held parent lock, saying so, and integrates once it is free
- `tests/integrate_test.sh::test_archive_failure_rolls_back_cas_and_preserves_active_buffer` -> a failed archive puts the parent back and keeps the plan current and bound
