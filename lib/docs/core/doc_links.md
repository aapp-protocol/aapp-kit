# doc_links

## Tests
Run: `aapp test doc_links`

- `tests/doc_links_test.sh::test_modular_docs_have_frontmatter` -> every page under `docs/` opens with front matter holding a `title:`
- `tests/doc_links_test.sh::test_modular_docs_have_navigation` -> every page under `docs/` has a navigation block
- `tests/doc_links_test.sh::test_docs_hold_no_machine_paths` -> no page, nor `README.md`, `MANUAL.md` or `COOKBOOK.md`, holds a `file:///` URI or a home path
- `tests/doc_links_test.sh::test_relative_links_resolve` -> every relative link outside code resolves to a file or directory
