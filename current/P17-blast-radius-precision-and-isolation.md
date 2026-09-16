# 🗺️ Plan P-17: Blast Radius Precision & Cross-Plan OOB Isolation
* **Created:** 2026-09-16 | **Last Refined:** 2026-09-16
* **Target Issue / Milestone:** #56, #57
* **Plan ID:** P-17
* **Status:** 🔴 Under Review
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Frozen | 🟠 In Development | 🚫 BLOCKED -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Every commit you make must include your co-author trailer (`Co-authored-by: Antigravity <antigravity@google.com>`).
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🚫 BLOCKED`, stop, and ask the user.

---

## 1. Context & Architectural Goal
* **What**: Fix two core security/safety defects in the AAPP blast radius enforcement engine, and introduce enterprise-grade execution lifecycle scaling:
  1. **Glob Path Traversal Precision (`#56`)**: Prevent single-star wildcards (`*`) from matching path separators (`/`), preventing patterns like `src/*.py` from unintentionally admitting nested subdirectories like `src/deep/nested/file.py`.
  2. **Cross-Plan Out-of-Bounds Isolation (`#57`)**: Establish clear, non-bypassable boundary isolation across concurrent blueprints, preventing one plan's target permissions from overriding another plan's safety fences.
  3. **Decoupled 4th Plan State (`🟠 In Development`) & O(1) Worktree Pointer Architecture**: Decouple architectural spec approval (`🟢 Frozen`) from active execution (`🟠 In Development`), solving multi-agent concurrency and enterprise scaling (hundreds of accumulated plans) via a sub-millisecond local pointer buffer (`.git/aapp_active_plan`).
  4. **Clean, Non-Interactive & Flagless Ergonomics**: A strictly non-interactive command lifecycle (`/aapp-freeze` -> `/aapp-start`) with parameterless single-token verbs (`aapp plan-swap`, `aapp plan-clear`) avoiding interactive stdin hanging and complex flag parsing.
* **Why**:
  - In `templates/blast-radius-guard.sh` and `templates/aapp-pre-commit`, pattern matching relies on bash `[[ "$target" == $pattern ]]`. In bash pattern matching, `*` matches arbitrary strings across directory boundaries. This renders single-directory boundaries porous.
  - In concurrent execution, evaluating plans sequentially where a match in Plan B overrides an OOB rejection in Plan A creates a dangerous security hole where an agent can edit forbidden files simply because another active plan targeted them.
  - Currently, `🟢 Ready for Execution` conflates "approved specification in the backlog" with "currently being coded in the working tree". When multiple plans are frozen, hooks scan and grep all plan files on every single keystroke/write (O(N) performance lag in large codebases) and merge their permissions into one porous allowlist.
  - Novice developers need zero-worktree simplicity in single-folder development, while multi-agent swarms in separate git worktrees require native, collision-free isolation.
