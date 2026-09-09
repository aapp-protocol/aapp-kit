# 🚀 Release Pre-Flight Runbook & Checklist Template

**Target Version:** `vX.Y.Z`  
**Target Release Date:** `YYYY-MM-DD`  
**Release Manager / Lead:** `[Your Name / Team]`  
**Status:** `DRAFT / IN PROGRESS / GREENLIT / DEPLOYED`

> [!NOTE]
> This is a customizable release runbook template. Tailor the verification steps, tooling commands, and deployment stages to match your project's specific tech stack and deployment architecture.

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
