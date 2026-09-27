# freeze <id>

## Ingress
- `id` (positional, required): the plan to freeze
    accepted forms: `P-<N>`, bare `<N>`, the filename stem, or a slug prefix
    constraints: must resolve to exactly one plan in `.plans/current/`; a `#`-prefixed value (an issue ID) is refused by the resolver
- reads: the plan file (§5 Open Questions, §4 Target Files via `lib/aapp-lib.sh`), `.plans/current/`
- reads config: `aapp.planState.*` (custom statuses, via the matrix re-derivation); the lifecycle hook registry for `on-freeze`

## Preconditions
- Inside a Git repository whose `.plans/current/` exists
- The plan is in the incubator (`🟣 Under Review`, `📝 Refining`, or a custom status from `aapp.planState.*`)

## Failure modes
- no `id` -> exit 1, stderr `You must specify a target plan for 'freeze'.`
- `id` resolves to no plan -> exit 1, stderr `Plan '<id>' not found`
- the plan is `🔷 Frozen`, `⚡ In Development`, `🟥 BLOCKED`, or carries a status no registry entry matches -> exit 1, stderr `[Freeze Refusal] Plan is not in the incubator`; the plan is unchanged (#89)
- an unchecked `* [ ]` item under `## ❓ 5. Open Questions` -> exit 1, stderr `[Freeze Refusal]` lists each unresolved question; the plan is unchanged
- no path under `### 📂 Target Files` in §4 -> exit 1, stderr `[Freeze Refusal] Plan declares no Target Files`; the plan is unchanged
- an `on-freeze` hook vetoes (non-zero) -> exit 1 and the plan stays unfrozen
    ⚠️ Divergence: the hook runs after the freeze is committed, so a veto exits 1 but leaves the plan frozen and committed.
- plans-worktree commit refused by a hook -> exit non-zero, stderr names the refusal
    ⚠️ Divergence (#81): the commit runs under `|| true`; the verb exits 0 with the transition staged but uncommitted.

## Effects (happy path)
- the plan's Status line reads `🔷 Frozen`
- a `*(Marked: **PROPOSED** …)*` marker, when present, reads `*(Marked: **LOCKED** — Greenlit for implementation)*`
- `## 📦 6. Change Log` gains a dated line: `Plan locked and frozen into 🔷 Frozen via freeze.`
- `.plans/state_matrix.md` is re-derived and lists the plan under Frozen
- one commit in the plans worktree, `plan(freeze): lock blast radius and greenlight <id>`, holds the plan and the matrix
- the `on-freeze` lifecycle event is dispatched with the plan ID, file and Target Files
- §2 and §4 of the plan are design-locked from this commit on (enforced by the pre-commit hook, not by this verb)

## Exit
- 0 only when every effect above landed

## Tests
Run: `aapp test verb freeze`

- `tests/verbs/freeze.sh::test_freezes_and_commits` -> status, changelog line, matrix and one commit
- `tests/verbs/freeze.sh::test_refuses_unresolved_questions` -> an unchecked §5 item: exit 1, plan unchanged
- `tests/verbs/freeze.sh::test_refuses_without_target_files` -> an empty Target Files section: exit 1, plan unchanged
- `tests/verbs/freeze.sh::test_refuses_unknown_plan` -> an unresolvable `id`: exit 1
- `tests/verbs/freeze.sh::test_refuses_non_incubator_plan` -> freezing a `🔷 Frozen` plan again: exit 1, plan unchanged (#89)
