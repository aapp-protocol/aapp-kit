# 🏛️ System Architecture Overview

> **Rule for All Agents:** Read this document at the start of every session to align with the core design patterns, structural choices, and technology rules of this project. Do NOT introduce frameworks, libraries, or global state patterns that violate this blueprint.

---

## 🚀 1. Executive Summary & Philosophy
* **Primary Purpose:** [What the application does]
* **Core Pillars:**
  * **Zero Non-Core Dependencies:** Lean build footprint, favoring native runtime APIs over heavy external packages.
  * **High Throughput / Low Overhead:** Performance-first architecture.

---

## ⚙️ 2. Technology Stack & Runtime
* **Core Language Runtime:** [e.g. Perl 5.34+ / Node.js 20+ / Go / Rust / Python]
* **Dependencies:** Core / Standard library only.

---

## 📂 3. Global Structural Mapping
```text
├── src/               # Application source code
├── .plans/             # Isolated planning worktree (mounted on orphan branch)
│   ├── current/       # Active RFC blueprints
│   ├── done/          # Completed blueprints & master ledger (000-archive-ledger.md)
│   ├── pickup.md      # Fast agent scratchpad for active context
│   ├── ISSUES.md      # Canonical defect audit trail & triage ledger
│   ├── issues_road_map.md # Defect priority roadmap & triage queue
│   └── state_matrix.md # State matrix & active incubator brain
├── .agents/            # Agent behavioral contracts & codemap worktree
│   ├── AGENTS.md      # Agent behavioral contracts & protocol rules
│   ├── CODEMAP.md     # Module ownership and interface registry
│   ├── claude/        # Canonical Claude Code configuration (settings.json)
│   └── skills/        # Universal AAPP skills (aapp-*/SKILL.md)
├── .claude/            # Gitignored Claude Code bridge (symlinked to .agents/)
├── .githooks/          # Blast radius enforcement worktree
│   ├── pre-commit     # Master runner (project-owned)
│   └── aapp-pre-commit # Managed blast radius engine
├── CHANGELOG.md       # Public release notes & keep-a-changelog ledger
└── ARCHITECTURE.md    # High-level architecture and invariants
```

---

## 🚦 4. Invariant Architectural Rules
1. **Zero Reinvention:** Always check `CODEMAP.md` before creating helper functions.
2. **State Isolation:** Follow the project's single source of truth pattern for memory and configuration.
3. **Graceful Handling:** Always log structured errors and clean up filehandles/resources.
4. **Documentation Synchronization:** Every implementation introducing new files, interfaces, or architectural contracts must update `ARCHITECTURE.md` and `.agents/CODEMAP.md`.
