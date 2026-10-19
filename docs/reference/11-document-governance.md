---
title: Three-Tier Document Governance Model
description: Template synchronization, HTML delimiter blocks, divergence handling, and auto-healing in AAPP.
---

# 📜 Three-Tier Document Governance Model

AAPP manages repository files across upgrades, re-initializations, and migrations using a deterministic **Three-Tier Document Governance Model**. This guarantees that project domain data is never erased, user rules are preserved, and engine templates stay updated.

---

## The Three Tiers

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   TIER 1: PURE ENGINE TEMPLATES                        │
│   • .plans/plan-template.md       • .plans/done/000-archive-ledger.md  │
│   • .plans/release/release_       • .githooks/*                        │
│     checklist.md                                                       │
│   Strategy: Refreshed by aapp init. Writes .new buffers if diverged.  │
├────────────────────────────────────────────────────────────────────────┤
│                   TIER 2: HYBRID GOVERNANCE FILES                      │
│   • .agents/AGENTS.md             • .plans/pickup.md                   │
│   Strategy: Managed strictly between HTML delimiter markers. Custom    │
│   user rules and pickup ideas outside markers are 100% preserved.      │
├────────────────────────────────────────────────────────────────────────┤
│                   TIER 3: PURE DOMAIN / PROJECT DATA                   │
│   • .plans/ISSUES.md              • .plans/issues_road_map.md          │
│   • .plans/state_matrix.md        • .agents/CODEMAP.md                 │
│   • .agents/PROJECT.MD            • ARCHITECTURE.md                    │
│   Strategy: Initialized once on setup. NEVER overwritten during sync.  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Tier 1: Pure Engine Templates

These files contain core AAPP runtime machinery, hook executables, and structural templates:
- `.plans/plan-template.md`
- `.plans/release/release_checklist.md`
- `.plans/done/000-archive-ledger.md`
- `.githooks/aapp-pre-commit`, `.githooks/pre-commit`, `.githooks/blast-radius-guard`, `.githooks/aapp-commit-msg`

### Divergence & Update Modes (`aapp.templateSync`)
When `aapp init` updates a project, handling of Tier 1 files depends on `aapp.templateSync`:
- `safe` (default): If customized with delimited blocks, updates strictly between markers. If the template has diverged without delimiters, writes a `.new` file (e.g. `.plans/plan-template.md.new`) rather than overwriting customized templates.
- `strict`: Overwrites diverged Tier 1 files with the latest upstream template.
- `manual`: Preserves existing files completely untouched and reports drift via `aapp status`.

---

## Tier 2: Hybrid Governance Files

Hybrid files contain both standardized protocol rules and user-customized project guidelines:
- `.agents/AGENTS.md` (agent rules and behavioral contracts)
- `.plans/pickup.md` (unstructured brainstorms and incoming ideas)

### Protocol Delimiter Markers
AAPP manages protocol sections strictly between standardized HTML comments:

```markdown
<!-- AAPP-PROTOCOL:START v1.0.0 -->
<!-- DO NOT EDIT THIS BLOCK DIRECTLY - IT IS MANAGED BY AAPP INIT. PLACE CUSTOM RULES OUTSIDE. -->

## 🚦 Code Verification & Changelog Rule
...

<!-- AAPP-PROTOCOL:END -->
```

During `aapp init`:
- Content inside `<!-- AAPP-PROTOCOL:START -->` ... `<!-- AAPP-PROTOCOL:END -->` is replaced with the updated protocol definition.
- Everything outside the markers (custom persona rules, organization-specific linters, brainstormed ideas) is preserved byte-for-byte.

---

## Tier 3: Pure Domain / Project Data

Live database tables, architectural roadmaps, and active ledgers belong exclusively to the project:
- `.plans/ISSUES.md` (active issue ledger)
- `.plans/issues_road_map.md` (work queue)
- `.plans/state_matrix.md` (plan state board)
- `.agents/CODEMAP.md` (repository architecture and ownership map)
- `.agents/PROJECT.MD` (project-specific domain rules)
- `ARCHITECTURE.md` (system constraints)

**Invariant**: `aapp init` and `aapp upgrade` **NEVER** overwrite Tier 3 files. If they already exist, they are preserved untouched.

## 🧭 Continuous Navigation
- 📖 [Technical Manual](../../MANUAL.md)
- 🍳 [Cookbook Catalog](../../COOKBOOK.md)
- 🏠 [Repository Overview](../../README.md)
