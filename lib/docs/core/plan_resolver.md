# plan_resolver

## Tests
Run: `aapp test plan_resolver`

- `tests/plan_resolver_test.sh::test_resolve_exact_path_and_filename` -> `resolve_plan_path` takes a relative path or a bare file name in `current/` as given
- `tests/plan_resolver_test.sh::test_resolve_numeric_id_forms` -> `P-13`, `p-13`, `P13`, `13` and zero-padded forms resolve to plan 13
- `tests/plan_resolver_test.sh::test_resolve_slug_substring` -> a slug substring resolves to its plan
- `tests/plan_resolver_test.sh::test_resolve_refuses_issue_reference` -> `#13` is refused as an issue reference, suggesting `P-13`
- `tests/plan_resolver_test.sh::test_resolve_refuses_empty_query_on_transitions` -> an empty query is refused for `freeze` and `done`
- `tests/plan_resolver_test.sh::test_get_plan_id` -> `get_plan_id` reads a plan's id
- `tests/plan_resolver_test.sh::test_mini_plans_are_not_plans` -> a `fix-<num>.md` mini plan is neither resolved as a plan nor checked by pair 4
- `tests/plan_resolver_test.sh::test_plan_counter_peek_and_allocate` -> `get_next_plan_id` peeks without changing `aapp.planId` (P-1 when unset); `allocate_plan_id` hands it out and advances it; a corrupt counter is refused and left as it is
- `tests/plan_resolver_test.sh::test_normalize_plan_id` -> `normalize_plan_id` accepts `P-42` and `42` and refuses anything else
- `tests/plan_resolver_test.sh::test_plan_id_provider` -> an `aapp-planid` provider receives the `plan.allocate` envelope and its id (string or integer) is used, the counter ratcheting past it; plain text, a malformed id or a failing provider is fatal, with its error shown and no local fallback
- `tests/plan_resolver_test.sh::test_issue_counter_peek_and_allocate` -> the issue counter peeks and allocates `#<n>` apart from the plan counter
- `tests/plan_resolver_test.sh::test_seed_issue_id` -> `seed_issue_id` returns 2 without ledgers, ignores template example rows, and seeds past the highest numeric id in both ledgers
- `tests/plan_resolver_test.sh::test_pair4_plan_id_integrity` -> pair 4 passes unique plan ids and refuses a duplicate
- `tests/plan_resolver_test.sh::test_pair5_self_protection` -> pair 5 refuses a plan targeting a self-protected path
- `tests/plan_resolver_test.sh::test_pair6_recorded_sha_integrity` -> pair 6 refuses a commit in the archive ledger or the changelog that the repository does not hold
- `tests/plan_resolver_test.sh::test_pair7_shared_docs_exempt` -> pair 7 lets plans share shared docs with a notice and refuses a shared code file; `aapp_is_shared_doc` tells them apart
- `tests/plan_resolver_test.sh::test_pair8_issue_id_integrity` -> pair 8 refuses an issue id used twice in the active ledger or in the archive, naming it
- `tests/plan_resolver_test.sh::test_planning_health_overall` -> `check_planning_health` passes consistent ledgers and refuses an issue id found in both the active ledger and the archive
- `tests/plan_resolver_test.sh::test_release_bundles_resolved_and_seeded` -> a plan in a release bundle resolves by id and slug, and its archived issues count for the issue seed
