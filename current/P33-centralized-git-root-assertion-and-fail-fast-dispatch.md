# 🗺️ Plan P-33: Centralized Git Root Assertion & Fail-Fast Dispatch
* **Created:** 2026-09-22 | **Last Refined:** 2026-09-22
* **Target Issue / Milestone:** #80 *(supersedes #80 upon completion)*
* **Plan ID:** P-33
* **Status:** 📝 Refining
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
> 5. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 6. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 1. Context & Architectural Goal

### Problem Statement
In `lib/cmd_*.sh`, subcommands redundantly re-derive `REPO_ROOT` using disparate fallback patterns:
```bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```
This pattern contains critical architectural defects:
1. **Silent Non-Repo Corruption**: The `|| pwd` fallback silently substitutes `$PWD` as the repository root when invoked outside a Git repository. Downstream commands proceed to evaluate `$PWD/.plans` or `$PWD/.agents` in arbitrary non-git directories (such as `/home/user` or `/tmp`), leading to unexpected side-effects or misleading errors.
2. **Dead Code**: In `lib/cmd_help.sh:10`, `REPO_ROOT` is declared with the `|| pwd` fallback but is never referenced anywhere in the file.
3. **Inconsistent Failure Semantics**: Across 9 files, three different derivation idioms coexist (`|| pwd`, `|| true`, and multi-candidate resolution in `cmd_init.sh`).
4. **Redundant Execution**: Because `aapp` sources subcommands (`source "$AAPP_LIB/cmd_*.sh"`), re-executing `git rev-parse` across every subcommand is completely unnecessary.

### Architectural Goal
Establish a single authoritative entrypoint assertion in `aapp` using a strict **Failure-First TDD (Negative-First)** workflow:
1. Validate Git repository membership once at the front door before command dispatch.
2. Fail fast with exit code 1 and a human-readable diagnostic message if operational commands are invoked outside a Git repository.
3. Exempt non-repo commands: `version`, `help`, `install`, `uninstall`, `upgrade`, `develop`, and `init` (which provides bootstrap target resolution).
4. Export canonical `REPO_ROOT` so all sourced subcommands inherit it cleanly without redundant `git rev-parse` calls or silent `|| pwd` fallbacks.
5. Purge dead `REPO_ROOT` declarations and legacy fallback idioms across `lib/cmd_*.sh`.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- All silent `|| pwd` fallbacks for `REPO_ROOT` are purged outright. Invocations of operational verbs outside a Git repository fail fast with exit code 1.

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

### 2.2 Subcommand Derivation Purge

Since `aapp` exports `REPO_ROOT`, sourced scripts in `lib/` can safely rely on `${REPO_ROOT}`:
- **`lib/cmd_help.sh`**: Delete line 10 completely (`REPO_ROOT` is unused).
- **`lib/cmd_matrix.sh`**: Remove `REPO_ROOT="$(git rev-parse ...)"`, use existing `REPO_ROOT`.
- **`lib/cmd_pause.sh`**: Remove `REPO_ROOT="$(git rev-parse ...)"`, use existing `REPO_ROOT`.
- **`lib/cmd_plan.sh`**: Remove `REPO_ROOT="$(git rev-parse ...)"`, use existing `REPO_ROOT`.
- **`lib/cmd_hook.sh`**: Remove redundant `REPO_ROOT="$(git rev-parse ...)"`.
- **`lib/cmd_sync.sh`**: Remove redundant `REPO_ROOT="$(git rev-parse ...)"`.
- **`lib/cmd_status.sh`**: Remove redundant `REPO_ROOT="$(git rev-parse ...)"`.
- **`lib/hook_dispatcher.sh`**: Fallback to `${REPO_ROOT:-$(git rev-parse ...)}` only when invoked outside `aapp`.
- **`lib/plan_resolver.sh`**: Standardize helper parameter `${4:-${REPO_ROOT:-$(git rev-parse ...)}}` without `|| pwd`.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Failure-First Negative Test Harness (Red 🔴)
- [ ] Task 1.1: Add Test 67 in `tests/install_test.sh`: Invoke operational commands (`status`, `plan`, `test`, `freeze`) in an isolated non-git `/tmp` directory. Assert `exit code == 1` and assert stderr contains `'must be run inside a Git repository'`.
- [ ] Task 1.2: Add Test 68 in `tests/install_test.sh`: Assert that exempt verbs (`version`, `help`, `install`) executed in a non-git directory succeed with `exit code == 0`.
- [ ] Task 1.3: Run `bash tests/install_test.sh` to confirm Test 67 FAILS (Red 🔴) against current code (current code silently uses `|| pwd` and returns exit 0).

