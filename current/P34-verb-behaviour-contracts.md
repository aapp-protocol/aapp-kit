# 🗺️ Plan P-34: Verb Behaviour Contracts
* **Created:** 2026-09-23 | **Last Refined:** 2026-09-23
* **Target Issue / Milestone:** #78 *(D2 only; D1 and D3 are unfiled defects this plan introduces and fixes)*
* **Plan ID:** P-34
* **Status:** 📝 Refining
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
5. The three defects the survey found (D1–D3, §2.6) fixed against those tests.

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

## Tests
Run: `aapp test verb <verb>`

- `tests/verbs/<verb>.sh::<test_name>` -> which failure mode or effect this covers
```

**Ingress is a separate axis from preconditions**, not a subset: preconditions are *state* ("inside a
git repository"), ingress is *what the verb accepts and where it comes from*. D1 is an ingress
defect — the bare path takes a pickup note as the title and feeds it to an unescaped `sed`. Each
ingress item also generates its own failure cases (absent, malformed, colliding), which is what makes
the failure-modes section enumerable rather than invented.

**The `## Tests` section exists so a reader cross-checks without searching.** The `Run:` line is a
copyable command; the identifier list below it maps each test to the failure mode or effect it
covers. A failure mode with no test listed is a visible hole — which is exactly D1's situation today:
bare `draft` crashes, nothing covers it, and nothing declared that anything should, so the absence
was invisible. The `path::name -> asserts …` syntax is deliberately identical to the plan-level
`### 🧪 Required Tests` convention, so one syntax serves both.

### 2.2 Registry Linkage

`lib/verbs.tsv` gains a fifth tab-separated column holding an explicit repo-relative path:

```
# verb	tier	standalone	description	contract
draft	daily	yes	Scaffold blueprint from template, stamp ID & date, register in matrix	lib/docs/verbs/draft.md
```

An explicit path rather than a name derived from the verb: hyphenated verbs (`freeze-start`,
`plan-status`) then map wherever needed.

**`lib/cmd_help.sh` must be changed, not merely left alone.** `cmd_help.sh:38` reads the file with
four variable names:

```bash
while IFS="$TAB" read -r verb tier standalone desc || [ -n "$verb" ]; do
```

`read` assigns **all trailing fields to the last variable**, so a fifth column lands inside `$desc`.
Verified: given a five-field line, `desc` evaluates to
`Scaffold blueprint<TAB>lib/docs/verbs/draft.md`. Every daily verb would print its contract path in
`aapp help`, and Test 56 in `tests/install_test.sh` (tiered help matches `verbs.tsv`) would fail.

The fix is one line — absorb the extra fields explicitly:

```bash
while IFS="$TAB" read -r verb tier standalone desc contract rest || [ -n "$verb" ]; do
```

`cmd_help.sh` is therefore a **Target File**, not Out of Bounds. What stays out of scope is
*rendering* the contract in help output: `aapp help` remains user-facing and gains nothing but the
parse fix.

### 2.3 Correspondence Check

Bidirectional, fail-closed: every `daily` row's contract path resolves to an existing file, and every
file under `lib/docs/verbs/` is referenced by exactly one row. This is what stops the contract set
drifting the way per-skill prose did.

### 2.4 Verb Test Location & Granular Execution

Contract-derived tests live at `tests/verbs/<verb>.sh` — one file per verb, no `_test.sh` suffix. The
suffix exists in `tests/` to disambiguate suites in a flat directory; the `verbs/` subdirectory does
that by location, so `tests/verbs/draft.sh` is self-explanatory.

`lib/cmd_test.sh` gains a `verb` token:

| Invocation | Runs |
| :--- | :--- |
| `aapp test verb draft` | `tests/verbs/draft.sh` alone |
| `aapp test verb` | every `tests/verbs/*.sh` |
| `aapp test` | the flat `tests/*_test.sh` suites **and** every `tests/verbs/*.sh` |
| `aapp test list` | both sets, verb suites labelled as such |

