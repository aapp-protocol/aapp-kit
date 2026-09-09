# 🗺️ Plan: Architectural Layout Refinement & Dual-Location Worktree Flexibility

* **Created:** 2026-09-09 | **Last Refined:** 2026-09-09
* **Target Issue / Milestone:** Layout Optimization & Multi-Location Documentation Flexibility
* **Status:** 🟢 Ready for Execution

---

## 1. Context & Architectural Goal

AAPP organizes project governance, agent behavior, and defect tracking into dedicated domains:
1. **Public Repository Anchors (Project Root):** High-level documentation for developers, contributors, and reviewers (`README.md`, `CHANGELOG.md`, `ARCHITECTURE.md`).
2. **Agent Behavioral & Module Context (`.agents/`):** Agent behavioral contracts (`AGENTS.md`), granular codebase interface registry (`CODEMAP.md`), and high-level milestones (`PROJECT.MD`).
3. **Internal Planning & Issue Lane (`.plans/`):** Canonical defect audit trail (`ISSUES.md`), priority roadmap (`issues_road_map.md`), and implementation blueprints.

**Goal:** Establish clear default locations while building full **dual-location flexibility** into all CLI tools, pre-commit hooks, and write-time guards. Document this architecture thoroughly in `README.md` and `MANUAL.md`.

---

## 2. Technical Blueprint

### 2.1 Worktree Directory & Ownership Mapping

```text
your-project/
├── README.md                    --> Public project overview & quickstart
├── CHANGELOG.md                 --> Public release notes (default root; .plans/ supported)
├── ARCHITECTURE.md              --> Public system design & invariants (default root; .agents/ supported)
├── .plans/                      --> (Worktree on orphan branch 'plans')
│   ├── ISSUES.md                --> Canonical defect audit trail (default in .plans/)
│   ├── issues_road_map.md       --> Priority roadmap
│   ├── state_matrix.md          --> Planning state matrix
│   ├── pickup.md                --> Scratchpad
│   ├── current/*.md             --> Active blueprints
│   ├── done/*.md                --> Archived blueprints
│   ├── release/                 --> Release runbooks
│   └── CHANGELOG.md             --> Optional/decoupled changelog location
├── .agents/                     --> (Worktree on orphan branch 'agents')
│   ├── AGENTS.md                --> Agent behavioral contracts & slash commands
│   ├── CODEMAP.md               --> Canonical module map & interface registry
│   ├── PROJECT.MD               --> High-level milestones
│   └── ARCHITECTURE.md          --> Optional/decoupled architecture location
├── .githooks/                   --> (Worktree on orphan branch 'githooks')
│   ├── pre-commit               --> Master hook runner
│   ├── aapp-pre-commit          --> Commit-time blast radius engine
│   └── blast-radius-guard       --> PreToolUse write-time guard
└── .claude/
    └── settings.json            --> Write-time hook binding
```

### 2.2 Pre-Commit Hook Dual-Location Enforcement (`templates/aapp-pre-commit`)
- **CHANGELOG.md Verification**:
  - Checks if either `CHANGELOG.md` (root) OR `.plans/CHANGELOG.md` has been modified/staged whenever core code is staged.
  - Supports arbitrary changelog styles (version numbers, custom headers, Keep-a-Changelog).
- **Documentation Reminders & Always-Allowed Files**:
  - `ALWAYS_ALLOWED_REGEX` includes `CHANGELOG.md`, `README.md`, `MANUAL.md`, `CODEMAP.md`, `ARCHITECTURE.md`, `ISSUES.md`, and any `.plans/*` / `.agents/*` path.

### 2.3 Write-Time Guard (`templates/blast-radius-guard.sh`)
- All documentation files (`CHANGELOG.md`, `ARCHITECTURE.md`, `CODEMAP.md`, `README.md`, `MANUAL.md`, `ISSUES.md`, and `.plans/*`, `.agents/*`) are unconditionally writable so planning and documentation are never blocked.

