# tdd <id_or_slug>

## Ingress
- `id_or_slug` (positional, required): existing plan identifier (`P-1`, `1`), slug, or full filename to upgrade, OR a new slug/title to scaffold directly as a TDD blueprint
- reads: `.plans/current/`
- reads config: none
- reads env: none

## Preconditions
- Inside a Git repository whose `.plans/` worktree exists
- If targeting an existing plan: plan exists in `.plans/current/` and is in the incubator (`🟣 Under Review` or `📝 Refining`)
- If targeting a new slug: `.plans/current/` exists and templates are available

## Failure modes
- `.plans/current` missing -> exit 1, stderr names missing directory
- target plan ID not found (e.g. `P-999`) -> exit 1, stderr names resolution failure
- existing plan is not in incubator (`🔷 Frozen`, `⚡ In Development`, `🚫 BLOCKED`) -> exit 1, stderr `[TDD Refusal] Plan is not in the incubator`
- existing plan already has `### 🧪 Required Tests` or `### 🧪 Required Test Files` -> exit 1, stderr `[TDD Refusal] Plan already has TDD failure test sections declared.`
- non-Git repository -> exit 1, stderr names repository assertion failure

## Effects (happy path)
- For a new slug: auto-drafts the blueprint from template, commits `plan(draft): scaffold P-<num> <slug>`, injects TDD sections, and commits `plan(refine): declare failure tests for P-<num>`
- For an existing plan: injects `### 🧪 Required Tests (Failure & Boundary Assertions)` into §3 before phases and `### 🧪 Required Test Files` into §4, and commits `plan(refine): declare failure tests for <plan_id>`
- stdout reports successful declaration and next steps for enumeration

## Exit
- 0 on successful declaration and commit; 1 on any refusal or error

## Tests
Run: `aapp test verb tdd`

- `tests/verbs/tdd.sh::test_auto_scaffolds_new_slug` -> new slug automatically drafts and injects TDD sections
- `tests/verbs/tdd.sh::test_refuses_unknown_plan` -> unknown plan ID exits 1
- `tests/verbs/tdd.sh::test_refuses_outside_repo` -> running outside a Git repository exits non-zero
- `tests/verbs/tdd.sh::test_injects_tdd_sections` -> injects §3 and §4 sections and commits to .plans
- `tests/verbs/tdd.sh::test_refuses_already_injected` -> second invocation on same plan is refused with no file changes
- `tests/verbs/tdd.sh::test_injection_commit_accepted_while_refining` -> commit is accepted and working tree clean
- `tests/verbs/tdd.sh::test_freeze_refuses_empty_tdd_sections` -> freeze refuses when sections are empty
- `tests/verbs/tdd.sh::test_freeze_refuses_mismatch` -> freeze refuses correspondence mismatch
- `tests/verbs/tdd.sh::test_freeze_tolerates_unwritten_matching_tests` -> freeze tolerates unwritten declared test files on disk
- `tests/verbs/tdd.sh::test_done_refuses_unticked_tests` -> done refuses when unticked test assertions remain
- `tests/verbs/tdd.sh::test_done_refuses_missing_test_file_on_disk` -> done refuses when declared test file is missing from disk
- `tests/verbs/tdd.sh::test_done_refuses_untracked_test_file` -> done refuses when declared test file is not tracked in Git
- `tests/verbs/tdd.sh::test_done_succeeds_and_records_ledger_badge` -> done succeeds when all tests verified and records tdd (N/N)
