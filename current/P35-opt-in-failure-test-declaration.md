# 🗺️ Plan P-35: Opt In Failure Test Declaration
* **Created:** 2026-09-23 | **Last Refined:** 2026-09-27
* **Target Issue / Milestone:** Protocol Enhancement (Opt-In Failure Testing)
* **Plan ID:** P-35
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
Agents default to silent error suppression. This repository carries **201 `|| true`** occurrences plus
**200 `2>/dev/null ||` fallbacks** across `lib/`, `aapp` and `.githooks/` — not a few stray idioms but
a house style, produced because `set -e` makes crash-or-suppress a local dilemma at every line and
nothing in the feedback loop punishes the suppression.

Running the full suite on every commit does **not** catch this. A green suite proves the happy path
works; `|| true` only changes behaviour on the error path, and the error path is exactly what no test
exercises unless someone wrote a case for it. A suite of happy-path tests stays green over a codebase
saturated with suppression, indefinitely.

What does help is enumerating the failure cases *before* writing the implementation, and declaring
them where they can be checked. `P-33` was executed this way and the effect was visible: Phase 1
authored two negative tests, confirmed Red 🔴 (`plan` and `ai-status` returned exit 0 outside a
repository), and only then was the guard written.

### Architectural Goal
Make failure-case declaration an **opt-in** planning step, injected only into the plans that warrant
it, with enforcement that is language- and project-agnostic.

1. A CLI verb, `aapp tdd <id>` (§5 Q1), injects a test-declaration section into an existing plan.
   It **declares** tests; it never writes test code and never runs tests (`aapp test` runs them).
2. The section is **absent by default**. A docs or config plan carries no test checklist, so agents
   never learn that a checked box can mean `N/A`.
3. Declarations are **paths and identifiers only**, never language-specific syntax, so the section
   works in a Kotlin, Python, Rust, Go or shell project without the kit understanding any of them.
4. A skill performs the part a shell script cannot: reading the blueprint and proposing the failure
   cases its design implies.

### Why Opt-In Is the Design, Not a Compromise
A mandatory section cannot be enforced. A documentation plan would have to fill it with `N/A`, and no
hook can distinguish a legitimate `N/A` from an evasion — while teaching agents that checked boxes
need not mean anything, which corrodes the checklist mechanism the rest of the protocol depends on.
An opt-in section is unambiguous: **present means enforce, absent means the plan opted out at
authoring time.** Presence itself carries the signal.

### Honest Limits (Do Not Oversell)
This catches failure cases anticipated at planning time. It does **not** catch suppression on paths
nobody enumerated, fallbacks in test scaffolding, or an agent satisfying a declared test while
suppressing errors elsewhere in the same function. The second-order effect — an agent that has just
enumerated "what happens when the ledger is missing, when the worktree is absent" is less likely to
reach for `|| true` on the next line — is probably worth more than the direct catch rate, and is the
part that generalises past the declared cases. No mechanism at hook level reliably stops the
behaviour across languages; this is a partial measure, deliberately.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`. Existing plans without the section are not migrated:
  absence is the documented default state, not a legacy condition.

### 2.1 Two Sections, Two Jobs

Test declaration is split across the plan by what each section is shaped for. This split is not
cosmetic — it was forced by using the single-section design during `P-33`.

| | §4 Blast Radius | §3 Implementation Steps |
| :--- | :--- | :--- |
| **Holds** | test **file paths** | individual **test identifiers** |
| **Checkboxes** | none — it is a declaration | yes — tickable during execution |
| **Frozen at freeze?** | yes, with Target Files | no, it is execution state |
| **Analogy** | "these files must prove it" beside "these files may change" | a phase task like any other |

**Why the split.** During `P-33`'s implementation the write-guard **refused** the commit that ticked
its declared tests, because they sat in §4 and §4 is design-locked once a plan is frozen. That is the
lock working correctly; the placement was wrong. A filename does not change when the test inside it
passes, so §4 carries no checkboxes and needs no lock exception. Execution state belongs in §3.

### 2.2 The §4 Declaration Is Project-Agnostic & Target-Bearing (Option A)

`templates/plan-template.md` ships to adopters, so §4 must not assume this kit's own test layout.
It declares paths in whatever the project uses:

```markdown
### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- `src/test/kotlin/AuthTest.kt`
- `tests/test_parser.py`
- `tests/verbs/draft.sh`
```

**Option A Single-Entry Guarantee (P-37 Alignment):**
Under P-37 §2.4, `### 🧪 Required Test Files` is explicitly whitelisted as an authoritative target-bearing
heading in `lib/aapp-lib.sh`. Files listed here automatically receive write permission during execution
without requiring redundant double-entry in `### 📂 Target Files`. The section is frozen with §4 at freeze time,
ensuring strict blast-radius immutability.

