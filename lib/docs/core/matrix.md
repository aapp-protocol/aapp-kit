# matrix

## Tests
Run: `aapp test matrix`

- `tests/matrix_test.sh::test_derives_sections_in_rank_order` -> the matrix holds the Roadmap, the four registry sections in rank order and the ledger; each row carries its status glyph under its status's section; the file ends with a newline
- `tests/matrix_test.sh::test_orphan_rows_removed` -> a row goes once its plan leaves `current/`; its siblings stay
- `tests/matrix_test.sh::test_annotation_preserved` -> a hand annotation, em-dashes included, survives a rewrite and follows its plan to another section
- `tests/matrix_test.sh::test_roadmap_preserved` -> the hand-written Roadmap is kept verbatim, with no extra separators
- `tests/matrix_test.sh::test_unrecognized_statuses_bucketed` -> plans with a retired or unknown status are listed under Unrecognized Status, and the matrix still checks in sync
- `tests/matrix_test.sh::test_paused_sync_advisory` -> while paused the matrix is still written, with an advisory naming `aapp resume`; a no-op stays silent, and the advisory goes after resuming
- `tests/matrix_test.sh::test_empty_current_renders` -> an empty `current/` renders a well-formed matrix that checks in sync
