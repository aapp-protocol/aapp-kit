# 🗺️ Plan P-41: CLI-First Universal Skills Alignment
* **Created:** 2026-09-28 | **Last Refined:** 2026-09-28
* **Target Issue / Milestone:** Protocol Enhancement (Universal Skills Realignment)
* **Plan ID:** P-41
* **Status:** ⚡ In Development
* **Base:** `08c3670` (develop)
* **Commits:** `6ab3b73` (develop)
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`: `none | lax | strict | notes`). When operating in `lax` or `strict` mode, AI commits must carry standard emailless semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Plan-Bound Commits**: Commit implementation with `aapp commit "<msg>" [agent <Agent> vendor <Vendor> model <Model>] [note "<text>"]` (or set `AAPP_AGENT_*`) so the plan records its commits. Never stage or commit the plan file yourself — the helper commits it alone. `aapp done` archives only recorded work.
> 5. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 8. **Fail-Closed Invariant**: Silent fallbacks (`|| true`, `|| pwd`, unchecked defaults, empty catch blocks) are strictly prohibited. Every operation must fail closed with a clear diagnostic unless a fallback is explicitly justified in code comments and registered under §2's Fallback Inventory.

---

## 1. Context & Architectural Goal

### Problem Statement
Universal skills in `templates/skills/` (`aapp-done`, `aapp-freeze`, `aapp-start`, `aapp-status`, and `aapp-digest`) were authored during early protocol iterations before deterministic CLI engines and authoritative lifecycle gates existed.

Currently, their instructions direct agents to perform manual filesystem and git operations:
1. **`aapp-done/SKILL.md`**: Instructs agents to run `mv .plans/current/<plan>.md .plans/done/<plan>.md`, run `sed -i` on status lines, manually edit markdown tables in `000-archive-ledger.md`, and execute raw `git -C .plans commit`.
2. **`aapp-freeze/SKILL.md`**: Instructs agents to perform raw `sed -i` on plan headers, hand-edit `state_matrix.md`, and execute raw `git -C .plans commit`.
3. **`aapp-start/SKILL.md`**: Instructs agents to manually write to `.git/aapp_active_plan`, update status lines by hand, and run raw git commits.
4. **`aapp-status/SKILL.md`**: Directs agents to manually parse files rather than invoking `aapp status`.

This legacy approach introduces severe architectural hazards:
- **Bypasses Lifecycle Gates**: Manual edits bypass the P-35 TDD completion gate (`tdd (N/N)` verification), the P-39 recorded commit reachability verification, the P-39 `pre-done` veto hook, P-30 state matrix derivation, and worktree concurrency guards.
- **Bypasses Commit Engine**: Manual `git -C .plans commit` bypasses the `plans_commit` engine in `lib/commit_engine.sh`, losing lock-retry resilience and re-introducing potential silent commit failures or race conditions.
- **Syntax and Prose Corruption**: Manual `sed -i` replacements risk matching example blocks inside blueprint prose (as observed during P-39 execution).

### Architectural Goal
Align all universal lifecycle skills in `templates/skills/` to the **CLI-First Standard** established by `aapp-tdd` in P-35:
1. **CLI Execution First**: The skill directs the agent to invoke the authoritative CLI verb (`aapp done <plan>`, `aapp freeze <plan>`, `aapp start <plan>`, `aapp status [short]`).
2. **Deterministic Failure Branch**: If the CLI exits non-zero (refusal or veto), the agent must **never** attempt manual filesystem hacks, `sed` edits, or raw git commits. It must parse the CLI diagnostic, explain the exact blocker to the user, and prompt for remediation.
3. **Clean Structured Summary**: On CLI exit 0, the skill instructs the agent to present the resulting ledger entry, buffer binding, or status matrix update.
4. **Synchronize Clones**: Propagate the updated skill templates to `.agents/skills/` and `.claude/skills/` via `aapp init`.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`. Manual shell instructions (`mv`, `sed`, raw `git -C .plans commit`) are completely removed from skill instructions. Agents must delegate to `aapp <verb>`.

### 2.1 Skill Ingress & Execution Taxonomy

