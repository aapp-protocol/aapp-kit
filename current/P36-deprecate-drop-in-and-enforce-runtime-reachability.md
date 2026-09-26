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
- **Keeping a local CLI in the repository (Rejected):** Leaving `./aapp` and `lib/` in the project working tree was considered and **firmly rejected**. The foundational premise of AAPP is that code branches remain 100% pristine and unpolluted by governance tooling. Furthermore, adding repo-relative execution paths to `$PATH` introduces security risks, while invoking repo-local binaries via relative paths adds maintenance churn and violates the clean-repo standard.
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

### 2.1 Distribution Architecture & Fast-Fail Predicate

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

#### Fast-Fail Predicate in `cmd_init.sh`
`aapp init` must only execute from an authorized runtime environment:
```bash
# Sourced inside cmd_init.sh
# Determine if running from installed share dir, aapp develop symlink, or live kit development
IS_AUTHORIZED_RUNTIME=0
if [ "$AAPP_BASE" = "${XDG_DATA_HOME:-$HOME/.local/share}/aapp-kit" ] || \
   [ "$(basename "$REPO_ROOT")" = "agent-planning-kit" ] || \
   [ "$(basename "$REPO_ROOT")" = "aapp-develop-kit" ]; then
    IS_AUTHORIZED_RUNTIME=1
fi

if [ "$IS_AUTHORIZED_RUNTIME" -eq 0 ]; then
    echo "❌ Error: AAPP must be installed globally before initializing projects." >&2
    echo "   Run: ./aapp install" >&2
    exit 1
fi
```
If an adopter clones `aapp-kit` into a project and attempts to run `./aapp-kit/aapp init` directly (the obsolete drop-in syntax), the command fails fast without modifying the project or self-consuming.

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
Because `cmd_init.sh` no longer performs parent-directory climbing, `init` cleanly inherits the front-door `REPO_ROOT` assertion, failing closed if executed outside a Git repository.

### 2.2 Pre-Commit Hook Runtime Reachability Gate (`templates/aapp-pre-commit`)

In `templates/aapp-pre-commit`, place the reachability gate at the very top, **above** `SKIP_BLAST_RADIUS`:

```bash
# ------------------------------------------------------------------------------
# 0. Pre-Flight: Runtime Reachability & Inspection-Only Gate
# ------------------------------------------------------------------------------
if ! command -v aapp >/dev/null 2>&1; then
    echo "❌ [AAPP Guard] 'aapp' command not found in PATH." >&2
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
- **Reachability Scope:** `command -v aapp` verifies reachability of the protocol runner. It is an operational prerequisite check, not a cryptographic hash check.
- **Strict Gating:** If `aapp` is not in `$PATH`, `SKIP_BLAST_RADIUS=1` has no effect. Only Git's native `--no-verify` flag bypasses pre-commit.

### 2.3 Test Harness Evolution (`tests/test_helpers.sh`)

To resolve F1 and eliminate dependency on uninstalled drop-in clones across all test suites:
1. **`setup_sandbox_installed_aapp "$SANDBOX_HOME"`**:
   Added to `tests/test_helpers.sh`. Creates an isolated user environment inside the test sandbox:
   - Sets `SANDBOX_BIN="$SANDBOX_HOME/.local/bin"` and `SANDBOX_SHARE="$SANDBOX_HOME/.local/share/aapp-kit"`.
   - Copies binary to `$SANDBOX_BIN/aapp` and `lib/`, `templates/`, `tests/`, `examples/` to `$SANDBOX_SHARE`.
   - Exports `PATH="$SANDBOX_BIN:$PATH"` and `XDG_DATA_HOME="$SANDBOX_HOME/.local/share"`.
2. **`init_sandbox_project "$PROJ_DIR"`**:
   Runs `aapp init` inside the project using the sandbox's installed binary, accurately simulating production adoption.
3. **Controlled PATH Isolation (F4)**:
   Tests verifying the inspection-only gate explicitly execute with `PATH` stripped of `aapp` (e.g. `PATH="/usr/bin:/bin" git commit`), ensuring green results on machines regardless of whether `~/.local/bin/aapp` exists on the host.

### 2.4 Documentation & Skill Updates
1. **`README.md`**:
   - Remove "Option 1: Drop-In Project Setup".
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
5. **`ARCHITECTURE.md` & `.agents/CODEMAP.md`**:
   - Record Runtime Reachability Invariant and update Rule 9 (init no longer exempt from front-door assertion).

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Test Harness Evolution & Reachability Test (Failure-First)
- [ ] Task 1.1: Add `setup_sandbox_installed_aapp` and `init_sandbox_project` to `tests/test_helpers.sh`.
- [ ] Task 1.2: Add failing regression test in `tests/pre-commit_test.sh`:
  - Run `git commit` in a sandbox with `PATH` stripped of `aapp`.
  - Assert commit is rejected with exit code 1 and contains `INSPECTION-ONLY mode`.
  - Assert `SKIP_BLAST_RADIUS=1` still fails when `aapp` is missing.
  - Assert `git commit --no-verify` succeeds.
- [ ] Task 1.3: Add reachability check to `templates/aapp-pre-commit` and verify Task 1.2 test passes green.

### Phase 2: Dispatcher & Init Simplification
- [ ] Task 2.1: In `aapp`:
  - Remove `AAPP_IS_DROP_IN`.
  - Remove `init` from front-door `REPO_ROOT` exemption list (`aapp:120`).
- [ ] Task 2.2: In `lib/cmd_init.sh`:
  - Remove Phase 7 ("Drop-in Folder Consumption").
  - Remove parent directory climbing (`PARENT_GIT_ROOT`, `IS_CWD_INSIDE_KIT`).
  - Add fast-fail check ensuring execution occurs via installed `$SHARE_DIR` or develop workspace.
- [ ] Task 2.3: In `lib/cmd_install.sh`:
  - Verify `is_safe_to_consume_kit_dir` remains intact and self-consumption of the installer clone is preserved.

### Phase 3: Test Suite Migration
- [ ] Task 3.1: Update `tests/install_test.sh`:
  - Migrate project setup helpers from drop-in `make_kit_clone` to `setup_sandbox_installed_aapp`.
  - Retire obsolete drop-in tests (Tests 3, 4, 6d, 6e, 20).
  - Add test asserting `aapp init` fails fast when run directly from uninstalled clone.
- [ ] Task 3.2: Update `tests/worktree_hooks_test.sh` and `tests/ai_attribution_test.sh` to use sandbox installed `aapp`.

### Phase 4: Documentation & Skill Synchronization
- [ ] Task 4.1: Update `templates/skills/aapp-status/SKILL.md` (remove `./aapp status` mention).
- [ ] Task 4.2: Update `README.md`: replace drop-in quickstart with global install and document Inspection-Only mode.
- [ ] Task 4.3: Update `MANUAL.md`: purge drop-in references, update installation guides, Q&A, and sample distribution.
- [ ] Task 4.4: Update `CHEATSHEET.md`: align setup commands.
- [ ] Task 4.5: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` with runtime reachability invariant and Rule 9 update.
- [ ] Task 4.6: Update `CHANGELOG.md` with drop-in deprecation and inspection-only gate.

