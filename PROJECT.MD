# 🏛️ Project Roadmap & Context: Agent Planning Kit (AAPP)

This file defines the high-level architecture, milestones, subagent personas, and long-term vision for the Asymmetric Agent Planning Protocol (AAPP) repository.

---

## 🎯 Project Overview & Mission

AAPP solves the AI agent coordination and runaway-modification problem by providing:
1. **Isolated Planning Worktrees:** Keeps planning text, design discussions, and issue tracking off active code branches via orphan git worktrees (`plans`, `agents`, `githooks`).
2. **Dual-Layer Blast Radius Enforcement:** Intercepts agent tool writes at write-time (Layer 1) and locks commits at git commit-time (Layer 2).
3. **Single-Active-Plan Architecture:** Per-worktree execution pointer buffers (`$(git rev-parse --git-path aapp_active_plan)`) enabling deterministic, conflict-free multi-agent parallel execution.
4. **Mechanical Planning Health:** 7-pair integrity validation engine preventing blueprint drift, issue corruption, and boundary collisions.

---

## 🗺️ Milestones & Development Phases

### ✅ Phase 1: Core Protocol & Isolation Architecture (v1.0.0 — Shipped)
- Multi-orphan worktree structure (`.plans/`, `.agents/`, `.githooks/`).
- Dual-layer blast radius guard (Layer 1 tool interceptor + Layer 2 commit gate).
- Unified CLI (`aapp init`, `install`, `develop`, `upgrade`, `status`, `uninstall`).
- Keep-a-Changelog enforcement & changelog worktree synchronization.
- Initial test harness across installation, write-guard, and pre-commit.

### 🚀 Phase 2: Multi-Agent Governance & Hardening (Current — v1.1.0 / v1.2.0 Edge)
- [x] **Universal Skills Framework**: Native `.agents/skills/` bridged to `.claude/skills/` exposing shorthand slash commands.
- [x] **Canonical Plan ID Standard (`P-<num>`)**: POSIX shorthand resolver, slug resolution, and transition empty-query guards.
- [x] **Flat Issue Ledger & Relocation Invariant**: Single flat table in `ISSUES.md`, physical relocation of resolved defects to `000-issues-archive.md`.
- [x] **AI Attribution Switchboard (P-14)**: Public emailless semantic trailers (`AI-Agent:`), local git notes Option C staging, append-only credits roster in `README.md`.
- [x] **Frozen Plan Design-Lock Immutability (P-16)**: Commit-time lock on technical blueprints and blast radius while keeping checkboxes and changelogs writable.
- [x] **Single-Active-Plan Architecture & Worktree Isolation (P-17)**: Dissolved cross-plan blocking via worktree buffers and flagless switchboard (`freeze-start`, `start`, `plan`, `plan-swap`, `plan-clear`).
- [x] **Pure-Bash Glob Compiler & Safe Grammar (P-18)**: 3-tier fast path matching and safe character class bracket parsing (`[...]`).
- [x] **Drop-in Target Resolution (#50)**: Physical path comparison resolving enclosing project root.
- [x] **Signature-Gated Self-Consumption & `--keep` Flag (#51)**: Replaced unconstrained `rm -rf` with manifest and git cleanliness audits.
- [ ] **Release Tagging & Upstream Branch Parity (#49, #58)**: Tag official releases, align `main` with `develop`, and stamp version dynamically.
- [ ] **Continuous Integration Workflow (#63)**: GitHub Actions workflow executing the 254-test suite and branch parity gate.
- [ ] **POSIX Portability & Parser Hardening (#59, #60, #69)**: Fallbacks for non-GNU `sort -z`, NUL-safe plan iteration, and regex escaping in `get_next_plan_id`.

### 🔮 Phase 3: Adversarial Review & Autonomous Subagent Attestation
- [ ] **Adversarial Plan Review Plugin**: Freeze-time hook handing blueprints to independent subagents or isolated secondary agents for red-teaming.
- [ ] **Attestation & Provenance Ledger**: Structured review attestations ingested by `aapp ai-credits` to credit non-committing reviewers (§E.9).
- [ ] **Dynamic Worktree Orchestration**: Automated multi-worktree dispatching and teardown for parallel plan execution.

---

## 🤖 Subagent Roles & Personas

When delegating tasks or operating in specialized roles within this repository, agents adopt the following personas:

### 1. 🔍 Context Recovery Agent (`aapp status`)
* **Responsibility:** Desk-return orientation.
* **Behaviors:** Scans all four pillars (Shipped, Issues, Plans, Pickup). Reports exact priority order from `issues_road_map.md` and `state_matrix.md` without re-ranking. Surfaces unworked pickup notes.

### 2. 📐 Blueprint Architect (`aapp digest`)
* **Responsibility:** Plan specification and boundary design.
* **Behaviors:** Converts pickup notes or promoted issues into ADR-style blueprints (`P<N>-<slug>.md`). Enforces explicit Target Files, locks down Out-of-Bounds boundaries, documents unresolved questions in Section 5, and updates `state_matrix.md`.

### 3. 🩺 Planning Health Auditor (`lib/planning_health.sh`)
* **Responsibility:** Structural integrity and invariants verification.
* **Behaviors:** Executes the 7-pair integrity engine. Validates disjointness, referential integrity, commit SHA existence, and boundary collisions between concurrent in-development plans.

### 4. 🛡️ Security & Boundary Gatekeeper (`blast-radius-guard`, `aapp-pre-commit`)
* **Responsibility:** Preventing runaway modifications and unauthorized edits.
* **Behaviors:** Never routes around write refusals. Enforces frozen blueprint design-locks and refuses commits leaving resolved rows in active `ISSUES.md`.

---

## 📚 Documentation Conventions & Locations

For the AAPP Kit repository itself, documentation is organized across canonical locations:
- **User & Operator Manuals**:
  - `README.md` — Project overview, installation, quick-start onboarding, and architecture summary.
  - `MANUAL.md` — Canonical comprehensive technical manual, CLI command catalog, configuration schema, and threat model.
  - `CHEATSHEET.md` — Quick-reference guide for common commands and daily workflows.
- **Architecture & Agent Governance References**:
  - `ARCHITECTURE.md` — Core repository topology, isolation layers, and component diagrams.
  - `.agents/CODEMAP.md` — Callable contracts, module boundaries, function registries, and CLI interfaces.
  - `.agents/PROJECT.MD` — High-level roadmap, milestones, subagent personas, and project conventions.
- **Documentation Style & Update Contract**:
  - Standard GitHub Flavored Markdown with semantic alerts (`[!IMPORTANT]`, `[!NOTE]`, `[!WARNING]`).
  - Strict synchronization invariant: Any implementation altering CLI commands, flags, configuration keys, or developer workflows must update `MANUAL.md` (and `README.md` if introductory).