### Phase 2: Front-Door Guard Clauses & Precondition Enforcement (Green 🟢)
- [ ] Task 2.1: Add front-door repository assertion in `aapp` with command exemption switchboard.
- [ ] Task 2.2: Export canonical `REPO_ROOT` for all operational commands.
- [ ] Task 2.3: Re-run `bash tests/install_test.sh` to confirm Test 67 and Test 68 turn Green 🟢.

### Phase 3: Subcommand De-Duplication & Dead Code Removal
- [ ] Task 3.1: Delete dead `REPO_ROOT` declaration from `lib/cmd_help.sh`.
- [ ] Task 3.2: Purge `|| pwd` fallback and redundant `git rev-parse` calls from `lib/cmd_plan.sh`, `lib/cmd_matrix.sh`, `lib/cmd_pause.sh`, `lib/cmd_hook.sh`, `lib/cmd_sync.sh`, and `lib/cmd_status.sh`.
- [ ] Task 3.3: Standardize standalone fallback in `lib/plan_resolver.sh` and `lib/hook_dispatcher.sh` without `|| pwd`.

### Phase 4: Full Suite Regression Verification
- [ ] Task 4.1: Run `./aapp test strict quiet` across all 10 test suites to verify complete suite pass.

### Phase 5: Documentation & Protocol Sync
- [ ] Task 5.1: Update `ARCHITECTURE.md` documenting front-door repository assertion and failure-first invariant.
- [ ] Task 5.2: Update `CHANGELOG.md` under `### Fixed`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `aapp` -> Add front-door Git repository assertion and export REPO_ROOT
- [ ] `lib/cmd_help.sh` -> Delete dead REPO_ROOT declaration
- [ ] `lib/cmd_plan.sh` -> Purge redundant REPO_ROOT derivation and || pwd fallback
- [ ] `lib/cmd_matrix.sh` -> Purge redundant REPO_ROOT derivation and || pwd fallback
- [ ] `lib/cmd_pause.sh` -> Purge redundant REPO_ROOT derivation and || pwd fallback
- [ ] `lib/cmd_hook.sh` -> Remove redundant REPO_ROOT derivation
- [ ] `lib/cmd_sync.sh` -> Remove redundant REPO_ROOT derivation
- [ ] `lib/cmd_status.sh` -> Remove redundant REPO_ROOT derivation
- [ ] `lib/hook_dispatcher.sh` -> Standardize standalone fallback without || pwd
- [ ] `lib/plan_resolver.sh` -> Standardize standalone fallback without || pwd
- [ ] `tests/install_test.sh` -> Add automated test coverage for non-repo fail-fast and exempt verbs
- [ ] `ARCHITECTURE.md` -> Document centralized repository root assertion in Architecture Invariants
- [ ] `CHANGELOG.md` -> Record P-33 fix in Unreleased changelog

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Guard engine self-protection
- [ ] `.agents/skills/*` -> Governance skills self-protection
- [ ] `.plans/ISSUES.md` -> Target data ledger (modified only via issue lifecycle)
- [ ] `.plans/state_matrix.md` -> Derived view (modified only via matrix derivation)

---

## ❓ 5. Open Questions & Settled Decisions

1. **Failure Message & Diagnostic Output**: Should non-repo failures emit to `stderr` or `stdout`?
   - **Decision**: **stderr with exit 1 (Adopted Directive)**. CLI tooling must fail loudly on stderr (`echo "❌ Error: 'aapp $CMD' must be run inside a Git repository." >&2`) and exit with status code 1.
2. **Command Exemption Boundary**: Are any operational commands valid outside a Git repository?
   - **Decision**: **Strict Exemption List (Adopted Directive)**. Only pure terminal output (`version`, `help`), system installer tools (`install`, `uninstall`, `upgrade`, `develop`), and the bootstrap initializer (`init`) are exempt. All planning, matrix, pause, hook, attribution, test, and sync operations require a valid Git repository.
3. **Standalone Library Sourcing**: How should library functions behave when sourced directly without `aapp` (e.g. in test fixtures)?
   - **Decision**: **Safe Defaulting without `|| pwd` (Adopted Directive)**. Functions in `lib/plan_resolver.sh` and `lib/hook_dispatcher.sh` will check `${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || true)}`. If empty, fail explicitly rather than falling back to `$PWD`.

---

## 📦 6. Change Log & Refinement History

* **2026-09-22 (Refinement):** Inverted implementation checklist to Failure-First TDD (Negative-First Engineering). Phase 1 mandates writing failing tests for non-repo error cases and verifying failure (Red 🔴) before authoring the front-door guard clauses (Green 🟢). Transitioned status to `📝 Refining`.
* **2026-09-22:** Drafted initial canonical blueprint P-33 from Issue #80. Centralized Git repository membership assertion in `aapp` dispatcher, established strict command exemption matrix, and purged silent `|| pwd` fallbacks across `lib/cmd_*.sh`.
