# 🗺️ Plan P-20: Canonical Blueprint Planning & Active Plan Buffer Decoupling
* **Created:** 2026-09-18 | **Last Refined:** 2026-09-19
* **Target Issue / Milestone:** None
* **Plan ID:** P-20
* **Status:** 🟡 Refining
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

In AAPP v1.0.0 / P-17, the flagless switchboard introduced `aapp plan [id]`, `aapp plan-swap`, and `aapp plan-clear` to manage the local worktree active plan buffer (`.git/aapp_active_plan`). While mechanically effective, this architecture suffers from two severe usability and structural problems:

1. **Semantic Misalignment & Command Overloading**:
   - The verb `plan` implies authoring, reviewing, or tracking plans. Using `aapp plan <id>` to set an execution buffer causes cognitive friction.
   - If `aapp plan <arg>` is overloaded to both inspect IDs and scaffold new plans, polymorphic argument sniffing risks collisions on titles starting with numbers (e.g. `3-way-merge`) and compromises deterministic scripting.
   - The buffer management is decoupled to **`aapp active [id|swap|clear]`**, directly reflecting `.git/aapp_active_plan`.
   - The deterministic plan inspector is decoupled to **`aapp plan-status [id]`**, providing a clean, read-only status query.
   - Bare **`aapp plan [query]`** becomes an **educational switchboard** for users and agents alike, explaining the planning workflow and providing contextual pointers.
   - Legacy aliases (`plan-swap`, `plan-clear`) are retired without backward-compatibility baggage.
2. **The Ephemeral IDE Scratchpad Trap**:
   - AI IDEs (such as Antigravity IDE and Cursor) feature built-in planning modes (e.g. `/plan`) that output implementation plans into proprietary, ephemeral cache directories (such as `~/.gemini/antigravity-ide/brain/<conv-id>/implementation_plan.md`).
   - These internal scratchpads cannot be shared with other agents (Claude Code, Cursor, Codex, team members), are wiped when conversation context resets, lack deterministic Git-level Blast Radius enforcement, and are never permanently banked in the project's historical archive ledger (`000-archive-ledger.md`).

### The Two-Tier Defense Architecture

Catching developers who instinctively type `/plan` or request planning in natural language requires a structured defense:

* **Tier 1 (Primary Defense — Universal Coverage)**: The **`AGENTS.md` Canonical Planning Invariant**. Most planning requests are expressed in natural language ("plan out how we'd do X", "write an implementation plan", "let's design this"). The prose governance rule in `AGENTS.md` catches **all** of these across every AI tool with zero collision risk.
* **Tier 2 (Secondary Catch — Direct Token Interception)**: A thin `/plan` workspace skill registration. In IDEs where workspace skills take precedence over built-ins, typing `/plan` routes directly into AAPP.
* **Visible Artifact Invariant**: The honest catch is protected against inconsistency: the kit's path always leaves a visible artifact in `.plans/current/` that is visible in `aapp status`. If no file appears in `.plans/current/`, the developer immediately knows the IDE built-in intercepted the prompt.

---

## 2. Technical Blueprint

### A. CLI Command Taxonomy (`active`, `plan-status`, `plan`)

Establish an unambiguous, predictable separation across buffer management, plan inspection, and educational guidance:

```bash
# 1. Canonical Active Verbs (Buffer Management)
aapp active              # Display active execution plan and declared targets
aapp active <plan-id>    # Designate active execution plan in .git/aapp_active_plan
aapp active swap         # Swap between active and previous buffer (.prev)
aapp active clear        # Clear buffer (revert to auto-discovery)

# 2. Plan Lane Inspector (Deterministic Read-Only)
aapp plan-status         # Display plan matrix (in-dev, backlog, incubator)
aapp plan-status <id>    # Inspect specific plan: status, targets, open questions

# 3. Educational Switchboard (Guiding Humans & Agents)
aapp plan                # Print educational switchboard explaining planning workflow
aapp plan <query>        # Print educational switchboard with contextual pointers:
                         #   "ℹ️  To inspect plan status: aapp plan-status <query>"
                         #   "ℹ️  To set execution buffer: aapp active <query>"
                         #   "ℹ️  To draft a blueprint: use '/plan <idea>' in chat"
```

