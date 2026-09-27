# test [modifier…] [verb [name] | suite…]

## Ingress
- modifiers (bare tokens, any order, combinable): `list` (show suites, run nothing), `strict` (export `AAPP_TEST_SANDBOX_STRICT=1`), `quiet` (suite-level output only), `bail` (stop at the first failing suite), `help`
- `verb` (token, optional): select contract-derived verb suites in `tests/verbs/`
    `verb <name>`: run `tests/verbs/<name>.sh` alone
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
- any selected suite failing -> exit 1 after the summary (or at the first failure with `bail`)

## Effects (happy path)
- each selected suite runs as `bash <suite>` in its own subshell from the repository root
- a summary row per suite reports passed and failed assertions and duration; verb suites are labelled `verb/<name>`
- `list` prints both sets — flat suites and verb suites — and runs nothing
- writes nothing outside the suites' own sandboxes

## Exit
- 0 only when every selected suite passed

## Tests
Run: `aapp test verb test`

- `tests/verbs/test.sh::test_list_shows_verb_suites` -> `list` names the flat suites and the verb suites
- `tests/verbs/test.sh::test_verb_token_selects_one_suite` -> `verb <name>` runs exactly that verb suite
- `tests/verbs/test.sh::test_refuses_unmatched_filter` -> an unknown suite or verb: exit 1
