# 📊 State Matrix (Plan Lane / The Planning Brain)

This document is the central dashboard for all active blueprints, drafts, ready plans, and completed architectures.

---

## 🚦 Recommended Implementation Roadmap

*(All active blueprints currently implemented & verified)*

---

## 🧠 1. Human Thought & Refinement (The Incubator)

- 🔴 [`plan-feature-aapp-guard-path-authorization.md`](current/plan-feature-aapp-guard-path-authorization.md) — Guard Path Authorization: external agent-path allowlist (`aapp.allowPath`), lexical canonicalization, and `MultiEdit` matcher coverage (`#65`, matcher half of `#53`).
- 🔴 [`plan-feature-aapp-remote-sync.md`](current/plan-feature-aapp-remote-sync.md) — Remote Worktree Synchronization (`aapp push`, `aapp pull`, `aapp sync`) with A/C hybrid configuration model.
- 🔴 [`plan-feature-aapp-airgapped-pickup.md`](current/plan-feature-aapp-airgapped-pickup.md) — Air-Gapped Reference Store (`.plans/pickup/`) & 5-Layer Leak Protection Architecture.
- 🔴 [`plan-feature-aapp-lifecycle-hooks.md`](current/plan-feature-aapp-lifecycle-hooks.md) — Lifecycle Plugin Hooks Architecture (`.plans/hooks/`) with POSIX JSON stdio contract.

---

## 🟢 2. Frozen & Ready for Coding (The Greenlight Zone)

- 🟢 [`plan-feature-aapp-plan-ids-and-shorthand-resolution.md`](current/plan-feature-aapp-plan-ids-and-shorthand-resolution.md) — Plan IDs, ADR-Style Filenames & Command Shorthand Resolution (`P-13`): Canonical unpadded `P-<num>` namespace, ergonomic shorthand for `/aapp-freeze` and `/aapp-done`, archive ledger ID field, and health integrity engine (Pairs 4 & 5).

---

## 🏛️ 3. Archival Ledger (Completed Plans DB)
Completed blueprints are permanently archived in [`done/000-archive-ledger.md`](done/000-archive-ledger.md).