Each skill in `templates/skills/` adopts the canonical 3-tier structure:

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. Parameter & Target Resolution                            │
│    - Parse inline arguments or resolve active buffer        │
│    - Handle candidate selection ceiling (max 10 items)      │
├─────────────────────────────────────────────────────────────┤
│ 2. Authoritative CLI Execution                              │
│    - Execute: aapp <verb> <target>                          │
│    - Capture stdout, stderr, and exit code                  │
├─────────────────────────────────────────────────────────────┤
│ 3. Branching Logic                                          │
│    ├─► Exit != 0: Refusal / Failure Branch                  │
│    │   - STOP immediately (zero manual workarounds)         │
│    │   - Present exact diagnostic and remediation path      │
│    └─► Exit == 0: Success Branch                            │
│        - Extract structured output (ledger SHA, matrix row) │
│        - Present concise conversational confirmation        │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Skill Specifications

#### 1. `templates/skills/aapp-done/SKILL.md`
- **Command**: `aapp done [target]`
- **Refusal Handling**:
  - Missing recorded commits: Instruct agent to run `aapp commit adopt <sha>...`.
  - Unticked TDD assertions: Direct user/agent to verify and tick §3 assertions.
  - Linked worktree collision: Report conflicting worktree holding the plan.
  - Pre-done hook veto: Report script refusal reason.
- **Success**: Output the generated archive ledger line (`Plan ID`, verification commit SHA, impact summary).

#### 2. `templates/skills/aapp-freeze/SKILL.md`
- **Command**: `aapp freeze [target]`
- **Refusal Handling**:
  - Unresolved §5 questions: List unticked questions and prompt user.
  - TDD correspondence failure: Report mismatch between §3 assertions and §4 test files.
  - Non-incubator status: Explain that only `🟣 Under Review` or `📝 Refining` plans can be frozen.
- **Success**: Confirm plan is locked in `🔷 Frozen` backlog and offer `aapp start [target]`.

#### 3. `templates/skills/aapp-start/SKILL.md`
- **Command**: `aapp start [target]`
- **Refusal Handling**:
  - Plan bound in another worktree: Report worktree path and refuse double-binding.
  - Plan not frozen: Direct user to run `aapp freeze` first.
  - Target files disjointness collision: Name conflicting in-development plan.
- **Success**: Confirm active buffer bound (`.git/aapp_active_plan`) and base commit recorded.

#### 4. `templates/skills/aapp-status/SKILL.md`
- **Command**: `aapp status [short]`
- **Refusal Handling**: Report any underlying repository corruption or missing toolchain.
- **Success**: Output the 4-pillar recovery briefing (Shipped, Issues, Plans, Pickup) and suggest the Next Action.

#### 5. `templates/skills/aapp-digest/SKILL.md`
- **Behavior**: Keep cognitive analysis (routing to issues vs blueprints, scan for NEW vs AMEND), but use `aapp draft <slug>` for scaffolding rather than manual template copying.

---

## 🔨 3. Implementation Steps & Execution Checklist

### 🧪 Required Tests (Failure & Boundary Assertions)
> Test assertions that must fail before implementation and pass upon completion. Format: `path::test_name -> asserts <condition>`
- [x] `tests/install_test.sh::test_skills_cli_first_done` -> asserts `templates/skills/aapp-done/SKILL.md` invokes `aapp done` and contains no manual `sed -i`, `mv`, or raw `git -C .plans commit`
- [x] `tests/install_test.sh::test_skills_cli_first_freeze` -> asserts `templates/skills/aapp-freeze/SKILL.md` invokes `aapp freeze` and contains no manual `sed -i` or raw `git -C .plans commit`
- [x] `tests/install_test.sh::test_skills_cli_first_start` -> asserts `templates/skills/aapp-start/SKILL.md` invokes `aapp start` and contains no direct buffer write `echo "<plan-id>" > "$ACTIVE_BUFFER"` or raw `git -C .plans commit`
- [x] `tests/install_test.sh::test_skills_cli_first_status` -> asserts `templates/skills/aapp-status/SKILL.md` delegates directly to `aapp status [short]`
- [x] `tests/install_test.sh::test_skills_cli_first_digest` -> asserts `templates/skills/aapp-digest/SKILL.md` delegates scaffolding to `aapp draft` instead of manual file copying

