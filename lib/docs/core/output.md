# output

## Tests
Run: `tests/test-run output`

- `tests/AAPP/Core/Output.pm::test_wrap_hanging_indent` -> `out_wrap` keeps every line within `aapp.statusOutputWidth`, indents the first line and hangs the rest, losing no word
- `tests/AAPP/Core/Output.pm::test_wrap_counts_characters` -> `out_wrap` measures multibyte text in characters, not bytes
- `tests/AAPP/Core/Output.pm::test_wrap_long_word_uncut` -> a word longer than the width stands alone on its line, uncut
- `tests/AAPP/Core/Output.pm::test_cut_at_word` -> `out_cut` cuts long text at a word boundary within the limit and marks it with `…`; short text is unchanged
- `tests/AAPP/Core/Output.pm::test_width_setting` -> `out_width` reads `aapp.statusOutputWidth` (default 85) and refuses a non-number or a width below 40, naming the setting