* **Key Invariants & Constraints**:
  - **Zero External Dependencies**: Pure Bash implementation for both `blast-radius-guard.sh` and `aapp-pre-commit`. Sub-millisecond execution with zero Python or AWK subshell overhead during path evaluation.
  - **O(1) Native Execution Speed**: Hooks directly inspect the worktree pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`) to evaluate only the designated in-flight blueprint, eliminating slow directory sweeps across dozens or hundreds of backlog plans.
  - **Worktree-Level Physical Isolation**: In Git linked worktrees (`git worktree add`), Git's native `--git-path` mechanism isolates active plan buffers per worktree automatically, enabling true parallel agent execution with zero cross-worktree interference.
  - **Non-Interactive & Flagless**: All verbs (`aapp start`, `aapp plan`, `aapp plan-swap`, `aapp plan-clear`) are single-token commands without interactive prompts or flags.
  - **Pair 5 Compliance**: Under no circumstances may `.githooks/*`, `.agents/skills/*`, or `.claude/*` be placed in `### 📂 Target Files`. All hook enhancements live in `templates/` and sync via `aapp init`.

---

## 2. Technical Blueprint

### A. Pure-Bash POSIX Glob-to-Regex Translation Engine (`glob_to_regex`)
Currently, `match_pattern_list` executes:
```bash
if [[ "$target" == $pattern ]]; then
    return 0
fi
```
Because `$pattern` is unquoted in bash, `*` matches `/`.

We introduce an efficient pure-Bash helper `glob_to_regex` that translates standard glob expressions into anchored POSIX Extended Regular Expressions (ERE):
- `*` -> `[^/]*` (matches zero or more non-slash characters within a single path segment)
- `**` -> `.*` (matches zero or more characters across arbitrary directory depths)
- `/**/` -> `/(.*/)?` (matches zero or more directory levels cleanly)
- `?` -> `[^/]` (matches exactly one non-slash character)
- Metacharacters `\ . + ^ $ ( ) [ ] { } |` are escaped.

#### Translation Algorithm
```bash
glob_to_regex() {
    local p="$1"
    # 1. Escape regex metacharacters: \ . + ^ $ ( ) { } |
    p="${p//\\/\\\\}"
    p="${p//./\\.}"
    p="${p//+/\\+}"
    p="${p//^/\\^}"
    p="${p//\$/\\\$}"
    p="${p//(/\\(}"
    p="${p//)/\\)}"
    p="${p//\{/\\\{}"
    p="${p//\}/\\\}}"
    p="${p//|/\\|}"

    # 2. Protect multi-segment globstars using collision-free sentinels
    p="${p//\/\*\*\//__SLASH_GLOBSTAR_SLASH__}"
    p="${p//\*\*/__GLOBSTAR__}"

    # 3. Translate single-segment wildcard and single-char tokens
    p="${p//\*/[^/]*}"
    p="${p//\?/[^/]}"

    # 4. Expand sentinels into POSIX regex
    p="${p//__SLASH_GLOBSTAR_SLASH__/\/(.*\/)?}"
    p="${p//__GLOBSTAR__/.*}"

    echo "^${p}\$"
}
```

#### Fast-Path Optimized `match_pattern_list`
To guarantee zero performance degradation for literal paths and directory prefixes, `match_pattern_list` executes a 3-tier fast path:
1. **Tier 1 (Exact Match)**: `[ "$target" = "$pattern" ]` -> return 0.
2. **Tier 2 (Directory Prefix)**: If `pattern` ends in `/`, check `[[ "$target" == "$pattern"* ]]` -> return 0.
3. **Tier 3 (Glob / Regex Match)**: If pattern contains `*` or `?`, compile via `glob_to_regex` and match via `[[ "$target" =~ $regex ]]`.

---

### B. The 4th Plan State: `🟠 In Development` (Decoupling Freeze from In-Flight Execution)

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

#### Non-Interactive Progression: `/aapp-freeze` vs `/aapp-start`
To eliminate agent stalls and human friction, state transitions are strictly non-interactive:
1. `/aapp-freeze <plan>`: Verifies checklist & open questions, sets status to `🟢 Frozen`, marks blast radius `LOCKED`, and moves entry in `state_matrix.md` to the Greenlight Backlog. Non-interactive, zero stdin prompts.
2. `/aapp-start <plan>`: Transitions plan from `🟢 Frozen` to `🟠 In Development`, sets the local worktree pointer buffer (`.git/aapp_active_plan`), and unlocks code execution for that plan.

#### The Disjointness Activation Gate
When an agent or developer activates a plan via `aapp start <plan>`:
1. Verifies that the plan is in `🟢 Frozen` status.
2. Checks whether any other plan is currently `🟠 In Development` in the same working tree.
   - If another plan is in flight: performs an intersection check between their `Target Files`.
   - If target files overlap: **Hard Block**: `"Cannot activate P-X: shares target files with in-flight plan P-Y. Finish P-Y first or isolate on a separate branch/worktree."`
   - If target files are completely disjoint: Permitted.
3. Updates the plan header to `* **Status:** 🟠 In Development`.
4. Writes the plan ID to the local worktree pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`).

---

### C. O(1) Worktree Stash / Pointer Buffer Architecture (`.git/aapp_active_plan`)

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
4. **Shell / Process Override**: In addition to the buffer file, the hook inspects `$AAPP_ACTIVE_PLAN`. If set in the current subshell, it overrides the filesystem buffer without disk I/O.

