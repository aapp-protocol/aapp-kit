# review [draft <id> | draft <slug> | flag <id> "<finding>" [file <path>] | fix <id> F<n> "<task>" | fix done <id> F<n> | fix decline <id> F<n> "<reason>" | check <id>]

## Ingress
- words (bare tokens, P-138):
    - `draft <id>`: a design review of plan `<id>` (🟣 Under Review or 📝 Refining): writes its RFC, `.plans/pickup/p<n>-<slug>-rfc.md`, from `templates/rfc-template.md`; nothing is committed (`pickup/` is local and ignored)
    - `draft <slug>`: an RFC for a topic with no plan yet, `.plans/pickup/<slug>-rfc.md` (`<slug>` normalised as `aapp draft` does); its §1 quotes the open pickup line whose title normalises to `<slug>`, when there is one
    - `flag <id> "<finding>" [file <path>]`: an implementation review of plan `<id>` (⚡ In Development): appends finding `F<n>` to its `## 🔍 7. Implementation Review`; `file` names the file the finding is about
    - `fix <id> F<n> "<task>"`: the implementer's answer: appends `- [ ] F<n>: <task>` to `## 🧩 8. Review Fixes`; the finding becomes `planned`
    - `fix done <id> F<n>`: ticks the task; the finding becomes `done`
    - `fix decline <id> F<n> "<reason>"`: the finding becomes `declined: <reason>`; no task
    - `check <id>`: read only; any Status
    - no word: lists the words
- `<id>`: `P-<N>`, bare `<N>`, the filename stem, or a slug prefix, as every plan verb takes it
- line formats:
    - finding: `- **F<n>** <date> · <reviewer> · ` + (`` `<path>` · `` inside the Target Files, `` `<path>` (outside targets: needs an amendment) · `` outside them, nothing without `file`) + `<finding> — <state>`; `<state>` is `open`, `planned`, `done` or `declined: <reason>`; only the state ever changes
    - fix: `- [ ] F<n>: <task>`, ticked `- [x] F<n>: <task>`
    - `F<n>` continues from the highest number in §7; findings are never renumbered
