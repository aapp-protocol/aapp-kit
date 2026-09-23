# 🗺️ Plan P-33: Centralized Git Root Assertion & Fail-Fast Dispatch
* **Created:** 2026-09-22 | **Last Refined:** 2026-09-23
* **Target Issue / Milestone:** #80 *(supersedes #80 upon completion)*
* **Plan ID:** P-33
* **Status:** ⚡ In Development
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. A ✅ Done plan is archived in
     .plans/done/ and records terminal completion in the archive ledger. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Failure-First TDD Invariant**: When implementing code, you **must invert execution order**: write the negative/failure tests first (Phase 1), verify that they fail against current code (Red 🔴), implement the guard clauses to turn tests green (Phase 2), and only then clean up happy-path logic and subcommands (Phase 3). Never write production code before its corresponding failure test is in place.
> 5. **Fail-Closed Invariant**: Never suppress an error to keep execution going. Silent fallbacks (`|| true`, `|| pwd`, unchecked default returns, and empty catch blocks) are strictly prohibited. A failure must exit non-zero with a stderr diagnostic. If an error is genuinely benign, state why in a code comment and register it under Section 2's *Fallback Inventory*.
> 6. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 7. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 1. Context & Architectural Goal

### Problem Statement
In `lib/`, multiple subcommands and health checks redundantly re-derive `REPO_ROOT` using disparate fallback patterns:
```bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```
This pattern contains critical architectural defects:
1. **Silent Non-Repo Corruption**: The `|| pwd` fallback silently substitutes `$PWD` as the repository root when invoked outside a Git repository. Downstream commands proceed to evaluate `$PWD/.plans` or `$PWD/.agents` in arbitrary non-git directories (such as `/home/user` or `/tmp`), leading to unexpected side-effects or misleading errors.
2. **Dead Code**: In `lib/cmd_help.sh:10`, `REPO_ROOT` is declared with the `|| pwd` fallback but is never referenced anywhere in the file.
3. **Inconsistent Failure Semantics**: Across `lib/`, eight files contain `|| pwd` **repository-root** fallback derivations (`cmd_help.sh`, `cmd_plan.sh`, `cmd_test.sh`, `cmd_matrix.sh`, `cmd_pause.sh`, `cmd_ai.sh`, `planning_health.sh`, and `plan_resolver.sh`), `hook_dispatcher.sh` uses `|| true`, and `cmd_init.sh` uses multi-candidate bootstrap target resolution. A ninth file, `cmd_init.sh:73`, matches a naive `grep '|| pwd'` but is **not** a repository-root derivation — it is `CWD_REAL="$(pwd -P 2>/dev/null || pwd)"`, a physical-vs-logical path resolution — and is intentionally out of scope.
4. **Redundant Execution**: Because `aapp` sources subcommands (`source "$AAPP_LIB/cmd_*.sh"`), re-executing `git rev-parse` across every subcommand is completely unnecessary.

