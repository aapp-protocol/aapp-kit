# kit_release_hook

## Tests
Run: `aapp test kit_release_hook`

- `tests/kit_release_hook_test.sh::test_version_from_environment` -> `AAPP_RAW_VERSION` sets the CLI's `AAPP_VERSION` and every managed template's protocol marker
- `tests/kit_release_hook_test.sh::test_version_from_stdin_json` -> the stdin envelope's `rawVersion` does the same
- `tests/kit_release_hook_test.sh::test_refuses_missing_or_invalid_version` -> no version, or a malformed one, exits 1 and changes nothing
- `tests/kit_release_hook_test.sh::test_release_runs_kit_hook` -> `aapp release <version>` runs the registered hook, which bumps the CLI and the templates
