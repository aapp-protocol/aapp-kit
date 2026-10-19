# group_docs

## Tests
Run: `aapp test group_docs`

- `tests/group_docs_test.sh::test_base_lines_recorded_for_new_sections` -> `group_docs_stamp` records the target section's checksum above a replacing fence and `new` above an added one; stamping again changes nothing
- `tests/group_docs_test.sh::test_apply_replaces_adds_and_reports` -> `group_docs_apply` replaces a section by heading, whole, adds a new heading at the end and reports `replaced:` / `added:`; applying again reports `unchanged:` and leaves the file as it is
- `tests/group_docs_test.sh::test_no_changes_leaves_files_untouched` -> a file marked `No changes.` is left untouched, with nothing reported
- `tests/group_docs_test.sh::test_changed_section_refuses` -> a section changed in the file since its base line, or an added heading someone else wrote meanwhile, is refused and the file left as it was
