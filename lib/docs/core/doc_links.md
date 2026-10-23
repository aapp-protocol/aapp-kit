# doc_links

## Tests
Run: `t/test-run doc_links`

- `t/core/doc_links.t::test_modular_docs_have_frontmatter` -> every page under `docs/` opens with front matter holding a `title:`
- `t/core/doc_links.t::test_modular_docs_have_navigation` -> every page under `docs/` has a navigation block
- `t/core/doc_links.t::test_docs_hold_no_machine_paths` -> no page, nor `README.md`, `MANUAL.md` or `COOKBOOK.md`, holds a `file:///` URI or a home path
- `t/core/doc_links.t::test_relative_links_resolve` -> every relative link outside code resolves to a file or directory
