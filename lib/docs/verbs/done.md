# done <id>

## Ingress
- `id` (positional, required): the implemented plan to archive
    accepted forms: `P-<N>`, bare `<N>`, the filename stem, or a slug prefix
    constraints: must resolve to exactly one plan in `.plans/current/`
- reads: the plan file (Plan ID, `Target Issue / Milestone` header), `.plans/done/000-archive-ledger.md`, `.plans/state_matrix.md`, the active buffer
- reads: the plan file (Plan ID, `Target Issue / Milestone` header, `* **Commits:**` header line), `.plans/done/000-archive-ledger.md`, `.plans/state_matrix.md`, the active buffer
- reads config: the lifecycle hook registry for `pre-done` and `on-done`

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
- `pre-done` lifecycle hook exits non-zero -> exit 1, vetoes archive; plan and ledger unchanged
- Target Issue `#<n>` in neither `ISSUES.md` nor `done/000-issues-archive.md` -> exit 1, stderr `Target issue #<n> is in neither`; nothing moves (P-32)
- plans-worktree commit refused by a hook -> exit non-zero via `plans_commit` (loud failure, no `|| true`)

## Effects (happy path)
- the plan moves from `.plans/current/` to `.plans/done/`
- its Status line reads `✅ Done`, and `## 📦 6. Change Log` gains a dated archival line
- `000-archive-ledger.md` gains one row under its header: date, Plan ID, a link to the archived file, the plan header's Target Issue, the verification commit, and a non-empty Impact Summary
    the Impact Summary is the plan title; an untouched template placeholder in the header reads `None` (D2, #78)
- `.plans/state_matrix.md` is re-derived from the remaining plans: this plan's row leaves, and no other row is touched (#88)
- the active buffer is cleared when it names this plan, and so is the buffer of the worktree that holds it, wherever `done` runs (P-54)
- a plan with its own worktree (P-54): the `* **Worktree:**` line moves to `done/` with the plan; the worktree and its branch are kept (integration is the developer's step), and stdout prints `git worktree remove <path>` (warning that it also deletes ignored files there) and `git branch -D <branch>` for after a squash merge
- a Target Issue `#<n>` still active is closed as by `aapp issue close`: its row moves to the top of `done/000-issues-archive.md` with summary `[<id>](<file>) - <title>`, and it leaves `issues_road_map.md`; an already-archived one is left alone (P-32)
- other open issues whose *Target Plan / Fix* cell (or road-map line) links `current/<file>` now link `done/<file>`; observation cells and the archive are untouched (P-50)
- one commit in the plans worktree, `plan(done): archive <id> to done/ and update state matrix`, holds the move, the ledger, the matrix, any issue close and any repaired links
- the `on-done` lifecycle event is dispatched (a failing handler does not undo the archive)
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
- `tests/verbs/done.sh::test_done_refuses_dirty_plan_worktree` -> uncommitted changes in the plan's worktree: exit 1, nothing moves (P-54)
- `tests/verbs/done.sh::test_done_from_primary_clears_holding_buffer_and_advises` -> run from the primary: the worktree's buffer is cleared, the worktree kept, removal and branch-deletion advice printed (P-54)
- `tests/verbs/done.sh::test_done_from_plan_worktree_archives` -> `done` run inside the plan worktree archives (P-54)
