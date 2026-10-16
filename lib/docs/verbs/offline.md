# offline [mount | unmount [force] | on | off | status | sync]

## Ingress
- positional forms:
    - `mount`: creates or mounts the `.offline` worktree on orphan branch `offline`
    - `unmount [force]`: removes the worktree; `force` when something is still staged
    - `on` / `off`: sets or clears `aapp.offlineOnly` (the provider is not asked at all)
    - `status` (default when no subcommand is given): what is staged
    - `sync`: publishes what is staged, once the provider answers
- reads config: `aapp.offlineEnabled` (default on; `false` = a failing provider refuses and nothing is staged), `aapp.offlineOnly` (default off; `true` = the provider is skipped, with no wait), `aapp.offlineIdOffset` (default 1000), `aapp.pluginTimeout` (seconds a provider may take, default 10; a timeout is a failure)
- reads: `.offline/` (`ISSUES.md`, `done/000-issues-archive.md`, `issues_road_map.md`, `outbox`, `closed.rows`, `current/`), the ledgers and plans in `.plans/`, the kit's store of descriptions and notes
- plugins: `aapp-issue-tracker` (`issue.log` and the outbox's steps at `sync`), `aapp-planid` (`plan.allocate` at `sync`)

## Preconditions
- Inside a Git repository
- `sync`: the `.plans/` worktree exists

## Failure modes
- an unknown subcommand -> exit 1, usage on stderr
- `mount` when `.offline` exists and is not the worktree -> exit 1; nothing changed
- `unmount` while anything is staged (an issue, an issue closed or withdrawn offline, a draft plan, a step in the outbox) -> exit 1, each item listed, naming `aapp offline sync` and `unmount force`; the worktree stays
- `sync` while `aapp.offlineOnly` is on -> exit 1, naming `aapp offline off`
- `sync`, a staged issue the provider fails on, answers without an id, or declines where the tracker keeps the record -> no failure: that issue stays staged, the others are published, stdout names it
- `sync`, a draft plan for which no plan id can be had -> no failure: it stays in `.offline/current/`
- `sync`, a step of the outbox the provider does not accept -> no failure: it and the steps after it stay, in order
- `aapp push` / `aapp sync` with `offline` named in `aapp.syncWorktrees` -> exit 1 before anything is pushed or pulled; the `.offline` worktree is never pushed

## Effects (happy path)
- `mount`: `.offline` on branch `offline` (an orphan: no history shared with any other branch), with empty ledgers, an empty `outbox` and `current/`; `.offline/` is added to `.git/info/exclude`, so no shared branch gets a commit or an ignore rule. Mounting again is a no-op. What the kit writes there is committed on `offline`, a local history of what was done offline
- staging happens in the issue verbs, not here: with a provider installed, `aapp issue log` and `aapp issue hotfix` stage the issue in `.offline` when the provider fails or times out (default), or at once when `aapp.offlineOnly` is on; with `aapp.offlineEnabled false` the failure refuses. Without a provider nothing is ever staged: the kit numbers and logs as usual
- a staged issue's id is temporary and numeric: one more than the highest offline id; for the first, the highest id in the main ledgers plus `aapp.offlineIdOffset`
- an issue staged offline is an issue: `aapp issue list` and `aapp status` show it, marked `(offline: staged in .offline)`; a plan can be blocked on it (`aapp refine <id> blocked <num>`); `aapp issue fix`, `close` and `abort` work on it. Closed or withdrawn offline, its row goes to `.offline/done/000-issues-archive.md` (with `` `aborted` `` for a withdrawal), and plans it blocked resume. None of its steps is sent to the provider: they go with its `log` at `sync`
- a step for an issue the tracker knows (`refine`, `fix`, `fix-abort`, `abort`, `close`) that cannot be sent is written to `.offline/outbox`, one per line, in order. It is sent before anything is read from the tracker (`aapp issue list`, `aapp status`): while a line remains the tracker's listing is not applied, so a close made meanwhile is never undone by it
- `aapp draft` with an `aapp-planid` provider installed and unreachable (or `aapp.offlineOnly`): the plan gets a temporary id by the same rule (highest offline plan id plus 1; first, the highest plan id known here plus the offset) and is written to `.offline/current/`; drafting with `issue <num>` or `group` is refused there
- `on`: `aapp.offlineOnly true`; `off`: the key is unset
- `status`: whether `.offline` is mounted, the mode, the staged rows, closed issues, draft plans and waiting steps
- `sync`, in this order: the outbox; then each staged issue, oldest first: `issue.log` with the whole issue, its description and notes, and the id that comes back (the tracker's key or number; the kit's counter when the provider declines and the ledgers are the record) replaces the temporary one in the row, in the plans' `Target Issue` and `Blocked On`, in the work queue, in staged drafts and in the store; the row moves to the main ledger, and an issue queued while offline is queued under its real id (P-89); an issue closed or withdrawn offline gets its archive row with `logged offline as #<temp>` in its summary, and the provider gets `issue.close` or `issue.abort`. Then each draft plan: the real plan id, the file renamed and moved to `.plans/current/` as `🟣 Under Review`, every reference to `P-<temp>` rewritten, `Plan drafted offline as P-<temp>` in its change log, the state matrix re-derived
- commits made offline name the temporary id and are never rewritten; `aapp issue fix <temp>`, `ledger_locate` and `ledger_row` resolve a former id to the real one
- `sync` commits once on the plans branch, `offline(sync): publish what was staged offline`: the ledgers and the changed plans where the ledgers are the record; only the plans where the tracker keeps it
- `unmount`: the worktree is removed; the branch `offline` keeps what was staged

## Exit
- 0 when the subcommand ran; `sync` also when something stays staged
- non-zero on an unknown subcommand, a refused `unmount`, `sync` in offline-only mode

## Tests
Run: `aapp test verb offline`

- `tests/verbs/offline.sh::test_mount_creates_orphan_worktree` -> `mount` creates `.offline` on orphan branch `offline`, with its ledgers
- `tests/verbs/offline.sh::test_offline_dir_excluded_locally` -> `.offline/` is in `.git/info/exclude`; no commit on the code or plans branch
- `tests/verbs/offline.sh::test_allocate_uses_offset` -> the first staged issue is numbered highest main id plus the offset; nothing changes in `.plans`
- `tests/verbs/offline.sh::test_allocate_subsequent_increments_by_one` -> the next ones follow the highest offline id
- `tests/verbs/offline.sh::test_custom_offset_configuration` -> `aapp.offlineIdOffset 5000` starts there
- `tests/verbs/offline.sh::test_plugin_smart_fallback_on_timeout` -> a provider slower than `aapp.pluginTimeout`: the issue is staged, with an advisory
- `tests/verbs/offline.sh::test_offline_only_skips_network` -> `offline on`: the provider is not called, and nothing waits
- `tests/verbs/offline.sh::test_offline_disabled_fails_closed` -> `aapp.offlineEnabled false`: a failing provider refuses, nothing is staged
- `tests/verbs/offline.sh::test_offline_issue_in_every_view` -> a staged issue shows, marked, in `issue list` and `status`, and blocks a plan
- `tests/verbs/offline.sh::test_status_reports_staged_offline_work` -> `status` has the Staged Offline Work section with the ids and the action
- `tests/verbs/offline.sh::test_offline_issue_local_archive` -> closing a staged issue moves its row to the offline archive with the commit
- `tests/verbs/offline.sh::test_offline_issue_abort_archives_row` -> `issue abort` of a staged issue archives it there as `aborted` and unblocks the plan
- `tests/verbs/offline.sh::test_unmount_refuses_when_dirty` -> `unmount` refuses while something is staged; `force` unmounts, and the branch keeps it
- `tests/verbs/offline.sh::test_offline_sync_promotes_and_relinks` -> `sync` moves a row to `.plans` under its real id and rewrites the plan's `Blocked On`
- `tests/verbs/offline.sh::test_sync_preserves_offline_commit_messages` -> an issue closed offline is archived under its real id with `logged offline as #<temp>`; the commit subject is unchanged
- `tests/verbs/offline.sh::test_former_id_lookup_resolves_to_canonical` -> `ledger_locate` and `ledger_row` resolve a former offline id
- `tests/verbs/offline.sh::test_sync_sends_description_and_notes` -> the `log` payload carries description and notes; the store's entries move to the real id
- `tests/verbs/offline.sh::test_sync_keeps_failed_row_staged` -> an issue the provider fails on stays staged and is reported; the others are published
- `tests/verbs/offline.sh::test_offline_draft_takes_temporary_plan_id` -> an unreachable plan-id provider: the draft is in `.offline/current/` under a temporary id; the next takes the following one
- `tests/verbs/offline.sh::test_sync_gives_draft_real_plan_id` -> `sync` renames the draft to its real id, rewrites header and references, records the former id
- `tests/verbs/offline.sh::test_outbox_sent_before_tracker_read` -> a close that could not be sent waits in the outbox; the tracker's listing is not applied until it is sent, and it is sent first
- `tests/verbs/offline.sh::test_sync_commits_by_record` -> committed ledgers: the sync commits ledgers and plans; tracker-kept record: only the plans
- `tests/verbs/offline.sh::test_push_verbs_refuse_offline` -> `push` leaves `.offline` alone by default; `push` and `sync` refuse `offline` in `aapp.syncWorktrees`