- `<reviewer>`: the agent identity (`AAPP::Attribution::resolve_ai_identity`: agent tokens, `AAPP_AGENT_*`, the worktree's `aapp.aiAgent`), else `git config user.name`
- an amendment a fix needs: the request number written in the task as `(R<n>)`; a finding about a file outside the Target Files needs one
- reads: the plan file, its group's amendments member (`## Scope Requests`) for `fix done`, `templates/rfc-template.md`, `.plans/pickup.md`, the active buffer and the other worktrees' buffers (the owner rule)
- reads config: `user.name`, `aapp.aiAgent` (per worktree), `aapp.perlLogFile`

## Preconditions
- Inside a Git repository with the `.plans` worktree
- `flag` and `fix`: the plan is ⚡ In Development; `draft <id>`: 🟣 Under Review or 📝 Refining
- `fix`: run from the plan's own checkout: its recorded `* **Worktree:**`, else the checkout whose active buffer holds it (P-99)

## Failure modes
- an unknown word or no `<id>` -> exit 1, stderr naming the words; nothing written
- `<id>` resolves to no plan -> exit 1, stderr `Plan '<id>' not found`; nothing written
- `flag` or `fix` on a 🟣 / 📝 plan -> exit 1, stderr `design findings go in the plan's RFC: aapp review draft <id>`; on 🔷 / 🟥 / ✅ (and `draft <id>` on anything but 🟣 / 📝) -> exit 1 naming the Status; nothing written
- `draft`: the RFC file exists -> exit 1 naming it; `<slug>` empty after normalising -> exit 1; nothing written
- `flag` with an empty finding -> exit 1; nothing written
- `fix` from a checkout that does not own the plan -> exit 1, stderr `<id> is in development; only <owner> answers its review.`; nothing written
- `fix`: `F<n>` not in §7 -> exit 1; not in the state the form needs (`fix … "<task>"` needs `open`; `fix done` needs `planned`; `fix decline` needs `open` or `planned`) -> exit 1 naming its state; an empty task or reason -> exit 1; nothing written
- `fix done` when the finding is outside the Target Files and its task names no `(R<n>)`, or the named request has not landed (its state is not `committed`, `landed …`, `closed · landed …` or `applied`) -> exit 1 naming the request or the path; nothing written
- `done` and `decline` are reserved after `fix`: a plan with such a slug is named by its id

## Effects (happy path)
- `draft`: the RFC file, its header naming the plan (or the topic) and the date, the five sections of the template; stdout names the file; no commit
- `flag`: the §7 heading is written on first use, after the last section; the finding line `open`; one plans commit `plan(review): <id> F<n> flagged`
- `fix <id> F<n> "<task>"`: the §8 heading on first use; the task line; the finding `planned`; one plans commit `plan(review): <id> F<n> planned`
- `fix done`: the task ticked, the finding `done`; one plans commit `plan(review): <id> F<n> done`
- `fix decline`: the finding `declined: <reason>`; one plans commit `plan(review): <id> F<n> declined`
- `check`: stdout lists each open or planned finding and each unticked task; `review check: <id> clear` when there is none
- commits go through `AAPP::CommitEngine::plans_commit`, with the configured attribution; only the plan file is committed
- events (`aapp.perlLogFile`): `review.draft` (`target`, `file`), `review.flag` (`plan_id`, `finding`, `file`, `outside_targets`), `review.fix` (`plan_id`, `finding`, `action`: `task`, `done` or `decline`)

## Exit
- 0 on success; `check`: 0 when the plan has no §7, or every finding is `done` or `declined` and every task ticked, else 1
- 1 on every refusal above
- 3 when the plan is not found

## Tests
Run: `t/test-run verb review`

- `t/verb/review.t::test_bare_lists_words` -> bare `aapp review` lists draft, flag, fix and check; an unknown word is refused naming them
- `t/verb/review.t::test_draft_by_id_writes_rfc` -> `review draft <id>` on a 🟣 plan writes `.plans/pickup/p<n>-<slug>-rfc.md` with the template's five sections and the plan named; nothing committed
- `t/verb/review.t::test_draft_by_slug_quotes_pickup_line` -> `review draft <slug>` writes `<slug>-rfc.md` whose §1 quotes the pickup line with that title
- `t/verb/review.t::test_draft_refusals` -> an existing RFC, an empty slug and a ⚡ plan are refused; nothing written
- `t/verb/review.t::test_flag_appends_signed_finding` -> on a ⚡ plan the §7 heading and `F1` with date, reviewer and `open` are written; one plans commit of the plan file only
- `t/verb/review.t::test_flag_numbers_and_marks_outside_targets` -> a second finding is `F2`; a `file` outside the Target Files is marked as needing an amendment, one inside is not
- `t/verb/review.t::test_flag_and_fix_refuse_by_status` -> on a 🟣 plan both name the RFC; on a 🔷 plan both name the Status; nothing written
- `t/verb/review.t::test_fix_task_plans_finding` -> from the owning checkout the §8 heading and the task are written and the finding becomes `planned`
- `t/verb/review.t::test_fix_refuses_non_owner` -> from a checkout that does not own the plan `fix` is refused naming the owner; nothing written
- `t/verb/review.t::test_fix_done_and_decline` -> `fix done` ticks the task and sets `done`; `fix decline` sets `declined: <reason>`; a form on a finding in the wrong state, or with an empty reason, is refused
- `t/verb/review.t::test_fix_done_waits_for_amendment` -> a finding outside the Target Files: `fix done` is refused while its task names no request, or a pending one, and passes once the request has landed
- `t/verb/review.t::test_check_reports_open_items` -> exit 0 with no §7; exit 1 listing an open finding and an unticked task; exit 0 once every finding is done or declined and every task ticked
- `t/verb/review.t::test_events_are_logged` -> `review.draft`, `review.flag` and `review.fix` events reach the log with their fields
