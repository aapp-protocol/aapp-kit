# status [short | json]

## Ingress
- `short` (positional, optional; alias `summary`): print the one-line pulse instead of the briefing
- `json` (bare token, optional, P-94): print the briefing's records as one JSON document instead of the terminal layout; its fields: `docs/reference/08-output-json.md`. With `short` -> refused
    constraints: any other value is refused
    ⚠️ Divergence: any other argument is ignored silently and the full briefing prints.
- reads: `.plans/ISSUES.md`, `.plans/issues_road_map.md`, `.plans/current/`, `.plans/state_matrix.md`, `.plans/pickup.md`, `.plans/adoption.md`, `CHANGELOG.md` (or `.plans/CHANGELOG.md`), `.plans/PAUSED.md`, the active buffer
- reads config: `aapp.planState.*` (plan lane bucketing), `aapp.devBranch` (the branch of an issue that names none), `aapp.issueSyncWindow`, `aapp.issueCacheMax`, `aapp.statusOutputWidth` (the briefing's width, default 85, P-92), `aapp.statusItemsMax` (Shipped entries and pickup ideas listed, default 5, P-88), `aapp.statusTextMax` (the characters of an item's text shown, default 220, P-88), `aapp.jsonLocalPath` (`json`: write the checkout's path, default `true`, P-94)
- reads: the Git history of the changelog (`git log -n 15 --first-parent -m -p --unified=0`; of the plans worktree for `.plans/CHANGELOG.md`, P-88)
- reads: the branches, here and on the remotes, and whether a fix commit is reachable from a plan's parent branch (P-78)

## Preconditions
- Inside a Git repository (asserted by the dispatcher)

## Failure modes
- outside a Git repository -> exit 1, stderr names the missing repository
- a missing pillar file -> no failure: the pillar reports it as absent
- `aapp.statusOutputWidth` not a whole number of at least 40 -> exit 1, stderr names the key; `short` is not affected (P-92)
- `aapp.statusItemsMax` or `aapp.statusTextMax` not a whole number of at least 1 -> exit 1, stderr names the key; `short` is not affected (P-88)
- `short json` -> exit 1, usage on stderr, and on stdout the error document with `error.code` `usage` (P-94, P-100)
- `json`: any failure -> exit non-zero; stdout holds the error document (`error.code`: `usage`, `invalid-setting` with `aapp_config`, `confirm-needed`, `sync-failed`, `failed`) and stderr the message (P-100); `aapp.jsonLocalPath` other than `true` or `false` -> `invalid-setting`, `repository` `null`. `aapp.statusOutputWidth` and `aapp.statusTextMax` are the terminal's and are not read (P-94)

## Effects (happy path)
- `.plans/state_matrix.md` is re-derived from the plans before it is read, so the briefing reports the real board; the write is not committed
- `short`: stdout is exactly one line beginning `📊 Overview:` with issue, plan and pickup counts; appends ` | <N> adoption` when `.plans/adoption.md` has open tasks (P-63)
- no argument: stdout carries the four pillars (Shipped, Issues, Plans, Pickup), open adoption tasks after pickup when present (`📋 Adoption: <N> open task(s) in .plans/adoption.md`), and one `➡️  Next Action:` line
- Shipped pillar (P-88): the entries the latest 15 commits of this branch that touched the changelog added, newest first, from any section, up to `aapp.statusItemsMax`; each entry once, in its current wording; an entry no longer in the file is skipped; no section headings. Each `  - <entry>`, cut at `aapp.statusTextMax` characters with `…` and wrapped, the continuation under the text. `  (more in CHANGELOG.md)` follows when `## [Unreleased]` holds more entries than shown. With no history (no commits yet, a shallow clone, a changelog outside Git): the first entries under `## [Unreleased]`
- Pickup pillar (P-88): up to `aapp.statusItemsMax` ideas, then `  ... and <N> more (see .plans/pickup.md)`. Each idea: `  - [ ] <title>` (wrapped at 8 spaces when wider than the line), its text below at 8 spaces, cut at `aapp.statusTextMax` with `…` and wrapped, then `        files: <path>` per `.plans/pickup/` file it names; an idea with no title starts its text on the `- [ ] ` line
- Issues pillar (P-89, P-93): the work queue (plan blockers, then the queued issues level by level), then the issues staged in `.offline`, each in the issue layout of `aapp issue list` (a facts line, the tracker's names when given, the symptom wrapped at 8 spaces), the symptom cut at `aapp.statusTextMax` with `…`; then `ℹ️  <N> more issue(s) logged, not queued for work: aapp issue list` when other issues are open; `(Nothing queued for work: …)` when only those exist, `(No open issues)` when there are none
- Issues pillar (P-78): once an open issue names a branch, each facts line has `(branch: <name>)` and the issues of the current branch (in a plan's worktree: of the plan's parent branch) come first, as in `aapp issue list`; an issue whose branch exists neither here nor on a remote is reported, with the development branch its fix will land on
- where a tracker keeps the issues (P-74): the briefing first brings them up to date through the `aapp-issue-tracker` provider's `issue.list`, at most once per `aapp.issueSyncWindow` minutes (default 15) counted from the last attempt, successful or not; a failing provider warns and changes nothing. Not done by `short`, nor while a plugin step runs
- an issue the tracker reports closed is closed here by the sync, at once (#142); a plan that waited on it is unblocked or named under Plans by the rule below
- a plan left blocked on a closed issue is unblocked once the fix commit is reachable from its parent branch (P-78): the plan and the re-derived matrix land in one `plans` commit `issue(unblock): fix reached the parent branch`, and the Plans pillar says `<plan> no longer waits for #<n>`; a plan still waiting gets a line naming the commit, the branch it was fixed on, the parent branch it is not in yet and `aapp refine <plan> unblocked <num>`. Not done by `short`, nor while a plugin step runs
- a plan with its own worktree shows it next to its status, from the header's `* **Worktree:**`: `• P-51: P51-….md  (⚡ In Development → ../repo-P51)` (P-54)
- records first (P-92): every section is collected into records (tab-separated lines, raw values) before anything is printed, and the terminal renderer prints them; side effects (sync, unblock, matrix) run first, and what they said is printed as notices of their section
- width (P-92): the `=` frame is `aapp.statusOutputWidth` characters wide; the header lines, the Plans pillar, the notices, the state lines, the adoption and offline lines and `➡️  Next Action:` keep to it, wrapped at spaces with the continuation indented under the text (counted in characters, not bytes; a word longer than the width stands on a line of its own). The issues keep to it in the issue layout (P-93)
- `json` (P-94): stdout holds one JSON object, indented by 2 spaces: the envelope (`version` `1.0`, `command` `status`, `generated_at`, `repository` with the remote, credentials removed, the branch and, unless `aapp.jsonLocalPath false`, the checkout's path; `notices`: `{ "warning": [...], "info": [...] }`, every remark of the run, P-100), then `overview`, `templates`, `pause`, `shipped`, `issues`, `plans` (a group's members nested), `pickup`, `adoption`, `offline`, `next_action`. The same side effects as the briefing, the tracker's sync without input; the same items (`aapp.statusItemsMax`), text whole; nothing on stderr. Fields: `docs/reference/08-output-json.md`
- the template advisory names the action first: `📑 Templates:  1 template drifted -> run 'aapp init' (<file> <reason>)`
- no other file changes

## Exit
- 0 whenever a briefing was printed

## Tests
Run: `aapp test verb status`

- `tests/verbs/status.sh::test_short_is_one_line` -> `status short` prints exactly one `📊 Overview:` line
- `tests/verbs/status.sh::test_short_json_refused` -> `status short json` exits 1 with usage on stderr and nothing on stdout (P-94)
- `tests/verbs/status.sh::test_briefing_has_next_action` -> the full briefing ends with a `Next Action` line and exits 0
- `tests/verbs/status.sh::test_plan_worktree_shown_next_to_plan` -> a plan's worktree path follows its status (P-54)
- `tests/verbs/status.sh::test_overview_counts_open_adoption_tasks` -> open adoption tasks show in overview and briefing (P-63)
- `tests/verbs/status.sh::test_no_adoption_output_when_none_open` -> nothing printed when no open adoption tasks (P-63)
- `tests/verbs/status.sh::test_members_listed_under_group` -> a group's members are listed, indented, on the lines after it (P-64)
- `tests/verbs/status.sh::test_issues_pillar_layout` -> the fixture's Issues pillar in the issue layout: facts lines, symptoms wrapped at 8 spaces (P-93)
- `tests/verbs/status.sh::test_briefing_lines_within_width` -> at a width of 60, no header, plan, notice or next-action line is longer (P-92)
- `tests/verbs/status.sh::test_pickup_records` -> pickup records split title and text, list the named files that exist, and a missing file is a warning notice (P-92)
- `tests/verbs/status.sh::test_shipped_shows_latest_landed` -> an entry committed last under `### Fixed`, below thirty `Added` entries, is the first Shipped line (P-88)
- `tests/verbs/status.sh::test_shipped_newest_first_across_sections` -> entries committed in turn to `Added`, `Fixed`, `Changed` print newest first (P-88)
- `tests/verbs/status.sh::test_shipped_skips_removed_entry` -> a removed entry is not printed; a reworded one prints once, as now worded (P-88)
- `tests/verbs/status.sh::test_shipped_points_to_changelog` -> more entries than shown end the pillar with `(more in CHANGELOG.md)` (P-88)
- `tests/verbs/status.sh::test_shipped_entry_wrapped` -> a long entry is cut at `aapp.statusTextMax` with `…` and wrapped within the width (P-88)
- `tests/verbs/status.sh::test_shipped_record_fields` -> a record carries section, text, plan, commit and date; from the file, no commit and date (P-88)
- `tests/verbs/status.sh::test_shipped_fallback_without_history` -> with no history the first entries under `[Unreleased]` are listed, without headings (P-88)
- `tests/verbs/status.sh::test_pickup_capped_with_more` -> five ideas, then `... and <N> more (see .plans/pickup.md)` (P-88)
- `tests/verbs/status.sh::test_pickup_bounded_and_wrapped` -> a 900-character idea: title line, text bounded to 220 characters, wrapped at 8 spaces within 85 columns (P-88)
- `tests/verbs/status.sh::test_pickup_long_title_wraps` -> a title wider than the line wraps at 8 spaces (P-88)
- `tests/verbs/status.sh::test_pickup_files_line` -> a named `.plans/pickup/` file gets a `files:` line; an untitled idea starts on the `- [ ] ` line (P-88)
- `tests/verbs/status.sh::test_status_limit_settings` -> `aapp.statusItemsMax` and `aapp.statusTextMax` change the caps; an invalid value is refused naming the key (P-88)
