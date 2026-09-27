# draft [slug]

## Ingress
- `slug` (positional, optional): the plan's slug and title source
    normalised: lowercased, spaces and `_` become `-`, anything outside `[a-z0-9-]` dropped, runs of `-` collapsed
    title: the argument's words capitalised (`fix-the-parser` -> `Fix The Parser`)
    source when omitted: the first unchecked note in `.plans/pickup.md`; interactive terminals choose from a list (max 10) or type a title; with no notes, open `🟠`/`🔵` issues in `.plans/ISSUES.md` (interactive only); otherwise a typed title (interactive only)
    constraints: the normalised slug must be non-empty; the title is free text and may contain `/`, `&`, `\`, `[`
- reads: `.plans/pickup.md`, `.plans/ISSUES.md`, `.plans/current/`, the plan template (`$AAPP_TEMPLATES/plan-template.md`, then `templates/plan-template.md` in the repository)
- reads config: `aapp.planId` (read and advanced by one); an installed `aapp-planid` provider plugin replaces the local counter
- reads env: `$EDITOR` (interactive terminals only: offers to open the new plan)

## Preconditions
- Inside a Git repository whose `.plans/` worktree exists

## Failure modes
- `.plans/` missing -> exit 1, stderr `[Plan Switchboard] .plans directory not found.`
- no argument, non-interactive, no pickup notes -> exit 1, stderr `[Draft Refusal] Please specify a plan slug`
- normalised slug empty -> exit 1, stderr `[Draft Refusal] Plan slug cannot be empty.`
- Plan ID allocation fails (including a failing provider plugin) -> exit 1, stderr `[Draft Refusal] Failed to allocate Plan ID.`
- plan template not found -> exit 1, stderr `[Draft Refusal] templates/plan-template.md not found.`
- title containing `/`, `&`, `\` or `[` -> no failure: the title appears literally in the plan
- plans-worktree commit refused by a hook -> exit non-zero, stderr names the refusal
    ⚠️ Divergence (#81): the commit is run under `|| true`; the refusal is swallowed and the verb exits 0 with the plan staged but uncommitted.

## Effects (happy path)
- `.plans/current/P<N>-<slug>.md` is created from the template
- its title line reads `Plan P-<N>: <Title>`, with the title literal
- every `[YYYY-MM-DD]` reads today's date and every `P-XX` reads `P-<N>`; no template placeholder remains
- `aapp.planId` is advanced past `<N>`
- `.plans/state_matrix.md` is re-derived and lists the plan in the incubator
- one commit in the plans worktree, `plan(draft): scaffold P-<N> <slug>`, holds the plan and the matrix; nothing is left untracked
- stdout names the new file, the Plan ID and the `🟣 Under Review` status

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
