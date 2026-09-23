# 🗺️ Plan P-34: Verb Behaviour Contracts
* **Created:** 2026-09-23 | **Last Refined:** 2026-09-23
* **Target Issue / Milestone:** #[Issue ID or Milestone] *(if this plan was promoted from `ISSUES.md`, put the issue ID here and link this file back in that issue's `Proposed Fix / Target Plan` cell — the issue stays open until the fix ships)*
* **Plan ID:** P-34
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->
<!-- * **Blocked On:** ISSUE-00X   <- add this line while BLOCKED, remove it when unblocked -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 6. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 1. Context & Architectural Goal

### Problem Statement
Each CLI verb's behaviour exists only in its implementation. `lib/verbs.tsv` carries a one-line help
string per verb — user-facing, and not a contract: *"Scaffold blueprint from template, stamp ID &
date, register in matrix"* asserts three things, none of them checkable, and omits whether the file
is committed, what happens with no argument, and where the ID comes from.

Three consequences, all observed in this repository:

1. **Defects are unfalsifiable.** `aapp draft` with no argument crashes on `sed`, writes a plan with
   every template placeholder intact (`Plan P-XX`, `[YYYY-MM-DD]`), and leaves it untracked — yet
   nothing states that it shouldn't, so the test suite's 427 assertions do not cover it.
2. **Skills substitute their own prose.** `.agents/skills/aapp-done/SKILL.md` instructs a raw `mv`
   because no authoritative document says `aapp done` performs the move *plus* the ledger append,
   matrix removal and commit. Per-skill prose is a drifting stand-in for a missing contract.
3. **Implicit ingress is invisible.** Pickup notes, `git config aapp.planId`, and
   `templates/plan-template.md` are all inputs to `draft`, and none are documented. An agent cannot
   infer them, and they are exactly where the defects live.

### Architectural Goal
Establish a per-verb behaviour contract as a single source of truth that humans read, agents resolve
mechanically, and tests are derived from.

1. One contract per daily verb at `lib/docs/verbs/<verb>.md`, covering **ingress**, preconditions,
   failure modes, happy-path effects, and exit semantics.
2. A fifth column in `lib/verbs.tsv` pointing at each contract, so the registry agents already read
   resolves to the contract in the same read.
3. Bidirectional correspondence: no declared verb without a contract, no contract without a row.
4. Tests derived from each contract — failure modes first, then happy-path effects.
5. The three defects the survey found (D1–D3, §2.4) fixed against those tests.

