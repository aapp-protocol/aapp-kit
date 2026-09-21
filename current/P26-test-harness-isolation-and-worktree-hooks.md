# 🗺️ Plan P-26: Test Harness Sandbox Confinement & Universal Worktree Hook Enforcement
* **Created:** 2026-09-21 | **Last Refined:** 2026-09-21
* **Target Issue / Milestone:** #74 *(supersedes #74 upon completion)*
* **Plan ID:** P-26
* **Status:** 📝 Refining
<!-- Status must be exactly ONE of: 🟣 Under Review | 📝 Refining | 🔷 Frozen | ⚡ In Development | 🟥 BLOCKED
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

### Problem Statement
An operational autopsy into un-signed commits and throwaway author credentials (`T <t@t>`) pushed to upstream branches revealed four fundamental architectural gaps across the test harness and Git hook wiring:

1. **Hardcoded Test Author Identities**: Test suites (`tests/sync_test.sh`, `install_test.sh`, `pre-commit_test.sh`, `write-guard_test.sh`, `hooks_test.sh`) hardcode throwaway dummy credentials (`git config user.name T; git config user.email t@t`). When snippets are executed during test authoring or unconfined subshells, they contaminate the host repository's `.git/config` and bypass real developer identity.
2. **Missing Sandbox Confinement**: No test harness enforces a fail-closed assertion verifying that `git config` and commit operations run strictly inside `$R` (disposable `mktemp -d` sandbox) and never against the host repository (`$KIT`).
3. **Relative `core.hooksPath` Worktree Blindspot**: The repository configures `core.hooksPath = .githooks`. In Git, relative `hooksPath` is resolved relative to the active worktree's working directory. In linked worktrees (`.plans`, `.agents`), Git looked for `.plans/.githooks` and `.agents/.githooks`. Because neither directory exists, **Git silently executed zero hooks** for any commits made inside `.plans` or `.agents`.
4. **Worktree Top-Level Resolution Failure**: Hook dispatchers (`templates/commit-msg`, `pre-commit`) resolve `REPO_ROOT` via `git rev-parse --show-toplevel`. Inside a linked worktree, this evaluates to the worktree itself (`.plans`), which has no `.githooks/` directory, causing hook execution to silently no-op. Consequently, banned AI co-author lines (`Co-authored-by: Claude...`, `Co-authored-by: Antigravity...`) sailed right into `.plans` without interception.

### Architectural Goal
1. **Dynamic Developer Identity Envelope**: Replace all hardcoded `T <t@t>` fixtures with dynamic inheritance from the developer's real Git environment (`git config --global user.name` / `user.email`), falling back to a clean, professional synthetic CI identity (`AAPP Test Runner <test-runner@aapp.internal>`) in headless CI environments.
2. **Fail-Closed Sandbox Assertion**: Implement `assert_test_sandbox()` in test fixtures, immediately aborting execution if any test helper attempts to run `git config` or `git commit` within the host repository root.
3. **Universal Git Common-Directory Hook Resolution**: Re-architect all hook dispatchers (`commit-msg`, `pre-commit`, `post-commit`) to resolve the canonical hook directory via `git rev-parse --git-common-dir`, ensuring hooks execute reliably across the main working tree and all linked worktrees.
4. **Worktree Hook Wiring in `aapp init`**: Automatically wire or symlink `.githooks` into linked worktrees (`.plans`, `.agents`) so Git natively finds hooks regardless of relative path resolution.

---

## 🏗️ 2. Technical Blueprint

### 🔄 Migration & Compatibility Strategy
- **Compatibility Mode**: `Clean Break` (Default)
- **Fallback Inventory**: `None (Clean Break)`
- All 7 test suites are converted to the shared test helper; all instances of `t@t` are purged from test fixtures.

### 2.1 Dynamic Developer Identity Envelope

A shared test utility `tests/test_helpers.sh` provides standard sandbox configuration:

```bash
setup_test_git_identity() {
    local target_dir="${1:-$(pwd)}"
    
    # 1. Enforce sandbox confinement
    assert_test_sandbox "$target_dir"
    
    # 2. Inherit developer identity or safe CI fallback
    local dev_name dev_email
    dev_name="$(git config --global user.name 2>/dev/null || git config user.name 2>/dev/null || echo "AAPP Test Runner")"
    dev_email="$(git config --global user.email 2>/dev/null || git config user.email 2>/dev/null || echo "test-runner@aapp.internal")"
    
    git -C "$target_dir" config user.name "$dev_name"
    git -C "$target_dir" config user.email "$dev_email"
    git -C "$target_dir" config commit.gpgsign false
    git -C "$target_dir" config tag.gpgsign false
}
```

