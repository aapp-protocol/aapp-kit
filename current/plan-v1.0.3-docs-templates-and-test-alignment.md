# 🗺️ Plan: Documentation, Templates & Test Alignment (Batch 4)
* **Created:** 2026-09-10 | **Last Refined:** 2026-09-10
* **Target Issue / Milestone:** #ISSUE-020 (Batch 4: ISSUE-020 to ISSUE-030, ISSUE-033, ISSUE-034, ISSUE-039)
* **Status:** 🟡 Refining

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
Following the completion of core engine hardening (Batch 1 & 2), CLI reliability & develop mode (Batch 3), and the master archival ledger, Batch 4 addresses all remaining documentation drift, starter template anomalies, and minor test suite coverage gaps identified during the 2026-09-09 system audit.

This ensures that generated template files (`templates/*`), technical manuals (`MANUAL.md`, `README.md`), examples, and test helper suites are 100% synchronized with the actual unified `aapp` CLI implementation.

---

## 2. Technical Blueprint

### A. Documentation & TOC Fixes (`README.md`, `MANUAL.md`)
- **TOC Regeneration (ISSUE-020, ISSUE-024)**: Rebuild the Table of Contents in `README.md` and `MANUAL.md` to ensure all anchors match rendered headings and include new sections (e.g. `aapp develop` Contributor Mode, Master Archival Ledger).
- **Hook Architecture & Wiring Clarity (ISSUE-021)**:
  - Clearly document the separation between `.githooks/pre-commit` (the project-owned master runner, installed once and never overwritten on upgrade) and `.githooks/aapp-pre-commit` (the AAPP-managed blast-radius engine, updated automatically on upgrades).
  - Highlight the Polyglot Invocation Cheat Sheet in `MANUAL.md` (Perl, Python, Node.js, Ruby, Husky, Lefthook) showing how developers wire `.githooks/aapp-pre-commit` into their master hooks alongside custom project linters/tests in their preferred execution order.
- **Syntax Validator Claims (ISSUE-025)**: Correct `MANUAL.md` syntax check descriptions to reflect supported linters (Python `py_compile`, PHP `php -l`, JSON syntax).
- **Orphan Branch & Error Codes (ISSUE-027)**: Update `MANUAL.md` explanation of orphan branch creation to match the safe non-destructive Git plumbing algorithm (`commit-tree`), and update Claude Code decision handling (`exit code 2` / `hookSpecificOutput`).

### B. Starter Template Fixes (`templates/`)
- **Issues Template Link (ISSUE-028)**: Fix relative blueprint path in `templates/issues.md` to use `.plans/current/` rather than `../.plans/current/`.
- **Architecture Template Tree (ISSUE-029)**: Fix file tree in `templates/architecture.md` and `ARCHITECTURE.md` to place `pickup.md` and `state_matrix.md` directly under `.plans/` rather than `.plans/current/`.
- **Rule Comment Stamping (ISSUE-030)**: Update `templates/AGENTS.md` comment from `AAPP-INIT` to `aapp init`.

### C. Examples & Test Suite Gaps (`examples/`, `tests/`)
- **Example Blueprint Modernization (ISSUE-039)**: Rename `examples/example_plan_unified_install_and_upgrade.md` to `examples/example-plan-unified-install-and-upgrade.md` (kebab-case) and modernize references to unified `aapp` commands.
- **Write-Guard Test Cleanup (ISSUE-033)**: Hoist helper assertions and remove duplicate dead stdin call in `tests/write-guard_test.sh`.
- **Pre-Commit Test Expansion (ISSUE-034)**: Verify test coverage for deletions, fallback init, and subdirectories.

---

## 🔨 3. Implementation Steps & Execution Checklist

### Phase 1: Starter Templates & Example Cleanup
- [ ] Task 1.1: Fix relative path in `templates/issues.md` (`ISSUE-028`).
- [ ] Task 1.2: Correct directory trees in `templates/architecture.md` and `ARCHITECTURE.md` (`ISSUE-029`).
- [ ] Task 1.3: Update header comments in `templates/AGENTS.md` (`ISSUE-030`).
- [ ] Task 1.4: Rename and modernize `examples/example_plan_unified_install_and_upgrade.md` to kebab-case (`ISSUE-039`).

### Phase 2: Documentation & Manual Alignment
- [ ] Task 2.1: Regenerate Table of Contents in `README.md` and `MANUAL.md` (`ISSUE-020`, `ISSUE-024`).
- [ ] Task 2.2: Clarify master `.githooks/pre-commit` vs managed `.githooks/aapp-pre-commit` upgrade architecture and polyglot wiring in `README.md` and `MANUAL.md` (`ISSUE-021`).
- [ ] Task 2.3: Correct syntax validation and orphan branch explanations in `MANUAL.md` (`ISSUE-025`, `ISSUE-027`).
- [ ] Task 2.4: Align No-Plan Grace Period description in `MANUAL.md` (`ISSUE-026`).

### Phase 3: Test Suite Refinement & Full Verification
- [ ] Task 3.1: Clean up helper assertions in `tests/write-guard_test.sh` (`ISSUE-033`).
- [ ] Task 3.2: Verify regression test suites pass with 80+ test cases.
- [ ] Task 3.3: Update `CHANGELOG.md` with Batch 4 resolution entries.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `README.md` -> TOC and hook wiring alignment
- [ ] `MANUAL.md` -> TOC, syntax check claims, and orphan branch alignment
- [ ] `ARCHITECTURE.md` -> Tree path correction
- [ ] `templates/issues.md` -> Fix relative link path
- [ ] `templates/architecture.md` -> Fix tree paths
- [ ] `templates/AGENTS.md` -> Update comment reference
- [ ] `examples/example-plan-unified-install-and-upgrade.md` -> Renamed and modernized example
- [ ] `tests/write-guard_test.sh` -> Clean up test assertions and remove dead call
- [ ] `CHANGELOG.md` -> Record Batch 4 resolution

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `templates/blast-radius-guard.sh` -> Core Layer 1 engine is frozen
- [ ] `templates/aapp-pre-commit` -> Core Layer 2 engine is frozen
- [ ] `lib/cmd_develop.sh` -> Develop mode command is frozen
- [ ] `lib/cmd_install.sh` -> Installer logic is frozen

---

## ❓ 5. Open Questions (Optional / Gate)
*(None — design is fully specified)*
* **Q1 (Resolved):** Standard Git rename of `examples/example_plan_unified_install_and_upgrade.md` to `examples/example-plan-unified-install-and-upgrade.md` (kebab-case).
* **Q2 (Resolved):** Separation of concerns locked: `.githooks/pre-commit` is installed once as the customizable project entrypoint (never overwritten on upgrade). `.githooks/aapp-pre-commit` is the managed engine (upgraded automatically). `MANUAL.md` showcases polyglot cheat sheets (Perl, Python, Node, Ruby, Husky, Lefthook) for custom hook wiring.

---

## 📦 6. Change Log & Refinement History
* **2026-09-10:** Plan drafted from `/digest ISSUE-020` (Batch 4 items).
* **2026-09-10:** Refined hook architecture: locked `.githooks/pre-commit` (project-owned entrypoint) vs `.githooks/aapp-pre-commit` (managed engine) with polyglot wiring recipes. Ready for freeze.