**Scope boundary.** The eleven `daily`-tier verbs only. `aapp help` remains user-facing and is not
extended to render contracts; the contract is agent- and test-facing, reached via `verbs.tsv`.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`. A verb row whose contract is missing is an error, not
  a degraded mode; the correspondence check fails closed rather than skipping unmatched rows.

### 2.1 Contract Location & Shape

Contracts live at `lib/docs/verbs/<verb>.md`, beside `lib/verbs.tsv`. `lib/` is packaged by
`cp -r` (`lib/cmd_install.sh:85`), so subdirectories ship to adopters with no packaging change; the
only glob is `lib/*.sh` for `chmod`, which neither matches `.md` nor recurses.

Five fixed headings per contract, in this order:

```markdown
# <verb> [args]

## Ingress
- `<arg>` (positional, optional): what it is
    source when omitted: where the value comes from instead
    constraints: what a valid value must satisfy
- reads: <files consulted>
- reads config: <git config keys, and whether read or mutated>

## Preconditions
- <state that must hold before the verb runs>

## Failure modes
- <condition> -> exit <code>, <what is printed and to which stream>

## Effects (happy path)
- <one assertable state change per line>

## Exit
- 0 only when every effect above landed
```

**Ingress is a separate axis from preconditions**, not a subset: preconditions are *state* ("inside a
git repository"), ingress is *what the verb accepts and where it comes from*. D1 is an ingress
defect — the bare path takes a pickup note as the title and feeds it to an unescaped `sed`. Each
ingress item also generates its own failure cases (absent, malformed, colliding), which is what makes
the failure-modes section enumerable rather than invented.

### 2.2 Registry Linkage

`lib/verbs.tsv` gains a fifth tab-separated column holding an explicit repo-relative path:

```
# verb	tier	standalone	description	contract
draft	daily	yes	Scaffold blueprint from template, stamp ID & date, register in matrix	lib/docs/verbs/draft.md
```

An explicit path rather than a name derived from the verb: hyphenated verbs (`freeze-start`,
`plan-status`) then map wherever needed, and `lib/cmd_help.sh` already parses this file positionally,
so a fifth field costs nothing. `cmd_help.sh` reads fields 1/2/4 and must continue to ignore field 5.

### 2.3 Correspondence Check

Bidirectional, fail-closed: every `daily` row's contract path resolves to an existing file, and every
file under `lib/docs/verbs/` is referenced by exactly one row. This is what stops the contract set
drifting the way per-skill prose did.

### 2.4 Defects This Plan Fixes

Found by probing the daily verbs in a clean sandbox (2026-09-23). Each becomes a failing test derived
from the contract before it is fixed.

| ID | Verb | Defect |
| :--- | :--- | :--- |
| **D1** | `draft` (bare) | `cmd_plan.sh:324` interpolates `${title}` into `sed -E "s/.../${title}/"` unescaped. The default onboarding pickup note contains `/` (`.agents/CODEMAP.md`), terminating the expression. The command prints `sed: -e expression #1, char 113: unknown option to 's'`, still writes the file, leaves every placeholder unreplaced (`Plan P-XX`, `[YYYY-MM-DD]`, `Plan ID: P-XX`), and leaves it **untracked**. Fires on the first `aapp draft` a new adopter runs. Any title containing `/`, `&` or `\` triggers it. |
| **D2** | `done` | `cmd_plan.sh:600` derives the ledger Impact Summary by grepping the plan for `**What:**`, a field `templates/plan-template.md` never emits, so the column is always blank — silently, since the write is guarded by `if [ -f ... ]`. `cmd_plan.sh:602` hardcodes the Target Issue column to `None` even when the plan header names one. Blank rows exist today for `P-33`, `P-31` and `P-26`. |
| **D3** | `draft` (bare) | The named path commits; the bare path leaves the new plan untracked, so the crashed plan from D1 is outside history and cannot be reverted. |

**Verified not defective.** The lifecycle verbs commit correctly and record the right SHA: in the
sandbox `aapp done` produced a `plan(done):` commit and the ledger SHA matched code `HEAD`. Earlier
suspicion that `|| true` in `cmd_plan.sh` was dropping lifecycle commits was wrong — in this
repository those commits are rejected by the attribution hook reaching into the `.plans` worktree,
which is a separate concern and out of scope here. `freeze` and `start` refuse correctly with
actionable diagnostics; `matrix --check` detects drift without writing.

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Contract Authoring (Source of Truth First)
- [ ] Task 1.1: Author `lib/docs/verbs/draft.md`, `freeze.md`, `start.md`, `freeze-start.md`, `done.md` — the five lifecycle verbs — to the §2.1 shape, read from the current implementation. Record behaviour as it *should* be, marking any line that current code violates.
- [ ] Task 1.2: Author `lib/docs/verbs/status.md`, `plan.md`, `plan-status.md`, `matrix.md`, `active.md`, `test.md` — the six remaining daily verbs.
- [ ] Task 1.3: Add the fifth `contract` column to `lib/verbs.tsv` for all `daily` rows, and confirm `lib/cmd_help.sh` still renders every tier unchanged (it reads fields 1/2/4).

### Phase 2: Failure-First Test Derivation (Red 🔴)
- [ ] Task 2.1: Add `tests/verb_contracts_test.sh` with the bidirectional correspondence check (§2.3): every `daily` row's contract path exists, every file under `lib/docs/verbs/` is referenced by exactly one row.
- [ ] Task 2.2: Derive failure-mode assertions from each contract's *Failure modes* section, including the three defect cases: D1 (title containing `/`), D2 (ledger Impact Summary and Target Issue populated), D3 (bare `draft` leaves no untracked file).
- [ ] Task 2.3: Derive happy-path assertions from each contract's *Effects* section.
- [ ] Task 2.4: Run `bash tests/verb_contracts_test.sh` and confirm the D1/D2/D3 assertions FAIL (Red 🔴) against current code.

### Phase 3: Defect Remediation (Green 🟢)
- [ ] Task 3.1: Fix D1 — escape `${title}` (and any interpolated value) before `sed` substitution in `cmd_draft`, or replace the placeholder substitution with a non-`sed` mechanism. A title containing `/`, `&` or `\` must produce a correct plan or a clean refusal, never a half-written one.
- [ ] Task 3.2: Fix D3 — the bare `draft` path stages and commits its new plan exactly as the named path does.
- [ ] Task 3.3: Fix D2 — derive the ledger Impact Summary from a field the template actually emits (or state `None` explicitly), and populate Target Issue from the plan header instead of hardcoding `None`.
- [ ] Task 3.4: Re-run `bash tests/verb_contracts_test.sh` and confirm Green 🟢.

### Phase 4: Full Suite Regression Verification
- [ ] Task 4.1: Run `./aapp test strict quiet` across all discovered suites and verify zero regressions.

### Phase 5: Documentation & Protocol Sync
- [ ] Task 5.1: Update `ARCHITECTURE.md` with the contract-as-source-of-truth invariant and the `verbs.tsv` linkage.
- [ ] Task 5.2: Update `.agents/CODEMAP.md` to name `lib/docs/verbs/` as the canonical owner of verb behaviour.
- [ ] Task 5.3: Update `CHANGELOG.md` under `### Added` (contracts) and `### Fixed` (D1–D3).

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `NEW FILE` -> `lib/docs/verbs/draft.md` -> Behaviour contract for `draft`
- [ ] `NEW FILE` -> `lib/docs/verbs/freeze.md` -> Behaviour contract for `freeze`
- [ ] `NEW FILE` -> `lib/docs/verbs/start.md` -> Behaviour contract for `start`
- [ ] `NEW FILE` -> `lib/docs/verbs/freeze-start.md` -> Behaviour contract for `freeze-start`
- [ ] `NEW FILE` -> `lib/docs/verbs/done.md` -> Behaviour contract for `done`
- [ ] `NEW FILE` -> `lib/docs/verbs/status.md` -> Behaviour contract for `status`
- [ ] `NEW FILE` -> `lib/docs/verbs/plan.md` -> Behaviour contract for `plan`
- [ ] `NEW FILE` -> `lib/docs/verbs/plan-status.md` -> Behaviour contract for `plan-status`
- [ ] `NEW FILE` -> `lib/docs/verbs/matrix.md` -> Behaviour contract for `matrix`
- [ ] `NEW FILE` -> `lib/docs/verbs/active.md` -> Behaviour contract for `active`
- [ ] `NEW FILE` -> `lib/docs/verbs/test.md` -> Behaviour contract for `test`
- [ ] `NEW FILE` -> `tests/verb_contracts_test.sh` -> Correspondence check and contract-derived assertions
- [ ] `lib/verbs.tsv` -> Add fifth `contract` column for all daily rows
- [ ] `lib/cmd_plan.sh` -> Fix D1 (unescaped title in sed), D2 (ledger summary & target issue), D3 (bare draft commit)
- [ ] `ARCHITECTURE.md` -> Record the contract-as-source-of-truth invariant and verbs.tsv linkage
- [ ] `.agents/CODEMAP.md` -> Name lib/docs/verbs/ as canonical owner of verb behaviour
- [ ] `CHANGELOG.md` -> Record contracts under Added and D1-D3 under Fixed

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/cmd_help.sh` -> Must keep rendering unchanged from fields 1/2/4; `aapp help` stays user-facing and does not gain contract rendering.
- [ ] `.agents/skills/*` -> Routing skills through the CLI is downstream work, gated on these contracts existing.
- [ ] `.githooks/*` -> Guard engine self-protection.
- [ ] `lib/cmd_init.sh` -> Bootstrap target resolution is out of scope.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [ ] **Question 1 — Where is the correspondence check enforced?** `tests/verb_contracts_test.sh`
  alone (runs with `aapp test`, no commit cost), `lib/planning_health.sh` (runs under strict test
  mode and adopter audit), or `.githooks/aapp-pre-commit` (blocks a commit that adds a verb without
  a contract). Pre-commit is the only option that prevents drift at the moment it is introduced, but
  it puts a docs check on the commit path for every adopter.
* [ ] **Question 2 — Does a contract cover `test` at all?** `aapp test` delegates to adopter runners
  (`aapp.testCommand`, npm, cargo, composer, go) via `cmd_test.sh`. Its effects are therefore
  project-defined, and a contract can only specify discovery and delegation, not outcomes. Include it
  with that limit stated, or drop it from the daily set and document ten verbs.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-09-23:** Drafted from a session that probed the daily verbs in a clean sandbox and found
  three defects (D1–D3) none of which any document forbade. Establishes `lib/docs/verbs/<verb>.md`
  as the source of truth for verb behaviour — ingress, preconditions, failure modes, effects, exit —
  linked from a fifth `contract` column in `lib/verbs.tsv` so agents resolve it in the same read that
  tells them the verb exists. Tests are derived from the contracts, failure modes first. Corrects an
  earlier suspicion recorded elsewhere in this session: the lifecycle verbs do commit correctly and
  record the right SHA; the missing commits in this repository come from the attribution hook
  reaching into the `.plans` worktree, which is out of scope here.