### 2.2 Host Repository Sandbox Confinement

Every test suite imports and asserts containment before touching Git state:

```bash
assert_test_sandbox() {
    local target="${1:-$(pwd)}"
    local target_abs host_root
    target_abs="$(cd "$target" 2>/dev/null && pwd || echo "$target")"
    host_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"

    if [ "$target_abs" = "$host_root" ] || [ "$(git -C "$target_abs" rev-parse --show-toplevel 2>/dev/null)" = "$host_root" ]; then
        echo "❌ [FATAL Test Sandbox Violation] Attempted Git configuration in host repository root!" >&2
        echo "   Target: $target_abs" >&2
        echo "   Host:   $host_root" >&2
        exit 1
    fi
}
```

### 2.3 Universal Worktree Hook Dispatcher (`--git-common-dir`)

All hook entrypoints (`templates/commit-msg`, `templates/pre-commit`, `templates/post-commit`) are updated to locate the canonical project root through Git's common directory:

```bash
# Resolve primary repository root via git-common-dir (works in main tree & linked worktrees)
COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")"
PRIMARY_ROOT="$(cd "$COMMON_DIR/.." 2>/dev/null && pwd || true)"
HOOK_DIR="$PRIMARY_ROOT/.githooks"

if [ -f "$HOOK_DIR/aapp-commit-msg" ]; then
    bash "$HOOK_DIR/aapp-commit-msg" "$@" || exit 1
fi
```

### 2.4 Worktree Hook Symlink Seeding in `lib/cmd_init.sh`

During `aapp init`, `mount_or_create_worktree()` guarantees hook presence in each created worktree:

```bash
# Seed .githooks symlink into linked worktree
if [ -d "$wt_dir" ] && [ ! -e "$wt_dir/.githooks" ]; then
    ln -sfn ../.githooks "$wt_dir/.githooks" 2>/dev/null || true
fi
```

This closes the relative `core.hooksPath` loop: Git resolves `$wt_dir/.githooks`, which points directly to the version-controlled `.githooks` engine.

---

## 🔨 3. Implementation Steps & Execution Checklist

- [ ] **Phase 1: Shared Test Sandbox Harness (`tests/test_helpers.sh`)**
  - [ ] Implement `assert_test_sandbox()` fail-closed directory verification.
  - [ ] Implement `setup_test_git_identity()` with developer inheritance and CI fallback.
  - [ ] Configure `AAPP_TEST_SANDBOX_STRICT=1` enforcement by default across all test fixtures.
  - [ ] Implement safe `make_sandboxed_kit_clone()` helper.

- [ ] **Phase 2: Purge `T <t@t>` and Confinement Across Test Suites**
  - [ ] Refactor `tests/sync_test.sh` to use `setup_test_git_identity`.
  - [ ] Refactor `tests/install_test.sh` to use `setup_test_git_identity`.
  - [ ] Refactor `tests/pre-commit_test.sh` to use `setup_test_git_identity`.
  - [ ] Refactor `tests/write-guard_test.sh` to use `setup_test_git_identity`.
  - [ ] Refactor `tests/hooks_test.sh` to use `setup_test_git_identity`.
  - [ ] Refactor `tests/plan_resolver_test.sh` to run in `$R` sandbox instead of mutating host `.git/config`.
  - [ ] Refactor `tests/ai_attribution_test.sh` to use `setup_test_git_identity`.

- [ ] **Phase 3: Universal Worktree Hook Dispatchers**
  - [ ] Update `templates/commit-msg` to use `git-common-dir` resolution.
  - [ ] Update `templates/pre-commit` to use `git-common-dir` resolution.
  - [ ] Update `templates/post-commit` to use `git-common-dir` resolution.
  - [ ] Update live `.githooks/commit-msg`, `pre-commit`, and `post-commit` in project.

