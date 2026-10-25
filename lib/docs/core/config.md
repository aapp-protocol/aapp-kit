# config

## Tests
Run: `t/test-run config`

- `t/core/config.t::test_system_overrides_user_and_repo` -> settings defined in system main.conf override user main.conf and local repository git config
- `t/core/config.t::test_user_overrides_repo` -> settings defined in user main.conf override local repository git config
- `t/core/config.t::test_repo_subsection_overrides_global` -> a repo-specific subsection block overrides the global block within the same main.conf
- `t/core/config.t::test_absent_keys_fallthrough` -> keys absent from upper levels fall through cleanly to local repository git config
- `t/core/config.t::test_source_origin_tracking` -> source returns the winning authority level (system:repo, system:global, user:repo, user:global, repository)
- `t/core/config.t::test_multivalued_highest_level_wins` -> multi-valued keys take their entire set from the highest defining authority level
- `t/core/config.t::test_disallowed_key_refusal` -> monotonic state counters and unlisted keys in upper-level main.conf are refused fail-closed with file, line, and key
- `t/core/config.t::test_malformed_syntax_refusal` -> malformed syntax in main.conf fails closed with file and line diagnostics