#### 3. Flagless Active Plan Switchboard (`aapp plan*`)
Following the clean, parameterless AAPP command style (`aapp ai-commit`, `aapp ai-off`), commands are single-token verbs:
```bash
aapp start <plan-id>  # Transition plan from 🟢 Frozen to 🟠 In Development and activate buffer
aapp plan <plan-id>   # Point execution context to plan (stashing prior in .prev)
aapp plan-swap        # Swap between current and previous active plan (like 'git checkout -' / 'cd -')
aapp plan-clear       # Clear active plan buffer (revert to auto-discovery mode)
aapp plan             # Display current active plan and its declared boundaries
```

---

### D. Hook Evaluation Hierarchy (Layer 1 & Layer 2)
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
       (Check $AAPP_ACTIVE_PLAN -> .git/aapp_active_plan -> Single 🟠 Discovery)
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

### E. Planning Health Pair 7: Active Blueprint Boundary Collision Validator
Beyond runtime hook enforcement, compile-time / planning health verification in `lib/planning_health.sh` enforces safety:
- **Pair 7 (Target Files vs Concurrent OOB Collision)**:
  - When multiple blueprints in `.plans/current/` are marked `🟠 In Development` simultaneously in the same workspace, their Target Files must be strictly disjoint.
  - If Plan A targets `path` and Plan B targets `path`, `check_planning_health` emits:
    ```text
    ❌ [Pair 7 Violation] In-Flight Blueprint Collision!
       -> Plan 'P-12' targets 'src/core/router.sh'
       -> Plan 'P-10' also targets 'src/core/router.sh'
       -> In-flight plans in the same workspace cannot share target files.
       -> To resolve: Isolate execution on separate git worktrees/branches, or finish P-10 first.
    ```
  - Pre-commit and `aapp start` immediately halt before allowing contradictory plans to execute concurrently in the same working tree.

---

### F. Documentation & Authoring Semantics Alignment
1. **`templates/plan-template.md`**:
   - Update header status enum: `🔴 Under Review | 🟡 Refining | 🟢 Frozen | 🟠 In Development | 🚫 BLOCKED`.
   - Explicitly document glob semantics in `### 📂 Target Files` and `### 🛑 Out of Bounds`:
     - `src/foo.py` -> exact file match
     - `src/` -> recursive directory prefix (all files under `src/`)
     - `src/*.py` -> single-directory glob (`*` does not cross `/`)
     - `src/**/*.py` -> recursive glob (`**` crosses `/`)
2. **`templates/AGENTS.md`**:
   - Document the 4-state lifecycle and active plan swap buffer protocol (`aapp start <id>`, `aapp plan <id>`, `aapp plan-swap`, `$(git rev-parse --git-path aapp_active_plan)`).
   - Update `### 💥 Blast Radius Enforcement` with exact glob semantics and plan-scoped execution rules.
3. **`MANUAL.md` & `CHEATSHEET.md`**:
   - Add `/aapp-start <plan>`, `aapp plan`, `aapp plan-swap`, and `aapp plan-clear` to command reference tables and user workflow sections.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Foundation & Regex Engine
- [ ] Task 1.1: Implement pure-Bash `glob_to_regex` helper in `templates/blast-radius-guard.sh`.
- [ ] Task 1.2: Implement pure-Bash `glob_to_regex` helper in `templates/aapp-pre-commit`.
- [ ] Task 1.3: Fix bash regex syntax error in `lib/plan_resolver.sh:267` (avoid unquoted backticks inside `[[ =~ ]]`).

### Phase 2: Lifecycle State & Active Plan Switchboard
- [ ] Task 2.1: Update status recognition in `lib/plan_resolver.sh` and `lib/planning_health.sh` to support `🟢 Frozen` and `🟠 In Development`.
- [ ] Task 2.2: Implement `lib/cmd_plan.sh` supporting flagless single-token verbs:
  - `aapp start <id>` (transitions `🟢 Frozen` -> `🟠 In Development` and sets buffer).
  - `aapp plan [id]` (sets buffer, stashes prior in `.prev`).
  - `aapp plan-swap` (toggles between current and `.prev`).
  - `aapp plan-clear` (removes buffer).
