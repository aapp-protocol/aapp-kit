# done <id> [integrate [squash | ff | hook] [target <branch>] [no-cleanup] [force-cleanup] [override-hotfix-cap] | no-integrate]

## Ingress
- `id` (positional, required): the implemented plan to archive
    accepted forms: `P-<N>`, bare `<N>`, the filename stem, or a slug prefix
    constraints: must resolve to exactly one plan in `.plans/current/`; with `integrate`, a plan already in `.plans/done/` is integrated without archiving again (P-55); when that integration squashes it, its `Commits:`, its archive ledger line and the archived row of its issue are corrected to the new commit in one commit `plan(record): record <sha> for <id>` on the plans branch (P-84)
- integration tokens (bare, P-55), for a plan with its own worktree (`* **Worktree:**`, P-54):
    - `integrate`: integrate now (the strategy from `aapp.integrate`, or `squash` when that is `manual`)
    - `squash` | `ff` | `hook`: the strategy (implies `integrate`); `target <branch>`: the target branch (implies `integrate`)
    - `no-cleanup`: keep the worktree and branch; `force-cleanup`: remove them even when sensitive ignored files are there; `override-hotfix-cap`: human sign-off past `aapp.maxEmergencyHotfixes`
    - `no-integrate`: archive only, whatever `aapp.integrate` says
- reads config (P-55): `aapp.integrate` (`manual` seeded; `squash`, `ff`, `hook`), `aapp.integrateTarget` (`parent` = the branch in `* **Base:**`, `dev`, or a branch), `aapp.integrateCleanup` (`true`), `aapp.quarantineIgnored` (`false`), `aapp.maxEmergencyHotfixes`, `aapp.issueFixWait`; the hook registry for `on-integrate`
- reads: the plan file (Plan ID, `Target Issue / Milestone` header), `.plans/done/000-archive-ledger.md`, `.plans/state_matrix.md`, the active buffer
- reads: the plan file (Plan ID, `Target Issue / Milestone` header, `* **Commits:**` header line), `.plans/done/000-archive-ledger.md`, `.plans/state_matrix.md`, the active buffer
- reads config: the lifecycle hook registry for `pre-done` and `post-done` (P-23)

## Preconditions
- Inside a Git repository whose `.plans/current/` and `.plans/done/` exist
- The plan is `⚡ In Development`
- The plan's `* **Commits:**` header contains at least one recorded commit (not `none` or empty)
- Every recorded commit is contained in Git ref history (branch or tag)