### Architectural Goal
Establish a single authoritative entrypoint assertion in `aapp` using a strict **Failure-First TDD (Negative-First)** workflow:
1. Validate Git repository membership once at the front door before command dispatch.
2. Fail fast with exit code 1 and a human-readable diagnostic message if operational commands (including `status`, `plan`, `test`, `pause`, `ai-*`, `sync`) are invoked outside a Git repository.
3. Exempt non-repo commands: `version`, `help`, `install`, `uninstall`, `upgrade`, `develop`, and `init` (which provides bootstrap target resolution).
4. Export canonical `REPO_ROOT` so all sourced subcommands inherit it cleanly without redundant `git rev-parse` calls or silent `|| pwd` fallbacks.
5. Purge dead `REPO_ROOT` declarations and legacy fallback idioms across `lib/`.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None for repository-root derivation (Clean Break)`. All silent `|| pwd` root fallbacks across `lib/` are purged outright. Three `|| pwd` occurrences survive by deliberate decision and are registered here per Invariant #5, so that a future `grep '|| pwd'` does not read as an unresolved violation:
  | Surviving occurrence | Why it is retained |
  | :--- | :--- |
  | `lib/cmd_init.sh:73` | `CWD_REAL="$(pwd -P 2>/dev/null || pwd)"` — physical-vs-logical path resolution, not a repository-root derivation. Bootstrap initializer is exempt (§5 Decision 5). |
  | `.githooks/blast-radius-guard:17` | Out of Bounds (§5 Decision 6). Runs under Git execution where repository context is already guaranteed. |
  | `.githooks/aapp-pre-commit:18` | Out of Bounds (§5 Decision 6). Same guarantee; guard engine self-protection forbids editing it from a feature plan. |
- Invocations of operational verbs outside a Git repository fail fast with exit code 1.

### 2.1 Front-Door Assertion in `aapp`

In the primary executable [`aapp`](aapp), immediately before command dispatch:

```bash
# ------------------------------------------------------------------------------
# 2. Repository Root Assertion
# ------------------------------------------------------------------------------
case "$CMD" in
    version|-v|--version|help|-h|--help|install|upgrade|update|uninstall|develop|init)
        # Exempt: machine-level operations, pure terminal help, or bootstrap setup
        ;;
    *)
        if ! REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
            echo "❌ Error: 'aapp $CMD' must be run inside a Git repository." >&2
            exit 1
        fi
        export REPO_ROOT
        ;;
