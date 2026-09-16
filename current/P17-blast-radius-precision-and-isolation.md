# 🗺️ Plan P-17: Blast Radius Precision & Cross-Plan OOB Isolation
* **Created:** 2026-09-16 | **Last Refined:** 2026-09-16
* **Target Issue / Milestone:** #56, #57
* **Plan ID:** P-17
* **Status:** 🔴 Under Review
<!-- Status must be exactly ONE of: 🔴 Under Review | 🟡 Refining | 🟢 Ready for Execution | 🚫 BLOCKED -->

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
* **What**: Fix two core security/safety defects in the AAPP blast radius enforcement engine:
  1. **Glob Path Traversal Precision (`#56`)**: Prevent single-star wildcards (`*`) from matching path separators (`/`), preventing patterns like `src/*.py` from unintentionally admitting nested subdirectories like `src/deep/nested/file.py`.
  2. **Cross-Plan Out-of-Bounds Isolation (`#57`)**: Establish Out of Bounds (`### 🛑 Out of Bounds`) as an authoritative global veto fence across all active blueprints, preventing concurrent plans from overriding another plan's explicit safety boundaries.
* **Why**:
  - In `templates/blast-radius-guard.sh` and `templates/aapp-pre-commit`, pattern matching relies on bash `[[ "$target" == $pattern ]]`. In bash pattern matching, `*` matches arbitrary strings across directory boundaries. This renders single-directory boundaries porous.
  - In concurrent execution, evaluating plans sequentially where a match in Plan B overrides an OOB rejection in Plan A creates a dangerous security hole where an agent can edit forbidden files simply because another active plan targeted them.
* **Key Invariants & Constraints**:
  - **Zero External Dependencies**: Pure Bash implementation for both `blast-radius-guard.sh` and `aapp-pre-commit`. Sub-millisecond execution with zero Python or AWK subshell overhead during path evaluation.
  - **Backward Compatibility**: Exact file paths (`src/file.py`) and directory prefixes (`dir/`) continue to work seamlessly without syntax changes.
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

### B. Multi-Agent Active Plan Stash / Swap Buffer (`.git/aapp_active_plan`)

#### 1. The Real-Life Multi-Agent Concurrency Reality
In practical development, two or more agents (or a human and an agent, or concurrent subagents) frequently work on different blueprints simultaneously:
- **Agent 1** implements `P-10` (Remote Sync).
- **Agent 2** implements `P-12` (Lifecycle Hooks).

Neither git hooks (`pre-commit`) nor agent tool interceptors (Claude Code `PreToolUse` / Antigravity) permit passing runtime command-line parameters when triggered. However, **hooks run locally on disk and can inspect the filesystem**.

By introducing an active plan **stash/swap buffer**, an agent or human designates which plan their current execution session is executing. The hook inspects this buffer to know precisely which plan's boundaries apply.

#### 2. Buffer Location & Native Worktree Isolation
The active plan buffer is stored at:
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
3. **Shell / Process Override**: In addition to the buffer file, the hook inspects `$AAPP_ACTIVE_PLAN`. If set in the current subshell, it overrides the filesystem buffer without disk I/O.

#### 3. Active Plan Switchboard & Swap Lifecycle (`aapp plan`)
Developers and agents manage the active plan buffer via concise CLI commands:
```bash
aapp plan <plan-id>   # Set active plan (stashes current active plan to .prev)
aapp plan --swap      # Swap between current and previous active plan (like 'git checkout -')
aapp plan --clear     # Clear active plan buffer (revert to auto-discovery mode)
aapp plan             # Display current active plan and its declared boundaries
```

#### 4. Hook Evaluation Hierarchy (Layer 1 & Layer 2)
When `blast-radius-guard.sh` or `aapp-pre-commit` evaluates a target file:
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
       (Check $AAPP_ACTIVE_PLAN -> .git/aapp_active_plan -> Auto-discovery)
                            │
       ┌────────────────────┴────────────────────┐
       ▼                                         ▼