## Failure modes
- no `id` -> exit 1, stderr `You must specify a target plan for 'done'.`
- `id` resolves to no plan -> exit 1, stderr `Plan '<id>' not found`; nothing moves
- the plan is not `⚡ In Development` -> exit 1, stderr `[Done Refusal] Plan is not ⚡ In Development`; nothing moves (#89)
- no recorded commits (`* **Commits:** none` or empty) -> exit 1, prints candidate commits and `aapp commit adopt <sha>` repair command
- recorded commit unreachable / amended away -> exit 1 naming the missing SHA (a rebase or amend keeps the record right through the `post-rewrite` hook, P-54)
- the plan records a `* **Worktree:**` with uncommitted changes in it -> exit 1, stderr `has uncommitted changes`; nothing moves (P-54)
- an unknown token, or `no-integrate` with integration tokens -> exit 1; nothing moves
- integration checks (P-55), all before `pre-done` and the archive commit, so a refusal leaves nothing archived: the plan branch or the target branch missing locally; the plan branch not containing the target (`rebase it first`, with the command); uncommitted tracked changes in the main checkout; more than `aapp.maxEmergencyHotfixes` emergency hotfixes without `override-hotfix-cap`; `hook` with no `on-integrate` handler registered; an open mini plan in the main checkout, waited for with the P-52 roller up to `aapp.issueFixWait` (`0` refuses at once) -> exit 1
- `integrate` on a plan without a worktree -> exit 1 (its commits are on the development branch already)
- after the archive: the fast-forward, or the `on-integrate` handler, fails -> exit 1; the plan stays archived and `aapp done <id> integrate` retries
- `pre-done` lifecycle hook exits non-zero (except 2) -> exit 1, vetoes archive; plan, matrix, and ledger unchanged (P-23)
- Target Issue `#<n>` in neither `ISSUES.md` nor `done/000-issues-archive.md` -> exit 1, stderr `Target issue #<n> is in neither`; nothing moves (P-32)
- plans-worktree commit refused by a hook -> exit non-zero via `plans_commit` (loud failure, no `|| true`)
- the archive commit fails (a hook, a lock, a signing timeout) -> exit 1; the plan, the ledgers and the matrix are restored and unstaged, so `aapp done <id>` archives again (#121)
- group plan (P-64): a member still in `current/`, a section of `## Architecture & Codemap` whose file section changed since its base line (or has none), or a parent that does not merge cleanly into the feature branch -> exit 1, stderr names the member, section or branch; the parent, the feature branch and the plans are unchanged

## Effects (happy path)
- group plan (P-64), before the normal path: the feature branch is checked out in `.workspace/P<n>` (with the kit links, recorded as the group's `Worktree:`); a parent that moved is merged in (`--no-verify`: its commits passed the hooks where they were made); the `ARCHITECTURE.md` sections are applied by heading (replaced, added, or unchanged on a retry) and committed with the group's umbrella changelog entry via `aapp commit`. Then `pre-done` runs with that worktree, the group is archived, P-55 fast-forwards the parent and removes the worktree and the feature branch, and the `.agents/CODEMAP.md` sections land in one `.agents` commit. A group always integrates (`ff`), whatever `aapp.integrate` says
- the `pre-done` gating hook executes before any mutation (payload carries plan ID, plan file, commits, and `worktree`: the plan worktree's absolute path, empty without one); to require green tests, register the test gate sample (`examples/hooks/test-gate.sh.sample`, P-60)
- the plan moves from `.plans/current/` to `.plans/done/`
- its Status line reads `✅ Done`, and `## 📦 6. Change Log` gains a dated archival line
- `000-archive-ledger.md` gains one row under its header: date, Plan ID, a link to the archived file, the plan header's Target Issue, the verification commit, and a non-empty Impact Summary
    the Impact Summary is the plan title; an untouched template placeholder in the header reads `None` (D2, #78)
- `.plans/state_matrix.md` is re-derived from the remaining plans: this plan's row leaves, and no other row is touched (#88)
- the active buffer is cleared when it names this plan, and so is the buffer of the worktree that holds it, wherever `done` runs (P-54)
- a plan with its own worktree (P-54): the `* **Worktree:**` line moves to `done/` with the plan. With `aapp.integrate = manual` (seeded) or `no-integrate`, the worktree and its branch are kept, and stdout prints `aapp done <id> integrate`, `git worktree remove <path>` (warning that it also deletes ignored files there) and `git branch -D <branch>` for after a squash merge
- the squash on the plan branch (P-84), after every check and `pre-done`, before the archive, for a plan with a worktree that is not a group:
    - which plans: every plan where the strategy is `squash`; and a plan made for an issue whatever `aapp.integrate` says (`ff`, `hook`, `manual` and `no-integrate` included). A plan is made for an issue when both sides agree: its `Target Issue` names `#<n>`, and `#<n>`'s ledger row is `Planned` and links this plan. One side alone is a plan like any other
    - how: the plan's commits become one commit on the plan branch (the plan's tree, on the point where it left its target), with subject `feat: <title> (<id>)`, the plan's changelog line, and trailers `Plan-ID:`, `Plan-Parent: <target>`, `Base-Branch: <development branch>`; signed when `commit.gpgsign` is set. The plan's commits passed the hooks on their branch, so this commit does not re-run them
    - attribution: the `AI-Agent`, `AI-Vendor` and `AI-Model` trailers of the plan's last commit, not the identity of whoever runs `done`; none when that commit has none. Git notes follow too: the last commit's `refs/notes/ai` note, and the `refs/notes/commits` notes of every replaced commit, in order
    - what is recorded: that one commit, in the plan's `* **Commits:**` (it replaces the list), the plan's line in the archive ledger, the archived row of the issue the plan closes, and the `commit` of `issue.close`; `commit_hash` of `post-done` is that commit (`pre-done` runs before the squash and gets the plan's last commit)
    - the commit cannot be made -> exit 1; the plan branch is at its former tip and nothing is archived. A failed archive commit puts the branch back too
    - a plan blocked on the closed issue is unblocked once the fast-forward is done, by the rule of P-78
    - under `manual`, `no-integrate` and `hook` the one commit stays on the plan branch, for the person or the handler to integrate
- integration (P-55; `aapp.integrate` = `squash`/`ff`/`hook`, or `integrate`), after the archive commit, for a plan with a worktree only:
    - `squash`: the plan was squashed on its branch before the archive (see "the squash on the plan branch"); the main checkout switches to the target (and back afterwards) and `git merge --ff-only <plan-branch>` moves it to the recorded commit
    - `ff`: `git merge --ff-only <plan-branch>` into the target; every commit and SHA survives
    - `hook`: the `on-integrate` handler (gate) gets `plan_id`, `plan_file`, `plan_branch`, `target_branch`, `worktree`; built-in cleanup is skipped (the handler owns the branch)
    - a plan already contained in the target (a retry) is not merged again
    - cleanup (unless `no-cleanup` or `aapp.integrateCleanup = false`): `git worktree remove`, then the plan branch is deleted. Sensitive ignored files in the worktree (`.env*`, `*.pem`, `*.key`, `*secret*`) refuse the cleanup with a warning listing them (exit 0: the integration stands); `aapp.quarantineIgnored = true` copies them to `$(git rev-parse --git-common-dir)/aapp_quarantine/<id>/` first, and `force-cleanup` removes them
- a Target Issue `#<n>` still active is closed as by `aapp issue close`: its row moves to the top of `done/000-issues-archive.md` with summary `[<id>](<file>) - <title>`, and it leaves `issues_road_map.md`; an already-archived one is left alone (P-32)
- other open issues whose *Target Plan / Fix* cell (or road-map line) links `current/<file>` now link `done/<file>`; observation cells and the archive are untouched (P-50)
- one commit in the plans worktree, `plan(done): archive <id> to done/ and update state matrix`, holds the move, the ledger, the matrix, any issue close and any repaired links
- the `post-done` observer lifecycle event is dispatched after commit (P-23)
- stdout names the archived file, the verification commit and the ledger

## Exit
- 0 only when every effect above landed

## Tests
Run: `aapp test verb done`

- `tests/verbs/done.sh::test_archives_and_commits` -> move, `✅ Done`, buffer cleared, one commit
- `tests/verbs/done.sh::test_ledger_row_populated` -> the row carries the header's Target Issue and a non-empty Impact Summary (D2)
- `tests/verbs/done.sh::test_refuses_unknown_plan` -> an unresolvable `id`: exit 1, nothing moves
- `tests/verbs/done.sh::test_refuses_plan_not_in_development` -> a `🟣 Under Review` plan: exit 1, nothing moves (#89)
- `tests/verbs/done.sh::test_matrix_row_removed_exactly` -> archiving `P-3` leaves `P-30`'s matrix row in place (#88)
- `tests/verbs/done.sh::test_ledger_uses_recorded_commit` -> an unrelated later commit is not recorded; the ledger takes the last recorded SHA
- `tests/verbs/done.sh::test_refuses_empty_commit_list` -> no recorded commits: exit 1, candidates and the repair command printed, nothing moves
- `tests/verbs/done.sh::test_refuses_unreachable_commit` -> a recorded SHA amended away: exit 1 naming it, although the object still exists
- `tests/verbs/done.sh::test_accepts_commit_on_deleted_branch` -> recorded branch deleted, SHA contained by another branch: accepted
- `tests/verbs/done.sh::test_detached_commit_needs_a_branch` -> a `(detached)` SHA no branch contains: exit 1; once a branch contains it: accepted
- `tests/verbs/done.sh::test_commit_takes_only_its_paths` -> the archive commit contains only the move, ledger and matrix
- `tests/verbs/done.sh::test_pre_done_veto_blocks_archive` -> a `pre-done` handler exiting non-zero: `done` exits 1, nothing moves; payload carries recorded commits
- `tests/verbs/done.sh::test_done_repairs_issue_links` -> another open issue linking the plan points at `done/` after `aapp done`, in the archive commit (P-50)
- `tests/verbs/done.sh::test_failed_archive_commit_restores_and_retry_archives` -> a failing archive commit leaves plan, ledgers, matrix and the plans index as before; a retry archives (#121)
- `tests/verbs/done.worktree.sh::test_done_refuses_dirty_plan_worktree` -> uncommitted changes in the plan's worktree: exit 1, nothing moves (P-54)
- `tests/verbs/done.worktree.sh::test_done_from_primary_clears_holding_buffer_and_advises` -> run from the primary: the worktree's buffer is cleared, the worktree kept, removal and branch-deletion advice printed (P-54)
- `tests/verbs/done.worktree.sh::test_done_from_plan_worktree_archives` -> `done` run inside the plan worktree archives (P-54)
- `tests/verbs/done.worktree.sh::test_done_finds_test_files_in_plan_worktree` -> a TDD plan with a worktree, `done` from the primary: its required test files are found in the worktree (#119)
- `tests/verbs/done.worktree.sh::test_pre_done_payload_names_plan_worktree` -> the `pre-done` payload's `worktree` is the plan worktree; the test gate runs its command there (P-60)
- `tests/verbs/done.worktree.sh::test_pre_done_payload_worktree_empty_in_single_checkout` -> no worktree: `worktree` is empty; the test gate runs in the repository root (P-60)
- `tests/verbs/done.squash.sh::test_recorded_commit_is_on_parent` -> squash setup: the plan's ledger line and its `Commits:` name the commit at the tip of the parent (P-84)
- `tests/verbs/done.squash.sh::test_one_commit_fast_forwarded` -> the parent gains exactly one commit, with the squash message; the plan branch and worktree are gone (P-84)
- `tests/verbs/done.squash.sh::test_issue_row_names_parent_commit` -> the archived row of the issue the plan closes names a commit on the parent (P-84)
- `tests/verbs/done.squash.sh::test_provider_gets_parent_commit` -> `issue.close` carries that same commit (P-84)
- `tests/verbs/done.squash.sh::test_waiting_plan_is_unblocked` -> a plan blocked on the closed issue is unblocked by the `done` (P-84)
- `tests/verbs/done.squash.sh::test_attribution_is_the_last_commit` -> the squashed commit carries the trailers of the plan's last commit, not the runner's; none when that commit has none (P-84)
- `tests/verbs/done.squash.sh::test_notes_follow_the_squash` -> `notes` attribution: the squashed commit has the last commit's `refs/notes/ai` note and every replaced commit's `refs/notes/commits` note (#149)
- `tests/verbs/done.squash.sh::test_failed_squash_restores_branch` -> a commit that cannot be made: exit 1, the plan branch at its former tip, nothing archived (P-84)
- `tests/verbs/done.squash.sh::test_ff_mode_keeps_every_commit` -> `ff`: a plan that closes no issue lands with every commit and SHA (P-84)
- `tests/verbs/done.squash.sh::test_issue_plan_squashed_in_ff_mode` -> `ff`: a plan made for an issue lands as one commit, which the issue's archived row names (P-84)
- `tests/verbs/done.squash.sh::test_issue_plan_needs_both_sides` -> a `Target Issue` the ledger does not link to the plan: not squashed in `ff` (P-84)
- `tests/verbs/done.squash.sh::test_issue_plan_squashed_under_manual` -> `manual`: a plan made for an issue is archived with one commit on its kept branch, which the records name (P-84)
- `tests/verbs/done.squash.sh::test_later_integration_corrects_records` -> `done <id> integrate squash` on an archived plan squashes, fast-forwards and corrects the plan's ledger line, its `Commits:` and the issue's archived row in one commit on the plans branch (P-84)
- `tests/verbs/done.squash.sh::test_issue_plan_gets_its_own_branch` -> `aapp.planWorktrees off`: `freeze-start` of a plan made for an issue creates its branch and worktree and names the path; another plan gets none (P-84)
- `tests/integrate_test.sh::test_manual_default_archives_without_integrating` -> seeded `manual`: archive only, the `integrate` advice printed (P-55 Q1)
- `tests/integrate_test.sh::test_squash_integrates_with_trailers_and_cleans_up` -> squash into the parent with lineage trailers; worktree and branch removed; main checkout back on its branch (P-55)
- `tests/integrate_test.sh::test_integrates_into_module_parent_not_develop` -> a plan from `module/auth` lands there, not on develop (P-55)
- `tests/integrate_test.sh::test_ff_keeps_microcommits_and_deletes_branch` -> fast-forward keeps the plan's commits and SHAs (P-55)
- `tests/integrate_test.sh::test_preflight_failure_archives_nothing` -> a plan branch behind its target: refused before the archive, nothing committed (P-55)
- `tests/integrate_test.sh::test_open_mini_plan_refuses_with_wait_zero` -> an open mini plan with `aapp.issueFixWait 0`: refused at once (P-55)
- `tests/integrate_test.sh::test_hotfix_cap_vetoes_without_override` -> three emergency hotfixes refuse integration until `override-hotfix-cap` (P-55)
- `tests/integrate_test.sh::test_ignored_env_refuses_cleanup_keeps_integration` -> a `.env` refuses the cleanup, the integration stands (P-55 Q2)
- `tests/integrate_test.sh::test_retry_on_archived_plan_quarantines_then_cleans` -> `done <id> integrate` on the archived plan quarantines the `.env` and cleans up, without merging again (P-55)
- `tests/integrate_test.sh::test_no_integrate_token_archives_only` -> `no-integrate` archives only (P-55)
- `tests/integrate_test.sh::test_plan_without_worktree_never_integrated` -> a plan without a worktree is archived as before (P-55)
- `tests/integrate_test.sh::test_hook_without_handler_refuses_before_archive` -> `hook` with no handler: refused, nothing archived (P-55)
- `tests/integrate_test.sh::test_hook_delegate_replaces_builtin_and_retries` -> the handler gets the branches, built-in merge and cleanup skipped; a refusal leaves the plan archived and `integrate` retries (P-55)
- `tests/integrate_test.sh::test_member_integrates_into_feature_branch` -> a member's `done` lands on the group's feature branch, not the parent (P-64)
- `tests/integrate_test.sh::test_group_done_refuses_open_member` -> an open member: exit 1, parent and feature branch unchanged (P-64)
- `tests/integrate_test.sh::test_group_done_gates_and_merges_into_parent` -> the gate sees the feature branch's worktree; the parent (a module branch) gets every member; member SHAs stay reachable (P-64)
- `tests/integrate_test.sh::test_group_done_merges_moved_parent_before_gate` -> a parent that moved is merged in before the gate (P-64)
- `tests/integrate_test.sh::test_group_done_commits_architecture_before_gate_codemap_after_merge` -> ARCHITECTURE sections at the gate, CODEMAP sections only after the merge, committed (P-64)
- `tests/integrate_test.sh::test_group_done_writes_umbrella_changelog` -> the group's entry next to its members' (P-64)
- `tests/integrate_test.sh::test_group_done_conflict_refuses_unchanged` -> a conflicting parent: exit 1, nothing changed (P-64)
