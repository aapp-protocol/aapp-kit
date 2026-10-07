# issue [next | allocate | hotfix "<text>" [file <path>]… [plan] | fix next-blocker | fix <num> [file <path>…] | fix <num> abort | close <id> [sha <sha>] [summary "<text>"] | list [<n> | all]]

## Ingress
- positional forms:
    - `next` (default when no subcommand is given): prints the next issue ID without claiming it
    - `allocate`: claims the next issue ID and prints it (`#<n>`)
    - `hotfix "<text>" [file <path>]… [plan]` (P-52): from a plan's worktree, logs the blocking bug as a new issue, queues it under 🧱 Plan Blockers, records it in the plan's `Emergency Hotfixes:` and blocks the plan, in one commit; `plan` drafts a plan from it instead of queueing
    - `fix next-blocker` | `fix <num> [file <path>…]` (P-52): opens a temporary mini plan `current/fix-<num>.md` for one issue, one fix at a time; the files come from the row's Location (only its path tokens: present in the working tree, or containing `/` or a file extension, `:lines` stripped, P-58), `file` adds one the log does not name; `next-blocker` claims the top Plan Blocker; with a mini plan of `#<num>` open, `file` adds files to it
    - `fix <num> abort` (P-52): drops an uncommitted mini plan; the issue stays open
    - `close <id>`: relocates an active issue row to the archive
    - `list [<n> | all]`: prints active issues in road-map order
- `<id>`: bare number (`79`), `#79` (quoted: an unquoted `#79` is a shell comment) or `ISSUE-79`
- close tokens (bare, no `--`):
    - `sha <sha>`: commit recorded in the archive row (default: `HEAD` of the repository, short)
    - `summary "<text>"`: resolution summary (default: `Direct fix (no plan): <Target Plan / Fix cell>`); `|` is escaped
- list cap: bare `<n>` sets it, `all` removes it; default 20
- reads config: `aapp.issueFixWait` (minutes `fix` and the issue lock wait, default 5; `0` = fail fast), `aapp.maxEmergencyHotfixes` (hotfixes a plan may take, default 2; the next one blocks it permanently) (P-52)
- reads config: `aapp.issueId` (next ID to hand out; read by `next`, advanced by `allocate`); when unset (always in a fresh clone), seeded from both ledgers on first use, template example rows ignored
- reads: `.plans/ISSUES.md`, `.plans/done/000-issues-archive.md`, `.plans/issues_road_map.md`
- plugin: an installed `aapp-issue-tracker` provider (`.agents/skills/aapp-issue-tracker/`) speaks the Plugin Payload Standard (`.agents/CODEMAP.md` §5): `issue.allocate` → `{"id": "#<n>"}`; `issue.close` (data `id`, `commit`, `summary`, `plan`; env `AAPP_ISSUE_ID`, `AAPP_COMMIT_SHA`, `AAPP_SUMMARY`) → `{"status": …}`; `issue.next-blocker` (`AAPP_ACTION=next-blocker`, P-52) → `{"id": "#<n>"}`: the provider is the authority for the claim, and a failure refuses it (no local fallback)

## Preconditions
- Inside a Git repository whose `.plans/` worktree exists

