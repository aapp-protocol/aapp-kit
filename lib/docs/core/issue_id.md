# issue_id

## Tests
Run: `t/test-run issue_id`

- `t/core/issue_id.t::test_normalize_numeric_forms` -> `46`, `#46`, `` `#046` `` and `ISSUE-79` normalize to `#<n>`; the fix file name and its id map both ways
- `t/core/issue_id.t::test_refs_from_plan_lines` -> `issue_id_refs` lists every numeric and tracker id a plan line names, in order
- `t/core/issue_id.t::test_refs_ignore_headings_and_hex` -> headings, hex colours and ids glued to a word are not references; a commit subject's `(#KEY-1)` is
- `t/core/issue_id.t::test_key_id_valid` -> tracker keys (`PROJ-101`, `#proj-101`, `A1-7`) normalize upper-cased and are not numeric; their fix file name maps both ways
- `t/core/issue_id.t::test_malformed_id_refused` -> malformed ids are neither valid nor normalized, and the refusal shows both accepted forms
- `t/core/issue_id.t::test_counter_ignores_key_ids` -> the issue counter seeds from numeric ids in both ledgers only; `ledger_ids` lists tracker keys too