esac
```

*Note on Operational Scope*: Operational commands intentionally require a valid Git repository:
- `test` requires a repository to discover suites or resolve adopter config (`aapp.testCommand`).
- `ai-*` commands (`ai-status`, `ai-commit`, `ai-notes`, `ai-off`, `ai-credits`, `ai-note`) operate directly on Git repository configuration (`git config`) and git notes (`refs/notes/commits`). Failing fast at the front door prevents cryptic raw Git stderr messages.

### 2.2 Subcommand Derivation Purge

Since `aapp` exports `REPO_ROOT`, sourced scripts in `lib/` can safely rely on `${REPO_ROOT}`:
- **`lib/cmd_help.sh`**: Delete line 10 completely (`REPO_ROOT` is unused).
- **`lib/cmd_test.sh`**: Purge redundant `repo_root="$(git rev-parse ... || pwd)"` at line 140, use `${REPO_ROOT}`.
- **`lib/cmd_ai.sh`**: Purge redundant `repo_root="$(git rev-parse ... || pwd)"` at line 289, use `${REPO_ROOT}`.
- **`lib/cmd_matrix.sh`**: Remove `REPO_ROOT="$(git rev-parse ...)"`, use existing `REPO_ROOT`.
- **`lib/cmd_pause.sh`**: Remove `REPO_ROOT="$(git rev-parse ...)"`, use existing `REPO_ROOT`.
- **`lib/cmd_plan.sh`**: Remove redundant derivation and use existing `REPO_ROOT`. **Worktree Invariant**: `REPO_ROOT` carries the active worktree root (matching `git rev-parse --show-toplevel`), while downstream resolution of `GIT_COMMON_DIR` and `PRIMARY_ROOT` remains intact for resolving `.plans` across worktrees.
- **`lib/cmd_hook.sh`**: Remove redundant `REPO_ROOT="$(git rev-parse ...)"`.
- **`lib/cmd_sync.sh`**: Remove redundant `REPO_ROOT="$(git rev-parse ...)"`.
- **`lib/cmd_status.sh`**: Remove redundant `REPO_ROOT="$(git rev-parse ...)"`.
- **`lib/planning_health.sh`**: Purge 6 occurrences of `|| pwd` fallback (lines 39, 297, 364, 466, 532, 615). Standardize on `${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}` and fail closed if empty.
- **`lib/cmd_init.sh`**: Intentionally untouched and exempt; handles custom bootstrap target resolution.
- **`lib/hook_dispatcher.sh`**: Standardize standalone fallback `${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}`. If empty, fail explicitly:
  ```bash
  if [ -z "${REPO_ROOT:-}" ]; then
      REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
          echo "❌ [Hook Dispatcher] Not inside a Git repository." >&2
          return 1 2>/dev/null || exit 1
      }
  fi
  ```
- **`lib/plan_resolver.sh`**: Standardize helper parameter `${4:-${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}}`. If empty, fail explicitly:
  ```bash
  if [ -z "$REPO_ROOT" ]; then
      REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
          echo "❌ [Plan Resolver] Not inside a Git repository." >&2
          return 1
      }
  fi
  ```
  Similarly in `allocate_plan_id()`:
  ```bash
  ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
  if [ -z "$ROOT" ]; then
      echo "❌ [Plan ID] Not inside a Git repository." >&2
      return 1
  fi
  ```

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Failure-First Negative Test Harness (Red 🔴)
- [x] Task 1.1: Add non-repo fail-fast test in `tests/install_test.sh`: Invoke operational commands (`status`, `plan`, `test`, `freeze`, `ai-status`) in an isolated non-git `/tmp` directory. Assert `exit code == 1` and assert stderr contains `'must be run inside a Git repository'`.
- [x] Task 1.2: Add exempt verbs test in `tests/install_test.sh`: Assert that exempt verbs (`version`, `help`, `install`) executed in a non-git directory succeed with `exit code == 0`.
- [x] Task 1.3: Run `bash tests/install_test.sh` to confirm negative tests FAIL (Red 🔴) against current code (current code silently uses `|| pwd` and returns exit 0).

### Phase 2: Front-Door Guard Clauses & Precondition Enforcement (Green 🟢)
- [x] Task 2.1: Add front-door repository assertion in `aapp` with command exemption switchboard.
- [x] Task 2.2: Export canonical `REPO_ROOT` for all operational commands.
- [x] Task 2.3: Re-run `bash tests/install_test.sh` to confirm negative tests turn Green 🟢.

### Phase 3: Subcommand De-Duplication & Dead Code Removal
- [x] Task 3.1: Delete dead `REPO_ROOT` declaration from `lib/cmd_help.sh`.
- [x] Task 3.2: Purge `|| pwd` fallback and redundant `git rev-parse` calls from `lib/cmd_plan.sh`, `lib/cmd_test.sh`, `lib/cmd_ai.sh`, `lib/cmd_matrix.sh`, `lib/cmd_pause.sh`, `lib/cmd_hook.sh`, `lib/cmd_sync.sh`, and `lib/cmd_status.sh`.
- [x] Task 3.3: Purge 6 occurrences of `|| pwd` in `lib/planning_health.sh` with fail-closed root resolution.
- [x] Task 3.4: Standardize standalone fail-closed fallback in `lib/plan_resolver.sh` and `lib/hook_dispatcher.sh` without `|| pwd`.

### Phase 4: Full Suite Regression Verification
- [x] Task 4.1: Run `./aapp test strict quiet` across all discovered test suites to verify complete suite pass.

### Phase 5: Documentation & Protocol Sync
- [x] Task 5.1: Update `ARCHITECTURE.md` documenting front-door repository assertion and failure-first invariant.
- [x] Task 5.2: Update `CHANGELOG.md` under `### Fixed`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `aapp` -> Add front-door Git repository assertion and export REPO_ROOT
- [ ] `lib/cmd_help.sh` -> Delete dead REPO_ROOT declaration
- [ ] `lib/cmd_test.sh` -> Purge redundant REPO_ROOT derivation and || pwd fallback at line 140
- [ ] `lib/cmd_ai.sh` -> Purge redundant REPO_ROOT derivation and || pwd fallback at line 289
- [ ] `lib/planning_health.sh` -> Purge 6 occurrences of || pwd fallback with fail-closed resolution
- [ ] `lib/cmd_plan.sh` -> Purge redundant REPO_ROOT derivation while preserving PRIMARY_ROOT worktree resolution
- [ ] `lib/cmd_matrix.sh` -> Purge redundant REPO_ROOT derivation and || pwd fallback
- [ ] `lib/cmd_pause.sh` -> Purge redundant REPO_ROOT derivation and || pwd fallback
- [ ] `lib/cmd_hook.sh` -> Remove redundant REPO_ROOT derivation
- [ ] `lib/cmd_sync.sh` -> Remove redundant REPO_ROOT derivation
- [ ] `lib/cmd_status.sh` -> Remove redundant REPO_ROOT derivation
- [ ] `lib/hook_dispatcher.sh` -> Standardize standalone fail-closed fallback without || pwd
- [ ] `lib/plan_resolver.sh` -> Standardize standalone fail-closed fallback without || pwd
- [ ] `tests/install_test.sh` -> Add automated test coverage for non-repo fail-fast and exempt verbs
- [ ] `ARCHITECTURE.md` -> Document centralized repository root assertion in Architecture Invariants
- [ ] `CHANGELOG.md` -> Record P-33 fix in Unreleased changelog

