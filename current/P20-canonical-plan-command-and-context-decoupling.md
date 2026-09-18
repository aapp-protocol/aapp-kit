# 🗺️ Plan P-20: Canonical Blueprint Planning & Execution Context Decoupling
* **Created:** 2026-09-18 | **Last Refined:** 2026-09-18
* **Target Issue / Milestone:** None
* **Plan ID:** P-20
* **Status:** 🔴 Under Review
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Frozen | 🟠 In Development | 🚫 BLOCKED
     The pre-commit hook and write-guard read this line. A 🟢 Frozen plan is an approved backlog
     specification. An 🟠 In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.
> 5. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.
> 6. **Portability Invariant**: Never write machine-specific absolute paths or `file:///` URIs into tracked files. Use repo-relative paths or backticked basenames only.

---

## 1. Context & Architectural Goal

In AAPP v1.0.0 / P-17, the flagless switchboard introduced `aapp plan [id]`, `aapp plan-swap`, and `aapp plan-clear` to manage the local worktree active plan buffer (`.git/aapp_active_plan`). While mechanically effective, this creates two severe usability and conceptual problems:

1. **Semantic Misalignment of `plan`**:
   The verb `plan` strongly implies creating, authoring, or reviewing plans. Using `plan` merely to toggle a pointer buffer violates developer intuition and creates cognitive friction.
2. **The Ephemeral IDE Scratchpad Trap**:
   AI IDEs (such as Antigravity IDE and Cursor) feature built-in planning modes (e.g. `/plan`) that output implementation plans into proprietary, ephemeral cache directories (such as `~/.gemini/antigravity-ide/brain/<conv-id>/implementation_plan.md`). These internal scratchpads:
   - Cannot be shared with other agents (Claude Code, Cursor, Codex, team members).
   - Are deleted or orphaned when conversation context resets.
   - Lack deterministic Git-level Blast Radius protection.
   - Are never permanently banked in the project's historical archive ledger (`000-archive-ledger.md`).

### The Architectural Goal:
1. **Decouple Buffer Switching to `aapp context`**: Move pointer buffer management to `aapp context [id|swap|clear]` and `/aapp-context`, preserving legacy `aapp plan-swap` / `plan-clear` CLI aliases.
2. **Repurpose `/aapp-plan` (and `/plan`) to Canonical AAPP Planning**:
   - **Bare `/plan` or `/aapp-plan`**: Displays the active planning state matrix (`state_matrix.md`) and in-development context.
   - **`/plan <idea>` or `/aapp-plan <idea>`**: Directly scaffolds or amends canonical blueprints in `.plans/current/P<num>-<slug>.md`, registers them in `state_matrix.md`, and initiates technical refinement.
3. **Establish IDE Planning Override Invariant (`AGENTS.md`)**: Instruct agents across all IDEs that any planning request or `/plan` command MUST target `.plans/current/` blueprints and NEVER internal ephemeral scratchpads.
4. **First-Class `/plan` Universal Skill**: Bridge `/plan` directly into `.agents/skills/plan/` and `.claude/skills/plan/` so developers have native chat autocomplete.

---

## 2. Technical Blueprint

### A. Execution Context Switchboard Decoupling (`lib/cmd_plan.sh` -> `lib/cmd_context.sh` & `aapp`)

Refactor execution buffer operations into clean `context` verbs while maintaining backwards compatibility:

```bash
# New Canonical Context Verbs
aapp context              # Display active execution context and boundaries
aapp context <plan-id>    # Set active execution context buffer
aapp context swap         # Swap between active and previous buffer
aapp context clear        # Clear buffer (revert to auto-discovery)

# Backwards-Compatible Aliases (Preserved)
aapp plan-swap            # Alias for 'aapp context swap'
aapp plan-clear           # Alias for 'aapp context clear'
```

### B. Canonical Planning Command (`aapp plan` & `/aapp-plan` / `/plan`)

Repurpose `aapp plan` and the slash commands `/aapp-plan` and `/plan`:

