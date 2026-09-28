# 🗺️ Plan P-42: Dual Scaffolding And Continuous Execution
* **Created:** 2026-09-28 | **Last Refined:** 2026-09-28
* **Target Issue / Milestone:** Protocol Enhancement (Dual Scaffolding & Continuous Execution)
* **Plan ID:** P-42
* **Status:** 🔷 Frozen
* **Base:** none
* **Commits:** none
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
Two distinct operational friction points exist in the daily plan-and-execute loop:

1. **Fragmented TDD Ingress (The 2-Step Scaffolding Dance)**:
   The `aapp tdd <query>` verb was implemented in P-35 strictly as an *in-place modifier* on pre-existing incubator plans. If a user or agent attempts to start a failure-first implementation from scratch using `aapp tdd <new-slug>`, `resolve_plan_file` fails because the plan does not exist yet. Users are forced to execute a clunky two-step workflow: first scaffold a test-agnostic blueprint via `aapp draft <slug>`, wait for completion, and then run `aapp tdd <slug>` to inject the failure-assertion sections.

2. **Conversational Stalling in `aapp-start` (The Redundant Gate)**:
   When an autonomous agent invokes `/aapp-start <plan>`, the skill currently instructs the agent to "Confirm active binding to the user and notify them that... Implementation begins with...". This causes agents to stop at the conversational turn boundary and ask: *"Plan is bound in development. Shall I begin implementing Phase 1?"*.
   In AAPP, `/aapp-freeze` is the design gate where human review occurs; `/aapp-start` is the green light to code. Pausing after `start` creates an unnecessary, redundant prompt cycle.

### Architectural Goal
Unify planning ingress into two distinct, purpose-driven entry points and eliminate execution turn-stalling:
1. **Purpose-Driven Dual Ingress**:
   - `aapp draft <slug>` (or `/aapp-plan`): Scaffolds standard, test-agnostic blueprints (for docs, refactors, configurations, or non-TDD features).
   - `aapp tdd <slug>` (or `/aapp-tdd`): Acts as a **Smart Scaffolder & Upgrader**:
     - *If `<slug>` does not exist:* Deterministically drafts the new blueprint (`cmd_draft`) and immediately injects the failure-assertion (§3) and test-file (§4) sections in a single atomic operation.
     - *If `<slug>` matches an existing incubator plan:* Upgrades the existing blueprint by injecting the TDD failure sections as before.
     - *If `<slug>` is an unallocated Plan ID (e.g. `P-999`):* Fails closed with an unknown plan refusal.
2. **Continuous Execution Ingress**:
   - Update `templates/skills/aapp-start/SKILL.md` to instruct agents to proceed immediately to Section 3 execution upon binding, eliminating redundant confirmation pauses.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`. `cmd_tdd` preserves exact refusal semantics when given an unallocated Plan ID or an already-injected plan.

### 2.1 Smart TDD Scaffolding Engine (`lib/cmd_plan.sh`)

In `cmd_tdd()`, modify the resolution logic:
```text
┌─────────────────────────────────────────────────────────────┐
│ Query Ingress                                               │
├─────────────────────────────────────────────────────────────┤
│ 1. Is query an existing plan in .plans/current/?            │
│    ├─► YES: Proceed to Upgrade Path (Inject sections)       │
│    └─► NO: Check query format                               │
│        ├─► Matches Plan ID syntax (e.g. ^P-[0-9]+$)?        │
│        │   └─► Refuse (Plan ID not found in current/)       │
│        └─► Slug syntax (alphanumeric / words):              │
│            └─► Auto-Scaffold Path:                          │
│                1. Invoke cmd_draft "$query"                 │
│                2. Resolve newly drafted plan file           │
│                3. Inject §3 and §4 TDD sections             │
│                4. Commit to .plans                          │
│                5. Output TDD scaffold confirmation          │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Continuous Execution Directive (`templates/skills/aapp-start/SKILL.md`)

Update Step 3:
```markdown
### Step 3: Begin Implementation Immediately (Continuous Execution)
On exit 0, aapp start has activated the plan and bound the local execution buffer.
Do NOT pause to ask for redundant confirmation. Immediately proceed to execute Section 3 of the blueprint:
1. Verify / author failure tests (confirming Red 🔴) if TDD sections are declared.
2. Begin Phase 1 implementation tasks.
```