**The `verb` token is required, not optional.** A bare `aapp test draft` would be friendlier, but two
verb names collide with existing suite names: `matrix` (`tests/matrix_test.sh` **and**
`tests/verbs/matrix.sh`) and `test` itself. The current filter matches by substring
(`cmd_test.sh:199-201`), so `aapp test matrix` is already meaningful and would silently change
meaning — or ambiguously match both. Requiring the token keeps every existing invocation working and
keeps the two sets addressable without a disambiguation rule. `aapp test list` must show both sets so
the split is discoverable.

Three mechanical notes:

1. **Discovery is two passes, not a widened glob.** `cmd_test.sh:182` currently runs
   `find "$test_dir" -maxdepth 1 -name '*_test.sh'`. `tests/verbs/` is invisible to it, so a bare
   `aapp test` needs a second `find` over `tests/verbs/*.sh`. Two reasons this is the design rather
   than a workaround for the existing find depth:
   - **Tight feedback while changing behaviour.** A separately addressable set makes
     `aapp test verb draft` a first-class path, not a filter over a shared pool. Modifying a verb
     means re-running seconds of its own tests instead of 65s of everything — which is what keeps
     the loop usable while adjusting a verb or writing its contract. This is the primary reason.
   - **Convention isolation.** `tests/verbs/*.sh` and the flat `tests/*_test.sh` suites keep their
     own naming rules, so neither has to accommodate the other.
2. **Execution and reporting are already granular.** Each suite runs as its own
   `bash "$suite"` subshell and reports through `print_test_summary()`, so one file per verb yields
   per-verb results through the existing aggregation loop with no new reporting code.
3. **Existing suites are not relocated.** `install_test.sh`, `matrix_test.sh` and the rest keep their
   assertions and their sandbox setup. `tests/verbs/` is where *new* contract-derived tests land; a
   contract may still reference an existing suite where coverage already exists.

This also keeps the `Run:` line to a single command per contract, which is the point: `aapp test verb
draft` completes in seconds against 65s for the full sweep.

### 2.5 D1 Remediation: Substitution Mechanism

`sed` is the wrong tool for interpolating arbitrary user text, but the obvious replacement — bash
parameter expansion — carries two traps of its own. Both were found by testing the candidate, not by
reading it, and both must be covered by tests rather than assumed away.

**Trap 1 — brackets are glob metacharacters.** The template placeholder contains `[`:

```bash
content="${content//Plan P-XX: [Feature or Refactor Name]/…}"   # matches nothing
```

`[Feature or Refactor Name]` is parsed as a character class, so the substitution silently does
nothing and the placeholder survives — the same failure D1 produces, arrived at differently.

**Trap 2 — `&` in the replacement.** With the brackets escaped, a title containing `&` re-expands to
the matched text:

```
title="fix .agents/CODEMAP.md & stuff"
→ "Plan P-9: fix .agents/CODEMAP.md Plan P-XX: [Feature or Refactor Name] stuff"
```

**What works** is quoting both operands so neither is treated as a pattern:

```bash
pat="Plan P-XX: [Feature or Refactor Name]"
rep="Plan P-${num}: ${title}"
content="${content//"$pat"/"$rep"}"
```

Verified on bash 5.2. **Portability caveat:** `&`-in-replacement and quoted-operand semantics differ
across bash versions, and macOS ships bash 3.2. This repository documents no minimum bash version and
its scripts use `#!/usr/bin/env bash`, so the implementer must either verify the chosen form on 3.2 or
declare a floor. An `awk`-based substitution with the title passed via `-v` avoids both traps and the
version question entirely, and is the safer default if 3.2 cannot be tested.

### 2.6 Defects This Plan Fixes

Found by probing the daily verbs in a clean sandbox (2026-09-23). Each becomes a failing test derived
from the contract before it is fixed.