[Specific Plan Designated]             [No Plan Designated]
       │                                         │
       ▼                                         ▼
Check Designated Plan Only:             Count 🟢 Greenlit Plans:
- Target in Plan OOB?                   - Exactly 1 plan?
  ├── YES ──► 🛑 DENIED (OOB veto)        └── Auto-designate that plan!
- Target in Plan Targets?               - 0 plans?
  ├── YES ──► ✅ ALLOWED                  └── Fail-open (normal files allowed)
  └── NO  ──► 🛑 DENIED (Out of scope)   - 2+ plans?
                                          └── Two-Phase Global Scan or Prompt
```

**Key Concurrency Benefits:**
- **Zero Cross-Plan Interference**: When Agent 1 executes `P-10`, Plan `P-12`'s Out of Bounds does NOT block Agent 1, and Plan `P-12`'s Target Files do NOT grant unauthorized access to Agent 1.
- **Drift-Rails Restored**: A plan's `### 🛑 Out of Bounds` safely functions as a plan-local drift rail without locking out other concurrent agents who legitimately need to touch those files under their own plans!

---

### C. Two-Phase Active Boundary Evaluation (Fallback Mode)
When multiple plans are greenlit and NO active plan has been designated in `.git/aapp_active_plan`, the hook executes a two-phase fallback:
1. **Phase 1 (Global Out of Bounds Scan)**: If any greenlit plan lists the file in OOB, it is rejected immediately.
2. **Phase 2 (Target Authorization)**: If no greenlit plan excludes it, verify if any greenlit plan authorises it.
3. **Advisory Diagnostic**: The hook emits a notice advising the user/agent to designate an active plan (`aapp plan <id>`) to eliminate cross-plan ambiguity.

---

### D. Planning Health Pair 7: Active Blueprint Boundary Collision Validator
Beyond runtime hook enforcement, we introduce compile-time / planning health verification in `lib/planning_health.sh`:
- **Pair 7 (Target Files vs Concurrent OOB Collision)**:
  - When multiple blueprints in `.plans/current/` are greenlit (`🟢 Ready for Execution`), their boundaries must be mutually disjoint unless active plan isolation is maintained.
  - If Plan A targets `path` and Plan B declares `path` Out of Bounds, `check_planning_health` emits:
    ```text
    ❌ [Pair 7 Violation] Active Blueprint Boundary Collision!
       -> Plan 'P-12' targets 'src/core/router.sh'
       -> Plan 'P-10' marks 'src/core/router.sh' OUT OF BOUNDS
       -> Concurrent plans cannot have conflicting boundary declarations in shared mode.
       -> To resolve: Use worktree isolation with 'aapp plan', or align plan boundaries.
    ```
  - Pre-commit and `aapp freeze` warn or halt before allowing contradictory plans to execute in shared fallback mode.

---

### E. Documentation & Authoring Semantics Alignment
1. **`templates/plan-template.md`**:
   - Explicitly document glob semantics in `### 📂 Target Files` and `### 🛑 Out of Bounds`:
     - `src/foo.py` -> exact file match
     - `src/` -> recursive directory prefix (all files under `src/`)
     - `src/*.py` -> single-directory glob (`*` does not cross `/`)
     - `src/**/*.py` -> recursive glob (`**` crosses `/`)
2. **`templates/AGENTS.md`**:
   - Document the active plan stash/swap protocol (`aapp plan <id>`, `aapp plan --swap`, `$(git rev-parse --git-path aapp_active_plan)`).
   - Update `### 💥 Blast Radius Enforcement` with exact glob semantics and plan-scoped execution rules.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Foundation & Regex Engine
- [ ] Task 1.1: Implement pure-Bash `glob_to_regex` helper in `templates/blast-radius-guard.sh`.
- [ ] Task 1.2: Implement pure-Bash `glob_to_regex` helper in `templates/aapp-pre-commit`.
- [ ] Task 1.3: Fix bash regex syntax error in `lib/plan_resolver.sh:267` (avoid unquoted backticks inside `[[ =~ ]]`).

