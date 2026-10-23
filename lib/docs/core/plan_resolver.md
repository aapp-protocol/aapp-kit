# plan_resolver

## Tests
Run: `t/test-run plan_resolver`

- `t/core/plan_resolver.t::test_resolve_exact_path_and_filename` -> `resolve_plan_path` takes a relative path or a bare file name in `current/` as given
- `t/core/plan_resolver.t::test_resolve_numeric_id_forms` -> `P-13`, `p-13`, `P13`, `13` and zero-padded forms resolve to plan 13
- `t/core/plan_resolver.t::test_resolve_slug_substring` -> a slug substring resolves to its plan
- `t/core/plan_resolver.t::test_resolve_refuses_issue_reference` -> `#13` is refused as an issue reference, suggesting `P-13`
- `t/core/plan_resolver.t::test_resolve_refuses_empty_query_on_transitions` -> an empty query is refused for `freeze` and `done`
- `t/core/plan_resolver.t::test_get_plan_id` -> `get_plan_id` reads a plan's id
- `t/core/plan_resolver.t::test_mini_plans_are_not_plans` -> a `fix-<num>.md` mini plan is neither resolved as a plan nor checked by pair 4
- `t/core/plan_resolver.t::test_plan_counter_peek_and_allocate` -> `get_next_plan_id` peeks without changing `aapp.planId` (P-1 when unset); `allocate_plan_id` hands it out and advances it; a corrupt counter is refused and left as it is
- `t/core/plan_resolver.t::test_normalize_plan_id` -> `normalize_plan_id` accepts `P-42` and `42` and refuses anything else
- `t/core/plan_resolver.t::test_plan_id_provider` -> an `aapp-planid` provider receives the `plan.allocate` envelope and its id (string or integer) is used, the counter ratcheting past it; plain text, a malformed id or a failing provider is fatal, with its error shown and no local fallback
- `t/core/plan_resolver.t::test_issue_counter_peek_and_allocate` -> the issue counter peeks and allocates `#<n>` apart from the plan counter
- `t/core/plan_resolver.t::test_seed_issue_id` -> `seed_issue_id` reports not found without ledgers, ignores template example rows, and seeds past the highest numeric id in both ledgers
- `t/core/plan_resolver.t::test_pair4_plan_id_integrity` -> pair 4 passes unique plan ids and refuses a duplicate
- `t/core/plan_resolver.t::test_pair5_self_protection` -> pair 5 refuses a plan targeting a self-protected path
- `t/core/plan_resolver.t::test_pair6_recorded_sha_integrity` -> pair 6 refuses a commit in the archive ledger or the changelog that the repository does not hold
- `t/core/plan_resolver.t::test_pair7_shared_docs_exempt` -> pair 7 lets plans share shared docs with a notice and refuses a shared code file; `aapp_is_shared_doc` tells them apart
- `t/core/plan_resolver.t::test_pair8_issue_id_integrity` -> pair 8 refuses an issue id used twice in the active ledger or in the archive, naming it
- `t/core/plan_resolver.t::test_planning_health_overall` -> `check_planning_health` passes consistent ledgers and refuses an issue id found in both the active ledger and the archive
- `t/core/plan_resolver.t::test_release_bundles_resolved_and_seeded` -> a plan in a release bundle resolves by id and slug, and its archived issues count for the issue seed
