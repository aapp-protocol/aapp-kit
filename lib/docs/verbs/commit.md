# commit ["<msg>"] [amend] [adopt <sha>...] [agent <A> vendor <V> model <M>] [note "<text>"]

## Ingress
- positional forms:
    - `"<message>"`: commits staged files in current worktree, attributes commit, and records `sha (branch)` in active plan
    - `amend ["<message>"]`: amends last commit (message kept when omitted), updates recorded SHA in active plan
    - `adopt <sha>...`: records existing commit(s) in active plan without code commit (repair path)
- optional attribution tokens:
    - `agent <Agent>`: AI agent name override
    - `vendor <Vendor>`: AI vendor name override
    - `model <Model>`: AI model ID override
    - `note "<text>"`: note text attached to commit (routes with identity to `refs/notes/ai`, without identity to `refs/notes/commits`; operates across all modes)
- reads: active execution buffer `$(git rev-parse --git-path aapp_active_plan)` (or single `⚡ In Development` plan)
- reads: `.plans/current/<plan>.md` (`* **Commits:**` header line)
- reads config: `aapp.aiAttribution` (attribution mode: `none`, `lax`, `strict`, `notes`)
- reads config: `aapp.aiNotes` (parallel AI git notes: `true`, `false`)

## Preconditions
- Inside a Git worktree of an AAPP-governed repository
- An active plan is bound in the current worktree's buffer (or exactly one plan is `⚡ In Development`)
- The active plan is `⚡ In Development`
- For standard commit: at least one file is staged (`git diff --cached --quiet` exits non-zero)
- For `amend`: HEAD exists and has not been pushed to shared remote
- For `adopt`: each specified `<sha>` must exist and be contained in some branch
- In `strict` attribution mode: valid AI identity must resolve (via tokens, env, or worktree config)

## Failure modes
- no active plan in development -> exit 1, stderr `[Commit Refusal] No plan is currently ⚡ In Development` (or names choices with `aapp active <id>`)
- plan bound in another worktree -> exit 1, stderr naming the holding worktree
- standard commit with nothing staged -> exit 1, stderr `Nothing staged to commit`
- code commit hook refusal -> exit non-zero with hook output; active plan header remains untouched
- plan commit index lock timeout -> retry up to 5 times; if exhausted, exit non-zero and print `aapp commit adopt <sha>` repair command
- `strict` mode without identity -> exit 1 during pre-flight before code commit
- `adopt` with unknown or branchless SHA -> exit 1, active plan header untouched

## Effects (happy path)
- code commit:
    - staged files are committed in current worktree
    - commit message is decorated with emailless trailers per attribution mode (`lax`, `strict`)
    - note is attached in parallel when `note "<text>"` is provided or when `aapp.aiNotes` is `true`
- plan recording:
    - active plan's `* **Commits:**` header line is updated with the new commit `<sha> (<branch>)`
    - plan file is committed alone in `.plans/` worktree with subject `plan(record): record <short-sha> for P-NN` (or `plan(record): adopt <n> commit(s) for P-NN`) via `plans_commit`
- for `amend`:
    - old recorded SHA is replaced with new SHA in `* **Commits:**` header line
- for `adopt`:
    - existing SHAs not already in header are appended with their containing branch; prints a warning that commits did not pass through helper

## Exit
- 0 on success
- non-zero on any pre-flight failure, hook refusal, or git error

## Tests
Run: `aapp test verb commit`

- `tests/verbs/commit.sh::test_records_sha_and_branch` -> code commit's SHA and branch appear in plan header, plan committed
- `tests/verbs/commit.sh::test_plan_commit_is_pathspec_limited` -> another plan staged in `.plans` is not swept into commit
- `tests/verbs/commit.sh::test_refuses_without_active_plan` -> no `⚡` plan: exit 1, no commit
- `tests/verbs/commit.sh::test_preflight_fails_before_code_commit` -> missing identity in `strict`: exit 1, nothing committed
- `tests/verbs/commit.sh::test_detached_head_recorded` -> commit on detached HEAD recorded as `(detached)`
- `tests/verbs/commit.sh::test_refuses_nothing_staged` -> empty index: exit 1, no commit, header unchanged
- `tests/verbs/commit.sh::test_rejected_commit_records_nothing` -> refusing hook: exit non-zero, header unchanged
- `tests/verbs/commit.sh::test_amend_replaces_recorded_sha` -> amend swaps old SHA for new SHA in header
- `tests/verbs/commit.sh::test_strict_attributes_both_commits` -> trailers on code and plan commits
- `tests/verbs/commit.sh::test_lax_human_commit_needs_no_identity` -> lax without identity commits without trailers
- `tests/verbs/commit.sh::test_note_token_attached_in_notes_mode` -> notes mode attaches git note
- `tests/verbs/commit.sh::test_linked_worktree_records_its_own_plan` -> linked worktrees record into respective plans
- `tests/verbs/commit.sh::test_adopt_records_existing_commit` -> adopt records SHA with branch and warning
- `tests/verbs/commit.sh::test_adopt_refuses_unknown_sha` -> unknown SHA exits 1
- `tests/verbs/commit.sh::test_adopt_skips_recorded_sha` -> already-recorded SHA not duplicated
