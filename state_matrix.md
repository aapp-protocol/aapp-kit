# 📊 State Matrix (Plan Lane / The Planning Brain)

This document is the central dashboard for all active blueprints, drafts, ready plans, and completed architectures.

---

## 🚦 Recommended Implementation Roadmap

1. 🟢 **P-17**: [`P17-blast-radius-precision-and-isolation.md`](current/P17-blast-radius-precision-and-isolation.md) — Multi-Agent Lifecycle Switchboard & Worktree Isolation (#57)

---

## 🧠 1. Human Thought & Refinement (The Incubator)

- 🔴 **P-10**: [`P10-remote-sync.md`](current/P10-remote-sync.md) — Remote Worktree Synchronization (`aapp push`, `aapp pull`, `aapp sync`) with A/C hybrid configuration model.
- 🔴 **P-11**: [`P11-airgapped-pickup.md`](current/P11-airgapped-pickup.md) — Air-Gapped Reference Store (`.plans/pickup/`) & 5-Layer Leak Protection Architecture.
- 🔴 **P-12**: [`P12-lifecycle-hooks.md`](current/P12-lifecycle-hooks.md) — Lifecycle Plugin Hooks Architecture (`.plans/hooks/`) with POSIX JSON stdio contract.
- 🔴 **P-15**: [`P15-adversarial-review-plugin.md`](current/P15-adversarial-review-plugin.md) — ✏️ **SKETCH — do not refine** — Adversarial Review Packet, Layer 6 Agent Egress Boundary & reference review plugin. Settled ground only; blocked on `#64`, `#57`, `#56`.

---

## 🟢 2. Frozen & Ready for Coding (The Greenlight Zone)

* [ ] **P-17: [Multi-Agent Lifecycle Switchboard & Worktree Isolation](current/P17-blast-radius-precision-and-isolation.md)**
  * *Target Files:* `templates/blast-radius-guard.sh`, `templates/aapp-pre-commit`, `lib/cmd_plan.sh`, `aapp`, `lib/planning_health.sh`, `templates/plan-template.md`, `templates/AGENTS.md`, `templates/skills/aapp-freeze/SKILL.md`, `templates/skills/aapp-start/SKILL.md`, `templates/skills/aapp-freeze-start/SKILL.md`, `templates/skills/aapp-plan/SKILL.md`, `templates/state_matrix.md`, `MANUAL.md`, `CHEATSHEET.md`, `tests/write-guard_test.sh`, `tests/pre-commit_test.sh`, `tests/plan_resolver_test.sh`
  * *Status:* Approved. Blast radius locked. Ready to code.

---

## 🏛️ 3. Archival Ledger (Completed Plans DB)
Completed blueprints are permanently archived in [`done/000-archive-ledger.md`](done/000-archive-ledger.md).
