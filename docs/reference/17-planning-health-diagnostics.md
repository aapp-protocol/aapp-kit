---
title: Planning Health Engine Reference
description: Specification of the 8 invariant check pairs, validation rules, self-protection boundaries, and diagnostic tooling.
---

# 🩺 Planning Health Engine Reference

The Planning Health Engine (`lib/planning_health.sh`) is AAPP's automated static analysis and integrity enforcement system. It continuously validates that plans, issue ledgers, state matrices, and file boundaries remain strictly conformant to protocol invariants.

---

## 1. Architecture & Execution Contexts

The Planning Health Engine runs in two primary contexts:
1. **Interactive Diagnostics (`aapp doctor`)**: Scans the active repository and reports warnings, failures, and corrective actions.
2. **Automated Commit & Freeze Gates (`.githooks/pre-commit`, `aapp freeze`)**: Enforces critical protocol rules mechanically, refusing invalid operations before commits can be written.

---

## 2. The 8 Invariant Check Pairs

The engine organizes rules into 8 check pairs, each evaluating one architectural invariant:

| Pair ID | Invariant Scope | Diagnostic Purpose | Failure Prevention |
| :--- | :--- | :--- | :--- |
| **Pair 1** | **Issue Ledger Integrity** | Validates flat table structure, unique IDs (`#<num>`), date formats, and column headers in `ISSUES.md`. | Blocks malformed rows, duplicate issue IDs, or resolved rows lingering in active ledger. |
| **Pair 2** | **State Matrix Invariants** | Verifies `state_matrix.md` row structure, milestone groupings, and canonical status badges. | Blocks invalid status badges or unlisted blueprints. |
| **Pair 3** | **Plan File Naming & Headers** | Enforces ADR naming (`P<num>-<slug>.md`) and mandatory metadata header fields. | Catches missing headers (`Status:`, `Changelog:`, `Target Files:`) or mismatched IDs. |
| **Pair 4** | **Blast Radius Definition** | Ensures `### 📂 Target Files` entries are valid repository-relative paths and uniquely formatted. | Prevents vague file lists, wildcard globbing, or absolute paths in targets. |
| **Pair 5** | **Self-Protection Boundaries** | Enforces blast radius exclusion of harness infrastructure (`.githooks/*`, `.agents/skills/*`, `.claude/*`, `.cursor/*`). | Prevents autonomous agents from modifying verification engines or rulesets during normal plan execution. |
| **Pair 6** | **Open Questions Gate** | Validates that all questions in `## 5. Open Questions` are marked answered before plan freeze. | Prevents execution of ambiguous or under-specified blueprints. |
| **Pair 7** | **TDD Test Declarations** | Verifies that failure-first test identifiers in §3 match test files declared in §4. | Prevents freezing without explicit verification plans. |
| **Pair 8** | **Archive & Overflow Integrity** | Validates archival ledgers (`.plans/done/000-issues-archive.md`, overflow ledgers, release tags). | Ensures historical records remain readable, unbroken, and accurately cross-referenced. |

---

## 3. Self-Protection Invariant (Pair 5)

AAPP protects its own governance mechanics against unilateral modification by AI agents. Under Pair 5:
- No active implementation plan may declare files in `.githooks/`, `.agents/skills/`, `.claude/`, or `.cursor/` in its `### 📂 Target Files`.
- Modifications to core protocol engines require explicit protocol upgrade workflows, human review, and specialized lifecycle commits (`rules(agents):` or `feat(hooks):`).

---

## 4. Diagnostic & Repair CLI Commands

```bash
# Run comprehensive repository health check
aapp doctor

# Validate planning ledgers without executing repairs
aapp doctor --check

# Format and realign issue ledger tables
aapp refine issues --format

# Re-sort and synchronize state matrix
aapp refine state --sync
```

---

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- ⚙️ [Configuration Options](16-configuration-options.md)
- 💻 [CLI Verb Reference](02-cli-commands-and-verbs.md)
- 🏠 [Repository Overview](../../README.md)
