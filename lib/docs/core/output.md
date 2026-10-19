# output

## Tests
Run: `aapp test output`

- `tests/output_test.sh::test_wrap_hanging_indent` -> `out_wrap` keeps every line within `aapp.statusOutputWidth`, indents the first line and hangs the rest, losing no word
- `tests/output_test.sh::test_wrap_counts_characters` -> `out_wrap` measures multibyte text in characters, not bytes
- `tests/output_test.sh::test_wrap_long_word_uncut` -> a word longer than the width stands alone on its line, uncut
- `tests/output_test.sh::test_cut_at_word` -> `out_cut` cuts long text at a word boundary within the limit and marks it with `…`; short text is unchanged
- `tests/output_test.sh::test_width_setting` -> `out_width` reads `aapp.statusOutputWidth` (default 85) and refuses a non-number or a width below 40, naming the setting