### 🧪 Required Tests (Failure & Boundary Assertions)
> List the failure cases to write and verify. Each test must assert an explicit error path (exit code, exception, or error message).
- [ ] `tests/install_test.sh::test_non_repo_failure` -> asserts exit 1 and stderr message when operational verbs (`status`, `plan`, `test`, `freeze`, `ai-status`) run outside a Git repository.
- [ ] `tests/install_test.sh::test_exempt_verbs_succeed` -> asserts exit 0 when exempt verbs (`version`, `help`, `install`) run outside a Git repository.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Guard engine self-protection. Runs under Git execution where repository context is already guaranteed. Untouched in this plan to maintain strict self-protection boundary.
- [ ] `templates/*` -> Distributed hook templates; changes to installed hooks are managed via dedicated governance workflows, not feature plans.
- [ ] `.agents/skills/*` -> Governance skills self-protection
- [ ] `.plans/ISSUES.md` -> Target data ledger (modified only via issue lifecycle)
- [ ] `.plans/state_matrix.md` -> Derived view (modified only via matrix derivation)
- [ ] `lib/cmd_init.sh` -> Bootstrap initializer with custom non-repo target discovery

---

## ❓ 5. Open Questions & Settled Decisions

1. **Failure Message & Diagnostic Output**: Should non-repo failures emit to `stderr` or `stdout`?
   - **Decision**: **stderr with exit 1 (Adopted Directive)**. CLI tooling must fail loudly on stderr (`echo "❌ Error: 'aapp $CMD' must be run inside a Git repository." >&2`) and exit with status code 1.
2. **Command Exemption Boundary**: Are any operational commands valid outside a Git repository?
   - **Decision**: **Strict Exemption List (Adopted Directive)**. Only pure terminal output (`version`, `help`), system installer tools (`install`, `uninstall`, `upgrade`, `develop`), and the bootstrap initializer (`init`) are exempt. All planning, matrix, pause, hook, attribution (`ai-*`), test, and sync operations require a valid Git repository.
3. **Standalone Library Sourcing**: How should library functions behave when sourced directly without `aapp` (e.g. in test fixtures or hooks)?
   - **Decision**: **Fail-Closed without `|| pwd` (Adopted Directive)**. Functions in `lib/plan_resolver.sh` and `lib/hook_dispatcher.sh` will check `${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}`. If empty, fail explicitly with diagnostic stderr and exit/return 1 rather than falling back to `$PWD`.
4. **Worktree Semantics & Primary Root Preservation**:
   - **Decision**: **Preserve `PRIMARY_ROOT` Resolution (Adopted Directive)**. Exporting `REPO_ROOT` from `aapp` yields the active worktree root when inside `.plans/`. `cmd_plan.sh` will continue to resolve `GIT_COMMON_DIR` and `PRIMARY_ROOT` downstream to ensure seamless `.plans/` discovery across worktrees.
5. **Bootstrap Target Exemption (`cmd_init.sh`)**:
   - **Decision**: **Keep `cmd_init.sh` Untouched (Adopted Directive)**. `cmd_init.sh` is specifically designed to run outside existing repos to bootstrap target workspaces and already manages its own fail-fast checks.
