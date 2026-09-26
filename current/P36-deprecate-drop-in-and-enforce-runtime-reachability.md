# 🗺️ Plan P-36: Deprecate Drop-In Distribution & Enforce CLI Runtime Reachability
* **Created:** 2026-09-27 | **Last Refined:** 2026-09-27
* **Target Issue / Milestone:** #83
* **Plan ID:** P-36
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
> 4. **Mid-Execution Bugs**:
>    - *Non-blocking*: Log in `.plans/ISSUES.md` and continue your plan.
>    - *Blocking & small*: Add file under `### 🚨 Emergency Hotfix Extensions` with a 1-sentence justification.
>    - *Blocking & substantial*: Set status to `🟥 BLOCKED`, stop, and ask the user.
> 5. **User Documentation Sync**: If your implementation introduces or alters user-facing behavior, CLI commands/options, configuration flags, or operational workflows, you **must** update documentation in accordance with the locations and conventions defined in `.agents/PROJECT.MD` (e.g. `MANUAL.md`, `README.md`, or `docs/`). End users and adopters must never be left guessing about new or changed system behavior. Documentation files and `.agents/PROJECT.MD` are always-allowed workspace invariants.
> 6. **Architecture & Codemap Sync**: If your implementation introduces new files, functions, CLI verbs, or alters architectural boundaries, you **must** update `ARCHITECTURE.md` and `.agents/CODEMAP.md` (or repo-root `CODEMAP.md`). Both files are always-allowed workspace invariants.

---

## 1. Context & Architectural Goal

### Problem Statement
AAPP was originally conceived at v1.0.0 as a lightweight, zero-dependency set of Git hooks and Markdown prose guidelines. In that context, a self-consuming "drop-in" folder (`./aapp-kit/aapp init`) was designed: it mounted orphan worktrees (`.plans/`, `.agents/`, `.githooks/`), copied initial templates and rules, and then deleted itself (`rm -rf aapp-kit/`) under the rationale of leaving a "clean repo".

However, across successive milestones (Plans P-7 through P-34), AAPP evolved from a static checklist into an active, deterministic protocol runtime (`aapp status`, `matrix`, `freeze`, `start`, `done`, `test`, `pause`, `plan`). 

Because drop-in mode deletes the kit without installing `aapp` into the host environment's `$PATH`:
1. **Broken Commands:** Any adopter who followed "Option 1: Drop-In" in `README.md` or `MANUAL.md` has no `aapp` command. Running `aapp status` or `aapp freeze` fails immediately with `bash: aapp: command not found`.
2. **Prose-Only Degradation:** Universal skills (`.agents/skills/`) instruct agents to run CLI commands that cannot execute, falling back to manual prose edits and corrupting derived structures (like `state_matrix.md`).
3. **Misleading Documentation:** `README.md` and `MANUAL.md` heavily promote drop-in as a primary distribution mode while advertising CLI verbs that strictly require a global install.

### Evaluation of Alternatives
- **Keeping a local CLI in the repository (Rejected):** Leaving `./aapp` and `lib/` in the project working tree was considered and **firmly rejected**. The foundational premise of AAPP is that code branches remain 100% pristine and unpolluted by governance tooling. Storing tools in tracked branches breaks multi-repo clean-room isolation.
- **Global Toolchain Model (Adopted):** AAPP is a developer toolchain (like `git`, `gh`, or `cargo`). It is installed once into the user environment (`~/.local/bin/aapp` and `~/.local/share/aapp-kit/`), and then initialized cleanly inside projects via `aapp init`.
- **Install Self-Consumption Preserved:** In contrast to drop-in init, `aapp install` **continues to self-consume its temporary clone** (`./aapp-kit/aapp install` copies to `~/.local/` and then deletes `aapp-kit/`), ensuring the user's workspace is left completely clean.

