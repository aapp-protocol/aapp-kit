# draft [slug] [issue <num> | group [<id>]]

## Ingress
- `slug` (positional, optional): the plan's slug and title source
    normalised: lowercased, spaces and `_` become `-`, anything outside `[a-z0-9-]` dropped, runs of `-` collapsed
    title: the argument's words capitalised (`fix-the-parser` -> `Fix The Parser`)
    source when omitted: the title of the first unchecked note in `.plans/pickup.md` (via `pickup_entry_split`, P-97); interactive terminals choose from a list (max 10, displayed by title); with no notes, open `🟠`/`🔵` issues in `.plans/ISSUES.md` (interactive only); otherwise a typed title (interactive only)
    constraints: the normalised slug must be non-empty; an auto-derived slug from a pickup title is cut at its last `-` before 60 characters (P-97); an explicit slug argument is taken as given; the title is free text and may contain `/`, `&`, `\`, `[`
- `issue <num>` (tokens, optional, after the slug): promote active issue `#<num>` (its id without the `#`: a number or a tracker's key) to this plan (P-50)
- `group` (token, optional, after the slug): draft a group plan from `group-template.md` (P-64)
- `group <id>` (tokens, optional, after the slug): draft a member of group plan `<id>` (P-64)
- reads: `.plans/pickup.md`, `.plans/ISSUES.md`, `.plans/current/`, the plan template (`$AAPP_TEMPLATES/plan-template.md`, then `templates/plan-template.md` in the repository)
- reads config: `aapp.planId` (read and advanced by one); an installed `aapp-planid` provider plugin replaces the local counter; `aapp.subjectMaxLen` (bounds the draft commit subject, P-97)
- reads env: `$EDITOR` (interactive terminals only: offers to open the new plan)

## Preconditions
- Inside a Git repository whose `.plans/` worktree exists

## Failure modes
- `.plans/` missing -> exit 1, stderr `[Plan Switchboard] .plans directory not found.`
- no argument, non-interactive, no pickup notes -> exit 1, stderr `[Draft Refusal] Please specify a plan slug`
- normalised slug empty -> exit 1, stderr `[Draft Refusal] Plan slug cannot be empty.`
- `issue <num>` with `#<num>` archived or unknown -> exit 1, stderr `[Draft Refusal] #<num> is not an active issue in ISSUES.md`; checked before allocation, so no Plan ID is spent and no file is written
- `group <id>` naming no plan in `current/`, or a plan that is not a group plan -> exit 1, `[Draft Refusal] … is not a group plan`; checked before allocation
- Plan ID allocation fails (including a failing provider plugin) -> exit 1, stderr `[Draft Refusal] Failed to allocate Plan ID.`
- plan template not found -> exit 1, stderr `[Draft Refusal] templates/plan-template.md not found.`
- title containing `/`, `&`, `\` or `[` -> no failure: the title appears literally in the plan
- plans-worktree commit refused by a hook -> exit non-zero via `plans_commit` (loud failure, no `|| true`)

## Effects (happy path)
- `.plans/current/P<N>-<slug>.md` is created from the template (with slug bounded to at most 60 chars when drafted from pickup, P-97)
- its title line reads `Plan P-<N>: <Title>`, with the title literal
- every `[YYYY-MM-DD]` reads today's date and every `P-XX` reads `P-<N>`; no template placeholder remains
- bare draft: the pickup entry's text is written verbatim into `## 1. Context & Architectural Goal` in place of the template placeholder, followed by any referenced `.plans/pickup/` paths under `Notes from pickup:` (P-97)
- `aapp.planId` is advanced past `<N>`
- `.plans/state_matrix.md` is re-derived and lists the plan in the incubator
- one commit in the plans worktree, `plan(draft): scaffold P-<N> <slug>`, holds the plan and the matrix via `plans_commit`; the subject is fitted to `aapp.subjectMaxLen` by cutting the slug at a `-` (P-97)
- `issue <num>`: the header reads `* **Target Issue / Milestone:** #<num>`; the issue row's *Target Plan / Fix* becomes `[P-<N>](current/P<N>-<slug>.md)` and its Status `🔵 \`Planned\``; observation cells and the road map are untouched; `ISSUES.md` is in the draft commit
- `group`: the title line reads `# 🧩 Group Plan P-<N>: <Title>` (the marker every verb reads); the header carries `* **Feature Branch:** none` and `* **Members:** P-<N+1>`, its amendments member (P-101): `current/P<N+1>-<slug>-amendments.md` from `amendments-template.md` (`* **Kind:** amendments`, `* **Group:** P-<N>`, `* **Commit Mode:** microcommits`, no Target Files, `## Scope Requests` / `## Decisions` / `## Follow-ups` after §6), in the same commit; a member drafted later is listed before it, so it stays last. A group is refused while the plan-id provider is unreachable (its amendments member could not be linked offline)
- `group <id>`: the plan carries `* **Group:** <id>`, and the group's `* **Members:**` lists `P-<N>`; both files are in the draft commit; the group need not be started
- stdout names the new file, the Plan ID and the `🟣 Under Review` status
- the header carries `* **Changelog:** Changed: <Title>`, the plan's changelog declaration pre-filled from the title (P-48)
- the header records `* **Commit Mode:**` and `* **Changelog Mode:**` from the current config (P-51)

## Exit
- 0 only when every effect above landed

## Tests
Run: `aapp test verb draft`

- `tests/verbs/draft.sh::test_named_draft_scaffolds_and_commits` -> the named-path effects: file, ID, date, matrix, one commit
- `tests/verbs/draft.sh::test_title_with_slash` -> a `/` in the title yields a correct plan, never a half-written one (D1)
- `tests/verbs/draft.sh::test_title_with_ampersand` -> a `&` in the title appears literally, never re-expanded to the matched text (D1)
- `tests/verbs/draft.sh::test_no_placeholders_survive` -> no `P-XX`, `[YYYY-MM-DD]` or `[Feature or Refactor Name]` remains, whatever the title (D1)
- `tests/verbs/draft.sh::test_bare_draft_commits` -> a plan scaffolded from a pickup note is committed, nothing untracked (D3)
- `tests/verbs/draft.sh::test_bare_draft_without_notes_refuses` -> no argument, no notes, non-interactive: exit 1 and no file written
- `tests/verbs/draft.sh::test_commit_takes_only_its_paths` -> another file staged in `.plans` is not swept into the draft commit (C4)
- `tests/verbs/draft.sh::test_draft_prefills_changelog_entry` -> the drafted plan declares `Changed: <Title>`
- `tests/verbs/draft.sh::test_draft_issue_promotes` -> Target Issue, Planned row and link, road map untouched, one commit (P-50)
- `tests/verbs/draft.sh::test_draft_issue_refuses_archived_or_unknown` -> archived or unknown issue: exit non-zero, no file, no Plan ID spent (P-50)
- `tests/verbs/draft.sh::test_draft_records_modes` -> the drafted plan records both modes from config (P-51)
- `tests/verbs/draft.sh::test_draft_group_scaffolds_group_plan` -> `group`: next Plan ID, group heading, group fields, no placeholder, committed (P-64)
- `tests/verbs/draft.sh::test_draft_group_drafts_amendments_member` -> the group's amendments member: kind, group, `microcommits`, no Target Files, its sections after §6, in the draft commit (P-101)
- `tests/verbs/draft.sh::test_draft_member_joins_group` -> `group <id>`: `Group:` in the member, listed in the unstarted group before its amendments member, committed (P-64, P-101)
- `tests/verbs/draft.sh::test_bare_draft_takes_title_only` -> bare draft takes title only, no text in title or slug (P-97)
- `tests/verbs/draft.sh::test_bare_draft_slug_bounded` -> slug from title bounded to 60 characters cut at '-' (P-97)
- `tests/verbs/draft.sh::test_bare_draft_copies_text` -> bare draft writes text into §1 and references pickup files (P-97)
- `tests/verbs/draft.sh::test_draft_subject_fits_limit` -> draft commit subject fits aapp.subjectMaxLen (P-97)

