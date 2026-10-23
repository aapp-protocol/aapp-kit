# event_telemetry

## Tests
Run: `t/test-run event_telemetry`

- `t/core/event_telemetry.t::test_plan_lifecycle_events` -> `draft`, `active` (set and clear), `tdd`, `plan abort`, `refine`, `freeze`, `start`, `commit` and `done` each dispatch their `post-*` envelope with the command and the event's payload
- `t/core/event_telemetry.t::test_issue_lifecycle_events` -> `issue log`, `queue` (with its level), unqueue, `fix`, `close` and `abort` each dispatch a `post-issue` envelope naming the event
- `t/core/event_telemetry.t::test_pause_resume_events` -> `pause` and `resume` dispatch `post-pause` and `post-resume`
- `t/core/event_telemetry.t::test_sync_event` -> `sync` dispatches `post-sync`
