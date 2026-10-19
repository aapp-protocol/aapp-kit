---
name: aapp-release
description: Execute milestone release bundling, changelog rollup, and hook-based versioning via `aapp release`.
disable-model-invocation: false
context: fork
argument-hint: "<version-or-bump> [check] [yes] [push] [unverified] [json] [no-archive] [no-changelog]"
---

# AAPP Release (Milestone Bundling & Hook-Based Versioning)

Execute the milestone release command to bundle completed architecture blueprints, roll up changelogs, dispatch versioning hooks, and create git release tags.

## Invocations

### 1. Pre-Flight Simulation (Check Only)
Run Phase A read-only verification to preview the release without applying mutations:
```bash
aapp release <version-or-bump> check
```

### 2. Standard Production Release
Execute Phase A pre-flight checks followed by Phase B atomic mutations:
```bash
aapp release <version-or-bump> yes
```
* `<version-or-bump>`: Explicit version (e.g. `1.2.0`, `v1.0.1.alpha`) or SemVer bump token (`patch`, `minor`, `major`).

### 3. Release & Automated Push
Create local release and push release branch, tags, and `.plans` branch:
```bash
aapp release <version-or-bump> yes push
```

### 4. Headless CI/CD JSON Mode
Emit structured machine-readable JSON release data directly to stdout:
```bash
aapp release <version-or-bump> json yes
```

## Execution Pipeline

### Phase A: Mandatory Read-Only Pre-Flight Gate & Simulation
1. **Clean Worktree Verification**: Ensures working trees across primary checkout and kit worktrees (`.plans`, `.agents`, `.githooks`) are clean (exempting in-flight plan worktrees).
2. **Test Suite Gate**: Runs project test suite (`git config aapp.testCommand` or kit runner).
3. **Pre-Release Gate Hook**: Dispatches `pre-release` lifecycle quality gate hook.
4. **Tag Signing Capability**: Inspects native Git signing (`tag.gpgSign` and `user.signingkey`).
5. **Changelog Existence Gate**: Validates root `CHANGELOG.md` exists (bypassable with `no-changelog`).
6. **Commit Reachability Gate**: Verifies all bundled blueprints are reachable on the development branch via Tier 1 ancestry or Tier 2 `Plan-ID:` trailers (bypassable with `unverified`).
7. **Branch Parity Gate**: Asserts development branch fast-forwards cleanly into release branch.
8. **Simulation Preview**: Displays complete transition details before prompting confirmation.

### Phase B: Atomic Release Mutation
1. **Rollback Trap**: Installs fail-closed `_release_rollback()` trap capturing branch ref snapshots.
2. **Hook-Based Version Increment**: Dispatches `on-release` action delegate passing Dual Delivery payload (`AAPP_RELEASE_VERSION`, `AAPP_RAW_VERSION`, `AAPP_PREVIOUS_VERSION`, `AAPP_VERSION_BUMP`).
3. **Changelog Rollup**: Rolls up `## [Unreleased]` into `## [<version>] - <YYYY-MM-DD>`.
4. **Milestone Bundling**: Moves completed plans from `.plans/done/` into `.plans/release/<tag>/plans/`, relocates defects, updates plan links, and generates tag ledger `000-archive-ledger.md`, `manifest.md`, and `manifest.json`.
5. **Master Ledger Rollup**: Truncates master ledger with 1-line release summary row under `## 🏷️ Shipped Releases` and resets `.plans/done/000-issues-archive.md`.
6. **Worktree Commit**: Commits `.plans` worktree.
7. **Parity Merge & Tagging**: Merges to release branch and creates signed or annotated tag.
8. **Publication & Notification**: Displays publication banner (or pushes if `push` passed) and dispatches `post-release` observer hook.

---
*Canonical Specification: Refer to `.plans/current/P38-milestone-release-bundling-and-tag-ledgers.md` for full protocol governance.*