#### The Educational Switchboard Output Format
When `aapp plan` is invoked in the terminal, it outputs:
```text
🗺️  AAPP Planning Switchboard
--------------------------------------------------
To inspect plans or the active matrix:
  aapp plan-status              Inspect plan lane matrix
  aapp plan-status <plan-id>    Inspect specific plan details & targets

To manage the execution buffer:
  aapp active <plan-id>         Set active plan buffer for guard enforcement
  aapp active swap              Swap active buffer with previous plan
  aapp active clear             Clear buffer (revert to auto-discovery)

To draft or execute blueprints:
  Use '/plan <idea>' or '/aapp-plan <idea>' in your AI agent chat.
```

### B. Two-Lane Routing in Planning Workflows

To prevent bypassing the Two-Lanes invariant (`Never merge them`), `/plan <idea>` and `/aapp-plan <idea>` must execute the identical Step 2 lane-routing logic established in `/aapp-digest`:

1. **Step 1: Check lane**:
   - If `<idea>` describes wrong behavior, broken tests, or a bug in existing code -> Route to `.plans/ISSUES.md` and `.plans/issues_road_map.md` first. Only promote to a blueprint if the fix is large/architectural.
   - If `<idea>` describes a new capability, architectural feature, or refactor -> Route to the Plan lane.
2. **Step 2: Scaffold or Amend**:
   - Check `.plans/current/*.md` for related active blueprints (Amend vs. New).
   - If New: Allocate next unpadded ID (`get_next_plan_id`), scaffold `.plans/current/P<num>-<slug>.md` from `templates/plan-template.md`, and register in `.plans/state_matrix.md` under the Incubator.

### C. Thin Shim Architecture & Section 2 Guard Protection

To prevent the `plan` skill from becoming the only unprotected governance skill in the repository:

1. **Thin Shim (`templates/skills/plan/SKILL.md`)**:
   - `templates/skills/aapp-plan/SKILL.md` contains the full canonical procedure (protected by Section 2 pattern `*/.agents/skills/aapp-*`).
   - `templates/skills/plan/SKILL.md` is a thin 1-line pointer shim that delegates directly to `aapp-plan`.
2. **Narrow Section 2 Self-Protection Extension**:
   - Update `templates/blast-radius-guard.sh` and `templates/aapp-pre-commit` to explicitly protect the `plan` skill without restricting user-authored custom skills:
     ```bash
     .agents/skills/aapp-*|*/.agents/skills/aapp-*|\
     .claude/skills/aapp-*|*/.claude/skills/aapp-*|\
     .agents/skills/plan|*/.agents/skills/plan|.agents/skills/plan/*|*/.agents/skills/plan/*|\
     .claude/skills/plan|*/.claude/skills/plan|.claude/skills/plan/*|*/.claude/skills/plan/*)
         deny_action "Tampering with AAPP core configuration or governance skills is strictly prohibited."
         ;;
     ```

### D. Agent Governance Rules (`templates/AGENTS.md`)

Add the **Canonical Planning Invariant** to `templates/AGENTS.md`:

```markdown
### 📋 Canonical Planning Invariant (AAPP Blueprints Over IDE Ephemeral Artifacts)
- **Universal Blueprint Standard**: When asked to plan, architect, or scaffold an implementation (in natural language or via '/plan' / '/aapp-plan'), the agent MUST NEVER generate internal IDE scratchpads (such as 'implementation_plan.md' in IDE cache directories).
- **Two-Lane Routing**: Evaluate whether the request describes a bug in existing code (route to '.plans/ISSUES.md' first) or a new capability (scaffold in '.plans/current/').
- **Single Source of Truth**: All implementation plans MUST be authored as canonical AAPP blueprints in '.plans/current/P<num>-<slug>.md' using 'templates/plan-template.md' and registered in '.plans/state_matrix.md'.
- **Visible Artifact Standard**: Canonical planning always leaves a committed or staged file in '.plans/current/' that is visible in 'aapp status'.
```

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 0: Empirical Collision Verification
- [ ] Task 0.1: Empirically verify tool precedence for workspace skills named `plan` across Claude Code, Antigravity, and Cursor. Document known coverage in `MANUAL.md`.

