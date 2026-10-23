# adoption

## Tests
Run: `t/test-run adoption`

- `t/core/adoption.t::test_seeded_and_untracked` -> `aapp init` creates `.plans/adoption.md` with its sections, lists it in `.plans/.gitignore`, commits no version of it and leaves the plans worktree clean
- `t/core/adoption.t::test_gitignore_line_added_on_rerun` -> an existing `.plans/.gitignore` without the line gains it on a rerun
- `t/core/adoption.t::test_fresh_install_tasks` -> a fresh project gets the starter tasks under their sections
- `t/core/adoption.t::test_satisfied_rules_add_nothing` -> a rule whose check already passes adds no line
- `t/core/adoption.t::test_branch_and_remote_rules` -> `[DEV-BRANCH]`, `[STABLE-BRANCH]`, `[REMOTE]` and `[FIRST-PUSH]` appear on their trigger and tick once resolved
- `t/core/adoption.t::test_project_file_rules` -> `[INIT-FILES]`, `[PROJECT-RULES]`, `[PROJECT-MAP]`, `[TEMPLATE-DRIFT]`, `[ISSUES-SCHEMA]` and `[PROTOCOL-BLOCK]` appear on their trigger and tick once resolved
- `t/core/adoption.t::test_hook_rules` -> a foreign `core.hooksPath` adds `[HOOK-WIRING]`, a `pre-done` row ticks `[GATE-TEST]`, settings without the guard add `[WRITE-GUARD]`
- `t/core/adoption.t::test_build_tool_rules_follow_worktree_path` -> `nx.json` and Bazel markers add tasks naming the worktree directory; an ignore line ticks them; a worktree path outside the repository adds none
- `t/core/adoption.t::test_review_tasks_only_user_ticks` -> a review task stays open over reruns, and a hand tick survives
- `t/core/adoption.t::test_rerun_is_quiet` -> a rerun with nothing new changes no byte and adds no commit to the plans branch
- `t/core/adoption.t::test_user_edits_survive` -> a hand-ticked task, a reworded line and a deleted line are kept as the user left them
- `t/core/adoption.t::test_docs_targets_exist` -> every catalogue entry's documentation target is a file in the kit
- `t/core/adoption.t::test_docs_governance_disabled` -> `aapp.docs false` leaves out `[PROJECT-RULES]` and `[PROJECT-MAP]`