6. **Guard Hooks & Templates Out-of-Bounds Boundary (`.githooks/*` & `templates/*`)**:
   - **Decision**: **Keep Hooks Out of Bounds (Adopted Directive)**. Git hooks execute within Git lifecycle triggers where repository context is guaranteed. Pair 5 mechanically prevents plans from targeting `.githooks/*`. The fail-closed checks in `plan_resolver.sh` and `hook_dispatcher.sh` are fully compatible and unreachable as error triggers during normal Git operations.
7. **Lifecycle Toleration for Required Tests**:
   - **Decision**: **Enforce in `⚡ In Development` / Commit Time Only (Adopted Directive)**. Tests declared under `### 🧪 Required Tests` are planning-phase declarations during `📝 Refining` (authored in Phase 1). Hook presence checks must tolerate unwritten tests while refining, and enforce existence once in development.

---

## 📦 6. Change Log & Refinement History
* **2026-09-23:** Plan activated into ⚡ In Development via start.
* **2026-09-23:** Plan locked and frozen into 🔷 Frozen via freeze.

* **2026-09-23 (Red Team Round 3 Refinements):** Resolved Red Team findings F10–F11. Round 3 returned
  only editorial findings (no defects, no new files, no new search predicate), meeting the
  empty-round termination signal recorded as `P-15` F7; refinement closed and plan frozen.
  - F10: Corrected the §1 defect-3 count from nine to eight repository-root `|| pwd` derivations, and
    named `cmd_init.sh:73` explicitly as a physical-path resolution that matches a naive grep but is
    out of scope.
  - F11: Registered the three surviving `|| pwd` occurrences (`cmd_init.sh:73`,
    `.githooks/blast-radius-guard:17`, `.githooks/aapp-pre-commit:18`) in the §2 Fallback Inventory
    with reasons, as Invariant #5 requires, replacing the bare `None (Clean Break)` claim.
* **2026-09-23 (Red Team Round 2 Refinements):** Resolved Red Team findings F7–F9:
  - F7: Expanded Blast Radius to include `lib/cmd_ai.sh` (line 289) and `lib/planning_health.sh` (6 occurrences), purging all remaining `|| pwd` fallbacks across `lib/` and maintaining the clean break invariant.
  - F8: Formally documented the self-protection boundary for `.githooks/*` and `templates/*` in §4 and §5 Decision 6.
  - F9: Aligned Phase 1 task descriptions with semantic test names in `### 🧪 Required Tests` and recorded lifecycle toleration in §5 Decision 7.
* **2026-09-23 (Red Team Refinements):** Resolved Red Team findings F1–F5:
  - F1: Clarified non-repo operational requirement for `ai-*` and `test`; added `ai-status` to Test 67 assertion list.
  - F2: Clarified worktree invariant in §2.2 and §5 preserving `PRIMARY_ROOT` resolution in `cmd_plan.sh`.
  - F3: Harmonized §2.2 with §5 Decision 3 to provide explicit fail-closed error returns in `hook_dispatcher.sh` and `plan_resolver.sh`.
  - F4: Formally documented exemption of `cmd_init.sh` in §2.2, §4, and §5.
  - F5: Replaced static "10 suites" in Phase 4 with "all discovered test suites".
  - Added `lib/cmd_test.sh` to Target Files to clean up `repo_root` at line 140.
  - Injected `### 🧪 Required Tests` section into Section 4 to serve as live reference implementation for upcoming `aapp harden`.
* **2026-09-22 (Refinement):** Inverted implementation checklist to Failure-First TDD (Negative-First Engineering). Phase 1 mandates writing failing tests for non-repo error cases and verifying failure (Red 🔴) before authoring the front-door guard clauses (Green 🟢). Transitioned status to `📝 Refining`.
* **2026-09-22:** Drafted initial canonical blueprint P-33 from Issue #80. Centralized Git repository membership assertion in `aapp` dispatcher, established strict command exemption matrix, and purged silent `|| pwd` fallbacks across `lib/cmd_*.sh`.


