# event_telemetry

## Tests
Run: `aapp test event_telemetry`

- `tests/event_telemetry_test.sh::test_plan_lifecycle_events` -> `draft`, `active` (set and clear), `tdd`, `plan abort`, `refine`, `freeze`, `start`, `commit` and `done` each dispatch their `post-*` envelope with the command and the event's payload
- `tests/event_telemetry_test.sh::test_issue_lifecycle_events` -> `issue log`, `queue` (with its level), unqueue, `fix`, `close` and `abort` each dispatch a `post-issue` envelope naming the event
- `tests/event_telemetry_test.sh::test_pause_resume_events` -> `pause` and `resume` dispatch `post-pause` and `post-resume`
- `tests/event_telemetry_test.sh::test_sync_event` -> `sync` dispatches `post-sync`
