# 🗺️ Plan P-36: Deprecate Drop-In Distribution & Enforce CLI Runtime Reachability
* **Created:** 2026-09-27 | **Last Refined:** 2026-09-27
* **Target Issue / Milestone:** #83
* **Plan ID:** P-36
* **Status:** 🟣 Under Review
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
AAPP was originally conceived at v1.0.0 as a lightweight, zero-dependency set of Git hooks and Markdown prose guidelines. In that context, a self-consuming "drop-in" folder (`./aapp-kit/aapp init`) made sense: it mounted orphan worktrees (`.plans/`, `.agents/`, `.githooks/`), copied initial templates and rules, and then deleted itself (`rm -rf aapp-kit/`) under the rationale of leaving a "clean repo".

However, over successive iterations (Plans P-7 through P-34), AAPP evolved into an active protocol runtime. Crucial governance functions are now implemented as deterministic Bash engines (`aapp status`, `matrix`, `freeze`, `start`, `done`, `test`, `pause`, `plan`). 

Because drop-in mode deletes the kit without installing `aapp` into the host environment's `$PATH`:
1. **Broken Commands:** Any adopter who followed "Option 1: Drop-In" in `README.md` or `MANUAL.md` has no `aapp` command. Running `aapp status` or `aapp freeze` fails immediately with `bash: aapp: command not found`.
2. **Prose-Only Degradation:** Universal skills (`.agents/skills/`) instruct agents to run CLI commands that cannot execute, falling back to manual prose edits and corrupting derived structures (like `state_matrix.md`).
3. **Misleading Documentation:** `README.md` and `MANUAL.md` heavily promote drop-in as a primary distribution mode while advertising CLI verbs that require a global install.

Leaving a local `./aapp` binary and `lib/` directory inside the project repository was considered and **firmly rejected**:
- **Repo Pollution:** Polluting the host code branch with governance binaries violates AAPP's fundamental premise of isolated, clean repositories.
- **Security Anti-Pattern:** Adding a repository worktree path to the developer's `$PATH` is a severe security hazard (repo code executing in developer PATH).
- **Not Drop-in:** Requiring developers to alter shell rc files or configure local paths destroys the zero-parameter promise.

### Architectural Goal
1. **Deprecate and Purge Drop-In Mode:** Unify distribution exclusively around **Global Installation (`aapp install`)** followed by **Project Adoption (`aapp init`)**. Remove kit-consumption gymnastics (`is_safe_to_consume_kit_dir`, parent directory resolution) from `aapp` and `lib/cmd_init.sh`.
2. **Pre-Commit Runtime Reachability Check (Inspection-Only Mode):** When a repository using AAPP is cloned onto a machine where the `aapp` binary is not in `$PATH`, the pre-commit hook (`templates/aapp-pre-commit`) blocks commits and declares the clone to be in **Inspection-Only Mode**, printing an actionable diagnostic pointing to `aapp install`.
3. **Comprehensive Documentation Overhaul:** Completely purge drop-in references from `README.md`, `MANUAL.md`, and `CHEATSHEET.md`, presenting a clear, honest, and robust installation narrative.

---

## 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- All legacy drop-in flags (`--keep`, `AAPP_IS_DROP_IN`) and consumption checks (`is_safe_to_consume_kit_dir`) are removed without shims or dual-syntax aliases.

### 2.1 Distribution Architecture

AAPP transitions to a standard development toolchain model (analogous to `git`, `gh`, `cargo`):

```text
┌────────────────────────────────────────────────────────┐
│                   Developer Machine                    │
│                                                        │
│  1. One-Time Global Installation:                      │
│     git clone https://.../aapp-kit.git                 │
│     ./aapp-kit/aapp install                            │
│     ├── ~/.local/bin/aapp                              │
│     └── ~/.local/share/aapp-kit/{lib,templates,tests}  │
└───────────────────────────┬────────────────────────────┘
                            │ invokes 'aapp init'
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

#### Fast-Fail Outside Installed/Develop Environment
If `aapp init` is invoked directly from a clone without being installed (e.g. `./aapp init` inside a freshly cloned `aapp-kit`), it must detect that it is neither running from `$SHARE_DIR` nor under `aapp develop` symlinks, and exit with code 1:
```text
❌ Error: AAPP must be installed globally before initializing projects.
   Run: ./aapp install
```

### 2.2 Pre-Commit Hook Runtime Reachability Guard (Inspection-Only Mode)

In `templates/aapp-pre-commit` (Section 1: Pre-flight & System Boundaries), add an authoritative runtime reachability gate:

```bash
# ------------------------------------------------------------------------------
# 1. Pre-Flight: Runtime Reachability & Inspection-Only Gate
# ------------------------------------------------------------------------------
if ! command -v aapp >/dev/null 2>&1; then
    echo "❌ [AAPP Guard] 'aapp' command not found in PATH." >&2
    echo "" >&2
    echo "   This repository is governed by the Asymmetric Agent Planning Protocol." >&2
    echo "   Without the 'aapp' toolchain installed, this clone is in INSPECTION-ONLY mode." >&2
    echo "   Commits and plan state transitions are locked to prevent protocol desynchronization." >&2
    echo "" >&2
    echo "   To enable development and commits, install AAPP globally:" >&2
    echo "     git clone https://github.com/aapp-protocol/aapp-kit.git && ./aapp-kit/aapp install" >&2
    echo "" >&2
    exit 1