No counts, no per-file test totals: a count is only meaningful if something can verify it, and
verifying it means parsing test bodies in a language the kit does not know. See §5 Q2.

### 2.3 The §3 Checklist Is Tickable

```markdown
### 🧪 Required Tests (Failure & Boundary Assertions)
- [ ] `tests/verbs/draft.sh::test_slash_title` -> asserts clean refusal or correct plan, never half-written
- [ ] `src/test/kotlin/AuthTest.kt::testExpiredTokenRejects` -> asserts 401, never falls back to guest
```

Syntax is `path::name -> asserts <condition>`, deliberately identical to the convention `P-34` uses
for verb contracts, so one form serves both.

### 2.4 Conditional Enforcement & Shared Library Parsers

The pre-commit check and lifecycle gates fire **only when §4 `### 🧪 Required Test Files` is present**.
Because §4 is design-locked once a plan is frozen (`templates/aapp-pre-commit:614-620`), §4 is the sole
authoritative, tamper-proof trigger for test enforcement:

- **Plan with §4 present:**
  - Every §3 identifier in `### 🧪 Required Tests` must resolve to a file declared in §4.
  - Every §4 declared test file must be referenced by at least one §3 identifier.
  - If §4 is present and §3 `### 🧪 Required Tests` is missing or contains no assertions, or §4 lists no
    files -> refused, subject to the timing below.
- **Plan without §4:**
  - If §3 carries a test checklist without §4, it is treated as an opted-out informal checklist (grants no write
    permission and triggers no pre-commit correspondence or done gates).
  - Target Files enforcement only. Zero friction, zero boilerplate.

**Parser Ownership in `lib/aapp-lib.sh`:**
To comply with P-37's structural ban on duplicate inline parsers, the correspondence check uses two pure
functions added to `lib/aapp-lib.sh`:
- `parse_plan_required_test_files "$plan_file"`: extracts file paths declared under `### 🧪 Required Test Files`.
- `parse_plan_required_tests "$plan_file"`: extracts §3 test items and isolates the path prefix preceding `::`.

`templates/aapp-pre-commit` sources `aapp-lib.sh` and verifies mutual inclusion between the two sets.

**Enforcement timing.** `P-33` §5 Decision 7 already settled this and it carries over: declarations
are planning-phase during `📝 Refining`, so presence checks must tolerate unwritten tests while
refining and enforce file existence once `⚡ In Development`. The same timing governs empty sections,
because `aapp tdd` commits both headings empty and the skill fills them afterwards:

| Stage | Empty §3 or §4 | Correspondence mismatch | Declared file missing |
| :--- | :--- | :--- | :--- |
| `🟣`/`📝` (pre-commit) | tolerated | tolerated | tolerated |
| `aapp freeze` / `freeze-start` | **refused** | **refused** | tolerated |
| `🔷 Frozen` / `⚡ In Development` (pre-commit) | **refused** | **refused** | **refused** at `⚡` |

### 2.5 Division of Labour: CLI Injects, Skill Enumerates

- **CLI (`aapp tdd`)** — deterministic and mechanical: resolve the plan, refuse if either heading already
  exists, inject both headings, report what to do next.
- **Skill (`/aapp-tdd`)** — the part with judgement: read §1 and §2, enumerate the failure cases the design
  implies, propose test identifiers in the project's own idiom, write them into §3 and their files into §4.

### 2.6 Mechanical `done` Verification Gate & Ledger Recording

When `aapp done` (`lib/cmd_plan.sh:cmd_done`) is invoked on a plan that carries `### 🧪 Required Test Files`:
1. **Completion Check:** Every box in `### 🧪 Required Tests` must be ticked (`- [x]` or `- [X]`). If any
   uncompleted `- [ ]` remains, `cmd_done` refuses with exit 1 and prints the pending test assertions.
2. **Existence & Tracked Check:** Every test file declared under `### 🧪 Required Test Files` must exist on
   disk and be tracked in Git (`git ls-files --error-unmatch "$path"`).
3. **Ledger Recording:** `cmd_done` derives the count of completed test assertions ($N$) and records
   `tdd (N/N)` inside the `Impact Summary` or verification notes of `.plans/done/000-archive-ledger.md` without
   altering the table schema. Plans without §4 record nothing (absence = opted out).

---