### Phase 2: Active Plan Stash/Swap Buffer & Boundary Engine
- [ ] Task 2.1: Implement active plan resolution (`$AAPP_ACTIVE_PLAN` -> `$(git rev-parse --git-path aapp_active_plan)` -> auto-discovery) in `templates/blast-radius-guard.sh`.
- [ ] Task 2.2: Implement active plan resolution in `templates/aapp-pre-commit`.
- [ ] Task 2.3: Implement `aapp plan` CLI management verb in `lib/cmd_plan.sh` (`set`, `--swap`, `--clear`, `--show`).
- [ ] Task 2.4: Wire `plan` subcommand into main `aapp` dispatcher.
- [ ] Task 2.5: Implement Pair 7 Boundary Collision check in `lib/planning_health.sh`.

### Phase 3: Template & Rule Updates
- [ ] Task 3.1: Update `templates/plan-template.md` with explicit glob semantics, swap buffer conventions, and OOB invariant.
- [ ] Task 3.2: Update `templates/AGENTS.md` blast radius rules and multi-agent plan context protocol.
- [ ] Task 3.3: Update `templates/skills/aapp-freeze/SKILL.md` to auto-seed active plan buffer on freeze if unset.

### Phase 4: Verification & Automated Test Suites
- [ ] Task 4.1: Extend `tests/write-guard_test.sh` with test cases:
  - Single-segment wildcard (`src/*.py` matches `src/a.py`, blocks `src/sub/a.py`).
  - Recursive globstar (`src/**/*.py` matches `src/sub/a.py`).
  - Question mark (`src/?.py` matches single char).
  - Active plan buffer scoping: Plan A's OOB holds for Plan A, does not block Plan B when Plan B is active in buffer.
  - Plan swap functionality (`aapp plan <id>`, `aapp plan --swap`).
