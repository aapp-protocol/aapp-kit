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

### B. Two-Phase Active Boundary Evaluation & Global OOB Veto Engine
Currently, both `templates/blast-radius-guard.sh` and `templates/aapp-pre-commit` iterate through active plans in a single loop:
```bash
# FLAGGED IN ISSUE #57:
if match_pattern_list "$TARGET" "${PLAN_OOB[@]}"; then
    DENIED_BY_PLAN="$PLAN"
    continue # <-- Bypassed if subsequent plan matches targets!
fi
if match_pattern_list "$TARGET" "${PLAN_TARGETS[@]}"; then
    ALLOWED_BY_A_PLAN=1
    break
fi
```

We restructure the evaluation into two strict, non-bypassable phases:

```text
┌────────────────────────────────────────────────────────┐
│ Target File Evaluated: staged file or tool write target │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
          Phase 1: Global Out of Bounds Scan
    (Iterate ALL active unblocked plans in .plans/current/)
                           │
       Is file matched by ANY plan's OOB?
              ├── YES ──► 🛑 HARD DENIAL (Exit immediately)
              │            "File is explicitly OUT OF BOUNDS in active plan 'P-X'."
              └── NO
                           │
                           ▼
          Phase 2: Target File Authorization
       Is file matched by ANY plan's Target Files?
              ├── YES ──► ✅ AUTHORIZED (Allow write / commit)
              └── NO  ──► 🛑 REFUSED (Outside declared blast radius)
```

#### Phase 1: Global Veto Check
If any active unblocked plan declares a file in `### 🛑 Out of Bounds`, execution halts immediately. No plan's Target Files can override another active plan's OOB fence.

#### Phase 2: Target Authorization
Only when Phase 1 yields zero OOB vetoes is the target checked against active target files (`### 📂 Target Files` or `### 🚨 Emergency Hotfix Extensions`).

---

### C. Planning Health Pair 7: Active Blueprint Boundary Collision Validator
Beyond runtime hook enforcement, we introduce compile-time / planning health verification in `lib/planning_health.sh`:
- **Pair 7 (Target Files vs Concurrent OOB Collision)**:
  - When multiple blueprints in `.plans/current/` are greenlit (`🟢 Ready for Execution`), their boundaries must be mutually disjoint.
  - If Plan A targets `path` and Plan B declares `path` Out of Bounds, `check_planning_health` emits:
    ```text
    ❌ [Pair 7 Violation] Active Blueprint Boundary Collision!
       -> Plan 'P-12' targets 'src/core/router.sh'
       -> Plan 'P-10' marks 'src/core/router.sh' OUT OF BOUNDS
       -> Concurrent plans cannot have conflicting boundary declarations.
    ```
  - Pre-commit and `aapp freeze` immediately halt before allowing contradictory plans to be simultaneously active.

---

### D. Documentation & Authoring Semantics Alignment
1. **`templates/plan-template.md`**:
   - Explicitly document glob semantics in `### 📂 Target Files` and `### 🛑 Out of Bounds`:
     - `src/foo.py` -> exact file match
     - `src/` -> recursive directory prefix (all files under `src/`)
     - `src/*.py` -> single-directory glob (`*` does not cross `/`)
     - `src/**/*.py` -> recursive glob (`**` crosses `/`)
2. **`templates/AGENTS.md`**:
   - Update `### 💥 Blast Radius Enforcement` with exact glob semantics and global OOB veto rules.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Foundation & Regex Engine
- [ ] Task 1.1: Implement pure-Bash `glob_to_regex` helper in `templates/blast-radius-guard.sh`.
- [ ] Task 1.2: Implement pure-Bash `glob_to_regex` helper in `templates/aapp-pre-commit`.
- [ ] Task 1.3: Fix bash regex syntax error in `lib/plan_resolver.sh:267` (avoid unquoted backticks inside `[[ =~ ]]`).

### Phase 2: Boundary Engine Hardening
- [ ] Task 2.1: Refactor `templates/blast-radius-guard.sh` Section 4 into two-phase evaluation (Global OOB Veto -> Target Authorization).
- [ ] Task 2.2: Refactor `templates/aapp-pre-commit` Section 4 into two-phase evaluation (Global OOB Veto -> Target Authorization).
- [ ] Task 2.3: Implement Pair 7 Boundary Collision check in `lib/planning_health.sh`.

