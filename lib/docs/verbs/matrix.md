# matrix [--check]

## Ingress
- `--check` (flag, optional): audit only; never write
    ⚠️ Divergence: a double-dash flag, against the CLI's zero-double-dash convention (`aapp test` uses bare tokens).
    constraints: any other argument is refused
- reads: `.plans/current/*.md` (Plan ID, title, Status), `.plans/state_matrix.md` (its human-owned Roadmap and row annotations), `.plans/PAUSED.md`
- reads config: `aapp.planState.*` (custom statuses)

## Preconditions
- Inside a Git repository whose `.plans/current/` exists

## Failure modes
- an unknown argument -> exit 1, usage names `aapp matrix [--check]`
    ⚠️ Divergence: printed to stdout, not stderr.
- `.plans/current/` missing -> exit 1, `[Matrix] No .plans/current/ found. Run 'aapp init' first.`
    ⚠️ Divergence: printed to stdout, not stderr.
- `--check` and the matrix has drifted -> exit 1, `⚠️  [Matrix] state_matrix.md has drifted`; the file is unchanged

## Effects (happy path)
- in sync: `✅ [Matrix] state_matrix.md is in sync`, no write
- drifted, no flag: `state_matrix.md` is rewritten from the plans' Status lines, keeping the Roadmap and per-row annotations and deleting orphan rows; stdout `🔄 [Matrix] Re-derived`
- a plan whose Status matches no registry entry is listed under an Unrecognized heading and named on stdout
- while the project is paused, the rewrite still lands on disk and stdout says it cannot be committed until `aapp resume`
- never commits
- a second run after a rewrite reports in sync (idempotent)

## Exit
- 0 when the matrix is in sync or was rewritten; 1 on drift under `--check`

## Tests
Run: `aapp test verb matrix`

- `tests/verbs/matrix.sh::test_check_reports_drift_without_writing` -> `--check` on a drifted matrix: exit 1, file unchanged
- `tests/verbs/matrix.sh::test_sync_is_idempotent` -> a rewrite, then a second run reports in sync
- `tests/verbs/matrix.sh::test_refuses_unknown_option` -> an unknown argument: exit 1

Broader coverage (Roadmap preservation, orphans, custom statuses): `tests/matrix_test.sh`.