| ID | Verb | Defect |
| :--- | :--- | :--- |
| **D1** | `draft` (bare) | `cmd_plan.sh:324` interpolates `${title}` into `sed -E "s/.../${title}/"` unescaped. The default onboarding pickup note contains `/` (`.agents/CODEMAP.md`), terminating the expression. The command prints `sed: -e expression #1, char 113: unknown option to 's'`, still writes the file, leaves every placeholder unreplaced (`Plan P-XX`, `[YYYY-MM-DD]`, `Plan ID: P-XX`), and leaves it **untracked**. Fires on the first `aapp draft` a new adopter runs. Any title containing `/`, `&` or `\` triggers it. |
| **D2** | `done` | **Already filed as `#78`** (2026-09-22) — rediscovered independently by this survey, which is itself evidence for the plan's premise. `cmd_plan.sh:600` derives the ledger Impact Summary by grepping the plan for `**What:**`, a field `templates/plan-template.md` never emits, so the column is always blank — silently, since the write is guarded by `if [ -f ... ]`. `cmd_plan.sh:602` hardcodes the Target Issue column to `None` even when the plan header names one. Blank rows exist for `P-24`, `P-26`, `P-27`, `P-30` per `#78`, and this survey added `P-31` and `P-33`. |
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
- [ ] Task 1.2: Author `lib/docs/verbs/status.md`, `plan.md`, `plan-status.md`, `matrix.md`, `active.md`, `test.md` — the six remaining daily verbs. `test.md` states kit-suites-only per §5 Q2 and marks the adopter-runner delegation in `cmd_test.sh` as a recorded divergence, not as documented behaviour.
- [ ] Task 1.3: Add the fifth `contract` column to `lib/verbs.tsv` for all `daily` rows, and confirm `lib/cmd_help.sh` still renders every tier unchanged (it reads fields 1/2/4).

### 🧪 Required Tests (Failure & Boundary Assertions)
*Per-test identifiers for the files declared in §4. Failure modes first.*
- [ ] `tests/verbs/draft.sh::test_title_with_slash` -> asserts a title containing `/` yields a correct plan or a clean refusal, never a half-written one with placeholders intact (D1)
- [ ] `tests/verbs/draft.sh::test_title_with_ampersand` -> asserts a title containing `&` appears literally in the plan, never re-expanded to the matched text (§2.5 trap 2)
- [ ] `tests/verbs/draft.sh::test_no_placeholders_survive` -> asserts no `P-XX`, `[YYYY-MM-DD]` or `[Feature or Refactor Name]` remains in any scaffolded plan, whatever the title (§2.5 trap 1)
- [ ] `tests/verbs/draft.sh::test_bare_draft_commits` -> asserts a plan scaffolded from a pickup note is staged and committed, leaving nothing untracked (D3)
- [ ] `tests/verbs/done.sh::test_ledger_row_populated` -> asserts the archive ledger row carries a non-empty Impact Summary and the plan header's Target Issue rather than hardcoded `None` (D2)
- [ ] `tests/verb_contracts_test.sh::test_registry_contract_correspondence` -> asserts every daily row resolves to a contract file and every contract is referenced by exactly one row
- [ ] `tests/verb_contracts_test.sh::test_declared_test_files_exist` -> asserts every file named in a contract's `## Tests` section exists
- [ ] `tests/install_test.sh::test_help_ignores_contract_column` -> asserts `aapp help` output contains no contract path after the fifth column is added (F1 regression guard)
- [ ] `tests/install_test.sh::test_develop_hook_seeding` -> asserts the develop engine is absent after `aapp init`, present after `aapp develop`, and unchanged after a second `aapp develop`