### The Inspection-Only Trade-off
Under this unified architecture, when an adopting repository is cloned on a machine where `aapp` is not installed, the repository enters **Inspection-Only Mode**. Commits are gated by the pre-commit hook with an actionable message directing the contributor to install `aapp`.
- **Intentional Design Choice:** AAPP repositories are governed repositories. Allowing un-guarded commits by contributors without the runtime risks bypassing blast-radius protection, dropping changelog entries, or desynchronizing plan states.
- **Escape Hatch Boundary:** Standard Git `--no-verify` remains available at the Git engine level to bypass hooks if needed, but repository-level `SKIP_BLAST_RADIUS=1` **does NOT bypass the reachability check**—any commit that executes through AAPP hooks must have the runtime reachable.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- All legacy drop-in flags (`--keep`, `AAPP_IS_DROP_IN`) and consumption checks in `cmd_init.sh` are removed without shims or dual-syntax aliases.
- `aapp install` self-consumption (`is_safe_to_consume_kit_dir`) is explicitly preserved in `lib/cmd_install.sh`.

### 2.1 Distribution Architecture & Canonical Fast-Fail Predicate (F11, F12, F14)

```text
┌────────────────────────────────────────────────────────┐
│                   Developer Machine                    │
│                                                        │
│  1. One-Time Global Installation:                      │
│     git clone https://.../aapp-kit.git                 │
│     ./aapp-kit/aapp install                            │
│     ├── Copies binary to ~/.local/bin/aapp             │
│     ├── Copies assets to ~/.local/share/aapp-kit/      │
│     └── Consumes temporary clone folder (clean host)   │
└───────────────────────────┬────────────────────────────┘
                            │ invokes 'aapp init' from PATH
                            ▼
┌────────────────────────────────────────────────────────┐
│                   Target Repository                    │
│                                                        │
│  2. Clean Multi-Orphan Worktrees:                      │
│     ├── .plans/     (orphan 'plans' branch)            │
│     ├── .agents/    (orphan 'agents' branch)           │
│     └── .githooks/  (orphan 'githooks' branch)         │
│                                                        │
│  Working Tree Code Remains 100% Pristine (Zero Kit)    │
└────────────────────────────────────────────────────────┘
```

#### Dispatcher Single Source of Truth (`AAPP_RUNTIME`)
In `aapp`, the dispatcher resolves `AAPP_BASE` and exports `AAPP_RUNTIME`:
- `AAPP_RUNTIME="installed"`: resolved via `$XDG_DATA_HOME/aapp-kit`, `$HOME/.local/share/aapp-kit`, or `aapp develop` symlinks.
- `AAPP_RUNTIME="local"`: resolved via `$AAPP_SCRIPT_DIR` (an uninstalled clone).

#### Canonical Physical Path Comparison in `cmd_init.sh` (F14)
`AAPP_BASE` (derived via `cd && pwd`) and `REPO_ROOT` (derived via `git rev-parse --show-toplevel`) may diverge in the presence of directory symlinks (e.g. `/var` vs `/private/var` on macOS). `cmd_init.sh` canonicalizes both paths via `pwd -P`:

```bash
# Sourced inside cmd_init.sh
AAPP_BASE_PHYSICAL="$(cd "$AAPP_BASE" 2>/dev/null && pwd -P || echo "$AAPP_BASE")"
REPO_ROOT_PHYSICAL="$(cd "$REPO_ROOT" 2>/dev/null && pwd -P || echo "$REPO_ROOT")"

if [ "$AAPP_RUNTIME" != "installed" ] && [ "$AAPP_BASE_PHYSICAL" != "$REPO_ROOT_PHYSICAL" ]; then
    echo "❌ Error: AAPP must be installed globally before initializing projects." >&2
    echo "   Run: ./aapp install" >&2
    exit 1
fi
```
This rule is 100% name-independent, immune to symlink aliases, single-sources classification from the dispatcher, and fast-fails any uninstalled clone run against an external project.

