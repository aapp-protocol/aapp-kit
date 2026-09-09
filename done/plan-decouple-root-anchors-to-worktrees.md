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

## 🔨 3. Implementation Steps & Execution Checklist
*Mark tasks completed (`[x]`) as you progress so any interrupted or resumed session knows exactly where to pick up.*

### Phase 1: Core Templates & Agent Rules
- [x] 1.1 Update `templates/AGENTS.md` and `.agents/AGENTS.md` to reference `.agents/CODEMAP.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `.plans/ISSUES.md` with dual fallback.
- [x] 1.2 Update `templates/aapp-pre-commit` and `.githooks/aapp-pre-commit` to support dual-location CHANGELOG modification checks and updated doc reminders.
- [x] 1.3 Update `templates/blast-radius-guard.sh` and `.githooks/blast-radius-guard` always-allowed lists.

### Phase 2: CLI Commands & Initialization
- [x] 2.1 Update `lib/cmd_init.sh` to seed `CODEMAP.md` into `.agents/`, `ISSUES.md` into `.plans/`, and `CHANGELOG.md` & `ARCHITECTURE.md` to root by default (with interactive prompt support).
- [x] 2.2 Update `lib/cmd_status.sh` with dual-location parsing for `CHANGELOG.md` and `ISSUES.md`.

### Phase 3: Documentation & Manual Invariants
- [x] 3.1 Update `README.md` architectural overview, directory structure, and workflow guides.
- [x] 3.2 Update `MANUAL.md` with detailed 3-domain architecture diagrams, configuration options, and fallback rules.

### Phase 4: Test Suite Verification & Execution
- [x] 4.1 Update `tests/install_test.sh` to assert new seeding locations and verify `aapp init`.
- [x] 4.2 Update `tests/pre-commit_test.sh` to verify dual-location changelog modification checks.
- [x] 4.3 Update `tests/write-guard_test.sh` and run full test suite.
- [x] 4.4 Verify all tests pass cleanly.

---

## 💥 4. Blast Radius & System Boundaries

### 📂 Target Files (Modifications & Additions)
- [x] `templates/AGENTS.md` -> Update references to point to `.agents/CODEMAP.md`, `ARCHITECTURE.md`, `CHANGELOG.md`, `.plans/ISSUES.md` with dual fallback.
- [x] `templates/aapp-pre-commit` -> Adjust changelog and doc verification to inspect both root and worktree locations.
- [x] `templates/blast-radius-guard.sh` -> Align always-allowed rules with dual-location support.
- [x] `lib/cmd_init.sh` -> Update template seeding targets (CODEMAP to `.agents/`, ISSUES to `.plans/`, CHANGELOG & ARCHITECTURE to root).
- [x] `lib/cmd_status.sh` -> Support dual-lookup for changelog and issues.
- [x] `README.md` -> Document architectural layout, domain rationale, and dual-location flexibility.
- [x] `MANUAL.md` -> Update detailed manual diagrams, configuration options, and fallback behavior.
- [x] `tests/install_test.sh` -> Update assertion checks for `.agents/CODEMAP.md`, root `ARCHITECTURE.md`, root `CHANGELOG.md`, and `.plans/ISSUES.md`.
- [x] `tests/pre-commit_test.sh` -> Add test coverage for root and `.plans/` changelog modifications.
- [x] `tests/write-guard_test.sh` -> Update test anchors.

### 🛑 Out of Bounds (Do Not Touch)
- [ ] `LICENSE` -> License file.

---

## ❓ 5. Open Questions & Decision Matrix
* [x] **Question 1:** Public vs. Internal Layout Defaults? -> **Resolved**: Root default for `README.md`, `CHANGELOG.md`, `ARCHITECTURE.md`; `.agents/` for `CODEMAP.md`, `AGENTS.md`, `PROJECT.MD`; `.plans/` for `ISSUES.md`, `issues_road_map.md`, `state_matrix.md`.
* [x] **Question 2:** Dual-Location Tool Support? -> **Resolved**: Fully supported across hooks, guards, and CLI commands.
* [x] **Question 3:** Complete Documentation? -> **Resolved**: Thoroughly documented in `README.md` and `MANUAL.md` during execution.

---

## 📦 6. Change Log & Refinement History
* **2026-09-09:** Initial draft created, refined, and updated with root public document defaults, dual-location flexibility, and comprehensive documentation scope. Added structured phase-based execution checklist.
