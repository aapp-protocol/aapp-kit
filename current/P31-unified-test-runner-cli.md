# 🗺️ Plan P-31: Unified Test Runner CLI (aapp test)
* **Created:** 2026-09-22 | **Last Refined:** 2026-09-22
* **Target Issue / Milestone:** #63 *(Automated Test Execution & Pre-Flight Quality Gates)*
* **Plan ID:** P-31
* **Status:** 🟣 Under Review
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED | ✅ Done
     The pre-commit hook and write-guard read this line. A 🔷 Frozen plan is an approved backlog
     specification. A ⚡ In Development plan enforces the locked blast radius during implementation.
     A plan whose Status says BLOCKED grants no commit rights at all. -->

> ### ⚡ Critical Execution Invariants (Read Before Writing Code)
> 1. **Blast Radius Lock**: You are strictly confined to the files listed under `### 📂 Target Files`. If write-guard refuses an edit, **do NOT bypass it** with shell scripts or sed — ask the user to add the file to Target Files first.
> 2. **Changelog Requirement**: Every commit touching source code **must** update `CHANGELOG.md` (or `.plans/CHANGELOG.md`). Run syntax checks and automated tests *before* updating the changelog.
> 3. **Attribution Trailer**: Respect configured repo attribution (`git config aapp.aiAttribution`). When operating in `commit` mode, append standard semantic trailers (`AI-Agent:`, `AI-Vendor:`, `AI-Model:`). Synthetic emails are forbidden.
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 6. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 🎯 1. Context & Architectural Goal

### Sequencing Note: Dependency on Plan P-26
This plan is designed to be executed **strictly after Plan P-26 (`P26-test-harness-isolation-and-worktree-hooks.md`)**. Plan P-26 establishes:
- The shared test sandbox helper (`tests/test_helpers.sh`),
- Strict sandbox containment (`assert_test_sandbox()`),
- The `AAPP_TEST_SANDBOX_STRICT=1` environment invariant,
- Dynamic developer identity inheritance without host repository contamination.

Plan P-31 builds directly on top of P-26's isolated test foundations, providing the unified CLI orchestrator to discover, run, and aggregate results across all suites.