### 2.3 Verb Behaviour Contracts (`lib/docs/verbs/tdd.md`)
Update ingress documentation to specify dual capability:
- `id_or_slug` (positional, required): existing plan identifier (`P-1`, `1`, slug, filename) to upgrade, OR new slug to scaffold directly as a TDD blueprint.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Engine Scaffolding Enhancement
- [ ] Task 1.1: Enhance `cmd_tdd` in `lib/cmd_plan.sh` to detect non-existent slugs, auto-draft via `cmd_draft`, and immediately inject TDD failure sections.
- [ ] Task 1.2: Ensure unallocated Plan IDs (e.g. `P-999`) continue to be strictly refused as non-existent plans.

### Phase 2: Skills & Contracts Alignment
- [ ] Task 2.1: Update `templates/skills/aapp-tdd/SKILL.md` documenting direct TDD scaffolding for new slugs vs. upgrading existing plans.
- [ ] Task 2.2: Update `templates/skills/aapp-start/SKILL.md` to enforce the continuous execution invariant (no redundant pause).
- [ ] Task 2.3: Update `lib/docs/verbs/tdd.md` reflecting the dual ingress contract.

### Phase 3: Verification & Test Coverage
- [ ] Task 3.1: Add test cases to `tests/verbs/tdd.sh` testing:
  - Direct scaffolding of a new slug via `aapp tdd <new-slug>`.
  - Upgrading an existing plan via `aapp tdd <existing-plan>`.
  - Refusal of unallocated Plan ID `aapp tdd P-999`.
- [ ] Task 3.2: Run `aapp test strict quiet` to verify 25/25 suites pass.
- [ ] Task 3.3: Run `aapp init` to propagate updated skills to `.agents/skills/` and `.claude/skills/`.

### Phase 4: Documentation Sync
- [ ] Task 4.1: Update `MANUAL.md` documenting dual scaffolding entry points and continuous start execution.
- [ ] Task 4.2: Update `CHANGELOG.md` under `## [Unreleased]`.

---

## 💥 4. Blast Radius & System Boundaries
*Defines exactly what files may be modified or created. Serves as a strict boundary wall for execution.*

### 📂 Target Files (Modifications & Additions)
> **Rule for Execution Agent:** You are strictly forbidden from modifying any files outside of this explicit list without prior human approval.
- [ ] `lib/cmd_plan.sh` -> Enhance cmd_tdd for auto-drafting new slugs
- [ ] `templates/skills/aapp-tdd/SKILL.md` -> Document dual scaffolding and upgrading ingress
- [ ] `templates/skills/aapp-start/SKILL.md` -> Continuous execution directive in Step 3
- [ ] `lib/docs/verbs/tdd.md` -> Update behaviour contract for auto-scaffolding
- [ ] `tests/verbs/tdd.sh` -> Add automated test coverage for auto-drafting and ID refusal
- [ ] `MANUAL.md` -> Document dual entry points and continuous start
- [ ] `CHANGELOG.md` -> Record under Added / Changed

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.agents/skills/*` -> Synced via aapp init
- [ ] `.claude/skills/*` -> Symlinked from .agents
- [ ] `lib/commit_engine.sh` -> Immutable commit engine

---

## ❓ 5. Open Questions (Optional / Gate)
* [x] **Question 1 — Handling Bare `aapp tdd`**: When invoked without arguments, should `aapp tdd` scan for candidate incubator plans lacking TDD sections and present them, or prompt for a new slug?
  - *Resolution*: Retain standard candidate menu: if incubator plans exist without TDD, list them (up to 10); if none exist, prompt for a new feature slug to scaffold.
* [x] **Question 2 — Plan ID vs. Slug Disambiguation**: How does `cmd_tdd` distinguish an unallocated plan ID from a new slug?
  - *Resolution*: Any query matching `^P-[0-9]+$` or `^[0-9]+$` is treated as a Plan ID lookup (refusing if not found). Non-numeric strings without `P-` prefix are treated as new slugs to scaffold.

---

## 📦 6. Change Log & Refinement History
* **2026-09-28:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-09-28:** Scaffolded and authored blueprint P-42 to establish dual scaffolding entry points (`aapp-plan` vs `aapp-tdd`) and continuous execution in `aapp-start`.
