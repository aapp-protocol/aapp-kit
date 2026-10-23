# aapp_lib

## Tests
Run: `t/test-run aapp_lib`

- `t/core/aapp_lib.t::test_blockquote_not_parsed` -> a path in a `>` line under Target Files is not a target
- `t/core/aapp_lib.t::test_foreign_subsection_ends_region` -> any other heading, at any depth, ends the Target Files region
- `t/core/aapp_lib.t::test_foreign_heading_after_oob` -> a heading after Out of Bounds ends both regions
- `t/core/aapp_lib.t::test_required_test_files_is_parsed` -> paths under Required Test Files are targets, ticked or not
- `t/core/aapp_lib.t::test_required_tests_checklist_not_parsed` -> the Required Tests checklist and a near-miss heading grant nothing
- `t/core/aapp_lib.t::test_new_file_marker_skipped` -> a backticked marker (`NEW FILE`, `MODIFY`, `DELETE`, `ADD`, `REPLACE`) is skipped for the path after it
- `t/core/aapp_lib.t::test_fenced_example_not_parsed` -> headings and paths inside a fenced block are not parsed
- `t/core/aapp_lib.t::test_heading_outside_section4_not_parsed` -> target headings count only inside `## 4.`
- `t/core/aapp_lib.t::test_oob_paths_parsed` -> `parse_plan_oob_paths` lists Out of Bounds paths and globs, never quoted prose or later sections
- `t/core/aapp_lib.t::test_parse_required_test_files` -> `parse_plan_required_test_files` lists the Required Test Files only
- `t/core/aapp_lib.t::test_parse_required_tests` -> `parse_plan_required_tests` lists the files the §3 Required Tests name, backticked or not
- `t/core/aapp_lib.t::test_validate_tdd_correspondence_matches` -> §3 tests and §4 test files that match pass, and the plan declares test files
- `t/core/aapp_lib.t::test_validate_tdd_correspondence_opted_out` -> a plan with neither section passes and declares no test files
- `t/core/aapp_lib.t::test_extract_plan_section` -> `extract_plan_section 4` prints `## 4.` up to the next `## ` heading; a numbered heading inside a fenced block neither starts nor ends a section
- `t/core/aapp_lib.t::test_aapp_os_branches` -> `aapp_os` maps each `uname -s` (and WSL's `/proc/version`) to linux, wsl, darwin, windows, bsd or unknown
- `t/core/aapp_lib.t::test_parse_plan_commits` -> `parse_plan_commits` lists the backticked hashes of the Commits line, a trailing branch ignored; `none` and unbackticked entries give nothing
- `t/core/aapp_lib.t::test_pickup_entry_split` -> `pickup_entry_split` splits a pickup line into title and text at the first `: ` outside backticks, with or without the checkbox
- `t/core/aapp_lib.t::test_subject_max_len` -> `aapp_subject_max_len` reads `aapp.subjectMaxLen`, 72 when unset, and refuses a value that is not a number, naming the setting