### Phase 1: Guard Section 2 Self-Protection Extension
- [ ] Task 1.1: Add `.agents/skills/plan` and `.claude/skills/plan` to Section 2 self-protection in `templates/blast-radius-guard.sh` and `templates/aapp-pre-commit`.
- [ ] Task 1.2: Add regression test in `tests/write-guard_test.sh` asserting write denial on `plan/SKILL.md`.

### Phase 2: Active Plan Switchboard & CLI Ergonomics
- [ ] Task 2.1: Update `lib/cmd_plan.sh` to implement `aapp active [id|swap|clear]`.
- [ ] Task 2.2: Implement `aapp plan-status [id]` in `lib/cmd_plan.sh` as the deterministic read-only inspector.
- [ ] Task 2.3: Implement bare `aapp plan [query]` as the educational switchboard guiding users and agents.
- [ ] Task 2.4: Cleanly retire `plan-swap` and `plan-clear` from `aapp` dispatcher and `lib/cmd_plan.sh`.
- [ ] Task 2.5: Update `aapp` dispatcher and `lib/cmd_help.sh` documenting `active`, `plan-status`, and `plan`.

### Phase 3: Universal Skills & Thin Shim Bridging
- [ ] Task 3.1: Author `templates/skills/aapp-active/SKILL.md` for active buffer management (`/aapp-active`).
- [ ] Task 3.2: Update `templates/skills/aapp-plan/SKILL.md` with two-lane routing and visible artifact guidance.
- [ ] Task 3.3: Author `templates/skills/plan/SKILL.md` as a thin shim pointing to `aapp-plan`.
- [ ] Task 3.4: Update `lib/cmd_init.sh` (`sync_skills`) to synchronize both `aapp-*` skills and the `plan` shim to `.agents/skills/` and `.claude/skills/`.

### Phase 4: Agent Governance & Documentation
- [ ] Task 4.1: Add Canonical Planning Invariant to `templates/AGENTS.md`.
- [ ] Task 4.2: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` with `active`, `plan-status`, and `plan` contracts.
- [ ] Task 4.3: Update `README.md`, `MANUAL.md`, and `CHEATSHEET.md`.

### Phase 5: Automated Verification & Test Coverage
- [ ] Task 5.1: Update `tests/write-guard_test.sh` for `aapp active [id|swap|clear]` verbs, `plan-status`, and `plan` skill protection.
- [ ] Task 5.2: Update `tests/pre-commit_test.sh` to migrate buffer test assertions from `plan-swap` to `aapp active swap`.
- [ ] Task 5.3: Update `tests/install_test.sh` asserting `aapp-active` and `plan` skill sync and Claude bridging.
- [ ] Task 5.4: Run full automated regression suite (all test suites and planning health).
- [ ] Task 5.5: Record release notes in `CHANGELOG.md`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/blast-radius-guard.sh` -> Protect `plan` skill in Section 2 self-protection.
- [ ] `templates/aapp-pre-commit` -> Protect `plan` skill in Section 2 self-protection.
- [ ] `lib/cmd_plan.sh` -> Implement `aapp active`, `aapp plan-status`, and educational `aapp plan`.
- [ ] `aapp` -> CLI router updates for `active` and `plan-status`, removing `plan-swap`/`plan-clear`.
- [ ] `lib/cmd_help.sh` -> CLI help output updates.
- [ ] `lib/cmd_init.sh` -> Update `sync_skills` to bridge `plan` alongside `aapp-*`.
- [ ] `templates/skills/aapp-active/SKILL.md` -> NEW FILE: Active execution buffer switchboard (`/aapp-active`).
- [ ] `templates/skills/aapp-plan/SKILL.md` -> Repurposed canonical blueprint planning & matrix inspection.
- [ ] `templates/skills/plan/SKILL.md` -> NEW FILE: Thin shim pointing to `aapp-plan`.
- [ ] `templates/AGENTS.md` -> Add Canonical Planning Invariant (Tier 1 defense).
- [ ] `ARCHITECTURE.md` -> Update architecture interface definitions.
- [ ] `.agents/CODEMAP.md` -> Update callable contracts for `cmd_plan.sh` and skills.
- [ ] `README.md` -> Documentation alignment for `aapp active`, `aapp plan-status`, and `/plan`.
- [ ] `MANUAL.md` -> Document active buffer decoupling and collision coverage in Chapter 5.
- [ ] `CHEATSHEET.md` -> Command reference table updates.
- [ ] `tests/write-guard_test.sh` -> Active buffer switchboard and Section 2 protection tests.
- [ ] `tests/pre-commit_test.sh` -> Migrate buffer test assertions to `aapp active`.
- [ ] `tests/install_test.sh` -> Skill synchronization assertions for `plan` and `aapp-active`.
- [ ] `CHANGELOG.md` -> Feature release notes.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `lib/plan_resolver.sh` -> Shorthand resolver parsing engine is untouched.
- [ ] `lib/planning_health.sh` -> Planning health integrity engine is untouched.
- [ ] `.githooks/*` -> Hook dispatcher entrypoints are untouched.

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1: CLI `aapp plan` and `aapp plan-status` Architecture**
  - *Resolution:* `aapp plan-status [id]` is the canonical read-only CLI inspector. Bare `aapp plan [query]` serves as an educational switchboard guiding users and agents to `plan-status`, `active`, and `/plan` in chat, with contextual hints if an argument is passed.
