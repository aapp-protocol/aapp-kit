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
    ⚠️ Divergence: the status is not checked; a `🟣 Under Review` plan is archived as done.
    ⚠️ Divergence: the verification commit is whatever `HEAD` is at invocation; a later unrelated commit is recorded instead of the implementation.

## Failure modes
- no `id` -> exit 1, stderr `You must specify a target plan for 'done'.`
- `id` resolves to no plan -> exit 1, stderr `Plan '<id>' not found`; nothing moves
- plans-worktree commit refused by a hook -> exit non-zero
    ⚠️ Divergence (#81): the commit runs under `|| true`; the verb exits 0 with the archive staged.

## Effects (happy path)
- the plan moves from `.plans/current/` to `.plans/done/`
- its Status line reads `✅ Done`, and `## 📦 6. Change Log` gains a dated archival line
- `000-archive-ledger.md` gains one row under its header: date, Plan ID, a link to the archived file, the plan header's Target Issue, the verification commit, and a non-empty Impact Summary
    ⚠️ Divergence (D2, #78): Target Issue is hardcoded `None`, and the summary greps a `**What:**` field the template never emits, so it is always empty.
- the plan's row leaves `.plans/state_matrix.md`
    ⚠️ Divergence: rows are removed with `sed "/<id>/d"`, a substring match: archiving `P-3` also deletes the rows for `P-30`–`P-39`.
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
