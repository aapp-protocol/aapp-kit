# 🚀 Release Pre-Flight Runbook & Checklist Template

**Target Version:** `vX.Y.Z`  
**Target Release Date:** `YYYY-MM-DD`  
**Release Manager / Lead:** `[Your Name / Team]`  
**Status:** `DRAFT / IN PROGRESS / GREENLIT / DEPLOYED`

> [!NOTE]
> This is a customizable release runbook template. Tailor the verification steps, tooling commands, and deployment stages to match your project's specific tech stack and deployment architecture.

---

## 🏷️ 0. Versioning & Release Conventions (Stable vs. Edge)

### The 2-Rule Law: Branch & Suffix
1. **The Branch Law:**
   * **`main` = STABLE (Production):** Never commit directly to `main`. `main` only receives verified, fast-forward merges from `develop` during release, and every commit on `main` is an annotated release tag (`vX.Y.Z`). Production deployments, end-user clones, and upgrades track `main` by default.
   * **`develop` = EDGE (Active Runway):** All daily engineering, bugfixes, test suites, and incubator blueprints land here.
2. **The Version Suffix Law (SemVer):**
   * **STABLE Releases:** Strict SemVer with zero suffix: `v1.0.0`, `v1.0.1`, `v1.1.0`.
   * **EDGE Pre-Releases:** Suffix `-dev` for active development or `-rcX` for release candidates: `1.1.0-dev`, `1.0.0-rc1`.

### SemVer Bump Triggers:
* **PATCH (`1.0.x`):** Bug fixes, security hardening, portability, test updates, documentation fixes (zero new features, zero breaking changes).
* **MINOR (`1.x.0`):** New features & capabilities that remain backward-compatible.
* **MAJOR (`x.0.0`):** Breaking protocol or architecture changes requiring user migration.

---

## 📋 1. Pre-Flight Code Audit & Invariants

- [ ] **Automated Test Suite:**
  ```bash
  # Example test command (adapt to your stack):
  npm test # or pytest / go test ./... / cargo test / phpunit
  ```
- [ ] **Linters & Static Analysis:**
  ```bash
  # Example linter command:
  npm run lint # or flake8 / golangci-lint / cargo clippy / phpstan
  ```
- [ ] **Security & Dependency Audit:**
  ```bash
  # Scan for known CVEs in third-party packages:
  npm audit # or pip-audit / govulncheck / cargo audit
  ```
- [ ] **Debug Artifacts & Leak Scan:**
  - Verify zero hardcoded API keys, test secrets, or temporary debug logs (`console.log`, `print_r`, `var_dump`, `debugger`) exist in staged code.

---

## 📜 2. Documentation & Versioning

- [ ] **CHANGELOG.md:**
  - Move changes from `## [Unreleased]` into a dedicated `## [X.Y.Z] - YYYY-MM-DD` header.
  - Verify all breaking changes, new features, and bug fixes are documented.
- [ ] **Version Bump:**
  - Update version string in package manifest (`package.json`, `Cargo.toml`, `pyproject.toml`, or configuration constants).
- [ ] **Architecture & Codemap Sync:**
  - Verify `CODEMAP.md` and `ARCHITECTURE.md` reflect any newly added modules, endpoints, or interfaces.
- [ ] **AI Contributors Roster Review (`README.md`):**
  - Run `aapp ai-credits` to ensure all commit-mode agent contributors are recorded in the `AI Contributors` block.
  - Verify alphabetical sorting under `LC_ALL=C` and confirm that aliases (via `aapp.aiAlias`) merge any duplicate agent identities.
  - Confirm that hand-maintained or review-only contributor entries remain intact.

---

## 🧪 3. Staging & Smoke Verification

- [ ] **Deploy to Staging Environment:**
  ```bash
  # Deploy build to staging / preview environment
  ```
- [ ] **Smoke Tests & Critical Paths:**
  - [ ] User authentication flow (login, token refresh, logout)
  - [ ] Primary business logic / core transaction path
  - [ ] API endpoint response status & latency checks
- [ ] **Database Migrations:**
  - Run database migrations against a staging replica and measure execution time.

---

## 🚢 4. Production Deployment Runbook

1. **Pre-Deployment Notification:** Notify relevant stakeholders / team.
2. **Database Migrations:** Execute production schema migrations.
3. **Atomic Cutover:** Deploy binary / release build (via atomic symlink, container rollout, or blue-green switch).
4. **Cache & Assets:** Flush application caches and invalidate CDN static assets if applicable.

---

## 🛡️ 5. Post-Deployment Verification & Rollback Plan

### Post-Flight Health Checks:
- [ ] Production health endpoint returns `200 OK`.
- [ ] Inspect production error logs for anomalous 5xx spikes.
- [ ] Verify core user journey in production.

### 🚨 Instant Rollback Procedure:
If a critical blocking bug is discovered immediately following deployment:
1. **Rollback Trigger:** `[Define specific error rate or failure condition that triggers rollback]`
2. **Rollback Command:**
   ```bash
   # Example: Revert symlink to previous release (N-1) or trigger previous container image
   # ln -sfn /path/to/releases/N-1 /path/to/current
   ```
3. **Post-Mortem:** Log the issue in `ISSUES.md` and draft a hotfix blueprint in `.plans/current/`.