### Phase 0: Failure-First Test Declarations
- [x] Task 0.1: Add Test 52 in `tests/install_test.sh` asserting CLI-first execution and absence of manual git surgery / sed commands across all skill templates, confirming initial failure (Red 🔴).

### Phase 1: Skills Refactoring
- [x] Task 1.1: Refactor `templates/skills/aapp-done/SKILL.md` to CLI-first execution (`aapp done`), removing all `mv`, `sed`, and raw `git commit` instructions.
- [x] Task 1.2: Refactor `templates/skills/aapp-freeze/SKILL.md` to CLI-first execution (`aapp freeze`), adding explicit refusal branch for open questions and TDD mismatches.
- [x] Task 1.3: Refactor `templates/skills/aapp-start/SKILL.md` to CLI-first execution (`aapp start`), adding worktree collision diagnostic handling.
- [x] Task 1.4: Refactor `templates/skills/aapp-status/SKILL.md` to delegate directly to `aapp status [short]`.
- [x] Task 1.5: Review `templates/skills/aapp-digest/SKILL.md` and ensure scaffolding delegates to `aapp draft`.

### Phase 2: Verification & Idempotent Sync
- [x] Task 2.1: Run `aapp init` to verify clean propagation to `.agents/skills/` and `.claude/skills/`.
- [x] Task 2.2: Run test suite (`./aapp test strict quiet`) ensuring all existing skill drift and integration tests pass (e.g. `tests/install_test.sh`).

### Phase 3: Documentation Sync
- [x] Task 3.1: Update `MANUAL.md` documenting that Universal Skills are conversational shims over deterministic CLI verbs.
- [x] Task 3.2: Update `CHANGELOG.md` under `## [Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
- [ ] `tests/install_test.sh` -> Regression test suite asserting CLI-first structure and forbidding manual git/sed bypasses
- [ ] `templates/skills/aapp-done/SKILL.md` -> CLI-first execution and refusal diagnostics
- [ ] `templates/skills/aapp-freeze/SKILL.md` -> CLI-first execution and refusal diagnostics
- [ ] `templates/skills/aapp-start/SKILL.md` -> CLI-first execution and refusal diagnostics
- [ ] `templates/skills/aapp-status/SKILL.md` -> CLI-first execution delegation
- [ ] `templates/skills/aapp-digest/SKILL.md` -> Delegation to aapp draft
- [ ] `MANUAL.md` -> Universal skills alignment documentation
- [ ] `CHANGELOG.md` -> Record under Added/Changed

### 🧪 Required Test Files
> Test files that must prove this plan's failure cases. Frozen with the blast radius.
- [ ] `tests/install_test.sh`

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.agents/skills/*` -> Governance skills self-protection; authored in `templates/skills/` and synced via `aapp init`.
- [ ] `.claude/skills/*` -> Generated/symlinked from `.agents/skills/`.
- [ ] `lib/cmd_plan.sh` -> CLI execution logic is already complete and verified.
- [ ] `lib/commit_engine.sh` -> Commit engine is frozen and verified.

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Skill Fallback when `aapp` binary is unreachable**: If an agent is running in an environment where `aapp` is not in `$PATH` or alias (e.g. bare subshell), should the skill advise running `export PATH="$HOME/.local/bin:$PATH"` or `./aapp`, rather than performing manual git surgery?
  - *Resolution*: Advise checking PATH and running `./aapp` directly; never provide a manual git bypass that sidesteps lifecycle gates.
* [x] **Question 2 — Skill Frontmatter Invariant**: Verify that all modified skills maintain `disable-model-invocation: false` and valid `argument-hint` strings so IDE autocomplete in Claude Code and Antigravity remains seamless.
  - *Resolution*: All skill templates preserve `disable-model-invocation: false` and accurate `argument-hint` strings, matching the drift control tests in `tests/install_test.sh`.

---

## 📦 6. Change Log & Refinement History
* **2026-09-28:** Plan activated into ⚡ In Development via start.
* **2026-09-28:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-09-28:** Drafted blueprint following P-39 completion to align legacy skill templates with deterministic CLI engines and lifecycle gates.
* **2026-09-28:** Refined blueprint to 📝 Refining, declared failure-first tests in §3 and §4, resolved open questions Q1 & Q2, and bound Target Files.
