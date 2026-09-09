# 🗺️ Plan: Decouple Root Anchors and Move Changelog/Issues/Codemap into Worktrees

* **Created:** 2026-09-09 | **Last Refined:** 2026-09-09
* **Target Issue / Milestone:** Architectural Optimization (Zero Root Markdown Footprint)
* **Status:** 🔴 Under Review

---

## 1. Context & Architectural Goal

Currently, AAPP seeds 4 markdown files at the project root of the active code branch:
1. `CHANGELOG.md`
2. `ISSUES.md`
3. `CODEMAP.md`
4. `ARCHITECTURE.md`

**Goal:** Achieve a **100% pure source code root** by moving all architectural documentation, defect logs, and changelogs into the isolated Git worktrees (`.plans/` and `.agents/`), while updating agent behavioral rules (`AGENTS.md`), pre-commit hooks, and CLI commands to reference these new locations.

---

## 2. Technical Blueprint

### 2.1 Worktree Directory & Ownership Mapping

```text
your-project/ (Pure application source code — zero markdown clutter at root)
├── .plans/                      --> (Worktree on orphan branch 'plans')
│   ├── CHANGELOG.md             --> Canonical changelog (updated on code commits)
│   ├── ISSUES.md                --> Canonical defect audit trail
│   ├── issues_road_map.md       --> Priority roadmap
│   ├── state_matrix.md          --> Planning state matrix
│   ├── pickup.md                --> Scratchpad
│   ├── current/*.md             --> Active blueprints
│   ├── done/*.md                --> Archived blueprints
│   └── release/                 --> Release runbooks
├── .agents/                     --> (Worktree on orphan branch 'agents')
│   ├── AGENTS.md                --> Agent behavioral contracts & slash commands
│   ├── PROJECT.MD               --> High-level milestones
│   ├── CODEMAP.md               --> Module ownership & interface registry
│   └── ARCHITECTURE.md          --> Invariant architecture & technology rules
├── .githooks/                   --> (Worktree on orphan branch 'githooks')
│   ├── pre-commit               --> Master hook runner
│   ├── aapp-pre-commit          --> Commit-time blast radius engine
│   └── blast-radius-guard       --> PreToolUse write-time guard
└── .claude/
    └── settings.json            --> Write-time hook binding
```

### 2.2 Pre-Commit Hook Enforcement (`templates/aapp-pre-commit`)
- Update Section 1 (`CHANGELOG.md` Enforcement):
  - When core code changes, verify that `.plans/CHANGELOG.md` has been modified/updated (or allow updating `.plans/CHANGELOG.md` across worktrees).
  - Note: In Git, `.plans/` is in `.gitignore` on the code branch (it's a mounted worktree on orphan branch `plans`).
  - Therefore, the hook checks if `.plans/CHANGELOG.md` exists and contains recent unreleased entries, or commits to `.plans` directly.
- Update `ALWAYS_ALLOWED_REGEX` and documentation reminder to reference `.agents/` and `.plans/`.

### 2.3 Write-Time Guard (`templates/blast-radius-guard.sh`)
- Confirm that `.plans/*` and `.agents/*` remain unconditionally writable for agents so planning and agent rules can always be updated.

### 2.4 Agent Behavioral Rules (`templates/AGENTS.md`)
- Update header to instruct agents:
  - Check `.agents/CODEMAP.md` and `.agents/ARCHITECTURE.md` before writing code.
  - Update `.plans/CHANGELOG.md` for changelog tracking.
  - Log bugs in `.plans/ISSUES.md` and `.plans/issues_road_map.md`.

### 2.5 Init & CLI Command Updates
- **`lib/cmd_init.sh`**:
  - Phase 1: Seeds `CHANGELOG.md` and `ISSUES.md` directly into `.plans/`.
  - Phase 2: Seeds `CODEMAP.md` and `ARCHITECTURE.md` into `.agents/`.
  - Phase 4: Project root anchor seeding is removed.
- **`lib/cmd_status.sh`**:
  - Checks `.plans/CHANGELOG.md` for `[1/4] SHIPPED`.
  - Checks `.plans/ISSUES.md` and `.plans/issues_road_map.md` for `[2/4] ISSUES`.
  - Checks `.plans/current/` and `.plans/state_matrix.md` for `[3/4] PLANS`.
  - Checks `.plans/pickup.md` for `[4/4] PICKUP`.

---

## 💥 3. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/AGENTS.md` -> Update references to point to `.agents/CODEMAP.md`, `.agents/ARCHITECTURE.md`, `.plans/CHANGELOG.md`, `.plans/ISSUES.md`.
- [ ] `templates/aapp-pre-commit` -> Adjust changelog verification to inspect `.plans/CHANGELOG.md`.
- [ ] `templates/blast-radius-guard.sh` -> Align always-allowed rules.
- [ ] `lib/cmd_init.sh` -> Move template copy targets from project root to `.plans/` and `.agents/`.
- [ ] `lib/cmd_status.sh` -> Update status parser paths for `.plans/CHANGELOG.md` and `.plans/ISSUES.md`.
- [ ] `README.md` -> Update architectural diagrams, directory trees, and references.
- [ ] `MANUAL.md` -> Update manual architecture diagrams and ownership tables.
- [ ] `tests/install_test.sh` -> Update assertion checks for `.agents/CODEMAP.md` and `.plans/CHANGELOG.md`.
- [ ] `tests/pre-commit_test.sh` -> Update test fixtures to use `.plans/CHANGELOG.md`.
- [ ] `tests/write-guard_test.sh` -> Update test anchors.
- [ ] `DELETE` -> `CODEMAP.md` -> Removed from repo root.
- [ ] `DELETE` -> `ARCHITECTURE.md` -> Removed from repo root.
- [ ] `DELETE` -> `CHANGELOG.md` -> Removed from repo root (maintained in `.plans/CHANGELOG.md`).

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `LICENSE` -> License file.

---

## ❓ 4. Open Questions & Decision Matrix
* [ ] **Question 1:** In pre-commit enforcement, since `.plans/` is on an orphan branch (ignored by git on `develop`), should `aapp-pre-commit` check that `.plans/CHANGELOG.md` has uncommitted modifications, or verify a commit timestamp / recent unreleased entry?
* [ ] **Question 2:** Should we offer an optional fallback where if a project *does* place `CHANGELOG.md` at root, the hook checks root first, and falls back to `.plans/CHANGELOG.md`?

---

## 📦 5. Change Log & Refinement History
* **2026-09-09:** Initial draft created.
