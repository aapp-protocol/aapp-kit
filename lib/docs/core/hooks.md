# hooks

## Tests
Run: `t/test-run hooks`

- `t/core/hooks.t::test_hook_hash_formats_registry_line` -> `compute_file_sha256` gives a 64-character hash, and `aapp hook-hash` prints the five-column registry line with it
- `t/core/hooks.t::test_gate_hook_receives_envelope_and_environment` -> a gate hook exiting 0 lets the step proceed and receives the JSON envelope on stdin and the event in its environment
- `t/core/hooks.t::test_tampered_hook_aborts` -> a hook whose file no longer matches its registered hash aborts the step with an integrity violation
- `t/core/hooks.t::test_gate_hook_failure_halts` -> a gate hook exiting 1 halts the step and shows its stderr
- `t/core/hooks.t::test_notify_hook_failure_warns` -> a notify hook exiting 1 warns and the step proceeds
- `t/core/hooks.t::test_exit_two_warns_in_gate_mode` -> a gate hook exiting 2 warns and the step proceeds
- `t/core/hooks.t::test_watchdog_timeout` -> a hook past its timeout halts the step in gate mode and warns in notify mode
- `t/core/hooks.t::test_malformed_registry_line_refused` -> a registry line with a sixth field is refused
- `t/core/hooks.t::test_local_config_hooks` -> hooks from local git config run in notify mode and cannot gate; `aapp.allowLocalHooks false` turns them off
- `t/core/hooks.t::test_hooks_inspector_audits_hashes` -> `aapp hooks` lists registered hooks with their hash check
- `t/core/hooks.t::test_plugins_inspector_discovers_plugins` -> `aapp plugins` finds extensionless and any-language action plugins
- `t/core/hooks.t::test_action_plugin_fallthrough` -> `aapp <plugin>` runs an action plugin with `AAPP_REPO_ROOT`; `aapp help <plugin>`, `aapp <plugin> help` and `help <plugin> full` show its help and `SKILL.md`
- `t/core/hooks.t::test_sample_plugins_never_run` -> a `run.sample` is never taken as an entry point, even executable, and `aapp` refuses to run a sample
- `t/core/hooks.t::test_inspectors_show_samples` -> `aapp hooks` marks a registered sample INERT SAMPLE; both inspectors show the extension points and the samples available
- `t/core/hooks.t::test_plugin_registry_listing` -> `aapp plugins` lists the kit's registry under Kit Plugins (planned rows RESERVED, early installs marked) and others under Your Plugins with a prefix warning; a missing `plugins.tsv` fails closed
- `t/core/hooks.t::test_event_envelope` -> `build_event_envelope` carries the remote without credentials (or `null`), a reserved `extra`, and the data as given (`{}` when empty)
- `t/core/hooks.t::test_pre_hooks_abort_with_no_change` -> a vetoing `pre-freeze`, `pre-start`, `pre-done` or `pre-sync` hook stops its verb before any change
- `t/core/hooks.t::test_pre_done_test_gate_sample` -> the sample test gate lets `done` archive on a passing command and refuses a failing one, a dirty tree, an unset command or a timeout
- `t/core/hooks.t::test_pre_refine_gate_vetoes_the_refine` -> a vetoing `pre-refine` hook stops the refine
- `t/core/hooks.t::test_on_refine_failure_commits_nothing` -> a failing `on-refine` handler leaves nothing committed
- `t/core/hooks.t::test_post_refine_receives_kind_and_commit` -> `post-refine` receives the refine's kind, commit and notes
- `t/core/hooks.t::test_event_logger_sample` -> the event logger registers by `hook-hash`, writes one JSON line per event to the git dir by default, or to `aapp.logFile`