#### P-33 Front-Door Assertion Alignment (F7)
In `aapp:120`, `init` is removed from the exemption list:
```bash
# aapp dispatcher
case "$CMD" in
    version|-v|--version|help|-h|--help|install|upgrade|update|uninstall|develop)
        # Exempt: pure terminal output or machine-level installers
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
Because `cmd_init.sh` no longer performs parent-directory climbing, `init` inherits the front-door `REPO_ROOT` assertion, failing closed if executed outside a Git repository (aligning with `ARCHITECTURE.md` Rule 9).

### 2.2 Pre-Commit Hook Runtime Reachability Gate (`templates/aapp-pre-commit`) (F13)

Git hooks run with the environment of the invoking client. GUI clients (VS Code, Fork, GitKraken, Xcode) and macOS non-login shells often start without `~/.local/bin` in `$PATH`. To prevent false lockouts for legitimately installed users, the pre-commit gate probes both `$PATH` and `$HOME/.local/bin/aapp`:

```bash
# ------------------------------------------------------------------------------
# 0. Pre-Flight: Runtime Reachability & Inspection-Only Gate
# ------------------------------------------------------------------------------
AAPP_BIN=""
if command -v aapp >/dev/null 2>&1; then
    AAPP_BIN="$(command -v aapp)"
elif [ -x "$HOME/.local/bin/aapp" ]; then
    AAPP_BIN="$HOME/.local/bin/aapp"
fi

if [ -z "$AAPP_BIN" ]; then
    echo "❌ [AAPP Guard] 'aapp' command not found in PATH or ~/.local/bin." >&2
    echo "" >&2
    echo "   This repository is governed by the Asymmetric Agent Planning Protocol." >&2
    echo "   Without the 'aapp' toolchain installed, this clone is in INSPECTION-ONLY mode." >&2
    echo "   Commits are locked to prevent un-guarded code and plan desynchronization." >&2
    echo "" >&2
    echo "   To enable development and commits, install AAPP globally:" >&2
    echo "     git clone https://github.com/aapp-protocol/aapp-kit.git && ./aapp-kit/aapp install" >&2
    echo "" >&2
    exit 1
fi

# Escape hatch for blast radius & changelog (runs after reachability assertion)
if [ "${SKIP_BLAST_RADIUS:-0}" = "1" ]; then
    echo "⚡ [Pre-Commit Notice] Blast Radius and CHANGELOG verification skipped via SKIP_BLAST_RADIUS=1."
    exit 0
