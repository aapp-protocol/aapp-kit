# 🚀 Release Pre-Flight Runbook & Checklist (AAPP Kit)

**Target Version:** `v1.0.0`  
**Target Release Date:** `2026-09-10`  
**Release Lead:** AAPP Core Team  
**Status:** `PRE-FLIGHT AUDIT`

---

## 🏷️ 0. Versioning & Release Conventions (Stable vs. Edge)

### The 2-Rule Law: Branch & Suffix
1. **The Branch Law:**
   * **`main` = STABLE (Production):** Never commit directly to `main`. `main` only receives verified, fast-forward merges from `develop` during release, and every commit on `main` is an annotated release tag (`vX.Y.Z`). End-user clones and `aapp upgrade` track `main` by default.
   * **`develop` = EDGE (Active Runway):** All daily engineering, bugfixes, test suites, and incubator blueprints land here.
2. **The Version Suffix Law (SemVer):**
   * **STABLE Releases:** Strict SemVer with zero suffix: `v1.0.0`, `v1.0.1`, `v1.1.0`.
   * **EDGE Pre-Releases:** Suffix `-dev` for active development or `-rcX` for release candidates: `1.1.0-dev`, `1.0.0-rc1`.

### SemVer Bump Triggers:
* **PATCH (`1.0.x`):** Bug fixes, security hardening, POSIX portability, test updates, documentation fixes (zero new CLI verbs, zero breaking changes).
* **MINOR (`1.x.0`):** New features & CLI commands that are backward-compatible (e.g. `aapp sync`, `pickup/` store, `.plans/hooks/`).
* **MAJOR (`x.0.0`):** Breaking protocol changes requiring user migration.

---

## 📋 1. Pre-Flight Code Audit & Test Gates (Blocking)

- [ ] **Automated Test Suites (All 84 tests must pass):**
  ```bash
  # 1. Install, develop, upgrade, uninstall & PATH tests (36 tests)
  ./tests/install_test.sh < /dev/null

  # 2. Pre-commit hook & blast radius enforcement tests (18 tests)
  ./tests/pre-commit_test.sh < /dev/null

  # 3. Write-guard PreToolUse interception & schema tests (30 tests)
  ./tests/write-guard_test.sh < /dev/null
  ```
- [ ] **POSIX Shell Syntax Audit:**
  ```bash
  bash -n aapp lib/*.sh templates/blast-radius-guard.sh templates/aapp-pre-commit
  ```
- [ ] **Security & Secret Leak Scan:**
  - Verify zero developer tokens, test keys, or hardcoded paths exist in `aapp`, `lib/`, or `templates/`.
  - Verify `.plans/pickup/` remains air-gapped and excluded from git status.

---

## 📜 2. Documentation & Version Alignment

- [ ] **Version Stamping Consistency:**
  - [ ] `aapp:9`: `AAPP_VERSION="1.0.0"`
  - [ ] `templates/AGENTS.md:12`: `<!-- AAPP-PROTOCOL:START v1.0.0 -->`
  - [ ] `README.md` & `MANUAL.md`: Automated test count reflects 84 passing tests.
- [ ] **Cheat Sheet Review (`CHEATSHEET.md`):**
  - [ ] Every command shown still exists and behaves as described (`aapp help`, the five `/aapp-*` skills, `aapp ai-*` commands).
  - [ ] The four-pillar table, worktree map, and status enum match the shipped engines — not an earlier draft.
  - [ ] Plan/issue ID examples resolve against the real resolver.
  - [ ] Still fits one screen. If it has grown past that, cut rather than reorganize.
  - [ ] No content restated from `README.md`/`MANUAL.md` that could drift independently — link instead.
- [ ] **AI Contributors Roster Review (`README.md`):**
  - [ ] Run `aapp ai-credits` to ensure all commit-mode agent contributors are recorded in the `AI Contributors` block.
  - [ ] Verify alphabetical sorting under `LC_ALL=C` and confirm that aliases (via `aapp.aiAlias`) merge any duplicate agent identities.
  - [ ] Confirm that hand-maintained or review-only contributor entries remain intact.
- [ ] **CHANGELOG.md Rollup:**
  - [ ] Move unreleased changes from `## [Unreleased]` into a tagged release section:
    ```markdown
    ## [1.0.0] - 2026-09-10
    ### Added
    ...
    ### Fixed
    ...
    ```
  - [ ] Leave an empty `## [Unreleased]` template block at the top for subsequent commits.
  - [ ] Mirror changes into `.plans/CHANGELOG.md`.

---

## 🌿 3. Git Parity & Tagging Runbook (Critical)

- [ ] **Branch Parity (`develop` ➔ `main`):**
  *Notice: `aapp upgrade` clones `main` by default. `main` must strictly match `develop` prior to tagging.*
  ```bash
  git checkout main
  git merge --ff-only develop
  ```
- [ ] **Annotated Release Tagging:**
  ```bash
  git tag -a v1.0.0 -m "AAPP v1.0.0: Initial production release of Asymmetric Agent Planning Protocol"
  ```
- [ ] **Upstream Synchronization Across All Branches:**
  ```bash
  # Push application release and tags
  git push origin main --tags
  git push origin develop

  # Push matching orphan metadata worktrees
  git -C .plans push origin plans
  git -C .agents push origin agents
  git -C .githooks push origin githooks
  ```

---

## 🧪 4. Post-Flight Smoke Verification

- [ ] **Clean Global Install Smoke Test:**
  ```bash
  # Test in a temporary sandbox
  TMP_SANDBOX="$(mktemp -d)"
  git clone https://github.com/aapp-protocol/aapp-kit.git "$TMP_SANDBOX/aapp-kit"
  "$TMP_SANDBOX/aapp-kit/aapp" install
  aapp version
  rm -rf "$TMP_SANDBOX"
  ```
- [ ] **Repository Init Smoke Test:**
  ```bash
  TMP_REPO="$(mktemp -d)"
  cd "$TMP_REPO" && git init && git commit --allow-empty -m "init"
  aapp init
  [ -d .plans ] && [ -d .agents ] && [ -d .githooks ] && echo "✅ Smoke test passed"
  cd - && rm -rf "$TMP_REPO"
  ```

---

## 🚨 5. Rollback & Emergency Hotfix Procedure

If a critical flaw is identified immediately post-release:
1. **Remove Tag Upstream (if unannounced):**
   ```bash
   git tag -d v1.0.0
   git push origin :refs/tags/v1.0.0
   ```
2. **If Announced / Distributed:**
   - Do NOT rewrite tag history.
   - Author an immediate hotfix patch on `develop`, increment patch version (`v1.0.1`), fast-forward `main`, and publish `v1.0.1`.