### Phase 5: Verification Suite
- [ ] Task 5.1: Run syntax checks across modified scripts (`bash -n`).
- [ ] Task 5.2: Run full regression test suite (`./aapp test strict quiet`) and verify 100% green pass.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `tests/test_helpers.sh` -> Add sandbox installed kit helpers and PATH confinement
- [ ] `templates/aapp-pre-commit` -> Add runtime reachability check (above SKIP_BLAST_RADIUS)
- [ ] `tests/pre-commit_test.sh` -> Add reachability gate regression tests
- [ ] `aapp` -> Remove drop-in resolution and remove init from front-door exemption
- [ ] `lib/cmd_init.sh` -> Remove Phase 7 kit consumption and parent-directory climbing; add fast-fail check
- [ ] `lib/cmd_install.sh` -> Preserve self-consumption and clean clone handling
- [ ] `tests/install_test.sh` -> Migrate test cases to installed sandbox architecture
- [ ] `tests/worktree_hooks_test.sh` -> Use sandbox installed aapp
- [ ] `tests/ai_attribution_test.sh` -> Use sandbox installed aapp
- [ ] `templates/skills/aapp-status/SKILL.md` -> Remove ./aapp fallback
- [ ] `README.md` -> Replace drop-in setup with global install and document inspection-only mode
- [ ] `MANUAL.md` -> Purge drop-in references, update installation workflows and Q&A
- [ ] `CHEATSHEET.md` -> Update setup and installation cheatsheet
- [ ] `ARCHITECTURE.md` -> Document runtime reachability invariant and Rule 9 update
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

---

## 📦 6. Change Log & Refinement History
* **2026-09-27 (refinement 1):** Adopted Red Team findings:
  1. Expanded blast radius to include `tests/test_helpers.sh`, `tests/worktree_hooks_test.sh`, and `tests/ai_attribution_test.sh` with `setup_sandbox_installed_aapp` helper (resolving F1).
  2. Preserved installer self-consumption in `lib/cmd_install.sh` per developer directive (resolving F2).
  3. Codified testable fast-fail predicate in `cmd_init.sh` (resolving F3).
  4. Placed reachability check before `SKIP_BLAST_RADIUS=1` so only `--no-verify` bypasses (resolving F5).
  5. Removed `init` from front-door exemption list in `aapp` and updated Rule 9 (resolving F7).
  6. Added `templates/skills/aapp-status/SKILL.md` (resolving F8).
  7. Ordered Phase 1 as failure-first TDD (resolving F9).
  8. Recorded strict sequencing with P-34 (resolving F6).
* **2026-09-27:** Initial draft created from adversarial analysis of drop-in kit consumption and documentation drift (#83). Established Inspection-Only mode and single global distribution model.