- [ ] Task 4.2: Extend `tests/pre-commit_test.sh` with pre-commit parity test cases.
- [ ] Task 4.3: Extend `tests/plan_resolver_test.sh` with Pair 7 collision validation test cases.
- [ ] Task 4.4: Sync hooks via `./aapp init` and run all test suites (188+ tests).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/blast-radius-guard.sh` -> Implement `glob_to_regex`, active plan swap buffer resolution, and scoped OOB evaluation.
- [ ] `templates/aapp-pre-commit` -> Implement `glob_to_regex`, active plan swap buffer resolution, and pre-commit enforcement.
- [ ] `lib/cmd_plan.sh` -> Implement `aapp plan` CLI command for active plan buffer management (`set`, `--swap`, `--clear`, `--show`).
- [ ] `aapp` -> Dispatch `plan` command to `lib/cmd_plan.sh`.
- [ ] `templates/plan-template.md` -> Document glob semantics (`*`, `**`, `dir/`) and active plan swap buffer protocol.
- [ ] `templates/AGENTS.md` -> Synchronize protocol blast radius rules and multi-agent execution conventions.
- [ ] `templates/skills/aapp-freeze/SKILL.md` -> Auto-seed active plan swap buffer upon blueprint freeze.
- [ ] `lib/planning_health.sh` -> Implement Pair 7 Active Blueprint Boundary Collision Validator.
- [ ] `lib/plan_resolver.sh` -> Fix unquoted backtick syntax error in archive ledger parsing.
- [ ] `tests/write-guard_test.sh` -> Add glob precision, active plan buffer scoping, and swap test cases.
- [ ] `tests/pre-commit_test.sh` -> Add pre-commit glob, active plan buffer, and OOB parity tests.
- [ ] `tests/plan_resolver_test.sh` -> Add Pair 7 integrity test cases.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Section 2 self-protection (managed via `templates/` and `aapp init`).
- [ ] `.agents/skills/*` -> Section 2 self-protection (governance skills are locked).
- [ ] `.claude/*` -> Section 2 self-protection.
- [ ] `.cursor/rules/*` -> Section 2 self-protection.
- [ ] `lib/cmd_ai.sh`, `lib/cmd_init.sh`, `lib/cmd_status.sh` -> Unrelated CLI command implementations.
- [ ] `src/` -> Application source code is completely outside hook engine scope.

---

## ❓ 5. Open Questions (Optional / Gate)

* [ ] **Question 1: Active Plan Stash / Swap Buffer Protocol & Multi-Agent Ergonomics**
  - *The Real-Life Multi-Agent Context:*
    In multi-agent environments, two or more agents work concurrently on different plans (e.g. Agent 1 on P-10, Agent 2 on P-12). Because hooks cannot accept CLI arguments at invocation time, the hook inspects the filesystem buffer at `$(git rev-parse --git-path aapp_active_plan)`.
    - **In Git Worktrees:** `git rev-parse --git-path` automatically resolves to each worktree's private git directory (`.git/worktrees/<wt>/aapp_active_plan`), providing native, collision-free physical isolation out of the box!
    - **In a Single Worktree:** Agents swap execution contexts via `aapp plan <id>`, with previous plan stashed in `.git/aapp_active_plan.prev` for instant toggling (`aapp plan --swap`).
  - *Specific Design Choices for User Confirmation:*
    1. **Auto-seeding on `/aapp-freeze`**: When `/aapp-freeze <plan>` greenlights a blueprint, should it automatically write that plan ID into `aapp_active_plan` if the buffer is currently empty?
       - *Recommendation:* Yes. In single-plan workflows, this provides zero-friction progression directly into coding without requiring a manual `aapp plan <id>` invocation.
    2. **Fallback Behavior when Buffer is Unset and 2+ Plans are Greenlit**: If multiple plans are greenlit in `.plans/current/` and `aapp_active_plan` is empty:
       - *Option A (Strict Gate):* Refuse and instruct: `"Multiple plans are greenlit [P-10, P-12]. Set active plan context via 'aapp plan <id>' before editing."`
       - *Option B (Shared Fallback):* Evaluate against the union of greenlit plans with global OOB veto, emitting a non-blocking diagnostic.
       - *Recommendation:* Option A. Strict designation prevents accidental cross-plan boundary leakage when multiple plans are active.
    3. **Buffer Depth**: Is a 1-level swap buffer (`aapp_active_plan` and `aapp_active_plan.prev`, identical to `cd -` / `git checkout -`) sufficient, or is a full multi-item stack needed?
       - *Recommendation:* A 1-level swap buffer is lean, POSIX-simple, and covers 99% of hotfix/toggling workflows without state-stack corruption risks.

* [ ] **Question 2: Scope of Planning Health Pair 7 (Greenlit Only vs Incubated)**
  - *Context:* Should Pair 7 check collisions only between 🟢 `Ready for Execution` plans, or also warn when incubated drafts (🔴/🟡) have boundary collisions?
  - *Recommendation:* Pair 7 should strictly block (`FAIL`) when two 🟢 plans collide without worktree isolation, and emit a soft advisory warning (`INFO`) when an incubated draft collides with an active plan.

* [ ] **Question 3: Bracket Expression Semantics (`[...]`)**
  - *Context:* Should bracket character classes (e.g. `[0-9]`, `[a-z]`) be officially supported in Target Files globs?
  - *Recommendation:* Yes, preserving standard POSIX bracket expressions allows authors to write patterns like `migrations/[0-9]*.sql` without needing full regex syntax.

---

## 📦 6. Change Log & Refinement History
* **2026-09-16:** Plan initialized and drafted from issues #56 and #57 (`aapp-digest`). Proposed `glob_to_regex` translation engine, two-phase global OOB veto, Pair 7 collision validation, and authoring doc updates.