## 🔨 3. Implementation Steps & Execution Checklist
*Phased progression checklist. Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

*Written failure-first: negative tests are authored and confirmed Red 🔴 before the implementation
they cover — the practice this plan exists to make declarable.*

### Phase 1: Failure-First Test Harness (Red 🔴)
- [ ] Task 1.1: Add negative tests for the injection verb: refuses a plan id that does not resolve; refuses when the section already exists (idempotence, not duplication); refuses outside a Git repository.
- [ ] Task 1.2: Add negative tests for the conditional check: a plan **without** the section commits freely; a plan **with** it is refused when a §3 identifier names a file absent from §4, and when a §4 file has no §3 identifier.
- [ ] Task 1.3: Add lifecycle-timing tests per the §2.4 table: a `📝 Refining` plan with unwritten declared tests commits, and the same plan at `⚡ In Development` is refused (per `P-33` §5 Decision 7); `tests/verbs/tdd.sh::test_injection_commit_accepted_while_refining` (the verb's own commit of empty headings succeeds); `aapp freeze` refuses a tdd plan with an empty §3 or §4.
- [ ] Task 1.4: Add negative tests for `cmd_done` completion verification: refuses archival if any §3 test is unticked (`- [ ]`), and refuses if any §4 test file does not exist on disk/Git.
- [ ] Task 1.5: Run the new suite and confirm every assertion FAILS (Red 🔴) — none of this exists yet.

### Phase 2: CLI Injection & Shared Parsers (Green 🟢)
- [ ] Task 2.1: Implement the injection verb in `lib/cmd_plan.sh` — resolve the plan, refuse if either heading is already present, inject `### 🧪 Required Test Files` into §4 after Target Files and `### 🧪 Required Tests` into §3, commit the amendment.
- [ ] Task 2.2: Register `tdd` in `lib/verbs.tsv` (`daily` tier) with the description `Declare a plan's failure-first tests (§3 identifiers, §4 test files) before freeze`, and add its dispatcher case in `aapp`.
- [ ] Task 2.3: Re-run Phase 1's verb tests and confirm Green 🟢.
- [ ] Task 2.4: Implement pure functions `parse_plan_required_test_files` and `parse_plan_required_tests` in `lib/aapp-lib.sh`; add unit tests in `tests/aapp_lib_test.sh` and confirm Green 🟢.

### Phase 3: Conditional Enforcement & Done Gate (Green 🟢)
- [ ] Task 3.1: In `templates/aapp-pre-commit`, invoke `parse_plan_required_test_files` and `parse_plan_required_tests` from `lib/aapp-lib.sh` to enforce bidirectional correspondence string-level only.
- [ ] Task 3.2: Apply the §2.4 timing table: tolerate empty sections, mismatches and unwritten tests while `📝 Refining`; refuse empty sections and mismatches in `cmd_freeze`/`cmd_freeze_start` (`lib/cmd_plan.sh`) and in pre-commit from `🔷 Frozen`; enforce file existence at `⚡ In Development`.
- [ ] Task 3.3: In `lib/cmd_plan.sh` (`cmd_done`), implement mechanical completion gate: refuse archival if any §3 test is unticked (`- [ ]`), verify all declared §4 test files exist on disk and in Git, and append `tdd (N/N)` verification evidence to the archive ledger row in `.plans/done/000-archive-ledger.md`.
- [ ] Task 3.4: Re-run Phase 1's enforcement, timing, and `cmd_done` gate tests and confirm Green 🟢.

### Phase 4: Skill Authoring & Distribution
- [ ] Task 4.1: Author skill in `templates/skills/aapp-tdd/SKILL.md` (with `disable-model-invocation: false`): call the CLI first, then read §1/§2 and propose failure cases in the project's own idiom, writing identifiers into §3 and their files into §4. Include an explicit failure branch — if the CLI refuses, stop and report rather than hand-editing the plan.
- [ ] Task 4.2: Update `sync_skills` in `lib/cmd_init.sh` and Test 42 in `tests/install_test.sh` to recognize `aapp-tdd` as a retained skill.

### Phase 5: Template & Verification
- [ ] Task 5.1: Add the **Fail-Closed Invariant** to `templates/plan-template.md`'s header invariants — standalone and unconditional, not tied to TDD: silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are prohibited; a benign one is justified in a comment and registered in §2's Fallback Inventory.
- [ ] Task 5.2: Run `./aapp test strict quiet` across all discovered suites and verify zero regressions.

### Phase 6: Documentation & Protocol Sync
- [ ] Task 6.1: Update `ARCHITECTURE.md` with the opt-in declaration model, the §3/§4 split, Option A single-entry semantics, and the `cmd_done` mechanical gate.
- [ ] Task 6.2: Update `.agents/CODEMAP.md`, `MANUAL.md` and `CHEATSHEET.md` for `aapp tdd`. The docs describe what the verb **does**, not the acronym: it injects `### 🧪 Required Tests` (§3) and `### 🧪 Required Test Files` (§4), declares tests only (no test code, no test run), and belongs between `draft` and `freeze`. MANUAL states that the red phase happens at implementation (Phase 1 writes the declared tests and confirms them failing).
- [ ] Task 6.3a: Author the behaviour contract `lib/docs/verbs/tdd.md` (`P-34` shape: Ingress, Preconditions, Failure modes, Effects, Exit, Tests naming `tests/verbs/tdd.sh`) and reference it in the `verbs.tsv` contract column.
- [ ] Task 6.3: Update `CHANGELOG.md` under `### Added`.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
>
> **Authoring rule:** the **first** `backticked path` on a line is the target. Everything after it is prose — the pre-commit hook ignores it, so naming another file in a description does *not* grant access to it. To add a second file, give it its own line. (`NEW FILE` and similar markers are skipped, so the path after them is used.)
- [ ] `lib/cmd_plan.sh` -> Implement the injection verb (cmd_tdd) and cmd_done mechanical completion gate
- [ ] `lib/aapp-lib.sh` -> Add pure helpers parse_plan_required_test_files and parse_plan_required_tests
- [ ] `lib/verbs.tsv` -> Register the verb in the daily tier with contract pointer
- [ ] `lib/cmd_init.sh` -> Register aapp-tdd in sync_skills for skill propagation
- [ ] `aapp` -> Add the dispatcher case
- [ ] `templates/plan-template.md` -> Add the Fail-Closed Invariant to the header invariants
- [ ] `templates/aapp-pre-commit` -> Conditional correspondence check, active only when the section is present
- [ ] `NEW FILE` -> `templates/skills/aapp-tdd/SKILL.md` -> Skill template that enumerates failure cases and writes both sections
- [ ] `NEW FILE` -> `tests/verbs/tdd.sh` -> Verb tests (injection, refusals, idempotence)
- [ ] `NEW FILE` -> `lib/docs/verbs/tdd.md` -> Behaviour contract for tdd (P-34 correspondence)
- [ ] `tests/aapp_lib_test.sh` -> Unit tests for parse_plan_required_test_files and parse_plan_required_tests
- [ ] `tests/pre-commit_test.sh` -> Conditional enforcement, lifecycle-timing, and done-gate completion tests
- [ ] `tests/install_test.sh` -> Update skill inventory assertions (Test 42) for aapp-tdd
- [ ] `ARCHITECTURE.md` -> Record the opt-in declaration model, §3/§4 split, and done gate
- [ ] `.agents/CODEMAP.md` -> Name the verb's owner module and shared library helpers
- [ ] `MANUAL.md` -> Document the verb
- [ ] `CHEATSHEET.md` -> Add the verb to the quick reference
- [ ] `CHANGELOG.md` -> Record under Added

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.agents/skills/*` -> Governance skills self-protection; authored in `templates/skills/` and propagated via `aapp init`.
- [ ] `.githooks/*` -> Guard engine self-protection; `templates/aapp-pre-commit` is the authoring source and `aapp init` propagates it (Architectural Rule 3).
- [ ] `lib/cmd_test.sh` -> Test-runner changes belong to `P-34`.

---

## ❓ 5. Open Questions (Optional / Gate)
*Use this section ONLY for genuine, unresolved decisions requiring human input. If the design is fully determined, write `*(None — design is fully specified)*`.*
*Do NOT populate with already-decided choices or answer questions yourself.*
* [x] **Question 1 — Verb name.** RESOLVED (2026-09-27): **`tdd`** — `aapp tdd <id>`, skill
  `/aapp-tdd`. Short, and it names the practice the verb applies: tests declared before
  implementation. Rejected: `harden` (an outcome), `prove`/`cover`/`assert` (read as test results),
  `expect`, `plan2test` (long, digit), `doplan` (reads as execute, i.e. `start`). The acronym is
  offset by the help line and docs describing the action, not the expansion (Task 2.2, 6.2); no
  long-form alias. The "should not name the artifact" constraint below is dropped. Original
  constraints, kept for the record:
  - **Bare, not hyphenated.** In this CLI a hyphen currently signals an inspector (`plan-status`) or
    a composite (`freeze-start`) — and `freeze-start`, the one hyphenated lifecycle verb, is the one
    that never became a skill.
  - **Must read correctly as a skill**, since the skill is the larger half: `/aapp-<verb>`.
  - **Should not name the artifact it injects**, or it needs renaming when the section grows beyond
    test declarations.
  - **Should not imply running tests** — the operation edits two markdown sections. This is why
    `pretest` misleads.
  The name may become obvious once the operation is described precisely; it does not block Phase 1.
* [ ] **Question 2 — Notation for several tests in one file (deferred, likely its own plan).** §4
  declares paths without counts because a count is only meaningful if something can verify it, and
  verifying it means parsing test bodies in a language the kit does not know. A notation standard
  that makes tests *countable without parsing* would let the pre-commit check compare declared and
  actual totals rather than only checking correspondence. Undetermined: whether such a notation lives
  in the plan (identifiers enumerated in §3 and counted there) or in the test file (a convention the
  kit greps for). Out of scope here — this plan ships correspondence only.

### Dependencies & Sequencing
- **After `P-37`:** `P-37` establishes `lib/aapp-lib.sh`, fixes parser defects (#82), and whitelists `### 🧪 Required Test Files` as target-bearing (Option A).
- **After `P-34`:** `P-34` establishes verb contracts (`lib/docs/verbs/*.md`) and `lib/verbs.tsv` contract column; P-35 provides `lib/docs/verbs/tdd.md` satisfying P-34's correspondence check.

---

## 📦 6. Change Log & Refinement History
*Tracks how the plan evolved across sessions.*
* **2026-09-23:** Drafted from a session on why agents default to silent error suppression. Two
  findings shaped the design. First, running a full suite per commit does not catch `|| true` —
  confirmed against a separate project where a 30s suite runs on every commit with pre-written tests
  and the behaviour persists, because happy-path tests never traverse error paths. Second, the
  section placement was corrected by use rather than review: during `P-33`'s implementation the
  write-guard refused the commit that ticked its declared tests, because they sat in design-locked
  §4. Hence the §3/§4 split — §4 declares test **file paths** as a frozen boundary with no
  checkboxes, §3 carries the tickable per-test checklist. §4 is project-agnostic because
  `plan-template.md` ships to adopters whose layouts the kit cannot assume; the correspondence check
  is string-level and never opens a test file, for the same reason. Verb name carried as Q1
  (undecided, constraints recorded); multi-test-per-file notation carried as Q2 (deferred, likely its
  own plan).
* **2026-09-27:** Resolved Q1: the verb is `tdd`. Named `tests/verbs/tdd.sh` and `/aapp-tdd`, added
  the `lib/docs/verbs/tdd.md` contract (P-34 correspondence) and a docs task stating that the verb
  declares tests and never writes or runs them.
* **2026-09-27 (Refinement - RFC Alignment & Pair 5 Fix):**
  1. Fixed Pair 5 violation: changed skill target from `.agents/skills/aapp-tdd/SKILL.md` to `templates/skills/aapp-tdd/SKILL.md` and added `.agents/skills/*` to Out of Bounds.
  2. Adopted Option A from consensus RFC (`tri-plan-alignment-34-35-37.md`): declared test files in `### 🧪 Required Test Files` receive write access directly without duplication in `Target Files`.
  3. Delegated correspondence parsing to `lib/aapp-lib.sh` (`parse_plan_required_test_files` and `parse_plan_required_tests`) instead of duplicate inline awk in `templates/aapp-pre-commit`.
  4. Clarified enforcement trigger: §4 `### 🧪 Required Test Files` is the sole authoritative switch (design-locked at freeze); §3 without §4 is an informal opted-out checklist.
  5. Added mechanical `cmd_done` completion verification gate (all §3 ticked, §4 files exist and tracked in Git via `git ls-files`) and `tdd (N/N)` ledger recording to `lib/cmd_plan.sh`.
  6. Added explicit dependency sequencing: `After P-37, after P-34`.
* **2026-09-27 (RFC review of `a5c229a`):**
  1. Empty-section refusal now follows the P-33 Decision 7 timing (§2.4 table): tolerated while `📝 Refining`, so `aapp tdd`'s own commit of empty headings passes; refused at `freeze`/`freeze-start` and in pre-commit from `🔷 Frozen`. Added `tests/verbs/tdd.sh::test_injection_commit_accepted_while_refining`.
  2. Dropped the `.plans/current/*.md` Out of Bounds line: its glob matched this plan's own file and was unenforced (`.plans/*` is always allowed). Existing plans stay un-retrofitted by design (§2 Migration).
