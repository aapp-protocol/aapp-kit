# output_json

## Tests
Run: `aapp test output_json`

- `tests/output_json_test.sh::test_status_json_parses` -> `aapp status json` prints one JSON object for `status`, with no terminal briefing
- `tests/output_json_test.sh::test_issue_list_json_parses` -> `aapp issue list json` (also with a count and `all`) prints one object with `shown`, `total` and `issues`
- `tests/output_json_test.sh::test_fields_match_reference` -> every object's keys, in order, are those of its table in `docs/reference/08-output-json.md`, and every table has an object in the fixture
- `tests/output_json_test.sh::test_absent_values_are_null` -> absent values are `null` (or empty lists), never left out
- `tests/output_json_test.sh::test_text_verbatim` -> a symptom with quotes, backticks, backslashes and `…` comes out verbatim in both documents
- `tests/output_json_test.sh::test_issue_notes_count` -> an issue carries its note count, never a note's text
- `tests/output_json_test.sh::test_repository_remote` -> the remote's URL is printed without its credentials; without a remote it is `null`
- `tests/output_json_test.sh::test_local_path_setting` -> `aapp.jsonLocalPath false` prints `repository.root` as `null` and no local path anywhere
- `tests/output_json_test.sh::test_group_nests_members` -> a group lists its members, amendments member last, and members are not listed again at the top
- `tests/output_json_test.sh::test_pickup_objects` -> a pickup item is `{title, text, files}` with existing files only; a missing one is a notice
- `tests/output_json_test.sh::test_same_items_as_terminal` -> the queue, plans and pickup items are those of the terminal briefing, in its order
- `tests/output_json_test.sh::test_failure_is_error_document` -> a failing run prints the error document, its message also on stderr
- `tests/output_json_test.sh::test_notices_grouped_by_level` -> `notices` holds `warning` then `info`, each item `{section, text}`
- `tests/output_json_test.sh::test_sync_warning_in_notices` -> a failing tracker listing is a warning in `notices`, with nothing on stderr
- `tests/output_json_test.sh::test_error_codes` -> usage errors are `usage`, a bad setting `invalid-setting` naming it, a failure `failed`, and a needed answer `confirm-needed`