### 2.4 Agent Behavioral Rules (`templates/AGENTS.md`)
- Instructs agents to check `.agents/CODEMAP.md` (or root `CODEMAP.md`), `ARCHITECTURE.md` (or `.agents/ARCHITECTURE.md`), and update `CHANGELOG.md` (or `.plans/CHANGELOG.md`) and `.plans/ISSUES.md`.

### 2.5 Init & CLI Command Updates
- **`lib/cmd_init.sh`**:
  - Seeds `ISSUES.md` directly into `.plans/`.
  - Seeds `CODEMAP.md` into `.agents/`.
  - Seeds `CHANGELOG.md` and `ARCHITECTURE.md` into the repo root by default.
  - Interactive mode provides clear location confirmation.
- **`lib/cmd_status.sh`**:
  - Checks `CHANGELOG.md` (or `.plans/CHANGELOG.md`) for `[1/4] SHIPPED`.
  - Checks `.plans/ISSUES.md` (or root `ISSUES.md`) for `[2/4] ISSUES`.
  - Checks `.plans/current/` and `.plans/state_matrix.md` for `[3/4] PLANS`.
  - Checks `.plans/pickup.md` for `[4/4] PICKUP`.

### 2.6 Comprehensive Documentation
- Update `README.md` and `MANUAL.md` with detailed explanations of:
  - The 3-domain structure (Public Root, `.agents/`, `.plans/`).
  - Dual-location resolution rules for hooks and CLI tools.
  - Why `ISSUES.md` lives in `.plans/` and why `ARCHITECTURE.md` / `CHANGELOG.md` live at the root by default.

---

## 💥 3. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [ ] `templates/AGENTS.md` -> Update references to point to `.agents/CODEMAP.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `.plans/ISSUES.md` with dual fallback.
- [ ] `templates/aapp-pre-commit` -> Adjust changelog and doc verification to inspect both root and worktree locations.
- [ ] `templates/blast-radius-guard.sh` -> Align always-allowed rules with dual-location support.
- [ ] `lib/cmd_init.sh` -> Update template seeding targets (CODEMAP to `.agents/`, ISSUES to `.plans/`, CHANGELOG & ARCHITECTURE to root).
- [ ] `lib/cmd_status.sh` -> Support dual-lookup for changelog and issues.
- [ ] `README.md` -> Document architectural layout, domain rationale, and dual-location flexibility.
- [ ] `MANUAL.md` -> Update detailed manual diagrams, configuration options, and fallback behavior.
- [ ] `tests/install_test.sh` -> Update assertion checks for `.agents/CODEMAP.md`, root `ARCHITECTURE.md`, root `CHANGELOG.md`, and `.plans/ISSUES.md`.
- [ ] `tests/pre-commit_test.sh` -> Add test coverage for root and `.plans/` changelog modifications.
- [ ] `tests/write-guard_test.sh` -> Update test anchors.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `LICENSE` -> License file.

---

## ❓ 4. Open Questions & Decision Matrix
* [x] **Question 1:** Public vs. Internal Layout Defaults? -> **Resolved**: Root default for `README.md`, `CHANGELOG.md`, `ARCHITECTURE.md`; `.agents/` for `CODEMAP.md`, `AGENTS.md`, `PROJECT.MD`; `.plans/` for `ISSUES.md`, `issues_road_map.md`, `state_matrix.md`.
* [x] **Question 2:** Dual-Location Tool Support? -> **Resolved**: Fully supported across hooks, guards, and CLI commands.
* [x] **Question 3:** Complete Documentation? -> **Resolved**: Thoroughly documented in `README.md` and `MANUAL.md` during execution.

---

## 📦 5. Change Log & Refinement History
* **2026-09-09:** Initial draft created, refined, and updated with root public document defaults, dual-location flexibility, and comprehensive documentation scope.