### Phase 3: Template & Rule Updates
- [ ] Task 3.1: Update `templates/plan-template.md` with explicit glob semantics and OOB veto invariant.
- [ ] Task 3.2: Update `templates/AGENTS.md` blast radius rules.

### Phase 4: Verification & Automated Test Suites
- [ ] Task 4.1: Extend `tests/write-guard_test.sh` with test cases:
  - Single-segment wildcard (`src/*.py` matches `src/a.py`, blocks `src/sub/a.py`).
  - Recursive globstar (`src/**/*.py` matches `src/sub/a.py`).
  - Question mark (`src/?.py` matches single char).
  - Global OOB veto across concurrent plans (Plan A's OOB blocks Plan B's target).
- [ ] Task 4.2: Extend `tests/pre-commit_test.sh` with parity test cases for pre-commit.
- [ ] Task 4.3: Extend `tests/plan_resolver_test.sh` with Pair 7 collision validation test cases.
- [ ] Task 4.4: Sync hooks via `./aapp init` and run all test suites (188+ tests).

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/blast-radius-guard.sh` -> Implement `glob_to_regex` and two-phase global OOB evaluation in Layer 1.
- [ ] `templates/aapp-pre-commit` -> Implement `glob_to_regex` and two-phase global OOB evaluation in Layer 2.
- [ ] `templates/plan-template.md` -> Document glob semantics (`*`, `**`, `dir/`) and OOB invariant.
- [ ] `templates/AGENTS.md` -> Synchronize protocol blast radius rules.
- [ ] `lib/planning_health.sh` -> Implement Pair 7 Active Blueprint Boundary Collision Validator.
- [ ] `lib/plan_resolver.sh` -> Fix unquoted backtick syntax error in archive ledger parsing.
- [ ] `tests/write-guard_test.sh` -> Add glob precision and OOB veto test cases.
- [ ] `tests/pre-commit_test.sh` -> Add pre-commit glob and OOB parity tests.
- [ ] `tests/plan_resolver_test.sh` -> Add Pair 7 integrity test cases.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Section 2 self-protection (managed via `templates/` and `aapp init`).
- [ ] `.agents/skills/*` -> Section 2 self-protection (governance skills are locked).
- [ ] `.claude/*` -> Section 2 self-protection.
- [ ] `.cursor/rules/*` -> Section 2 self-protection.
- [ ] `lib/cmd_*.sh` -> CLI command implementations outside planning/enforcement engine.
- [ ] `src/` -> Application source code is completely outside hook engine scope.

---

## ❓ 5. Open Questions (Optional / Gate)

* [ ] **Question 1: Strict Global OOB Veto vs Plan-Attributed Scoping**
  - *Context:* When Plan A marks `src/critical.py` Out of Bounds, should this be an unconditional global veto that blocks ANY plan from touching it (Option A, recommended), or should an agent be able to declare which plan it is currently executing so Plan B can proceed if the human explicitly scoped Plan A's OOB as an internal drift-rail (Option B)?
  - *Recommendation:* Option A (Strict Global Veto). Out of Bounds signifies a frozen boundary or dangerous territory for the entire repository while that plan executes. If Plan B legitimately needs to touch `src/critical.py`, Plan A should simply omit `src/critical.py` from Target Files rather than declaring it Out of Bounds.

* [ ] **Question 2: Scope of Planning Health Pair 7 (Greenlit Only vs Incubated)**
  - *Context:* Should Pair 7 check collisions only between 🟢 `Ready for Execution` plans, or also warn when incubated drafts (🔴/🟡) have boundary collisions?
  - *Recommendation:* Pair 7 should strictly block (`FAIL`) when two 🟢 plans collide, and emit a soft advisory warning (`INFO`) when an incubated draft collides with an active plan.

* [ ] **Question 3: Bracket Expression Semantics (`[...]`)**
  - *Context:* Should bracket character classes (e.g. `[0-9]`, `[a-z]`) be officially supported in Target Files globs?
  - *Recommendation:* Yes, preserving standard POSIX bracket expressions allows authors to write patterns like `migrations/[0-9]*.sql` without needing full regex syntax.

---

## 📦 6. Change Log & Refinement History
* **2026-09-16:** Plan initialized and drafted from issues #56 and #57 (`aapp-digest`). Proposed `glob_to_regex` translation engine, two-phase global OOB veto, Pair 7 collision validation, and authoring doc updates.
