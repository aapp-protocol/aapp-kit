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
│   ├── current/       # Active drafts, pickup scratchpad, state matrix
│   ├── done/          # Permanent archive of completed blueprints
│   └── aborted/       # Discarded concepts
├── CODEMAP.md         # Module ownership and interface registry
└── ARCHITECTURE.md    # High-level architecture and invariants
```

---

## 🚦 4. Invariant Architectural Rules
1. **Zero Reinvention:** Always check `CODEMAP.md` before creating helper functions.
2. **State Isolation:** Follow the project's single source of truth pattern for memory and configuration.
3. **Graceful Handling:** Always log structured errors and clean up filehandles/resources.