## Failure modes
- `aapp.issueId` set but not an integer -> `next` and `allocate` exit 1, stderr `aapp.issueId is not an integer` naming `git config --unset aapp.issueId`; the key is left untouched
- `aapp.issueId` unset, no ledger files, no provider -> `next` and `allocate` exit 1, stderr names the `aapp-issue-tracker` provider; nothing is written
- installed provider exits non-zero on `allocate` -> exit 1, stderr `Provider plugin failed (<error text>); refusing to allocate locally`; no local fallback
- provider prints no `{"id": ...}` object -> exit 1, stderr `Provider must print {"id": ...}`
- provider prints a non-integer id -> exit 1, stderr `Provider must return an integer id`
- `close` without an id -> exit 1, usage on stderr
- `close` with an unknown token -> exit 1, stderr `Unknown token`
- `close` id in neither ledger -> exit 1, stderr `not found in ISSUES.md or done/000-issues-archive.md`
- `close` id already archived -> no failure: exit 0, ledgers untouched, the provider is notified again
- provider exits non-zero on `close` -> no failure: exit 0, stderr warning naming its `error` text; delivery and retry are the provider's responsibility
- `list` with a cap that is neither a number nor `all` -> exit 1, usage on stderr
- `hotfix` with no plan bound in this worktree, or a mini plan bound -> exit 1; nothing written, no ID spent (a file of the plan's own targets is accepted: plan work vs hotfix is decided by scope)
- `fix` while another mini plan is open -> waits, printing each wait (2 s, 3 s, …), up to `aapp.issueFixWait`; then exit 1, stderr `#<n> is still being fixed; retry later.`
- `fix` on an inactive issue, `next-blocker` with an empty queue, or no files known -> exit 1; nothing written
- `fix` on a file with uncommitted changes in this working copy -> waits with the same roller (`<file> has uncommitted changes here; waiting Ns…`), re-checking each step, and proceeds once the file is clean; the issue lock is not held while waiting. When the wait runs out -> exit 1, nothing written: stderr `<file> has uncommitted changes here; still busy after the wait`, or, when the plan bound in this checkout lists the file, that its own work is the cause and the remedy is `aapp issue hotfix "<text>" file <path>…`. `fix` never commits or stashes that work (P-58)
- `next-blocker` skips a blocker whose files are dirty here and claims the next; when every queued blocker is dirty, it waits the same way and claims the first to clear (P-58)
- `fix <num> abort` with recorded commits -> exit 1 (close it instead)
- `close` of an open mini plan with no recorded commit -> exit 1
- the issue lock (`$(git rev-parse --git-common-dir)/aapp_issue.lock`, held while `hotfix` and the start of a `fix` write) is waited for with the same roller; a lock whose holder PID is gone, or that has no PID after a few seconds, is taken over with a stale-lock notice

## Effects (happy path)
- `next`: prints `Next available issue ID: #<n>`; `aapp.issueId` unchanged (an unset counter stays unset)
- first `allocate` with an unset counter: `#<highest ledger ID + 1>`, or `#1` in a new project
- `allocate`: prints `#<n>`; `aapp.issueId` becomes `<n>+1`, or the provider's id plus one when a provider issued a higher id
- `close`:
    - the row leaves `.plans/ISSUES.md` and is inserted at the top of `.plans/done/000-issues-archive.md` as `| #<n> | Sev | Type | Date Opened | <today> | \`<sha>\` | <summary> |`
    - the `#<n>` entry leaves `.plans/issues_road_map.md`
    - the three files land in one `plans` commit `issue(close): archive #<n>`; nothing else is staged
    - then the provider, if installed, receives `issue.close` once; stdout reports `handed to aapp-issue-tracker: <status>`
- `hotfix`: a new row `| #<n> | \`High\` | \`CORE\` | <today> | <files> | <text> | blocks [<plan>](current/<file>) | 🟡 \`Incubated\` |`; `- [ ] #<n> -> <text> (blocks <plan>)` under `## 🧱 Plan Blockers` at the top of the road map; the plan gains `#<n>` in `* **Emergency Hotfixes:**` (append-only) and is blocked through `plan_block_on` (P-49); over `aapp.maxEmergencyHotfixes` the `Blocked On:` line carries `hotfix limit reached (…)` and only the developer lifts it; one commit `issue(hotfix): #<n> blocks <plan>`; with `plan`, the row is promoted to a new draft (`aapp draft … issue <n>`) and not queued
- `fix`: `current/fix-<num>.md` (Plan ID `#<num>`, `⚡ In Development`, `Changelog: Fixed: <text>`, §4 = the files) and the active buffer bound to `#<num>` with the previous value in `.prev`, one commit `fix(start): #<num>`; `abort` deletes it, restores the buffer, commit `fix(abort): #<num>`
- `close` of an issue with an open mini plan: the SHA defaults to the mini plan's last recorded commit and the summary to `Fixed via aapp issue fix: <files>; unblocks <plan>`; the mini plan is deleted and the buffer restored; any plan whose `Blocked On:` lists `#<n>` drops it and, once empty and not permanent, gets its recorded status back; the matrix is re-derived; all in the one close commit (the same unblocking runs when `aapp done` closes a Target Issue); stdout then prints `ℹ️  <plan> also lists <file>: it picks this fix up at its next rebase.` for every other ⚡ or BLOCKED plan whose Target Files include a fixed file (output only, P-58)
- `list`: road-map entries in board order, the same selection as the `aapp status` Issues pillar; a truncated list ends with `… <k> more (aapp issue list all)`
- `aapp done` on a plan whose Target Issue is `#<n>` performs the same `close` in its own archive commit; a Target Issue in neither ledger refuses `done` before anything moves

## Exit
- 0 on success, including an already-archived `close` and a provider that fails on `close`
- non-zero on invalid arguments, a corrupt counter, a failing provider on `allocate`, or an unknown id

## Tests
Run: `aapp test verb issue`

- `tests/verbs/issue.sh::test_next_peeks_without_claiming` -> `next` prints the counter and leaves it unchanged
- `tests/verbs/issue.sh::test_allocate_claims_and_advances` -> `allocate` prints `#<n>` and advances the counter
- `tests/verbs/issue.sh::test_non_integer_counter_fails_closed` -> a corrupt counter refuses `next` and `allocate`
- `tests/verbs/issue.sh::test_provider_allocate_ratchets_counter` -> a provider's id is issued and the counter moves past it
- `tests/verbs/issue.sh::test_failing_provider_refuses_allocation` -> a failing provider is fatal, no local fallback
- `tests/verbs/issue.sh::test_close_relocates_prunes_and_commits` -> row archived at the top, road map pruned, one clean commit
- `tests/verbs/issue.sh::test_close_plugin_failure_only_warns` -> a failing provider on `close` warns, exit 0
- `tests/verbs/issue.sh::test_close_summary_escapes_pipes` -> `|` in the summary is escaped in the archive row
- `tests/verbs/issue.sh::test_close_sends_envelope_and_reports_status` -> `issue.close` envelope carries data, the credential-free remote and `extra`; the returned status is printed
- `tests/verbs/issue.sh::test_close_archived_is_idempotent` -> closing an archived issue changes nothing, exit 0
- `tests/verbs/issue.sh::test_close_refuses_unknown_id_and_tokens` -> unknown id, unknown token and missing id exit non-zero
- `tests/verbs/issue.sh::test_list_default_cap_in_roadmap_order` -> 20 entries in board order plus the overflow line
- `tests/verbs/issue.sh::test_list_cap_tokens` -> `<n>` and `all` set the cap; `-n` is refused
- `tests/verbs/issue.sh::test_done_closes_target_issue` -> `aapp done` archives its Target Issue in the same commit
- `tests/verbs/issue.sh::test_done_refuses_dangling_target_issue` -> a Target Issue in neither ledger refuses `done`
- `tests/verbs/issue.sh::test_new_project_first_issue_is_1` -> template ledgers only: the first issue is `#1`
- `tests/verbs/issue.sh::test_clone_first_allocate_continues_ledgers` -> unset counter continues from the ledgers; `next` writes nothing
- `tests/verbs/issue.sh::test_no_ledgers_without_provider_refuses` -> no ledgers and no provider refuses, never `#1`
- `tests/verbs/issue.sh::test_no_ledgers_with_provider_allocates` -> no ledgers but a provider: the provider issues the ID
- `tests/verbs/issue.sh::test_hotfix_refusals` -> no bound plan or a file in the plan's own targets: refused, no ID spent (P-52)
- `tests/verbs/issue.sh::test_hotfix_logs_queues_records_and_blocks` -> row, 🧱 Plan Blockers at the top, `Emergency Hotfixes:`, BLOCKED with previous status, one commit (P-52)
- `tests/verbs/issue.sh::test_fix_next_blocker_opens_mini_plan` -> top blocker claimed with its Location files; buffer bound, previous in `.prev` (P-52)
- `tests/verbs/issue.sh::test_fix_one_at_a_time` -> with `aapp.issueFixWait 0` a second fix is refused at once, nothing written (P-52)
- `tests/verbs/issue.sh::test_close_archives_and_unblocks` -> SHA from the mini plan, summary, mini plan deleted, buffer restored, plan resumed (P-52)
- `tests/verbs/issue.sh::test_hotfix_over_limit_blocks_permanently` -> the 3rd hotfix marks the block permanent; the issue is still queued (P-52)
- `tests/verbs/issue.sh::test_fix_abort_keeps_hotfix_queued` -> abort drops the mini plan; the issue stays queued and blocking (P-52)
- `tests/verbs/issue.sh::test_permanent_block_survives_close` -> closing a blocker does not lift a permanent block (P-52)
- `tests/verbs/issue.sh::test_stale_lock_taken_over` -> a lock whose holder is gone is taken over with a notice (P-52)
- `tests/verbs/issue.sh::test_concurrent_hotfixes_get_distinct_ids` -> two simultaneous hotfixes get different numbers (P-52)
- `tests/verbs/issue.sh::test_hotfix_plan_token_promotes` -> `plan` drafts a plan, row Planned with its link, not queued (P-52)
- `tests/verbs/issue.sh::test_provider_next_blocker_claims` -> an installed provider's `next-blocker` id is claimed (P-52)
- `tests/verbs/issue.sh::test_done_of_promoted_plan_unblocks` -> `aapp done` of a plan promoted from a hotfix closes the issue and resumes the blocked plan in its commit (P-52)
- `tests/verbs/issue.sh::test_fix_adds_files_to_open_mini_plan` -> `fix <num> file` on an open mini plan adds the file, keeps its commits, one commit (P-52)
- `tests/verbs/issue.sh::test_hotfix_own_file_stashes_only_its_files` -> a file of the plan's own targets is accepted; only its uncommitted work is stashed, other work stays (P-52)
- `tests/verbs/issue.sh::test_mini_plan_edits_file_listed_by_blocked_plan` -> the guard lets the bound mini plan edit a file the BLOCKED plan lists (P-52)
- `tests/verbs/issue.sh::test_close_reapplies_stash_on_top_of_fix` -> close re-applies the stashed work on top of the fix and drops the stash (P-52)
- `tests/verbs/issue.sh::test_fix_refuses_dirty_file` -> a file with uncommitted changes is refused once the wait runs out, nothing written (P-52)
- `tests/verbs/issue.sh::test_next_blocker_skips_untakeable` -> a blocker with dirty files is skipped; the next one is claimed (P-52)
- `tests/verbs/issue.sh::test_fix_takes_only_paths_from_location` -> a hand-written Location yields only its path tokens (P-58)
- `tests/verbs/issue.sh::test_fix_strips_line_suffix_from_location` -> `:lines` is stripped from a Location path (P-58)
- `tests/verbs/issue.sh::test_close_notices_other_plan_listing_fixed_file` -> close names another active plan that lists a fixed file (P-58)
- `tests/verbs/issue.sh::test_close_no_notice_when_unlisted` -> no notice when no other plan lists the files (P-58)
- `tests/verbs/issue.sh::test_fix_timeout_on_bound_plan_file_hints_hotfix` -> the bound plan's own dirty file: the refusal names `aapp issue hotfix` (P-58)
- `tests/verbs/issue.sh::test_fix_wait_zero_refuses_at_once` -> `aapp.issueFixWait 0` refuses a dirty file without waiting (P-58)
- `tests/verbs/issue.sh::test_fix_waits_for_dirty_file_then_proceeds` -> `fix` waits, printed, and proceeds once the file is clean (P-58)
- `tests/verbs/issue.sh::test_next_blocker_waits_when_every_blocker_is_dirty` -> `next-blocker` waits for the first blocker to clear (P-58)
