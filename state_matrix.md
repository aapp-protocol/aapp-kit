# 📊 State Matrix (Plan Lane / The Planning Brain)

This document is the central dashboard for all active blueprints, drafts, ready plans, and completed architectures.

---

## 🚦 Recommended Implementation Roadmap

*(All active blueprints currently implemented & verified)*

---

## 🧠 1. Human Thought & Refinement (The Incubator)

- 🔴 **P-9**: [`P9-guard-path-authorization.md`](current/P9-guard-path-authorization.md) — Guard Path Authorization: external agent-path allowlist (`aapp.allowPath`), lexical canonicalization, and `MultiEdit` matcher coverage (`#65`, matcher half of `#53`).
- 🔴 **P-10**: [`P10-remote-sync.md`](current/P10-remote-sync.md) — Remote Worktree Synchronization (`aapp push`, `aapp pull`, `aapp sync`) with A/C hybrid configuration model.
- 🔴 **P-11**: [`P11-airgapped-pickup.md`](current/P11-airgapped-pickup.md) — Air-Gapped Reference Store (`.plans/pickup/`) & 5-Layer Leak Protection Architecture.
- 🔴 **P-12**: [`P12-lifecycle-hooks.md`](current/P12-lifecycle-hooks.md) — Lifecycle Plugin Hooks Architecture (`.plans/hooks/`) with POSIX JSON stdio contract.

---

## 🟢 2. Frozen & Ready for Coding (The Greenlight Zone)

- 🟢 **P-13**: [`P13-plan-ids-and-shorthand-resolution.md`](current/P13-plan-ids-and-shorthand-resolution.md) — Plan IDs, ADR-Style Filenames & Command Shorthand Resolution (`P-13`): Canonical unpadded `P-<num>` namespace, ergonomic shorthand for `/aapp-freeze` and `/aapp-done`, archive ledger ID field, and health integrity engine (Pairs 4 & 5).

---

## 🏛️ 3. Archival Ledger (Completed Plans DB)
Completed blueprints are permanently archived in [`done/000-archive-ledger.md`](done/000-archive-ledger.md).
