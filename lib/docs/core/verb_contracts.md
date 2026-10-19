# verb_contracts

## Tests
Run: `aapp test verb_contracts`

- `tests/verb_contracts_test.sh::test_registry_contract_correspondence` -> every daily verb in `lib/verbs.tsv` names one existing contract, and every contract has exactly one registry row
- `tests/verb_contracts_test.sh::test_contracts_follow_the_shape` -> every verb contract has the six headings in order, a `# <verb>` first line and a `Run:` line
- `tests/verb_contracts_test.sh::test_declared_test_files_exist` -> every test file a verb contract names exists
- `tests/verb_contracts_test.sh::test_contract_tests_exist_in_suite_or_part` -> every test a verb contract names is in that verb's suite or one of its parts
- `tests/verb_contracts_test.sh::test_every_verb_test_named_by_contract` -> every test a verb suite reports is named by its verb's contract
- `tests/verb_contracts_test.sh::test_core_contract_per_suite` -> every `tests/<suite>_test.sh` has `lib/docs/core/<suite>.md` and the other way round, each with `# <suite>`, one `## Tests` heading and its `Run:` line
- `tests/verb_contracts_test.sh::test_every_core_test_named_by_contract` -> a core contract names only tests its suite reports, and a core suite reports only `test_<name>` results its contract names
- `tests/verb_contracts_test.sh::test_daily_verbs_in_agent_reference` -> every daily verb has a line in the rules file's CLI Reference and `aapp help <verb>` prints its contract's synopsis
- `tests/verb_contracts_test.sh::test_rules_file_has_no_walkthroughs` -> the rules file holds no verb walkthroughs and keeps the planning invariant
- `tests/verb_contracts_test.sh::test_rules_file_points_to_help` -> the rules file names `/aapp` and `aapp help <verb>`
- `tests/verb_contracts_test.sh::test_every_skill_in_rules_index` -> every kit skill has a row in the rules file's skill index
- `tests/verb_contracts_test.sh::test_help_unknown_verb_refuses` -> `aapp help` with an unknown verb exits non-zero