- [ ] Task 2.3: Wire `start`, `plan`, `plan-swap`, and `plan-clear` subcommands into main `aapp` dispatcher.
- [ ] Task 2.4: Implement active plan resolution (`$AAPP_ACTIVE_PLAN` -> `$(git rev-parse --git-path aapp_active_plan)` -> auto-discovery of single `🟠` plan) in `templates/blast-radius-guard.sh`.
- [ ] Task 2.5: Implement active plan resolution in `templates/aapp-pre-commit`.
- [ ] Task 2.6: Implement Pair 7 In-Flight Boundary Collision check in `lib/planning_health.sh`.

### Phase 3: Template, Rule & Manual Updates
- [ ] Task 3.1: Update `templates/plan-template.md` with explicit glob semantics, the 4-state lifecycle, and swap buffer conventions.
- [ ] Task 3.2: Update `templates/AGENTS.md` blast radius rules, lifecycle definitions, and multi-agent plan context protocol.
- [ ] Task 3.3: Update `templates/skills/aapp-freeze/SKILL.md` to transition plans to `🟢 Frozen` (approved backlog) without interactive prompts.
- [ ] Task 3.4: Create `templates/skills/aapp-start/SKILL.md` to transition plans from `🟢 Frozen` to `🟠 In Development` and populate the active buffer.
- [ ] Task 3.5: Create `templates/skills/aapp-plan/SKILL.md` for context switching (`plan`, `plan-swap`, `plan-clear`).
- [ ] Task 3.6: Update `MANUAL.md` and `CHEATSHEET.md` with the new lifecycle commands and tables.

### Phase 4: Verification & Automated Test Suites
- [ ] Task 4.1: Extend `tests/write-guard_test.sh` with test cases:
  - Single-segment wildcard (`src/*.py` matches `src/a.py`, blocks `src/sub/a.py`).
  - Recursive globstar (`src/**/*.py` matches `src/sub/a.py`).
  - Question mark (`src/?.py` matches single char).
  - Plan lifecycle enforcement: `🟢 Frozen` grants zero write rights; `🟠 In Development` enforces declared boundaries.
  - Active plan buffer scoping: Plan A's OOB holds for Plan A, does not block Plan B when Plan B is active in buffer.
  - Flagless plan swap functionality (`aapp plan <id>`, `aapp plan-swap`).
