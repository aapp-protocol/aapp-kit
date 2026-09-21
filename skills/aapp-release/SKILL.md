---
name: aapp-release
description: Execute release pre-flight verification runbook. Verifies branch parity, executes test suites and linters, and checks changelog readiness.
disable-model-invocation: false
context: fork
argument-hint: "[version]"
---

# AAPP Release (Pre-Flight Runbook Verification)

Execute the release pre-flight verification runbook to ensure repository stability and deployment readiness.

## Five-Step Execution Procedure

### Step 1: Inspect Canonical Runbook
Inspect `.plans/release/release_checklist.md` (the canonical release runbook for the repository) to review project-specific gates, environment requirements, and checklist items.

### Step 2: Enforce Stable vs. Edge Branch Convention
Check current branch and git status:
* `main` is strictly **STABLE** (clean tag `vX.Y.Z`).
* `develop` is **EDGE** (`-dev`).
* If working on `develop`, verify that it fast-forwards cleanly into `main` without conflicts before proceeding:
  ```bash
  git checkout main && git merge --ff-only develop
  ```

### Step 3: Run Verification Test Suites & Linters
Execute the automated validation commands defined in the release checklist:
* Run unit, integration, and regression test suites.
* Run syntax checks, linters, and static analysis tools.
* Verify clean exit codes across all test runs.

### Step 4: Verify Changelog & Tag Readiness
Inspect `CHANGELOG.md` (or `.plans/CHANGELOG.md`):
* Verify that entries for `<version>` exist and accurately summarize changes.
* Ensure headings follow Keep a Changelog standards (`## [vX.Y.Z] - YYYY-MM-DD`).
* Confirm working trees across all worktrees (`main`, `.plans`, `.agents`, `.githooks`) are clean.

### Step 5: Report Posture Assessment
Print a structured release posture assessment:
* **Branch Parity:** Clean / FF status between `develop` and `main`.
* **Tests & Linters:** Status and summary of test executions.
* **Documentation & Changelog:** Ready for release tagging.
* **Rollback Readiness:** Confirmation of tag commit SHA and clean rollback path.

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
