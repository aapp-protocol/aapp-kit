# worktree_hooks

## Tests
Run: `aapp test worktree_hooks`

- `tests/worktree_hooks_test.sh::test_init_links_hooks_into_worktrees` -> `aapp init` links `.githooks` into `.plans` and `.agents` and ignores it there once; a rerun keeps both
- `tests/worktree_hooks_test.sh::test_plans_worktree_runs_commit_hooks` -> a commit in `.plans` with a co-author trailer or a subject over 72 characters is refused; a clean one passes
- `tests/worktree_hooks_test.sh::test_agents_worktree_runs_commit_hooks` -> a commit in `.agents` with a co-author trailer is refused; a clean one passes
- `tests/worktree_hooks_test.sh::test_attribution_modes_in_worktrees` -> `strict` refuses a `.plans` commit without AI trailers and takes one with them; `lax` takes a human commit without trailers
- `tests/worktree_hooks_test.sh::test_plan_worktree_guard` -> the write guard allows the plan's targets and the primary `.plans`, and refuses other files, from the plan worktree and from the primary session
- `tests/worktree_hooks_test.sh::test_plan_worktree_pre_commit_refuses_outside_files` -> pre-commit runs in a plan worktree and refuses a file outside the plan
- `tests/worktree_hooks_test.sh::test_plan_worktree_commit_record_follows_rewrites` -> `aapp commit` records the commit; after a rebase, a squash, a commit dropped as already upstream and `aapp commit amend`, the record holds each reachable SHA once
- `tests/worktree_hooks_test.sh::test_plan_worktree_refuses_merge` -> finishing a conflicted merge in a plan worktree is refused: plan branches take fixes by rebase only