### Phase 2: Failure-First Test Derivation (Red 🔴)
- [ ] Task 2.1: Add the `verb` token to `lib/cmd_test.sh` (§2.4): `aapp test verb <name>` runs `tests/verbs/<name>.sh`, `aapp test verb` runs all of them, and a bare `aapp test` sweeps `tests/verbs/*.sh` in a second discovery pass alongside the flat `tests/*_test.sh` suites.
- [ ] Task 2.2: Add `tests/verb_contracts_test.sh` with the bidirectional correspondence check (§2.3): every `daily` row's contract path exists, every file under `lib/docs/verbs/` is referenced by exactly one row, and every test **file** named in a contract's `## Tests` section exists.
- [ ] Task 2.3: Add `templates/aapp-pre-commit-develop` running the same correspondence check, and the presence-guarded invocation block in `templates/pre-commit`.
- [ ] Task 2.3b: Wire `lib/cmd_develop.sh` to copy the engine into `$REPO_ROOT/.githooks/` and ensure the wrapper block exists idempotently (the live wrapper is preserved by `cmd_init.sh`, so it will not gain the block by re-propagation). Verify: absent after a plain `aapp init`, present after `aapp develop`, and running `aapp develop` twice changes nothing.
- [ ] Task 2.3c: Wire `lib/cmd_uninstall.sh` to remove the engine and its wrapper block when invoked inside a repository that has them, and to skip silently when no repository resolves.
- [ ] Task 2.4: Derive failure-mode assertions into `tests/verbs/<verb>.sh`, one file per verb, including the three defect cases: D1 (title containing `/`), D2 (ledger Impact Summary and Target Issue populated), D3 (bare `draft` leaves no untracked file).
- [ ] Task 2.5: Derive happy-path assertions from each contract's *Effects* section into the same files.
- [ ] Task 2.6: Run `aapp test verb` and confirm the D1/D2/D3 assertions FAIL (Red 🔴) against current code.

