# kit_release_hook

## Tests
Run: `t/test-run kit_release_hook`

- `t/core/kit_release_hook.t::test_version_from_environment` -> `AAPP_RAW_VERSION` sets the CLI's `AAPP_VERSION` and every managed template's protocol marker
- `t/core/kit_release_hook.t::test_version_from_stdin_json` -> the stdin envelope's `rawVersion` does the same
- `t/core/kit_release_hook.t::test_refuses_missing_or_invalid_version` -> no version, or a malformed one, exits 1 and changes nothing
- `t/core/kit_release_hook.t::test_release_runs_kit_hook` -> `aapp release <version>` runs the registered hook, which bumps the CLI and the templates
