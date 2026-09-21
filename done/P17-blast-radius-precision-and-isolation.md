# 🗺️ Plan P-17: Multi-Agent Lifecycle Switchboard & Worktree Isolation
* **Created:** 2026-09-16 | **Last Refined:** 2026-09-17
* **Target Issue / Milestone:** #57 *(Superseded: dissolved by Single-Active-Plan Architecture)*
* **Plan ID:** P-17
* **Status:** ✅ Done
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Frozen | 🟠 In Development | 🚫 BLOCKED -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent: Antigravity`, `AI-Vendor: Google`, `AI-Model: gemini-1.5-pro`). Synthetic or fake emails are strictly forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

---

## 1. Context & Architectural Goal
* **What**: Implement the **Single-Active-Plan Architecture**, introducing enterprise-grade execution lifecycle scaling, native Git worktree physical isolation for multi-agent swarms, and flagless CLI ergonomics:
  1. **Decoupled 5th Plan State (`🟠 In Development`)**: Decouple architectural specification approval (`🟢 Frozen`) from active in-flight execution (`🟠 In Development`), solving multi-agent allowlist inflation and enterprise scaling across large backlogs.
  2. **O(1) Worktree Stash / Pointer Buffer (`.git/aapp_active_plan`)**: Enable sub-millisecond execution checks (< 0.001ms) by pointing directly to the single active blueprint, eliminating O(N) directory sweeps and allowing native parallel agent execution across linked Git worktrees without cross-worktree interference.
  3. **Flagless Switchboard & Non-Interactive Progression**: Implement parameterless single-token CLI verbs (`aapp freeze-start`, `aapp start`, `aapp plan`, `aapp plan-swap`, `aapp plan-clear`), a non-interactive `/aapp-freeze` -> `/aapp-start` flow, and an atomic workflow accelerator `/aapp-freeze-start <plan>` to eliminate agent stalls and execution latency.
  4. **Compile-Time Integrity (Planning Health Pair 7)**: Prevent in-flight collisions by ensuring two blueprints cannot be actively `🟠 In Development` concurrently in the same working tree if their Target Files overlap.
  5. **Clean Vocabulary Migration**: Perform a clean, direct migration across active templates and documents to establish the 5-state lifecycle vocabulary without permanent legacy aliases.
* **Why**:
  - Previously, `🟢 Ready for Execution` conflated "approved specification in the backlog" with "currently being coded in the working tree". When multiple plans were approved, hooks scanned and grepped all plan files on every single tool write (O(N) performance cliff in large codebases) and merged their permissions into one porous allowlist.
  - **Resolution of Issue #57 (Cross-Plan Out-of-Bounds Isolation)**:
    Issue #57 is structurally dissolved and superseded by this architecture. Because the hook engine evaluates strictly the single designated in-flight blueprint (`🟠 In Development`), no concurrent plan's Target Files can ever override or bypass that plan's Out of Bounds boundaries.
  - *Note on Issue #56 (Glob Path Traversal)*: Issue #56 is decoupled into **P-18** (`P18-glob-path-traversal-precision.md`) to be fixed directly at the engine level prior to this plan.
* **Key Invariants & Constraints**:
  - **Authoritative Filesystem Buffer**: The active plan buffer at `$(git rev-parse --git-path aapp_active_plan)` is the sole source of truth. Environment variable overrides (e.g. `$AAPP_ACTIVE_PLAN`) are strictly forbidden to prevent self-granted permission bypasses.
  - **Worktree-Level Physical Isolation**: In Git linked worktrees (`git worktree add`), Git's native `--git-path` mechanism isolates active plan buffers per worktree automatically, enabling true parallel agent execution with zero cross-worktree interference.
  - **Zero Lifetime Aliases**: Direct vocabulary migration across templates and active blueprints.
  - **Non-Interactive & Flagless**: All CLI verbs are single-token commands without interactive stdin prompts or flag complexity.
  - **Pair 5 Compliance**: Under no circumstances may `.githooks/*`, `.agents/skills/*`, or `.claude/*` be placed in `### 📂 Target Files`. All hook enhancements live in `templates/` and sync via `aapp init`.

---

## 2. Technical Blueprint

### A. The 5th Plan State: `🟠 In Development` (Decoupling Freeze from In-Flight Execution)

We formally expand the plan lifecycle enum to establish parity with the Issue Lane:

```text
AAPP Plan Lifecycle:
🔴 Under Review  ──►  🟡 Refining  ──►  🟢 Frozen  ──►  🟠 In Development  ──►  🏛️ Done
   (Drafting)          (Refining)        (Backlog)         (In-Flight)        (Archived)
```

| State | Purpose & Role | Write Rights Granted |
| :--- | :--- | :--- |
| **🔴 Under Review** | Initial RFC / incubator sketch. Open questions unresolved. | **Zero**. Read-only specification. |
| **🟡 Refining** | Active design refinement. Resolving questions and checklist. | **Zero**. Read-only specification. |
| **🟢 Frozen** | **Approved Specification in Backlog.** Blast radius locked, questions resolved. Ready for implementation, but **not yet active**. | **Zero**. Sits safely in the greenlit backlog. Does not leak target permissions and does not cross-block other plans. |
| **🟠 In Development** | **Active Implementation Context.** The plan is currently being executed in the working tree. | **Enforces Blast Radius.** Target files permitted; Out of Bounds strictly enforced. |
| **🚫 BLOCKED** | Execution halted on a critical defect. | **Zero**. All commits and edits refused until cleared. |
| **🏛️ Done** | Verified, merged, and archived in `.plans/done/`. | **Zero**. Historical record. |

#### Non-Interactive Progression: `/aapp-freeze`, `/aapp-start`, and the `/aapp-freeze-start` Accelerator
To eliminate agent stalls and human friction, state transitions are strictly non-interactive:
1. `/aapp-freeze <plan>`: Verifies checklist & open questions, sets status to `🟢 Frozen`, marks blast radius `LOCKED`, and moves entry in `state_matrix.md` to the Greenlight Backlog. Non-interactive, zero stdin prompts.
2. `/aapp-start <plan>`: Transitions plan from `🟢 Frozen` to `🟠 In Development`, sets the local worktree pointer buffer (`.git/aapp_active_plan`), and unlocks code execution for that plan.
3. `/aapp-freeze-start <plan>` (CLI: `aapp freeze-start <plan>`): **The Atomic Workflow Accelerator.** Chains freeze verification and in-flight activation in a single step for immediate execution. Validates open questions and checklist, locks the blast radius, verifies the Disjointness Activation Gate, transitions the plan directly to `🟠 In Development`, binds the local worktree pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`), and unlocks code execution without requiring two separate commands.

#### The Disjointness Activation Gate
When an agent or developer activates a plan via `aapp start <plan>` or `aapp freeze-start <plan>`:
1. Verifies that the plan is in `🟢 Frozen` status (or for `freeze-start`, validates open questions/checklist first).
2. Checks whether any other plan is currently `🟠 In Development` in the same working tree.
   - If another plan is in flight: performs an intersection check between their `Target Files`.
   - If target files overlap: **Hard Block**: `"Cannot activate P-X: shares target files with in-flight plan P-Y. Finish P-Y first or isolate on a separate branch/worktree."`
   - If target files are completely disjoint: Permitted.
3. Updates the plan header to `* **Status:** 🟠 In Development`.
4. Writes the plan ID to the local worktree pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`).

---

### B. O(1) Worktree Stash / Pointer Buffer Architecture (`.git/aapp_active_plan`)

#### 1. The Enterprise Concurrency & Scaling Problem
In enterprise adoption, repositories accumulate dozens or hundreds of blueprints across incubators, backlogs, and concurrent feature teams.
- Scanning `.plans/current/*.md` with `grep` on every tool write creates an O(N) performance cliff (500ms–3s per edit).
- In multi-agent worktree setups, all worktrees share the same `.plans/current/` tree. Without a local pointer, Worktree B cannot know whether it owns `P-10` or `P-12`.

#### 2. Buffer Location & Native Worktree Isolation
The active plan buffer lives at:
```bash
ACTIVE_PLAN_FILE="$(git rev-parse --git-path aapp_active_plan 2>/dev/null || echo ".git/aapp_active_plan")"
PREV_PLAN_FILE="$(git rev-parse --git-path aapp_active_plan.prev 2>/dev/null || echo ".git/aapp_active_plan.prev")"
```

**Why this location is architecturally optimal:**
1. **Never Committed / Pristine Git State**: Located inside `.git/`, it is automatically untracked, completely private to the local environment, and cannot leak into git commits or remote branches.
2. **Native Git Worktree Isolation**:
   - In the primary working tree, `git rev-parse --git-path aapp_active_plan` resolves to `.git/aapp_active_plan`.
   - In a linked git worktree (e.g. `git worktree add ../wt-agent2 feature-hooks`), Git automatically resolves the path to `.git/worktrees/wt-agent2/aapp_active_plan`.
   - **Result:** Two agents working in parallel in separate worktrees get **100% collision-free, isolated active plan contexts natively without any special coordination!**
3. **Sub-Millisecond O(1) Speed**: Hook reads 1 line (`P-10`) in 0.001ms and opens exactly that 1 blueprint directly.
4. **Authoritative Single Source of Truth**: The buffer file is authoritative. No environment variable overrides exist, preventing agents from self-granting unauthorized permissions.

#### 2b. Canonical `.plans/` Resolution & Linked Worktree Isolation
1. **Canonical `.plans/` Worktree Resolution**:
   In linked Git worktrees (`git worktree add`), the orphan `plans` branch is not mounted locally (Git enforces that a branch cannot be checked out simultaneously in two worktrees). Hooks resolve the primary root dynamically:
   ```bash
   COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")"
   if [ -d "$COMMON_DIR" ]; then
       PRIMARY_ROOT="$(cd "$COMMON_DIR/.." 2>/dev/null && pwd)"
   else
       PRIMARY_ROOT="$REPO_ROOT"
   fi
   if [ -d "$REPO_ROOT/.plans" ]; then
       PLANS_DIR="$REPO_ROOT/.plans"
   elif [ -n "$PRIMARY_ROOT" ] && [ -d "$PRIMARY_ROOT/.plans" ]; then
       PLANS_DIR="$PRIMARY_ROOT/.plans"
   else
       PLANS_DIR=""
   fi
   ```
2. **Fail-Closed Quarantine in AAPP Repositories**:
   If an AAPP-managed repository is detected (e.g. hook executed from `.githooks/` or `aapp` configuration active), but `$PLANS_DIR/current` is unreachable or unmounted, hooks fail closed with a diagnostic quarantine rather than silently failing open.
3. **Physical Worktree Boundary Invariant**:
   Multi-agent concurrency strictly requires **one Git worktree per active agent**. Same-worktree multi-agent concurrency is forbidden to prevent buffer collisions on `.git/aapp_active_plan`.
4. **Design-Lock Prerequisite**:
   Grounded on **Plan P-16** delivered: because Section 2 and Section 4 of frozen blueprints are locked by pre-commit, no concurrent agent can mutate another agent's active blast radius via background file writes.

#### 3. Flagless Active Plan Switchboard (`aapp plan*` & `aapp freeze-start`)
Following the clean, parameterless AAPP command style (`aapp ai-commit`, `aapp ai-off`), commands are single-token verbs:
```bash
aapp freeze-start <plan-id> # Atomically freeze specification, transition to 🟠 In Development, and activate buffer
aapp start <plan-id>        # Transition plan from 🟢 Frozen to 🟠 In Development and activate buffer
aapp plan <plan-id>         # Point execution context to plan (stashing prior in .prev)
aapp plan-swap              # Swap between current and previous active plan (like 'git checkout -' / 'cd -')
aapp plan-clear             # Clear active plan buffer (revert to auto-discovery mode)
aapp plan                   # Display current active plan and its declared boundaries
```

**Zero-Duplication Composition in `lib/cmd_plan.sh`**:
`cmd_freeze_start` is composed cleanly from the atomic primitives:
```bash
cmd_freeze_start() {
    local plan="$1"
    cmd_freeze "$plan" && cmd_start "$plan"
}
```

---

### C. Hook Evaluation Hierarchy (Layer 1 & Layer 2)
When `templates/blast-radius-guard.sh` or `templates/aapp-pre-commit` evaluates a target file:

```text
┌─────────────────────────────────────────────────────────┐
│              Target File Evaluated by Hook               │
└───────────────────────────┬─────────────────────────────┘
                            │
                            ▼
    1. Check Section 2 Self-Protection (.githooks/*, etc.)
       └── MATCH? ──► 🛑 HARD DENIAL (Invariant quarantine)
                            │
                            ▼
    2. Resolve Active Plan Execution Context
       (Check .git/aapp_active_plan -> Single 🟠 Discovery)
                            │
       ┌────────────────────┴────────────────────┐
       ▼                                         ▼
[Designated Plan Found]                [No Plan Designated]
       │                                         │
       ▼                                         ▼
Check Designated Plan Only:            Count 🟠 In Development Plans:
- Target in Plan OOB?                  - Exactly 1 in-flight plan?
  ├── YES ──► 🛑 DENIED (OOB veto)       └── Auto-designate that plan!
- Target in Plan Targets?              - 0 in-flight plans?
  ├── YES ──► ✅ ALLOWED                 └── Fail-open (normal files allowed)
  └── NO  ──► 🛑 DENIED (Out of scope)  - 2+ in-flight plans?
                                         └── Human-Friendly Instruction:
                                             "Multiple plans in development [P-10, P-12].
                                              Run 'aapp plan <id>' to select context."
```

**Key Concurrency Benefits:**
- **Zero Cross-Plan Interference**: When Agent 1 executes `P-10`, Plan `P-12`'s Out of Bounds does NOT block Agent 1, and Plan `P-12`'s Target Files do NOT grant unauthorized access to Agent 1.
- **Drift-Rails Restored**: A plan's `### 🛑 Out of Bounds` safely functions as a plan-local drift rail without locking out other concurrent agents who legitimately need to touch those files under their own plans!

---

### D. Planning Health Integrity: In-Flight Collision Validator (Pair 7)
Beyond runtime hook enforcement, compile-time planning health verification in `lib/planning_health.sh` enforces static safety:

1. **Pair 7: In-Flight Boundary Collision Validator (Strictly `🟠 In Development`)**:
   - **Scope**: Checks collisions exclusively between active, in-flight (`🟠 In Development`) plans in the same workspace.
   - **Zero False Alarms for Backlog (`🟢 Frozen`)**: Blueprints sitting in `🟢 Frozen` are approved roadmap specifications awaiting work. Because roadmap milestones often touch the same core modules sequentially, backlog plans emit **zero collision warnings at freeze time**.
   - **Hard Block for In-Flight Overlaps**: If two blueprints in `.plans/current/` are marked `🟠 In Development` simultaneously in the same workspace, their Target Files must be strictly disjoint. If Plan A targets `path` and Plan B targets `path`:
     ```text
     ❌ [Pair 7 Violation] In-Flight Blueprint Collision!
        -> Plan 'P-12' targets 'src/core/router.sh'
        -> Plan 'P-10' also targets 'src/core/router.sh'
        -> In-flight plans in the same workspace cannot share target files.
        -> To resolve: Isolate execution on separate git worktrees/branches, or finish P-10 first.
     ```
   - If an advisory notice is emitted for related plans, it **specifically names the exact overlapping files**, preventing noisy generic warnings.
   - Pre-commit and `aapp start` immediately halt before allowing contradictory plans to execute concurrently in the same working tree.

---

### E. Clean Vocabulary & Template Alignment
1. **`templates/plan-template.md`**:
   - Update header status enum: `🔴 Under Review | 🟡 Refining | 🟢 Frozen | 🟠 In Development | 🚫 BLOCKED`.
2. **`templates/AGENTS.md`**:
   - Document the 5-state lifecycle, atomic `aapp freeze-start <id>`, `aapp start <id>`, and active plan swap buffer protocol (`aapp plan <id>`, `aapp plan-swap`, `$(git rev-parse --git-path aapp_active_plan)`).
   - Update `### 💥 Blast Radius Enforcement` with plan-scoped execution rules.
3. **`MANUAL.md` & `CHEATSHEET.md`**:
   - Add `/aapp-freeze-start <plan>`, `/aapp-start <plan>`, `aapp freeze-start`, `aapp start`, `aapp plan`, `aapp plan-swap`, and `aapp plan-clear` to command reference tables and user workflow sections.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Hook Engine Buffer Resolution & Concurrency Isolation
- [x] Task 1.1: Implement active plan context resolution (`$(git rev-parse --git-path aapp_active_plan)` -> auto-discovery of single `🟠` plan) in `templates/blast-radius-guard.sh`.
- [x] Task 1.2: Implement designated active plan evaluation in `templates/blast-radius-guard.sh` (evaluates strictly the active plan's Target Files and Out of Bounds).
- [x] Task 1.3: Implement active plan context resolution and enforcement in `templates/aapp-pre-commit`.

### Phase 2: Flagless Active Plan Switchboard (`lib/cmd_plan.sh`)
- [x] Task 2.1: Implement `lib/cmd_plan.sh` supporting flagless single-token verbs:
  - `aapp freeze-start <id>` (atomic freeze verification + activation into `🟠 In Development` + buffer set).
  - `aapp start <id>` (transitions `🟢 Frozen` -> `🟠 In Development` and sets buffer).
  - `aapp plan [id]` (sets buffer, stashes prior in `.prev`).
  - `aapp plan-swap` (toggles between current and `.prev`).
  - `aapp plan-clear` (removes buffer).
  - `aapp plan` (displays current active plan context and declared bounds).
- [x] Task 2.2: Wire `freeze-start`, `start`, `plan`, `plan-swap`, and `plan-clear` subcommands into main `aapp` dispatcher.
- [x] Task 2.3: Implement disjointness activation gate in `aapp start` and `aapp freeze-start` (checks target file overlap with in-flight plans).

### Phase 3: Planning Health Pair 7 & Status Vocabulary
- [x] Task 3.1: Update status recognition in `lib/planning_health.sh` to support `🟢 Frozen` and `🟠 In Development`.
- [x] Task 3.2: Implement Pair 7 In-Flight Boundary Collision check in `lib/planning_health.sh`, reporting exact overlapping file paths upon collision.

### Phase 4: Skills, Manual & Clean Vocabulary Migration
- [x] Task 4.1: Update `templates/plan-template.md` with the 5-state lifecycle and updated attribution trailer placeholder.
- [x] Task 4.2: Update `templates/AGENTS.md` blast radius rules, lifecycle definitions, and multi-agent plan context protocol.
- [x] Task 4.3: Update `templates/skills/aapp-freeze/SKILL.md` to transition plans to `🟢 Frozen` (approved backlog) without interactive prompts.
- [x] Task 4.4: Create `templates/skills/aapp-start/SKILL.md` to transition plans from `🟢 Frozen` to `🟠 In Development` and populate the active buffer.
- [x] Task 4.5: Create `templates/skills/aapp-freeze-start/SKILL.md` for atomic freeze and immediate execution activation.
- [x] Task 4.6: Create `templates/skills/aapp-plan/SKILL.md` for context switching (`plan`, `plan-swap`, `plan-clear`).
- [x] Task 4.7: Update `templates/state_matrix.md` to synchronize state matrix template with 5-state lifecycle (Backlog vs In-Development).
- [x] Task 4.8: Update `MANUAL.md` and `CHEATSHEET.md` with the new lifecycle commands (`freeze-start`, `start`, `plan`, `plan-swap`, `plan-clear`) and tables.
- [x] Task 4.9: Perform clean vocabulary migration across active blueprints in `.plans/current/`.

### Phase 5: Verification & Automated Test Suites
- [x] Task 5.1: Extend `tests/write-guard_test.sh` with test cases:
  - Plan lifecycle enforcement: `🟢 Frozen` grants zero write rights; `🟠 In Development` enforces declared boundaries.
  - Active plan buffer scoping: Plan A's OOB holds for Plan A, does not block Plan B when Plan B is active in buffer.
  - Flagless plan swap functionality (`aapp plan <id>`, `aapp plan-swap`).
  - Atomic workflow accelerator (`aapp freeze-start <id>`).
- [x] Task 5.2: Extend `tests/pre-commit_test.sh` with pre-commit parity test cases.
- [x] Task 5.3: Extend `tests/plan_resolver_test.sh` with Pair 7 collision validation and status resolution test cases.
- [x] Task 5.4: Sync hooks via `./aapp init` and run all test suites.

---

## 💥 4. Blast Radius & System Boundaries
*(Marked: **LOCKED** — Greenlit for implementation)*

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/blast-radius-guard.sh` -> Implement active plan buffer resolution and `🟠 In Development` enforcement.
- [ ] `templates/aapp-pre-commit` -> Implement active plan buffer resolution and pre-commit enforcement.
- [ ] `NEW FILE` -> `lib/cmd_plan.sh` -> Implement `aapp freeze-start`, `aapp start`, `aapp plan`, `aapp plan-swap`, and `aapp plan-clear` CLI switchboard.
- [ ] `aapp` -> Dispatch `freeze-start`, `start`, `plan`, `plan-swap`, and `plan-clear` commands to `lib/cmd_plan.sh`.
- [ ] `lib/planning_health.sh` -> Implement Pair 7 Active Blueprint Boundary Collision Validator and updated status vocabulary.
- [ ] `templates/plan-template.md` -> Document 5-state lifecycle and active plan swap buffer protocol.
- [ ] `templates/AGENTS.md` -> Synchronize protocol blast radius rules, state definitions, and multi-agent execution conventions.
- [ ] `templates/skills/aapp-freeze/SKILL.md` -> Update freeze verb to set status `🟢 Frozen` (backlog greenlight) non-interactively.
- [ ] `NEW FILE` -> `templates/skills/aapp-start/SKILL.md` -> Universal skill for activating plan into `🟠 In Development`.
- [ ] `NEW FILE` -> `templates/skills/aapp-freeze-start/SKILL.md` -> Universal skill for atomic freeze and start into `🟠 In Development`.
- [ ] `NEW FILE` -> `templates/skills/aapp-plan/SKILL.md` -> Universal skill for active plan buffer switching.
- [ ] `templates/state_matrix.md` -> Synchronize state matrix template with 5-state lifecycle (Backlog vs In-Development).
- [ ] `MANUAL.md` -> Document full command reference for `aapp freeze-start`, `aapp start`, `aapp plan`, `aapp plan-swap`, `aapp plan-clear`.
- [ ] `CHEATSHEET.md` -> Update cheat sheet loop and command tables with `aapp freeze-start`, `aapp start`, and plan switching.
- [ ] `tests/write-guard_test.sh` -> Add active plan buffer scoping, lifecycle, swap, and freeze-start test cases.
- [ ] `tests/pre-commit_test.sh` -> Add pre-commit active plan buffer and lifecycle parity tests.
- [ ] `tests/plan_resolver_test.sh` -> Add Pair 7 integrity test cases and status resolution coverage.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Section 2 self-protection (managed via `templates/` and `aapp init`).
- [ ] `.agents/skills/*` -> Section 2 self-protection (governance skills are locked).
- [ ] `.claude/*` -> Section 2 self-protection.
- [ ] `.cursor/rules/*` -> Section 2 self-protection.
- [ ] `lib/cmd_ai.sh`, `lib/cmd_init.sh`, `lib/cmd_status.sh` -> Unrelated CLI command implementations.
- [ ] `lib/plan_resolver.sh` -> Unrelated plan resolver logic (tracked separately).
- [ ] `src/` -> Application source code is completely outside hook engine scope.

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1: Multi-Agent Concurrency, State Decoupling & Flagless Buffer Protocol**
  - *Resolution:* Adopted decoupled 5-state lifecycle (`🟢 Frozen` = approved backlog spec, `🟠 In Development` = active coding) combined with local worktree pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`). Non-interactive `/aapp-freeze` and `/aapp-start` flow, augmented by atomic `/aapp-freeze-start`. Flagless verbs (`aapp plan-swap`, `aapp plan-clear`). Native Git worktree physical isolation. Dropped environment variable override to prevent self-granted permissions.

* [x] **Question 2: Scope of Planning Health Pair 7 (In-Flight Collisions vs Backlog Warnings)**
  - *Resolution:* Strictly scoped to `🟠 In Development` plans executing in the same workspace. Blueprints sitting in `🟢 Frozen` emit **zero warnings** at freeze time. Roadmap specifications often touch the same modules across sequential milestones; emitting warnings during freeze creates unnecessary friction. Pair 7 boundary collision checks enforce hard blocks exclusively when two plans are actively marked `🟠 In Development` concurrently in the same working tree. Any advisory notices must explicitly report the conflicting filenames.

---

## 📦 6. Change Log & Refinement History
* **2026-09-17:** Completed and verified in commit `df1828b`. All 247 automated test cases passing. Archiving to `.plans/done/`.
* **2026-09-17:** Plan activated into 🟠 In Development via start.
* **2026-09-17:** Plan frozen and greenlit (`🟢 Ready for Execution`). Integrated linked worktree primary root resolution (`PRIMARY_ROOT` via `git-common-dir`), fail-closed quarantine for missing `.plans/`, and Physical Worktree Boundary Invariant (1 worktree per agent). Grounded on P-16 design-lock delivery. Blast radius locked.
* **2026-09-17:** Added `aapp freeze-start` and `/aapp-freeze-start` compound workflow verb: atomically freezes specification and activates plan into `🟠 In Development` with worktree buffer binding in a single command, accelerating immediate single-plan execution without multi-command friction.
* **2026-09-17:** Plan refocused on Multi-Agent Lifecycle Switchboard and Worktree Buffer Architecture following red team evaluation: decoupled Issue #56 (glob traversal precision) into P-18 to be implemented prior to P-17; confirmed Issue #57 is structurally superseded and dissolved by the single active plan model; dropped `$AAPP_ACTIVE_PLAN` environment variable to prevent self-granted permissions; marked new targets with `NEW FILE ->`; dropped `lib/plan_resolver.sh` from target files; updated attribution trailer invariant to P-14 standard; and adopted direct vocabulary migration (zero lifetime aliases).
* **2026-09-16:** Resolved Open Questions 2 & 3: established strict syntax rules for parameterized patterns and bracket character classes (`[...]`) to prevent raw regex or malformed file names, backed by Planning Health pattern validation. Confirmed Planning Health Pair 7 collision check is strictly scoped to in-flight (`🟠 In Development`) plans, ensuring `🟢 Frozen` backlog plans emit zero false alarms at freeze time.
* **2026-09-16:** Plan refined following ergonomic review: adopted non-interactive two-step progression (`/aapp-freeze` -> `/aapp-start`), eliminating interactive stdin prompts. Formulated single-token flagless command suite (`aapp plan-swap`, `aapp plan-clear`). Added documentation target files (`MANUAL.md`, `CHEATSHEET.md`, skills).
* **2026-09-16:** Plan amended following architectural review: introduced the 4th plan lifecycle state (`🟠 In Development`) to decouple specification approval (`🟢 Frozen`) from active execution, eliminating O(N) multi-plan allowlist inflation. Designed the O(1) Worktree Stash / Pointer Buffer architecture (`$(git rev-parse --git-path aapp_active_plan)`), providing sub-millisecond execution and native Git worktree multi-agent physical isolation.
* **2026-09-16:** Plan initialized and drafted from issues #56 and #57 (`aapp-digest`). Proposed `glob_to_regex` translation engine, two-phase global OOB veto, Pair 7 collision validation, and authoring doc updates.
