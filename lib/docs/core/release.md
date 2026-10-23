# release

## Tests
Run: `t/test-run release`

- `t/core/release.t::test_version_forms` -> three- and two-segment versions, `v`-prefixed or with a suffix up to 30 characters, pass `check`; a bare number, a word or a longer suffix is refused
- `t/core/release.t::test_bump_tokens_from_last_tag` -> `patch`, `minor` and `major` bump the last release tag, two-segment tags included
- `t/core/release.t::test_phase_a_gates` -> `check` and a non-interactive run without `yes` create no tag; a dirty tree, a failing `aapp.testCommand` or a missing `CHANGELOG.md` refuses; `no-changelog` lifts the last
- `t/core/release.t::test_reachability_and_bundling` -> a done plan's commits must be ancestors (`unverified` lifts it); the release tags, moves plans and the issue archive into `.plans/release/<tag>/` with its ledger and manifests, links it from the master ledger and rolls the changelog up under a fresh Unreleased
- `t/core/release.t::test_json_contract` -> `json check` prints the release document with its schema version, tag and version
- `t/core/release.t::test_rollback_on_hook_failure` -> a failing on-release hook aborts the release, leaving no tag and no bundle
