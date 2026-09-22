# 🗺️ Plan P-31: Unified Test Runner CLI (aapp test)
* **Created:** 2026-09-22 | **Last Refined:** 2026-09-22
* **Target Issue / Milestone:** Partial for #63 *(CLI Unified Test Runner Engine; CI GitHub workflow deferred to dedicated follow-up)*
* **Plan ID:** P-31
* **Status:** ⚡ In Development
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

### Sequencing Note: Shipped Dependency (Plan P-26)
This plan builds directly on **Plan P-26 (`P26-test-harness-isolation-and-worktree-hooks.md`)**, which has successfully shipped (`c4fc5b2`). Plan P-26 established:
- The shared test sandbox harness (`tests/test_helpers.sh`),
- Strict sandbox containment (`assert_test_sandbox()`),
- The `AAPP_TEST_SANDBOX_STRICT=1` environment invariant,
- Dynamic developer identity inheritance without host repository contamination.

Plan P-31 provides the unified CLI orchestrator on top of these isolated test foundations to discover, execute, and aggregate results across all suites.

### Problem Statement
1. **Scattered Test Suite Execution**: The repository contains 10 independent test suites in `tests/*_test.sh` (`install_test.sh`, `hooks_test.sh`, `write-guard_test.sh`, `pre-commit_test.sh`, `sync_test.sh`, `plan_resolver_test.sh`, `ai_attribution_test.sh`, `worktree_hooks_test.sh`, `matrix_test.sh`, `plan_states_test.sh`) shipping 422 assertions. Running all tests requires manual script-by-script execution or custom terminal loops.
2. **Missing Canonical Pre-Flight Gate (Issue #63 - Partial Scope)**: There is no single canonical command for CI pipelines (`.github/workflows/ci.yml`), release pre-flight runbooks (`aapp-release`), or local developer verification to run all test suites with consolidated exit-code reporting. *(Note: P-31 delivers the unified CLI test runner that CI will execute; the actual `.github/workflows/ci.yml` automation and release branch-parity gate remain open on Issue #63 until a dedicated CI follow-up).*
3. **No Selective Suite Targeting**: Developers debugging a specific subsystem (e.g. hook dispatch or write-guard) have no unified CLI interface to target single suites by name or slug (`aapp test hooks`, `aapp test guard`).
4. **Adopter Confusion**: In an initialized adopter repository without `tests/`, invoking test workflows is undefined. AAPP needs clear contextual detection: running unit suites in development kits, delegating to project test runners if configured, and providing environmental health audits in adopter projects.

### Architectural Goal
1. **Unified Test Orchestrator (`aapp test`)**: Implement `lib/cmd_test.sh` to discover, execute, and aggregate test suites under `tests/*_test.sh`.
2. **Deterministic Aggregation & Exit Codes**: Execute each suite in an isolated subshell, track execution time, capture test assertions, and exit 0 only if 100% of suites pass (exiting with the non-zero code of failing suites).
3. **Selective Targeting & Filtering**: Support running all suites (`aapp test`) or individual suites by name/prefix (`aapp test hooks`, `aapp test install`, `aapp test guard`).
4. **Zero Double-Dash Flags (CLI Ergonomics Invariant)**: In accordance with the kit's bare-word ergonomics, completely eliminate GNU-style `--flag` sprawl. Modifiers are parsed as bare positional tokens: `aapp test list`, `aapp test strict`, `aapp test quiet`, `aapp test bail`.
5. **Adopter Mode Graceful Fallback**: Detect when invoked inside an adopter project without kit test suites, executing a non-destructive repository verification audit (`worktree`, `hooks`, `config`).

---

## 🏗️ 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- Adds a new CLI verb `test` to `lib/verbs.tsv` and `aapp`; does not alter existing standalone test scripts.

### 2.1 CLI Interface & Options Contract (Pure Bare-Word Tokens)

```text
Usage: aapp test [modifier] [suite-name...]

Run automated test suites across kit components with consolidated aggregation.

Modifiers (bare-word tokens; no double-dash flags):
  (default)          Run all discovered test suites with standard real-time output
  list               List all discovered test suites without running them
  strict             Enforce fail-closed sandbox containment (AAPP_TEST_SANDBOX_STRICT=1)
  quiet              Quiet output: suppress assertion stream, report suite-level status only
  bail               Abort immediately upon first failing suite

Arguments:
  [suite-name...]    Specific test suite name or prefix to run (e.g., 'hooks', 'install', 'guard')
                     If omitted, all discovered 'tests/*_test.sh' suites are executed.

Examples:
  aapp test                  Run all test suites
  aapp test hooks            Run only tests/hooks_test.sh
  aapp test strict           Run all suites with strict sandbox verification
  aapp test strict hooks     Run hooks suite with strict sandbox verification
  aapp test list             List all available test suites
  aapp test quiet            Run all suites with compact 1-line progress
  aapp test bail             Run suites and stop on the first failure
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

    # 2. Parse bare-word modifiers (zero double-dash flags)
    local mode="run"
    local strict=0
    local bail=0
    local quiet=0
    local suite_filter=""

    while [ $# -gt 0 ]; do
        case "$1" in
            list)   mode="list" ;;
            strict) strict=1 ;;
            bail)   bail=1 ;;
            quiet)  quiet=1 ;;
            help)
                cmd_test_help
                return 0
                ;;
            *)
                suite_filter="$1"
                ;;
        esac
        shift
    done

    # 3. Handle list mode
    if [ "$mode" = "list" ]; then
        cmd_test_list "$test_dir"
        return 0
    fi

    # 4. Discover matching suites: tests/*_test.sh
    # 5. Execute suites in subshells, collecting:
    #    - PASS/FAIL exit status
    #    - Execution duration (seconds)
    #    - Suite name
    # 6. Render summary banner and exit with cumulative status code
}
```

### 2.3 Visual Aggregation Output

```text
============================================================
  🧪 AAPP Unified Test Runner
  📍 Repository: /home/lorand/000/agent-planning-kit
  🎯 Execution: 10 suites selected | Sandbox Strict: ON
============================================================

  ✔ install_test.sh            (70 passed, 0 failed)  [2.1s]
  ✔ hooks_test.sh              (20 passed, 0 failed)  [0.8s]
  ✔ write-guard_test.sh        (96 passed, 0 failed)  [1.4s]
  ✔ pre-commit_test.sh         (78 passed, 0 failed)  [1.9s]
  ✔ sync_test.sh               (15 passed, 0 failed)  [0.5s]
  ✔ plan_resolver_test.sh      (42 passed, 0 failed)  [0.6s]
  ✔ ai_attribution_test.sh     (34 passed, 0 failed)  [0.7s]
  ✔ worktree_hooks_test.sh     (14 passed, 0 failed)  [0.9s]
  ✔ matrix_test.sh             (34 passed, 0 failed)  [0.5s]
  ✔ plan_states_test.sh        (19 passed, 0 failed)  [0.4s]

------------------------------------------------------------
  📊 Test Results: 10/10 suites passed (422 assertions, 0 failed) in 9.8s
  🎉 All test suites passed cleanly!
```

### 2.4 Verb Manifest Registration (`lib/verbs.tsv`)

Add to `lib/verbs.tsv` under the `setup` or `daily` tier:
```tsv
test	daily	yes	Run automated test suites across all kit components with aggregation
```

### 2.5 Assertion Aggregation & Normalization Contract

To prevent fragile parsing or banner omissions, AAPP establishes a two-pronged contract for test assertion aggregation:

1. **Shared Harness Summary Helper (`tests/test_helpers.sh`)**:
   Add a standard function `print_test_summary()` to `tests/test_helpers.sh`:
   ```bash
   print_test_summary() {
       local pass="${1:-$PASS}"
       local fail="${2:-$FAIL}"
       echo ""
       echo "============================================================"
       echo "  Results: $pass passed, $fail failed"
       echo "============================================================"
       [ "$fail" -eq 0 ] || exit 1
   }
   ```
2. **Suite Summary Normalization**:
   All 10 test suites (`tests/*_test.sh`) are normalized to emit the canonical machine-readable summary line:
   `Results: <passed> passed, <failed> failed`
3. **Dual-Layer Robust Scraper (`lib/cmd_test.sh`)**:
   When reading a suite's output, `lib/cmd_test.sh` strips ANSI color escape codes and parses assertion metrics:
   ```bash
   clean_output="$(echo "$suite_output" | sed -E 's/\x1b\[[0-9;]*m//g')"
   # Primary canonical parser:
   if [[ "$clean_output" =~ Results:[[:space:]]*([0-9]+)[[:space:]]*passed,[[:space:]]*([0-9]+)[[:space:]]*failed ]]; then
       suite_passed="${BASH_REMATCH[1]}"
       suite_failed="${BASH_REMATCH[2]}"
   # Fallback scraper for legacy or alternative formats:
   elif [[ "$clean_output" =~ ([0-9]+)[[:space:]]*passed.*([0-9]+)[[:space:]]*failed ]] || \
        [[ "$clean_output" =~ Passed:[[:space:]]*([0-9]+).*Failed:[[:space:]]*([0-9]+) ]] || \
        [[ "$clean_output" =~ passed=([0-9]+).*failed=([0-9]+) ]]; then
       suite_passed="${BASH_REMATCH[1]}"
       suite_failed="${BASH_REMATCH[2]}"
   fi
   ```
   This dual-layer approach ensures 100% accurate count extraction without relying on brittle ad-hoc parsing.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Test Runner Module Core (`lib/cmd_test.sh`)
- [x] Task 1.0: Add `print_test_summary()` helper to `tests/test_helpers.sh` and normalize trailing summary line format across all 10 suites (`tests/*_test.sh`).
- [x] Task 1.1: Implement suite discovery scanning for `tests/*_test.sh`.
- [x] Task 1.2: Implement filter matching for positional arguments (`hooks` -> `tests/hooks_test.sh`, `guard` -> `tests/write-guard_test.sh`).
- [x] Task 1.3: Implement isolated subshell execution harness capturing exit codes, assertion metrics, and timing.
- [x] Task 1.4: Implement bare-word modifier parsers: `strict`, `bail`, `quiet`, `list` (zero `--flags`).
- [x] Task 1.5: Implement aggregate result summary banner and cumulative exit code logic.

### Phase 2: Switchboard & Manifest Wiring
- [x] Task 2.1: Add `test)` dispatch case in `aapp` switchboard delegating to `lib/cmd_test.sh`.
- [x] Task 2.2: Register `test` in `lib/verbs.tsv` and verify appearance in `aapp help`.

### Phase 3: Adopter Mode & Health Audit Fallback
- [x] Task 3.1: Implement adopter project test delegation (`aapp.testCommand` / auto-detection) with fallback to protocol environment and health audit when kit unit tests are absent.

### Phase 4: Automated Verification Suite
- [x] Task 4.1: Add tests in `tests/install_test.sh` verifying `aapp test list`, suite filtering, `aapp test bail` behavior, and proper exit code on simulated test failure.
- [x] Task 4.2: Verify complete test suite execution via `./aapp test strict`.

### Phase 5: Documentation & Protocol Sync
- [x] Task 5.1: Update `MANUAL.md` with `aapp test` command reference and bare-word examples.
- [x] Task 5.2: Update `CHEATSHEET.md` CLI matrix with `test` verb.
- [x] Task 5.3: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
- [x] Task 5.4: Update `CHANGELOG.md` under `### Added`.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `lib/cmd_test.sh` -> New unified test runner command module
- [ ] `aapp` -> Wire test verb in CLI switchboard
- [ ] `lib/verbs.tsv` -> Register test verb in tiered manifest
- [ ] `tests/test_helpers.sh` -> Add `print_test_summary()` output standardizer
- [ ] `tests/*_test.sh` -> Normalize trailing summary line format to canonical `Results: N passed, N failed`
- [ ] `tests/install_test.sh` -> Add automated CLI test coverage for aapp test
- [ ] `MANUAL.md` -> Document aapp test command options and workflows
- [ ] `CHEATSHEET.md` -> Add test verb to CLI discovery matrix
- [ ] `ARCHITECTURE.md` -> Document test orchestrator architecture
- [ ] `.agents/CODEMAP.md` -> Update codemap with lib/cmd_test.sh
- [ ] `CHANGELOG.md` -> Record shipped aapp test capability

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Protected by Pair 5 self-protection rule
- [ ] `.agents/skills/*` -> Governance skills self-protection
- [ ] `.plans/ISSUES.md` -> Issue #63 remains open until CI workflow lands

---

## ❓ 5. Open Questions & Settled Decisions

1. **CLI Ergonomics Invariant (No Double-Dash Flags)**: Should `aapp test` use flags or positional bare-words?
   - **Decision**: **Bare Words Only (Adopted Directive)**. Strict prohibition of GNU-style `--flag` sprawl across the CLI. Modifiers are parsed as bare positional tokens (`aapp test list`, `aapp test strict`, `aapp test quiet`, `aapp test bail`).
2. **Adopter Mode Scope**: Should `aapp test` in an adopter repository execute project tests, full planning health checks, or a simple worktree and hook audit?
   - **Decision**: **Dual-Mode Delegation & Protocol Sanity (Adopted Directive)**. In an adopter repository (where kit test fixtures in `tests/` are absent):
     1. If a project test command is configured via `git config aapp.testCommand` or auto-detected (e.g. `npm test`, `pytest`, `cargo test`, `composer test`, `go test ./...`), `aapp test` delegates execution to the project's own test suite.
     2. If no project test suite is detected, `aapp test` executes the AAPP protocol environment and health audit (verifying `.plans`, `.agents`, `.githooks` mounts, permissions, and running `lib/planning_health.sh`). Full diagnostic repair remains cleanly separated for `aapp matrix check` or a future `aapp doctor` verb.

---

## 📦 6. Change Log & Refinement History
* **2026-09-22:** Plan activated into ⚡ In Development via start.
* **2026-09-22:** Plan locked and frozen into 🔷 Frozen via freeze.

* **2026-09-22 (Refinement - Amendment 2):** Addressed red team review: (1) resolved assertion aggregation discrepancy across 10 suites by defining a standardized summary helper (`print_test_summary` in `test_helpers.sh`) and a dual-layer ANSI-stripping scraper in `cmd_test.sh`, (2) expanded Target Files to include `tests/*_test.sh` for trailing summary normalization, (3) corrected suite inventory to 10 suites (422 assertions), including `matrix_test.sh` and `plan_states_test.sh`, (4) clarified Issue #63 scope boundary as partial runner engine with CI workflow deferred, (5) settled Open Question 2 with dual-mode adopter delegation, and (6) removed `--help` from test parser to preserve the zero-double-dash invariant.
* **2026-09-22 (Refinement - Amendment 1):** Amended blueprint to strictly eliminate all GNU-style `--double-dash` flags per developer direction. Replaced all flags with clean bare-word positional tokens (`aapp test list`, `strict`, `quiet`, `bail`).
* **2026-09-22:** Drafted initial canonical blueprint P-31 from user request. Defined unified test runner architecture, selective suite execution, sandbox strictness propagation, adopter doctor fallback, and explicit sequencing dependency on Plan P-26.