1. **Inspection Mode (`aapp plan` or `/plan` without arguments)**:
   - Reads `.plans/state_matrix.md` and current buffer (`.git/aapp_active_plan`).
   - Displays a clean visual dashboard of:
     - 🟠 **In Development**: Currently executing plan and its declared target files.
     - 🟢 **Frozen Backlog**: Approved specifications ready for execution (`aapp start`).
     - 🔴 / 🟡 **Incubator**: Draft blueprints under thought and refinement.
2. **Scaffolding Mode (`/plan <idea>` or `/aapp-plan <idea>`)**:
   - Resolves whether `<idea>` amends an existing plan or requires a new plan.
   - For new plans: Allocates the next Plan ID (`get_next_plan_id`), scaffolds `.plans/current/P<num>-<slug>.md` from `templates/plan-template.md`, registers it in `state_matrix.md`, and prompts for technical refinement.

### C. Agent Governance Rules (`templates/AGENTS.md` & `.agents/AGENTS.md`)

Add the **Canonical Planning Invariant** to `## 🏛️ Core Philosophy & Role` and `## 🤖 Asymmetric Planning Protocol (AAPP)`:

```markdown
### 📋 Canonical Planning Invariant (AAPP Blueprints Over IDE Ephemeral Artifacts)
- **Universal Blueprint Standard**: When asked to plan, architect, or scaffold an implementation (or when '/plan' / '/aapp-plan' is invoked), the agent MUST NEVER generate internal IDE scratchpads (such as 'implementation_plan.md' in IDE cache directories).
- **Single Source of Truth**: All implementation plans MUST be authored as canonical AAPP blueprints in '.plans/current/P<num>-<slug>.md' using 'templates/plan-template.md' and registered in '.plans/state_matrix.md'.
- **Shared & Banked**: Blueprints in '.plans/' are Git-tracked on an isolated branch, accessible to all AI agents and collaborators, protected by pre-commit blast radius enforcement, and permanently archived to '.plans/done/000-archive-ledger.md' upon completion.
```

### D. Universal Skills Architecture (`templates/skills/`)

1. **`templates/skills/aapp-context/SKILL.md`**:
   - Manages active buffer (`context`, `context <id>`, `context swap`, `context clear`).
2. **`templates/skills/aapp-plan/SKILL.md`**:
   - Canonical planning dashboard and blueprint authoring.
3. **`templates/skills/plan/SKILL.md`**:
   - Direct alias for `/plan` in IDE chat autocompletes, routing to AAPP blueprint planning.
4. **`lib/cmd_init.sh` (`sync_skills`)**:
   - Updates skill installer to sync both `aapp-*` skills and the canonical `plan` skill into `.agents/skills/` and `.claude/skills/`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Context Switchboard Refactoring & CLI Ergonomics
- [ ] Task 1.1: Extend `lib/cmd_plan.sh` (or create `lib/cmd_context.sh`) to support `aapp context [id|swap|clear]`.
- [ ] Task 1.2: Update `aapp` CLI dispatcher and help text (`lib/cmd_help.sh`) documenting `context` and repurposed `plan`.
- [ ] Task 1.3: Update `aapp plan` bare invocation to display the full planning matrix overview alongside active context.

### Phase 2: Universal Skills & Bridging
- [ ] Task 2.1: Author `templates/skills/aapp-context/SKILL.md`.
- [ ] Task 2.2: Rewrite `templates/skills/aapp-plan/SKILL.md` for blueprint inspection and creation.
- [ ] Task 2.3: Author `templates/skills/plan/SKILL.md` for native `/plan` IDE autocomplete.
- [ ] Task 2.4: Update `lib/cmd_init.sh` `sync_skills` to provision both `aapp-*` and `plan` skills.