- [ ] **Phase 4: Worktree Hook Wiring in `lib/cmd_init.sh`**
  - [ ] Add `.githooks` symlink creation in `mount_or_create_worktree()`.
  - [ ] Add test verification for worktree hook execution in `tests/install_test.sh`.

- [ ] **Phase 5: Automated Verification & Regression Suite**
  - [ ] Add regression test in `tests/worktree_hooks_test.sh` verifying that commits in `.plans` and `.agents` trigger `aapp-commit-msg` and block banned `Co-authored-by:` trailers.
  - [ ] Verify complete test suite passes (0 failures across all suites).

---

## 🛡️ 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `tests/test_helpers.sh` -> New shared test harness & sandbox confinement module
- [ ] `tests/sync_test.sh` -> Purge hardcoded t@t, wire sandbox confinement
- [ ] `tests/install_test.sh` -> Purge hardcoded t@t, wire sandbox confinement
- [ ] `tests/pre-commit_test.sh` -> Purge hardcoded t@t, wire sandbox confinement
- [ ] `tests/write-guard_test.sh` -> Purge hardcoded t@t, wire sandbox confinement
- [ ] `tests/hooks_test.sh` -> Purge hardcoded t@t, wire sandbox confinement
- [ ] `tests/plan_resolver_test.sh` -> Purge host repo mutation, isolate in sandbox
- [ ] `tests/ai_attribution_test.sh` -> Adopt shared test identity helper
- [ ] `templates/commit-msg` -> Adopt git-common-dir hook resolution
- [ ] `templates/pre-commit` -> Adopt git-common-dir hook resolution
- [ ] `templates/post-commit` -> Adopt git-common-dir hook resolution
- [ ] `lib/cmd_init.sh` -> Wire worktree .githooks symlinks
- [ ] `MANUAL.md` -> Document test harness sandbox invariants and worktree hook architecture
- [ ] `ARCHITECTURE.md` -> Document worktree hook resolution and sandbox confinement

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `.githooks/*` -> Protected by Pair 5 self-protection rule during plan execution
- [ ] `.agents/skills/*` -> Governance skills self-protection
- [ ] `.plans/ISSUES.md` -> Handled via issue lifecycle
- [ ] `.plans/state_matrix.md` -> Handled via state transitions

---

## ❓ 5. Open Questions & Settled Decisions

1. **GPG Signing in Test Clones**: Should test clones ever attempt GPG signing?
   - **Decision**: **No (Adopted Recommendation)**. All test fixtures explicitly set `commit.gpgsign false` and `tag.gpgsign false` in disposable test sandboxes so test suites execute headlessly and non-interactively across all developer workstations and CI environments without triggering GPG pinentry prompts.
2. **Worktree Symlink vs Direct Relative Traversal**: Should worktrees rely on symlinks (`.plans/.githooks -> ../.githooks`) or hook dispatchers navigating via `--git-common-dir`?
   - **Decision**: **Both in Defense-in-Depth (Adopted Recommendation)**:
     - Symlinks ensure Git's native `core.hooksPath = .githooks` discoverability mechanism succeeds from inside any linked worktree (`.plans`, `.agents`).
     - `git rev-parse --git-common-dir` inside hook entrypoints ensures that once dispatched, sub-hooks (`aapp-commit-msg`, `aapp-pre-commit`) are reliably resolved from the primary project root regardless of execution context.
3. **Test Sandbox Environment Variable**: Should we support `AAPP_TEST_SANDBOX_STRICT=1` to fail CI if any git config write lacks containment?
   - **Decision**: **Yes (Adopted Recommendation)**. Strict sandbox verification is enforced by default in all test suites to immediately fail-closed upon any unconfined Git state mutations targeting the host workspace.

---

## 📦 6. Change Log & Refinement History

* **2026-09-21 (Refinement):** Plan refined and all 3 Open Questions settled per developer direction: confirmed strict GPG disabling in test sandboxes (`gpgsign false`), adopted dual defense-in-depth (`.githooks` symlinks + `--git-common-dir` hook dispatch), and enabled `AAPP_TEST_SANDBOX_STRICT=1` by default. Status updated to `📝 Refining`.
* **2026-09-21:** Drafted initial canonical blueprint P-26. Established dynamic developer identity inheritance, fail-closed test sandbox assertion, `--git-common-dir` universal worktree hook resolution, and worktree `.githooks` symlink wiring.
