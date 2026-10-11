# test [modifier…] [verb [name] | suite…]

## Ingress
- modifiers (bare tokens, any order, combinable): `list` (show suites, run nothing), `strict` (export `AAPP_TEST_SANDBOX_STRICT=1`), `quiet` (suite-level output only), `bail` (no suite starts after the first failure; running ones finish), `jobs <n>` (up to `<n>` suites at once, P-67), `help`
- reads: the CPU count (`getconf _NPROCESSORS_ONLN`) for the default job count: rounded down to a multiple of 4 (10 -> 8, 12 -> 12), the CPU count below 4, `1` with a notice when unreadable
- `verb` (token, optional): select contract-derived verb suites in `tests/verbs/`
    `verb <name>`: run `tests/verbs/<name>.sh` and its parts `tests/verbs/<name>.<part>.sh` (P-68)
    `verb` alone: run every `tests/verbs/*.sh`
- `suite…` (positional, optional): flat suites to run, matched against `tests/<name>_test.sh` by exact name, stem or substring
    source when omitted: every flat suite and every verb suite
- reads: `tests/*_test.sh`, `tests/verbs/*.sh`

## Preconditions
- Inside a Git repository that is the kit itself (runs the kit's own suites only)
    ⚠️ Divergence: in any repository with a `tests/` directory, its `tests/*_test.sh` run; without one, the verb delegates to `aapp.testCommand`, `npm`, `cargo`, `composer`, `go` or `make`, or runs a protocol audit. Delegation is recorded here, not endorsed (P-34 §5 Q2); removing it belongs to its own plan.

## Failure modes
- a filter matching no suite -> exit 1, `[Test Runner] No test suites matched filter`
- `verb <name>` with no `tests/verbs/<name>.sh` -> exit 1, names the missing suite
- any selected suite failing -> exit 1 after the summary (with `bail`, no suite starts after it)
- `jobs` without a positive number -> exit 1 with usage; nothing runs
- interrupted (INT/TERM) -> running suites are stopped with everything they started, the run's temporary files removed, exit non-zero (P-67)

## Effects (happy path)
- each selected suite runs as `bash <suite>` in its own subshell from the repository root, up to the job count at once, each in its own process group (P-67); the banner names the job count
- a suite's output goes to its own temporary file and is printed whole when it finishes, never interleaved with another's (`quiet`: its row then)
- a summary row per suite reports passed and failed assertions and duration, in selection order whatever the finish order; verb suites are labelled `verb/<name>`
- a verb suite may be split into parts, `tests/verbs/<verb>.<part>.sh`, each scheduled as its own suite and labelled `verb/<verb>.<part>`; parts sort right after their verb (P-68)
- `list` prints both sets — flat suites and verb suites, each part indented under its verb — and runs nothing
- writes nothing outside the suites' own sandboxes

## Exit
- 0 only when every selected suite passed

## Tests
Run: `aapp test verb test`

- `tests/verbs/test.sh::test_list_shows_verb_suites` -> `list` names the flat suites and the verb suites
- `tests/verbs/test.sh::test_verb_token_selects_one_suite` -> `verb <name>` runs exactly that verb suite
- `tests/verbs/test.sh::test_refuses_unmatched_filter` -> an unknown suite or verb: exit 1
- `tests/verbs/test.sh::test_aborted_suite_fails_in_default_mode` -> a suite exiting 1 without a results line: `FAILED (exit 1)` (#115)
- `tests/verbs/test.sh::test_suites_run_concurrently` -> four 2 s suites with `jobs 4` take under 5 s (P-67)
- `tests/verbs/test.sh::test_jobs_one_runs_serially` -> three 1 s suites with `jobs 1` take at least 3 s (P-67)
- `tests/verbs/test.sh::test_parallel_failure_fails_the_run` -> one failing suite among passing ones: exit 1, its `FAILED` row (P-67)
- `tests/verbs/test.sh::test_suite_output_not_interleaved` -> each suite's lines stay together (P-67)
- `tests/verbs/test.sh::test_summary_in_selection_order` -> rows in selection order, not finish order (P-67)
- `tests/verbs/test.sh::test_interrupt_cleans_up` -> TERM: exit non-zero, no temporary files, no suite process left (P-67)
- `tests/verbs/test.sh::test_default_jobs_multiple_of_four` -> 10 CPUs -> 8, 12 -> 12, 2 -> 2, unreadable -> 1 with a notice (P-67)
- `tests/verbs/test.sh::test_jobs_refuses_non_number` -> `jobs 0`, `jobs x`, bare `jobs`: exit 1 (P-67)
- `tests/verbs/test.sh::test_verb_runs_all_its_parts` -> `verb draft` runs `draft.sh` and `draft.extra.sh`, labelled `verb/draft` and `verb/draft.extra` (P-68)
- `tests/verbs/test.sh::test_parts_listed_under_their_verb` -> `list` shows a part indented right under its verb (P-68)