### Phase 3: Agent Governance & Documentation
- [ ] Task 3.1: Add Canonical Planning Invariant to `templates/AGENTS.md` and `.agents/AGENTS.md`.
- [ ] Task 3.2: Update `README.md`, `MANUAL.md`, and `CHEATSHEET.md` with `context` and `/plan` documentation.
- [ ] Task 3.3: Update `CODEMAP.md` and `ARCHITECTURE.md` interface registries.

### Phase 4: Automated Verification & Test Coverage
- [ ] Task 4.1: Update `tests/write-guard_test.sh` to verify `aapp context` verbs alongside legacy aliases.
- [ ] Task 4.2: Update `tests/install_test.sh` to verify `plan` and `aapp-context` skill synchronization.
- [ ] Task 4.3: Run full automated regression suite (all test suites and planning health).
- [ ] Task 4.4: Record release notes in `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_plan.sh` -> Support `aapp context` verbs and matrix inspection on `aapp plan`.
- [ ] `aapp` -> CLI router updates for `context` and updated `plan` help.
- [ ] `lib/cmd_help.sh` -> CLI help output updates.
- [ ] `templates/skills/aapp-context/SKILL.md` -> NEW FILE: Active context management skill.
- [ ] `templates/skills/aapp-plan/SKILL.md` -> Repurposed canonical blueprint planning skill.
- [ ] `templates/skills/plan/SKILL.md` -> NEW FILE: Native `/plan` IDE slash command.
- [ ] `lib/cmd_init.sh` -> Update `sync_skills` to bridge `plan` alongside `aapp-*`.
- [ ] `templates/AGENTS.md` -> Add Canonical Planning Invariant.
- [ ] `README.md` -> Lifecycle documentation alignment.
- [ ] `MANUAL.md` -> Chapter 5 lifecycle pipeline documentation.
- [ ] `CHEATSHEET.md` -> Command reference table updates.
- [ ] `tests/write-guard_test.sh` -> Context switchboard regression tests.
- [ ] `tests/install_test.sh` -> Skill synchronization assertions.
- [ ] `CHANGELOG.md` -> Feature release notes.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/aapp-pre-commit` -> Pre-commit hook evaluation engine is stable.
- [ ] `lib/plan_resolver.sh` -> Shorthand resolver parsing engine is untouched.
- [ ] `lib/planning_health.sh` -> Planning health integrity engine is untouched.
- [ ] `.githooks/*` -> Hook dispatcher entrypoints are untouched.

---

## ❓ 5. Open Questions (Optional / Gate)

* [ ] **Question 1: Bare `aapp plan` Output Formatting**
  - *Context:* When a user runs `aapp plan` in the shell without arguments, should it output only the active context or the full matrix?
  - *Proposal:* Output a composite status: if an active buffer is set, display the active plan details first; then print the active development count, frozen backlog count, and incubator count from `state_matrix.md`.
* [ ] **Question 2: Non-Destructive Backward Compatibility for `aapp plan-swap` / `plan-clear`**
  - *Context:* Many scripts and tests invoke `aapp plan-swap` and `aapp plan-clear`.
  - *Proposal:* Keep `plan-swap` and `plan-clear` as permanent zero-overhead aliases in `aapp` calling the underlying context routines, ensuring 100% backward compatibility without breaking changes.
* [ ] **Question 3: `/plan` vs `/aapp-digest` Ergonomics**
  - *Context:* How does `/plan <idea>` relate to `/aapp-digest <idea>`?
  - *Proposal:* `/aapp-digest` remains the formal lane router (checking whether an idea is an issue vs. a plan and consuming from `pickup.md`). `/plan <idea>` is the direct IDE shortcut that executes the same canonical blueprint scaffolding flow for developers who type `/plan` instinctively.

---

## 📦 6. Change Log & Refinement History
* **2026-09-18:** Plan drafted in `.plans/current/P20-canonical-plan-command-and-context-decoupling.md`. Scaffolds decoupling of execution context buffer (`aapp context`) from canonical blueprint planning (`/plan`, `/aapp-plan`), establishes the Canonical Planning Invariant overriding ephemeral IDE scratchpads, and defines native `/plan` skill bridging.
