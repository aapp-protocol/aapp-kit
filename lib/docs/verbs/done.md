# done <id>

## Ingress
- `id` (positional, required): the implemented plan to archive
    accepted forms: `P-<N>`, bare `<N>`, the filename stem, or a slug prefix
    constraints: must resolve to exactly one plan in `.plans/current/`
- reads: the plan file (Plan ID, `Target Issue / Milestone` header), `.plans/done/000-archive-ledger.md`, `.plans/state_matrix.md`, the active buffer
- reads: the code repository's `HEAD`, recorded as the verification commit
- reads config: the lifecycle hook registry for `on-done`

## Preconditions
- Inside a Git repository whose `.plans/current/` and `.plans/done/` exist
- The plan is `⚡ In Development`, and its implementation commit is the code repository's `HEAD`
    ⚠️ Divergence: the verification commit is whatever `HEAD` is at invocation; a later unrelated commit is recorded instead of the implementation.

## Failure modes
- no `id` -> exit 1, stderr `You must specify a target plan for 'done'.`
- `id` resolves to no plan -> exit 1, stderr `Plan '<id>' not found`; nothing moves
- the plan is not `⚡ In Development` -> exit 1, stderr `[Done Refusal] Plan is not ⚡ In Development`; nothing moves (#89)
- plans-worktree commit refused by a hook -> exit non-zero
    ⚠️ Divergence (#81): the commit runs under `|| true`; the verb exits 0 with the archive staged.

## Effects (happy path)
- the plan moves from `.plans/current/` to `.plans/done/`
- its Status line reads `✅ Done`, and `## 📦 6. Change Log` gains a dated archival line
- `000-archive-ledger.md` gains one row under its header: date, Plan ID, a link to the archived file, the plan header's Target Issue, the verification commit, and a non-empty Impact Summary
    the Impact Summary is the plan title; an untouched template placeholder in the header reads `None` (D2, #78)
- `.plans/state_matrix.md` is re-derived from the remaining plans: this plan's row leaves, and no other row is touched (#88)
- the active buffer is cleared when it names this plan
- one commit in the plans worktree, `plan(done): archive <id> to done/ and update state matrix`, holds the move, the ledger and the matrix
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