fi
```
- **Reachability Scope:** `AAPP_BIN` discovery confirms the runtime toolchain is present on the machine.
- **Strict Gating:** If `AAPP_BIN` is empty, `SKIP_BLAST_RADIUS=1` does not bypass the gate. Only Git's native `--no-verify` flag bypasses pre-commit.

### 2.3 Dedicated Test Runtime Confinement (`tests/test_helpers.sh`) (F1, F1', F4, F15)

To eliminate dependency on uninstalled drop-in clones across all test suites, prevent host environment leaks, and ensure deterministic test isolation:

1. **`confine_test_runtime "$SANDBOX_ROOT"` (F15)**:
   Added to `tests/test_helpers.sh`. Called at the top-level of every test suite.
   - Sets `SANDBOX_HOME="$SANDBOX_ROOT/home"`.
   - Sets `SANDBOX_BIN="$SANDBOX_HOME/.local/bin"` and `SANDBOX_SHARE="$SANDBOX_HOME/.local/share/aapp-kit"`.
   - Exports `HOME="$SANDBOX_HOME"`, `XDG_DATA_HOME="$SANDBOX_HOME/.local/share"`, and `PATH="$SANDBOX_BIN:/usr/bin:/bin:/usr/sbin:/sbin"`.
   - Installs a clean AAPP kit into `$SANDBOX_BIN` and `$SANDBOX_SHARE`.
   - **Fail-Closed Assertion:** Asserts that `command -v aapp` resolves strictly inside `$SANDBOX_BIN`, failing loudly if it ever resolves to the developer's host binary or a system path outside the sandbox.
2. **`init_sandbox_project "$PROJ_DIR"`**:
   Runs `aapp init` inside the project using the sandbox's installed binary, accurately simulating production adoption.
3. **Suite Migrations (F1')**:
   - `tests/install_test.sh`: Migrates from `make_kit_clone` to `confine_test_runtime`.
   - `tests/worktree_hooks_test.sh`, `tests/ai_attribution_test.sh`, `tests/hooks_test.sh`, `tests/sync_test.sh`: Migrate their uninstalled clone `init` calls to the sandbox-installed `aapp`.

### 2.4 Documentation & Skill Updates
1. **`README.md`**:
   - Delete "Option 1: Drop-In Project Setup".
   - Make Global Installation the primary Quick Start workflow.
   - Document Inspection-Only clone behavior and resolution.
2. **`MANUAL.md`**:
   - Purge drop-in setup, `--keep` discussions, and drop-in sample isolation.
   - Document the Runtime Reachability Invariant and Inspection-Only mode.
   - Update Troubleshooting and Q&A.
3. **`CHEATSHEET.md`**:
   - Align adoption commands to global install + `aapp init`.
4. **`templates/skills/aapp-status/SKILL.md`**:
   - Remove `./aapp status` fallback from execution instructions.
5. **`ARCHITECTURE.md`, `.agents/ARCHITECTURE.md` & `.agents/CODEMAP.md`**:
   - Record Runtime Reachability Invariant and update Rule 9 (init no longer exempt from front-door assertion).

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Test Runtime Confinement & Reachability Tests (Failure-First TDD)
- [ ] Task 1.1: Add `confine_test_runtime` with fail-closed sandbox assertion to `tests/test_helpers.sh`.
- [ ] Task 1.2: Add regression tests in `tests/pre-commit_test.sh`:
  - **Negative test (missing aapp):** Run `git commit` in sandbox with `PATH` stripped of `aapp` and `$HOME/.local/bin/aapp` absent; assert commit is blocked with exit code 1 and outputs `INSPECTION-ONLY mode`.
  - **Negative test (missing aapp + skip flag):** Assert `SKIP_BLAST_RADIUS=1` without `aapp` is STILL blocked.
  - **Positive test (reachable aapp):** Assert commit succeeds under standard plan conditions when `aapp` is present in `PATH`.
  - **Fallback test (reachable via ~/.local/bin):** Assert commit succeeds when `command -v aapp` fails but `$HOME/.local/bin/aapp` is executable.
  - **Native bypass test:** Assert `git commit --no-verify` succeeds even without `aapp`.
- [ ] Task 1.3: Add reachability check to `templates/aapp-pre-commit` and verify all Task 1.2 tests pass green.

### Phase 2: Dispatcher & Init Simplification
- [ ] Task 2.1: In `aapp`:
  - Export `AAPP_RUNTIME="installed"` vs `AAPP_RUNTIME="local"` based on base resolution.
  - Remove `AAPP_IS_DROP_IN`.
  - Remove `init` from front-door `REPO_ROOT` exemption list (`aapp:120`).
- [ ] Task 2.2: In `lib/cmd_init.sh`:
  - Remove Phase 7 ("Drop-in Folder Consumption").
  - Remove parent directory climbing (`PARENT_GIT_ROOT`, `IS_CWD_INSIDE_KIT`).
  - Add canonical physical path fast-fail check: `[ "$AAPP_RUNTIME" != "installed" ] && [ "$AAPP_BASE_PHYSICAL" != "$REPO_ROOT_PHYSICAL" ]`.
- [ ] Task 2.3: In `lib/cmd_install.sh`:
  - Verify `is_safe_to_consume_kit_dir` remains intact and self-consumption of the installer clone is preserved.

### Phase 3: Test Suite Migration (F1', F1'', F14, F15)
- [ ] Task 3.1: Update `tests/install_test.sh`:
  - Adopt `confine_test_runtime`.
  - Retire obsolete drop-in tests (Tests 3, 4, 5, 6, 6b, 6d, 6e, 20).
  - Rewrite Test 6c (#50) to assert kit self-init under physical canonical path resolution.
  - Add test asserting `aapp init` fails fast when run from an uninstalled clone against an external project.
- [ ] Task 3.2: Update `tests/worktree_hooks_test.sh` and `tests/ai_attribution_test.sh` to use `confine_test_runtime`.
- [ ] Task 3.3: Update `tests/hooks_test.sh` and `tests/sync_test.sh` to use `confine_test_runtime`.

### Phase 4: Documentation & Skill Synchronization
- [ ] Task 4.1: Update `templates/skills/aapp-status/SKILL.md` (remove `./aapp status` mention).
- [ ] Task 4.2: Update `README.md`: replace drop-in quickstart with global install and document Inspection-Only mode.
- [ ] Task 4.3: Update `MANUAL.md`: purge drop-in references, update installation guides, Q&A, and sample distribution.
- [ ] Task 4.4: Update `CHEATSHEET.md`: align setup commands.
- [ ] Task 4.5: Update `ARCHITECTURE.md`, `.agents/ARCHITECTURE.md`, and `.agents/CODEMAP.md` with runtime reachability invariant and Rule 9 update.
- [ ] Task 4.6: Update `CHANGELOG.md` with drop-in deprecation and inspection-only gate.

### Phase 5: Verification Suite
- [ ] Task 5.1: Run syntax checks across modified scripts (`bash -n`).
- [ ] Task 5.2: Run full regression test suite (`./aapp test strict quiet`) and verify 100% green pass.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `tests/test_helpers.sh` -> Add confine_test_runtime helper with PATH/HOME confinement and fail-closed assertion
- [ ] `templates/aapp-pre-commit` -> Add runtime reachability check (above SKIP_BLAST_RADIUS)
- [ ] `tests/pre-commit_test.sh` -> Add reachability gate regression tests
- [ ] `aapp` -> Add AAPP_RUNTIME export, remove drop-in resolution, remove init from front-door exemption
- [ ] `lib/cmd_init.sh` -> Remove Phase 7 kit consumption and parent-directory climbing; add canonical physical fast-fail check
- [ ] `lib/cmd_install.sh` -> Preserve self-consumption and clean clone handling
- [ ] `tests/install_test.sh` -> Migrate test cases to installed sandbox architecture; rewrite Test 6c (#50)
- [ ] `tests/worktree_hooks_test.sh` -> Use confine_test_runtime
- [ ] `tests/ai_attribution_test.sh` -> Use confine_test_runtime
- [ ] `tests/hooks_test.sh` -> Use confine_test_runtime
- [ ] `tests/sync_test.sh` -> Use confine_test_runtime
- [ ] `templates/skills/aapp-status/SKILL.md` -> Remove ./aapp fallback
- [ ] `README.md` -> Replace drop-in setup with global install and document inspection-only mode
- [ ] `MANUAL.md` -> Purge drop-in references, update installation workflows and Q&A
- [ ] `CHEATSHEET.md` -> Update setup and installation cheatsheet
- [ ] `ARCHITECTURE.md` -> Document runtime reachability invariant and Rule 9 update
- [ ] `.agents/ARCHITECTURE.md` -> Document runtime reachability invariant in agents worktree
- [ ] `.agents/CODEMAP.md` -> Update dispatch boundaries
- [ ] `CHANGELOG.md` -> Document drop-in deprecation and inspection-only gate

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Guard Section 2 self-protection. Propagated exclusively via `templates/aapp-pre-commit` and `aapp init`.
- [ ] `.agents/skills/*` -> Governance skills self-protection.
- [ ] `lib/cmd_plan.sh` -> Core plan lifecycle logic is unchanged.
- [ ] `lib/cmd_test.sh` -> Test runner enhancements belong to P-34.

---

## ❓ 5. Open Questions & Decision Matrix

* [x] **Question 1: Should the Inspection-Only check block all commits, or allow commits that do not touch planning/governance files?**  
  *Decision:* **Block all commits.** Pre-commit hooks protect the entire repository (verifying blast radius, changelog updates, and relative path invariants). Allowing non-planning commits without `aapp` would permit unverified, un-guarded code to bypass protocol enforcement. The error message clearly directs the user to install `aapp`.

* [x] **Question 2: Does SKIP_BLAST_RADIUS=1 bypass the reachability check?**  
  *Decision:* **No.** The reachability check executes before `SKIP_BLAST_RADIUS`. Missing `aapp` is a hard block. Only Git's native `--no-verify` flag bypasses pre-commit entirely.

* [x] **Question 3: How should P-36 be sequenced relative to P-34?**  
  *Decision:* **P-36 executes first, followed by P-34.** Both touch `tests/install_test.sh`. Migrating `install_test.sh` to the installed sandbox model in P-36 ensures P-34 authors its tests against the clean, permanent test harness. Pair 7 enforces that only one plan is in `⚡ In Development` at a time.

* [x] **Question 4: How should GUI/IDE PATH environments be handled for reachability (F13)?**  
  *Decision:* Probe both `command -v aapp` and `[ -x "$HOME/.local/bin/aapp" ]`. If either is found, reachability succeeds. If neither is found, the Inspection-Only refusal is displayed.

* [x] **Question 5: How are physical vs logical path comparisons and test environment leaks handled (F14, F15)?**  
  *Decision:* (1) `cmd_init.sh` canonicalizes `AAPP_BASE` and `REPO_ROOT` using `pwd -P` before comparison. (2) `tests/test_helpers.sh` provides a dedicated `confine_test_runtime` helper setting sandbox `HOME`, `XDG_DATA_HOME`, and `PATH` with fail-closed assertion against host leaks.

---

## 📦 6. Change Log & Refinement History
* **2026-09-27:** Plan locked and frozen into 🔷 Frozen via freeze.
* **2026-09-27 (refinement 3):** Resolved Round 3 Red Team findings:
  1. Canonicalized physical paths (`pwd -P`) in `cmd_init.sh` fast-fail predicate, preventing symlink false-positives on macOS `/var` and symlinked test scratchpads (resolving F14).
  2. Extracted dedicated `confine_test_runtime` helper in `tests/test_helpers.sh` covering `HOME`, `XDG_DATA_HOME`, and `PATH` with fail-closed host leak assertion (resolving F15).
  3. Rewrote Test 6c (#50) in `install_test.sh` to preserve regression link for kit self-init.
* **2026-09-27 (refinement 2):** Resolved Round 2 Red Team findings:
  1. Expanded target files to include `tests/hooks_test.sh` and `tests/sync_test.sh` (resolving F1').
  2. Expanded test retirement list in Task 3.1 to include tests 3, 4, 5, 6, 6b, 6c, 6d, 6e, 20 (resolving F1'').
  3. Single-sourced runtime classification in `aapp` via `AAPP_RUNTIME=installed|local` and made fast-fail predicate in `cmd_init.sh` name-independent (resolving F11, F12).
  4. Hardened pre-commit reachability gate with `$HOME/.local/bin/aapp` executable check to prevent false lockouts in GUI/macOS clients lacking shell PATH (resolving F13).
  5. Added positive, negative, and fallback test specifications to Task 1.2.
  6. Added `.agents/ARCHITECTURE.md` to Target Files (resolving F8).
* **2026-09-27 (refinement 1):** Adopted Round 1 Red Team findings:
  1. Expanded blast radius to include `tests/test_helpers.sh`, `tests/worktree_hooks_test.sh`, and `tests/ai_attribution_test.sh` with `setup_sandbox_installed_aapp` helper (resolving F1).
  2. Preserved installer self-consumption in `lib/cmd_install.sh` per developer directive (resolving F2).
  3. Codified testable fast-fail predicate in `cmd_init.sh` (resolving F3).
  4. Placed reachability check before `SKIP_BLAST_RADIUS=1` so only `--no-verify` bypasses (resolving F5).
  5. Removed `init` from front-door exemption list in `aapp` and updated Rule 9 (resolving F7).
  6. Added `templates/skills/aapp-status/SKILL.md` (resolving F8).
  7. Ordered Phase 1 as failure-first TDD (resolving F9).
  8. Recorded strict sequencing with P-34 (resolving F6).
* **2026-09-27:** Initial draft created from adversarial analysis of drop-in kit consumption and documentation drift (#83). Established Inspection-Only mode and single global distribution model.