- [ ] Task 4.2: Extend `tests/pre-commit_test.sh` with pre-commit parity test cases.
- [ ] Task 4.3: Extend `tests/plan_resolver_test.sh` with Pair 7 collision validation and status resolution test cases.
- [ ] Task 4.4: Sync hooks via `./aapp init` and run all test suites (188+ tests).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/blast-radius-guard.sh` -> Implement `glob_to_regex`, active plan swap buffer resolution, and `🟠 In Development` enforcement.
- [ ] `templates/aapp-pre-commit` -> Implement `glob_to_regex`, active plan swap buffer resolution, and pre-commit enforcement.
- [ ] `lib/cmd_plan.sh` -> Implement `aapp plan`, `aapp plan-swap`, `aapp plan-clear`, and `aapp start` CLI switchboard.
- [ ] `aapp` -> Dispatch `plan`, `plan-swap`, `plan-clear`, and `start` commands to `lib/cmd_plan.sh`.
- [ ] `templates/plan-template.md` -> Document glob semantics (`*`, `**`, `dir/`), 4-state lifecycle, and active plan swap buffer protocol.
- [ ] `templates/AGENTS.md` -> Synchronize protocol blast radius rules, state definitions, and multi-agent execution conventions.
- [ ] `templates/skills/aapp-freeze/SKILL.md` -> Update freeze verb to set status `🟢 Frozen` (backlog greenlight) non-interactively.
- [ ] `templates/skills/aapp-start/SKILL.md` -> Universal skill for activating plan into `🟠 In Development`.
- [ ] `templates/skills/aapp-plan/SKILL.md` -> Universal skill for active plan buffer switching.
- [ ] `MANUAL.md` -> Document full command reference for `aapp start`, `aapp plan`, `aapp plan-swap`, `aapp plan-clear`.
- [ ] `CHEATSHEET.md` -> Update cheat sheet loop and command tables with `aapp start` and plan switching.
- [ ] `lib/planning_health.sh` -> Implement Pair 7 Active Blueprint Boundary Collision Validator and updated status vocabulary.
- [ ] `lib/plan_resolver.sh` -> Fix unquoted backtick syntax error and support new plan lifecycle states.
- [ ] `tests/write-guard_test.sh` -> Add glob precision, active plan buffer scoping, and swap test cases.
- [ ] `tests/pre-commit_test.sh` -> Add pre-commit glob, active plan buffer, and lifecycle parity tests.
- [ ] `tests/plan_resolver_test.sh` -> Add Pair 7 integrity test cases and status resolution coverage.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Section 2 self-protection (managed via `templates/` and `aapp init`).
- [ ] `.agents/skills/*` -> Section 2 self-protection (governance skills are locked).
- [ ] `.claude/*` -> Section 2 self-protection.
- [ ] `.cursor/rules/*` -> Section 2 self-protection.
- [ ] `lib/cmd_ai.sh`, `lib/cmd_init.sh`, `lib/cmd_status.sh` -> Unrelated CLI command implementations.
- [ ] `src/` -> Application source code is completely outside hook engine scope.

---

## ❓ 5. Open Questions (Optional / Gate)

* [x] **Question 1: Multi-Agent Concurrency, State Decoupling & Flagless Buffer Protocol**
  - *Resolution:* Adopted decoupled 4-state lifecycle (`🟢 Frozen` = approved backlog spec, `🟠 In Development` = active coding) combined with local worktree pointer buffer (`$(git rev-parse --git-path aapp_active_plan)`). Non-interactive `/aapp-freeze` and `/aapp-start` flow. Flagless verbs (`aapp plan-swap`, `aapp plan-clear`). Native Git worktree physical isolation.

* [ ] **Question 2: Scope of Planning Health Pair 7 (In-Flight Collisions vs Backlog Warnings)**
  - *Context:* Should Pair 7 check collisions only between `🟠 In Development` plans, or also warn when two `🟢 Frozen` backlog plans have overlapping boundaries?
  - *Recommendation:* Pair 7 should strictly block (`FAIL`) when two `🟠 In Development` plans share target files in the same workspace. For `🟢 Frozen` plans, it should emit an advisory notice (`INFO`) reminding authors that those plans must be executed sequentially or in separate worktrees.

* [ ] **Question 3: Bracket Expression Semantics (`[...]`)**
  - *Context:* Should bracket character classes (e.g. `[0-9]`, `[a-z]`) be officially supported in Target Files globs?
  - *Recommendation:* Yes, preserving standard POSIX bracket expressions allows authors to write patterns like `migrations/[0-9]*.sql` without needing full regex syntax.

---

## 📦 6. Change Log & Refinement History
* **2026-09-16:** Plan refined following ergonomic review: adopted non-interactive two-step progression (`/aapp-freeze` -> `/aapp-start`), eliminating interactive stdin prompts. Formulated single-token flagless command suite (`aapp plan-swap`, `aapp plan-clear`). Added documentation target files (`MANUAL.md`, `CHEATSHEET.md`, skills).
* **2026-09-16:** Plan amended following architectural review: introduced the 4th plan lifecycle state (`🟠 In Development`) to decouple specification approval (`🟢 Frozen`) from active execution, eliminating O(N) multi-plan allowlist inflation. Designed the O(1) Worktree Stash / Pointer Buffer architecture (`$(git rev-parse --git-path aapp_active_plan)`), providing sub-millisecond execution and native Git worktree multi-agent physical isolation.
* **2026-09-16:** Plan initialized and drafted from issues #56 and #57 (`aapp-digest`). Proposed `glob_to_regex` translation engine, two-phase global OOB veto, Pair 7 collision validation, and authoring doc updates.