* [x] **Question 2: Non-Destructive Backward Compatibility for `aapp plan-swap` / `plan-clear`**
  - *Resolution:* No backward compatibility or legacy aliases (`plan-swap`, `plan-clear`) are retained. As AAPP does not yet have adopters in the wild, clean design without deprecated alias baggage is strictly preferred. All active plan buffer operations exclusively use `aapp active [id|swap|clear]`.
* [x] **Question 3: Two-Lane Routing in `/plan <idea>`**
  - *Resolution:* `/plan <idea>` in chat incorporates the mandatory Step 2 routing check from `/aapp-digest`: bugs in existing code route to `ISSUES.md` first; new capabilities scaffold in `.plans/current/`.
* [x] **Question 4: Section 2 Protection Scope for `plan` Skill**
  - *Resolution:* Narrowly protect `.agents/skills/plan` and `.claude/skills/plan` in Section 2 without widening to all `.agents/skills/*`, preserving user autonomy to author custom skills.

---

## 📦 6. Change Log & Refinement History
* **2026-09-19:** Adopted `aapp plan-status [id]` as the canonical CLI inspector and made bare `aapp plan [query]` an educational switchboard guiding humans and agents to `plan-status`, `active`, and `/plan`.
* **2026-09-18:** Question 2 resolved per user decision: rejected backward compatibility aliases (`plan-swap`, `plan-clear`) to eliminate baggage and enforce clean CLI grammar (`aapp active [id|swap|clear]`).
* **2026-09-18:** Adopted `aapp active` and `/aapp-active` in place of `context` to eliminate cognitive collision with agent token context window and `aapp onboard` project context.
* **2026-09-18:** Plan refined to address Red Team findings: inverted priority making `AGENTS.md` prose invariant the primary Tier 1 catch; designed thin shim architecture for `templates/skills/plan/SKILL.md` delegating to `aapp-plan`; extended Section 2 self-protection to protect `plan` from agent tampering; disambiguated `aapp plan <id>` as a read-only inspector directing to `aapp active <id>`; integrated Two-Lane routing into planning workflows; added empirical Phase 0 collision testing; and aligned Blast Radius target files.
* **2026-09-18:** Plan drafted in `.plans/current/P20-canonical-plan-command-and-context-decoupling.md`.