### Problem Statement
1. **Scattered Test Suite Execution**: The repository contains 8+ independent test suites in `tests/*_test.sh` (`install_test.sh`, `hooks_test.sh`, `write-guard_test.sh`, `pre-commit_test.sh`, `sync_test.sh`, `plan_resolver_test.sh`, `ai_attribution_test.sh`, `worktree_hooks_test.sh`, `plan_states_test.sh`). Running all tests requires manual script-by-script execution or custom terminal loops.
2. **Missing Canonical Pre-Flight Gate (Issue #63)**: There is no single canonical command for CI pipelines (`.github/workflows/ci.yml`), release pre-flight runbooks (`aapp-release`), or local developer verification to run all test suites with consolidated exit-code reporting.
3. **No Selective Suite Targeting**: Developers debugging a specific subsystem (e.g. hook dispatch or write-guard) have no unified CLI interface to target single suites by name or slug (`aapp test hooks`, `aapp test guard`).
4. **Adopter Confusion**: In an initialized adopter repository without `tests/`, invoking test workflows is undefined. AAPP needs clear contextual detection: running unit suites in development kits, while providing environmental doctor/health audits in adopter projects.

### Architectural Goal
1. **Unified Test Orchestrator (`aapp test`)**: Implement `lib/cmd_test.sh` to discover, execute, and aggregate test suites under `tests/*_test.sh`.
2. **Deterministic Aggregation & Exit Codes**: Execute each suite in an isolated subshell, track execution time, capture test assertions, and exit 0 only if 100% of suites pass (exiting with the non-zero code of failing suites).
3. **Selective Targeting & Filtering**: Support running all suites (`aapp test`) or individual suites by name/prefix (`aapp test hooks`, `aapp test install`, `aapp test pre-commit`).
4. **Standardized Strict Execution Flags**: Pass through `--strict` (`AAPP_TEST_SANDBOX_STRICT=1`), `--quiet` (concise 1-line progress per suite), `--bail` (abort upon first suite failure), and `--list` (print discovered suites).
5. **Adopter Mode Graceful Fallback**: Detect when invoked inside an adopter project without kit test suites, executing a non-destructive repository verification audit (`worktree`, `hooks`, `config`).

---

## 🏗️ 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- Adds a new CLI verb `test` to `lib/verbs.tsv` and `aapp`; does not alter existing standalone test scripts.

### 2.1 CLI Interface & Options Contract

```text
Usage: aapp test [options] [suite-name...]

Run automated test suites across kit components with consolidated aggregation.

Arguments:
  [suite-name...]    Specific test suite name or prefix to run (e.g., 'hooks', 'install', 'guard')
                     If omitted, all discovered 'tests/*_test.sh' suites are executed.

Options:
  -s, --strict       Enforce fail-closed sandbox containment (AAPP_TEST_SANDBOX_STRICT=1)
  -b, --bail         Abort immediately upon first failing suite
  -q, --quiet        Quiet output: suppress individual assertion lines, show suite summary only
  -v, --verbose      Verbose output: stream complete test stdout/stderr in real-time (default)
  -l, --list         List all discovered test suites without running them
  -h, --help         Show this help message
```

### 2.2 Suite Discovery & Execution Algorithm (`lib/cmd_test.sh`)

```bash
cmd_test() {
    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    local test_dir="$repo_root/tests"

    # 1. Adopter repository mode check
    if [ ! -d "$test_dir" ]; then
        echo "ℹ️  No 'tests/' directory found in current repository."
        echo "   Running AAPP Adopter Environment Health Check..."
        aapp_adopter_health_audit "$repo_root"
        return $?
    fi

    # 2. Parse flags and target filters
    # ...
    # 3. Discover matching suites: tests/*_test.sh
    # ...
    # 4. Execute suites in subshells, collecting:
    #    - PASS/FAIL exit status
    #    - Execution duration (seconds)
    #    - Suite name
    # 5. Render summary banner and exit with cumulative status code
}
```

### 2.3 Visual Aggregation Output

```text
============================================================
  🧪 AAPP Unified Test Runner
  📍 Repository: /home/lorand/000/agent-planning-kit
  🎯 Execution: 8 suites selected | Sandbox Strict: ON
============================================================

  ✔ install_test.sh            (69 passed, 0 failed)  [2.1s]
  ✔ hooks_test.sh              (20 passed, 0 failed)  [0.8s]
  ✔ write-guard_test.sh        (96 passed, 0 failed)  [1.4s]
  ✔ pre-commit_test.sh         (78 passed, 0 failed)  [1.9s]
  ✔ sync_test.sh               (12 passed, 0 failed)  [0.5s]
  ✔ plan_resolver_test.sh      (24 passed, 0 failed)  [0.6s]
  ✔ ai_attribution_test.sh     (18 passed, 0 failed)  [0.7s]
  ✔ worktree_hooks_test.sh     (10 passed, 0 failed)  [0.9s]

------------------------------------------------------------
  📊 Test Results: 8/8 suites passed (327 assertions, 0 failed) in 8.9s
  🎉 All test suites passed cleanly!
```

### 2.4 Verb Manifest Registration (`lib/verbs.tsv`)

Add to `lib/verbs.tsv` under the `setup` or `daily` tier:
```tsv
test	daily	yes	Run automated test suites across all kit components with aggregation
```

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Test Runner Module Core (`lib/cmd_test.sh`)
- [ ] Task 1.1: Implement suite discovery scanning for `tests/*_test.sh`.
- [ ] Task 1.2: Implement filter matching for positional arguments (`hooks` -> `tests/hooks_test.sh`, `guard` -> `tests/write-guard_test.sh`).
- [ ] Task 1.3: Implement isolated subshell execution harness capturing exit codes and timing.
- [ ] Task 1.4: Implement flag parsers: `--strict`, `--bail`, `--quiet`, `--verbose`, `--list`.
- [ ] Task 1.5: Implement aggregate result summary banner and cumulative exit code logic.

### Phase 2: Switchboard & Manifest Wiring
- [ ] Task 2.1: Add `test)` dispatch case in `aapp` switchboard delegating to `lib/cmd_test.sh`.
- [ ] Task 2.2: Register `test` in `lib/verbs.tsv` and verify appearance in `aapp help`.

### Phase 3: Adopter Mode & Health Audit Fallback
- [ ] Task 3.1: Implement `aapp_adopter_health_audit()` verifying `.plans/`, `.agents/`, and `.githooks/` worktree mounts, permissions, and `core.hooksPath` configuration when `tests/` is absent.

### Phase 4: Automated Verification Suite
- [ ] Task 4.1: Add tests in `tests/install_test.sh` (or `tests/cmd_test.sh`) verifying `aapp test --list`, suite filtering, `--bail` behavior, and proper exit code on simulated test failure.
- [ ] Task 4.2: Verify complete test suite execution via `./aapp test --strict`.

### Phase 5: Documentation & Protocol Sync
- [ ] Task 5.1: Update `MANUAL.md` with `aapp test` command reference and examples.
- [ ] Task 5.2: Update `CHEATSHEET.md` CLI matrix with `test` verb.
- [ ] Task 5.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
- [ ] Task 5.4: Update `CHANGELOG.md` under `### Added`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_test.sh` -> New unified test runner command module
- [ ] `aapp` -> Wire test verb in CLI switchboard
- [ ] `lib/verbs.tsv` -> Register test verb in tiered manifest
- [ ] `tests/install_test.sh` -> Add automated CLI test coverage for aapp test
- [ ] `MANUAL.md` -> Document aapp test command options and workflows
- [ ] `CHEATSHEET.md` -> Add test verb to CLI discovery matrix
- [ ] `ARCHITECTURE.md` -> Document test orchestrator architecture
- [ ] `.agents/CODEMAP.md` -> Update codemap with lib/cmd_test.sh
- [ ] `CHANGELOG.md` -> Record shipped aapp test capability

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Protected by Pair 5 self-protection rule
- [ ] `.agents/skills/*` -> Governance skills self-protection
- [ ] `tests/*_test.sh` -> Existing individual test suites are orchestrated, not modified (governed by P-26)

---

## ❓ 5. Open Questions

1. **Default Output Stream Mode**: Should `aapp test` stream the full verbose test output by default, or default to concise 1-line progress per suite with a `--verbose` flag for details?
   - **Recommendation**: Default to streaming verbose output so developers and CI immediately see failed assertion details, with `--quiet` / `-q` available for clean high-level summaries.
2. **Adopter Mode Scope**: Should `aapp test` in an adopter repository execute full planning health checks (Pair 1–6 checks from `lib/planning_health.sh`) or stick to a simple worktree and hook audit?
   - **Recommendation**: Run both worktree/hook integrity and `lib/planning_health.sh` audit, giving adopters a true `aapp doctor` verification command.

---

## 📦 6. Change Log & Refinement History

* **2026-09-22:** Drafted initial canonical blueprint P-31 from user request. Defined unified test runner architecture, selective suite execution, sandbox strictness propagation, adopter doctor fallback, and explicit sequencing dependency on Plan P-26.
