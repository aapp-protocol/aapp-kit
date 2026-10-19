# plugin_protocol

## Tests
Run: `aapp test plugin_protocol`

- `tests/plugin_protocol_test.sh::test_message_is_shown` -> a plugin's `message` is shown to the user after its step
- `tests/plugin_protocol_test.sh::test_unnamed_part_left_to_kit` -> `plugin_step` takes over only the parts the answer names in `handled`; an answer without `handled` leaves all to the kit
- `tests/plugin_protocol_test.sh::test_declined_leaves_all_to_kit` -> a `declined` answer leaves every part to the kit, whatever it names
- `tests/plugin_protocol_test.sh::test_newer_version_refused` -> an answer of a newer protocol version is refused; the current version is accepted
- `tests/plugin_protocol_test.sh::test_list_file_read_per_line` -> the plugin's list file is read one JSON line per item
- `tests/plugin_protocol_test.sh::test_do_list_runs_accepted_commands_in_order` -> the `do` list runs after the step, in order; a command off the whitelist is refused by name and the rest still run; the plugin is not called again
- `tests/plugin_protocol_test.sh::test_write_verb_refused_inside_plugin` -> a plugin calling a writing verb during its step is refused and pointed to the `do` list; a reading verb runs
- `tests/plugin_protocol_test.sh::test_timeout_ends_plugin` -> a plugin running past `aapp.pluginTimeout` is stopped, reported as failed, and the step completes
- `tests/plugin_protocol_test.sh::test_envelope_carries_no_secret` -> the envelope and the plugin's environment carry the remote URL without its credentials, plus the `do` and list file paths
- `tests/plugin_protocol_test.sh::test_sample_issue_tracker_queue_events` -> the sample tracker marks an issue queued on `issue.queue` and open again on `issue.unqueue`