fi
```

- **Behavior:** Clones without `aapp` can be checked out, read, browsed, and inspected. Any attempt to commit code or documentation without the active enforcement engine is immediately refused before touching git history.
- **Escape Hatch:** Standard `SKIP_BLAST_RADIUS=1` bypass remains available for emergency administrative actions if needed.

### 2.3 Simplification of `aapp` Dispatcher & `lib/cmd_init.sh`

1. **`aapp` binary:**
   - Remove `AAPP_IS_DROP_IN`.
   - Remove `is_safe_to_consume_kit_dir` and the self-consumption checks.
   - Base lookup simplifies strictly to:
     - Check `$AAPP_SCRIPT_DIR` if develop symlink / repo root.
     - Check `$XDG_DATA_HOME/aapp-kit` or `~/.local/share/aapp-kit`.
     - Otherwise fail with installation instructions.
2. **`lib/cmd_init.sh`:**
   - Remove Phase 7 ("Drop-in Folder Consumption").
   - Remove parent directory climbing (`PARENT_GIT_ROOT`, `CWD_GIT_ROOT`, `IS_CWD_INSIDE_KIT`). Target repository resolution is strictly `git rev-parse --show-toplevel` from current directory (per P-33 fail-fast assertion).

### 2.4 Comprehensive Documentation Synchronization

1. **`README.md`**:
   - Delete `Option 1: Drop-In Project Setup (Self-Consuming)`.
   - Re-anchor Quick Start to:
     - Step 1: Global Install (`./aapp-kit/aapp install`)
     - Step 2: Adopt in any project (`cd my-project && aapp init`)
     - Step 3: Daily CLI usage (`aapp status`, `aapp plan`, etc.)
   - Document **Inspection-Only Mode** for cloned repositories.
2. **`MANUAL.md`**:
   - Purge all drop-in setup recipes, self-consumption discussions, and `--keep` references.
   - Remove §2.5 drop-in sample isolation in favor of the uniform `$SHARE_DIR/examples/` model.
   - Update Q&A section to reflect single-method installation.
3. **`CHEATSHEET.md`**:
   - Update Installation & Setup table to reflect global install + init.
4. **`ARCHITECTURE.md` & `.agents/CODEMAP.md`**:
   - Record the Runtime Reachability Invariant and single global distribution model.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Pre-Commit Reachability Engine
- [ ] Task 1.1: Add `command -v aapp` reachability check and Inspection-Only diagnostic banner to `templates/aapp-pre-commit`.
- [ ] Task 1.2: Add unit and regression tests in `tests/pre-commit_test.sh` asserting:
  - Commit blocked when `aapp` is absent from `PATH` with inspection-only banner and non-zero exit code.
  - Commit allowed when `aapp` is present in `PATH` (under standard plan conditions).
  - Commit allowed when `SKIP_BLAST_RADIUS=1` even if `aapp` is absent.

### Phase 2: CLI Dispatcher & Init Simplification
- [ ] Task 2.1: Remove `AAPP_IS_DROP_IN`, `is_safe_to_consume_kit_dir`, and parent-directory climbing from `aapp`.
- [ ] Task 2.2: Remove Phase 7 self-consumption and parent-path traversal from `lib/cmd_init.sh`.
- [ ] Task 2.3: Ensure `aapp init` asserts that AAPP is running from an installed `$SHARE_DIR` or develop symlink.
- [ ] Task 2.4: Update `tests/install_test.sh`:
  - Remove obsolete drop-in self-consumption tests (Tests 6, 6d, 6e, 25b, 25c, 25d).
  - Add tests asserting global installation and clean project adoption (`aapp init`).

### Phase 3: Comprehensive Documentation Overhaul
- [ ] Task 3.1: Update `README.md`: replace drop-in quickstart with global installation and document Inspection-Only mode.
- [ ] Task 3.2: Update `MANUAL.md`: purge drop-in references, update installation guides, Q&A, and sample distribution.
- [ ] Task 3.3: Update `CHEATSHEET.md`: align setup commands.
- [ ] Task 3.4: Update `ARCHITECTURE.md` and `.agents/CODEMAP.md` with runtime reachability invariant.
- [ ] Task 3.5: Update `CHANGELOG.md` with drop-in deprecation and inspection-only gate.

### Phase 4: Verification Suite
- [ ] Task 4.1: Run syntax checks across modified scripts (`bash -n`).
- [ ] Task 4.2: Run full regression test suite (`./aapp test strict quiet`) and verify 100% green pass.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/aapp-pre-commit` -> Add runtime reachability check and inspection-only diagnostic
- [ ] `aapp` -> Remove drop-in resolution, parent detection, and consumption helper
- [ ] `lib/cmd_init.sh` -> Remove Phase 7 kit consumption and parent-directory climbing
- [ ] `tests/pre-commit_test.sh` -> Add regression tests for CLI reachability in pre-commit
- [ ] `tests/install_test.sh` -> Replace drop-in consumption tests with global adoption verification
- [ ] `README.md` -> Replace drop-in setup with global install and document inspection-only mode
- [ ] `MANUAL.md` -> Purge drop-in references, update installation workflows and Q&A
- [ ] `CHEATSHEET.md` -> Update setup and installation cheatsheet
- [ ] `ARCHITECTURE.md` -> Document runtime reachability invariant and distribution architecture
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

* [x] **Question 2: How should `aapp develop` relate to global installation?**  
  *Decision:* `aapp develop` remains the canonical development workflow for kit contributors, creating symlinks in `~/.local/bin` and `~/.local/share/aapp-kit` so local edits are live immediately. Adopters use `aapp install`, which copies files. Both result in `aapp` being reachable in `$PATH`.

---

## 📦 6. Change Log & Refinement History
* **2026-09-27:** Initial draft created from adversarial analysis of drop-in kit consumption and documentation drift (#83). Established Inspection-Only mode and single global distribution model.