### Phase 3: Defect Remediation (Green 🟢)
- [ ] Task 3.1: Fix D1 per §2.5 — replace the `sed` placeholder substitution in `cmd_draft`. A title containing `/`, `&`, `\` or `[` must produce a correct plan or a clean refusal, never a half-written one. Whichever mechanism is chosen, the escaping traps in §2.5 must be covered by tests, not assumed.
- [ ] Task 3.2: Fix D3 — the bare `draft` path stages and commits its new plan exactly as the named path does.
- [ ] Task 3.3: Fix D2 — derive the ledger Impact Summary from a field the template actually emits (or state `None` explicitly), and populate Target Issue from the plan header instead of hardcoding `None`.
- [ ] Task 3.4: Re-run `aapp test verb` and `aapp test verb_contracts` and confirm Green 🟢.

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
- [ ] `NEW FILE` -> `tests/verb_contracts_test.sh` -> Bidirectional correspondence check (registry, contracts, named test files)
- [ ] `NEW FILE` -> `tests/verbs/draft.sh` -> Contract-derived tests for `draft` (covers D1, D3)
- [ ] `NEW FILE` -> `tests/verbs/freeze.sh` -> Contract-derived tests for `freeze`
- [ ] `NEW FILE` -> `tests/verbs/start.sh` -> Contract-derived tests for `start`
- [ ] `NEW FILE` -> `tests/verbs/freeze-start.sh` -> Contract-derived tests for `freeze-start`
- [ ] `NEW FILE` -> `tests/verbs/done.sh` -> Contract-derived tests for `done` (covers D2)
- [ ] `NEW FILE` -> `tests/verbs/status.sh` -> Contract-derived tests for `status`
- [ ] `NEW FILE` -> `tests/verbs/plan.sh` -> Contract-derived tests for `plan`
- [ ] `NEW FILE` -> `tests/verbs/plan-status.sh` -> Contract-derived tests for `plan-status`
- [ ] `NEW FILE` -> `tests/verbs/matrix.sh` -> Contract-derived tests for `matrix`
- [ ] `NEW FILE` -> `tests/verbs/active.sh` -> Contract-derived tests for `active`
- [ ] `NEW FILE` -> `tests/verbs/test.sh` -> Contract-derived tests for `test`
- [ ] `lib/cmd_test.sh` -> Add the `verb` token and second discovery pass over tests/verbs/
- [ ] `NEW FILE` -> `templates/aapp-pre-commit-develop` -> Develop-only correspondence hook engine
- [ ] `lib/cmd_develop.sh` -> Seed the develop-only hook; introduces hook wiring to this command
- [ ] `lib/cmd_uninstall.sh` -> Remove the develop-only hook on uninstall
- [ ] `templates/pre-commit` -> Invoke the develop hook engine when present
- [ ] `lib/verbs.tsv` -> Add fifth `contract` column for all daily rows
- [ ] `lib/cmd_help.sh` -> Absorb the fifth field in the read loop so it does not leak into the description; rendering itself is unchanged
- [ ] `lib/cmd_plan.sh` -> Fix D1 (unescaped title in sed), D2 (ledger summary & target issue), D3 (bare draft commit)
- [ ] `ARCHITECTURE.md` -> Record the contract-as-source-of-truth invariant and verbs.tsv linkage
- [ ] `.agents/CODEMAP.md` -> Name lib/docs/verbs/ as canonical owner of verb behaviour
- [ ] `CHANGELOG.md` -> Record contracts under Added and D1-D3 under Fixed

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius; per-test
> identifiers are tracked in §3.
- `tests/verbs/draft.sh`
- `tests/verbs/done.sh`
- `tests/verb_contracts_test.sh`
- `tests/install_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.agents/skills/*` -> Routing skills through the CLI is downstream work, gated on these contracts existing.
- [ ] `.githooks/*` -> Guard engine self-protection. The installed hooks are never edited directly (Architectural Rule 3); `templates/pre-commit` is the authoring source and `aapp init` propagates it.
- [ ] `lib/cmd_init.sh` -> Bootstrap target resolution is out of scope.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — Where is the correspondence check enforced?**
  - **Decision: a develop-only pre-commit hook, installed by `aapp develop` and not otherwise
    (Adopted Directive).** Contract correspondence is a *kit-authoring* invariant, not a protocol
    invariant: adopters consume verbs and never add them, so the check has nothing to catch in their
    repositories, while a kit developer is the only party who can add a verb without a contract — and
    gets the check at the moment of introduction. This keeps the drift-prevention benefit of
    pre-commit without putting a docs check on every adopter's commit path.
  - **Mechanism.** `.githooks/pre-commit` is already a tier-1 wrapper that composes independent
    steps (`aapp-pre-commit` runs as step 1, with a documented slot for project checks). The new
    check lands as a sibling engine — `.githooks/aapp-pre-commit-develop` — invoked from that
    wrapper only when present, so its absence in an adopter repo is the normal case rather than a
    degraded one.
  - **Installation.** `lib/cmd_develop.sh` performs no hook wiring today (zero references to
    `.githooks`), so this introduces the mechanism. `aapp develop` copies
    `templates/aapp-pre-commit-develop` to `$REPO_ROOT/.githooks/aapp-pre-commit-develop` and makes
    it executable. `aapp init` must not seed it.
  - **Invocation without overwriting.** `.githooks/pre-commit` already exists in this repository and
    in adopter repositories, and `cmd_init.sh` deliberately preserves an existing wrapper rather than
    overwriting it. The wrapper therefore cannot be relied on to gain the invocation by
    re-propagation. `templates/pre-commit` gains a presence-guarded block (mirroring how it already
    guards `aapp-pre-commit`), and `aapp develop` must ensure the block is present in the live
    `.githooks/pre-commit` for repositories whose wrapper predates it — appending it if absent,
    idempotently.
  - **Alternative considered — a kit-signature guard, no wiring.** Put the check inside the existing
    `.githooks/aapp-pre-commit` (or `planning_health.sh`), guarded by
    `[ -d "$REPO_ROOT/lib/docs/verbs" ] && [ -f "$REPO_ROOT/lib/verbs.tsv" ]`. It is inert in adopter
    repositories for the same reason the develop-only hook is, and it removes four moving parts:
    the new engine file, the wrapper edit, the `cmd_develop.sh` wiring and the `cmd_uninstall.sh`
    cleanup. **Rejected, narrowly:** an adopter who vendors the kit into their own repository would
    match the signature and start running a kit-authoring check they never asked for, which is
    exactly the adopter-cost the develop-only decision exists to avoid. Signature detection also
    couples the check to a directory layout rather than to an explicit developer action. The
    trade is accepted deliberately — four small moving parts for a boundary that cannot be
    accidentally tripped. If the wiring proves fragile in practice, this alternative is the
    documented fallback.
  - **Idempotence is a hard requirement, not a nicety.** `aapp develop` may be run repeatedly on the
    same repository. Copying the engine is naturally idempotent; appending the wrapper block is not,
    and must be guarded by a presence check so repeat runs cannot duplicate lines. Task 2.3b asserts
    this directly.
  - **Uninstall boundary.** `lib/cmd_uninstall.sh` is a *global* uninstaller: it removes
    `$HOME/.local/bin/aapp` and `$SHARE_DIR`, and has no record of which repositories ran
    `aapp develop`. It can therefore only clean the hook when it happens to be invoked inside such a
    repository. The task is: if a repository root resolves and
    `$REPO_ROOT/.githooks/aapp-pre-commit-develop` exists, remove it and its wrapper block; if no
    repository resolves, skip silently — running `aapp uninstall` outside a repository is normal and
    must not error.
  - **Consequence for scope.** `tests/verb_contracts_test.sh` still carries the correspondence
    assertions, so the invariant is verifiable without the hook installed and CI stays independent
    of developer-machine state. The hook is the early-warning layer, not the only one.
* [x] **Question 2 — Does a contract cover `test` at all?**
  - **Decision: yes, and it documents `aapp test` as kit-suites-only (Adopted Directive).** The
    contract specifies discovery of `tests/*_test.sh`, execution, aggregation, and exit non-zero on
    any suite failure. No "effects are project-defined" caveat is needed, because running an
    adopter's suite is not this verb's job.
  - **Rationale.** The kit ships no linters and no language toolchain integration; outsourcing test
    execution to `npm`/`cargo`/`composer`/`go` is the same category of thing. Adopters who want their
    own suite on every commit already have the entry point: `templates/pre-commit` carries a
    documented slot for project checks (`# e.g., npm test || exit 1`). That extension point is
    theirs, and it is the correct place for it — the kit does not need a delegation path to duplicate
    it.
  - **Scope boundary.** The existing delegation in `lib/cmd_test.sh` (`aapp.testCommand`, npm, cargo,
    composer, go — `cmd_test.sh:51-90`) is therefore behaviour that should not exist, but **removing
    it is out of scope for this plan**. P-34 documents the intended contract; the removal is a
    user-visible behaviour change for anyone relying on it and belongs in its own blueprint. The
    contract states kit-suites-only, so the divergence is recorded rather than silently tolerated —
    exactly the condition Task 1.1 asks authors to mark where current code violates a contract line.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-09-24 (Red Team Round 2):** Four suggestions reviewed; three adopted, one already done.
  - **D1 mechanism (§2.5, new).** The proposed pure-bash replacement was tested rather than accepted
    and **fails twice**: `[Feature or Refactor Name]` is parsed as a glob character class so the
    substitution silently does nothing (the same outcome as D1), and with brackets escaped, a title
    containing `&` re-expands to the matched text. Quoting both operands works on bash 5.2, but the
    semantics differ across versions and macOS ships 3.2, while this repo documents no floor. §2.5
    records both traps, the working form, the portability caveat, and `awk -v` as the safer default.
    Two new required tests cover the traps directly.
  - **`aapp test <verb>` without the token — rejected, with cause.** `matrix` and `test` are both
    verb names *and* existing suite names, and the runner matches by substring
    (`cmd_test.sh:199-201`), so a bare form would silently change what `aapp test matrix` means.
    The token stays required; `aapp test list` must show both sets.
  - **Develop-hook alternative recorded.** A kit-signature guard inside the existing
    `aapp-pre-commit` would remove four moving parts. Rejected narrowly — an adopter vendoring the
    kit would match the signature and inherit a check they never asked for — but documented in §5 Q1
    as the fallback if the wiring proves fragile. Idempotence promoted to a hard requirement.
  - **Target Issue `#78`** was already stamped in the header by round 1; no change.
* **2026-09-24 (Red Team Round 1):** Resolved findings F1–F4 from an adversarial review.
  - **F1 (blocker).** §2.2 claimed `cmd_help.sh` "reads fields 1/2/4 and must continue to ignore
    field 5". That was wrong and untested. `read` assigns all trailing fields to the last variable,
    so a fifth column lands inside `$desc` — verified directly: `desc` becomes
    `Scaffold blueprint<TAB>lib/docs/verbs/draft.md`. Every daily verb would print its contract path
    in `aapp help` and Test 56 would fail. `lib/cmd_help.sh` moved from Out of Bounds to Target Files
    for the one-line parse fix; contract *rendering* stays out of scope.
  - **F2.** `cmd_init.sh` preserves an existing `.githooks/pre-commit` rather than overwriting it, so
    the wrapper cannot gain the develop-hook invocation by re-propagation. §5 Q1 now tasks
    `aapp develop` with ensuring the block idempotently, and Task 2.3b covers it.
  - **F3.** `cmd_uninstall.sh` is a global uninstaller with no record of which repositories ran
    `aapp develop`; it can only clean the hook when invoked inside one. §5 Q1 now states that, and
    that running outside a repository skips silently rather than erroring. Task 2.3c covers it.
  - **F4.** §2.1 claimed the `path::name` syntax matches the plan-level convention, but the plan
    carried no such section. Added, using the split `P-35` settled: test **files** in §4 frozen with
    the blast radius, per-test **identifiers** in §3 where they can be ticked during execution.
  - Also recorded: **D2 duplicates `#78`**, filed 2026-09-22 and rediscovered independently by this
    survey — which is itself evidence for the plan's premise. Header Target Issue set to `#78`.
* **2026-09-23 (Refinement):** Added the `## Tests` heading to the contract shape (§2.1) and the
  `tests/verbs/` layout with granular execution (§2.4). Each contract carries a copyable
  `Run: aapp test verb <verb>` line plus per-test identifiers, so a reader cross-checks coverage
  without searching and a failure mode with no test is a visible hole. Tests live one file per verb
  at `tests/verbs/<verb>.sh` — no `_test.sh` suffix, since the subdirectory disambiguates by
  location. `lib/cmd_test.sh` gains a `verb` token; a bare `aapp test` sweeps `tests/verbs/` in a
  second discovery pass. That separation is the design, not a workaround for `-maxdepth 1`: its
  primary purpose is a tight feedback loop while changing a verb's behaviour (seconds for one verb
  against 65s for the full sweep), with convention isolation as the secondary benefit. Existing
  suites are not relocated. Blast radius grew by eleven verb test files and `lib/cmd_test.sh`.
* **2026-09-23 (Refinement):** Resolved Question 2 — `test` gets a contract, documenting
  `aapp test` as kit-suites-only. The kit ships no linters or language toolchain integration, so
  delegating to `npm`/`cargo`/`composer`/`go` is out of character; adopters wanting their own suite
  per commit use the project-checks slot already documented in `templates/pre-commit`. Removing the
  existing delegation in `cmd_test.sh` is a user-visible change and stays out of scope — the contract
  records it as a divergence instead. All open questions are now resolved.
* **2026-09-23 (Refinement):** Resolved Question 1 — the correspondence check runs as a develop-only
  pre-commit engine (`.githooks/aapp-pre-commit-develop`), seeded by `aapp develop` and absent in
  adopter repositories, since contract correspondence is a kit-authoring invariant rather than a
  protocol one. Added `templates/aapp-pre-commit-develop`, `lib/cmd_develop.sh`,
  `lib/cmd_uninstall.sh` and `templates/pre-commit` to the blast radius, plus Task 2.1b. The test
  suite keeps the same assertions so the invariant stays verifiable without the hook installed.
* **2026-09-23:** Drafted from a session that probed the daily verbs in a clean sandbox and found
  three defects (D1–D3) none of which any document forbade. Establishes `lib/docs/verbs/<verb>.md`
  as the source of truth for verb behaviour — ingress, preconditions, failure modes, effects, exit —
  linked from a fifth `contract` column in `lib/verbs.tsv` so agents resolve it in the same read that
  tells them the verb exists. Tests are derived from the contracts, failure modes first. Corrects an
  earlier suspicion recorded elsewhere in this session: the lifecycle verbs do commit correctly and
  record the right SHA; the missing commits in this repository come from the attribution hook
  reaching into the `.plans` worktree, which is out of scope here.
