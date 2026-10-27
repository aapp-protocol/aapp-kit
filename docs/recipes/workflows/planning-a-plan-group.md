---
title: "Planning a Plan Group"
description: "How to decompose large architectural initiatives into aligned, sequential or parallel plan groups."
category: "workflows"
difficulty: "advanced"
tags: [plan-groups, architecture, planning, decomposition, alignment]
---

# 🍳 Recipe: Planning a Plan Group

## 🎯 Goal
Decompose a large, multi-faceted architectural refactor or epic into a cohesive **Plan Group**: growing related blueprints organically, aligning shared decisions across members, ordering execution waves, and catching interface drift before code touches disk.

## 📋 Prerequisites
- A complex architectural feature or refactor spanning multiple domains or sessions.
- An initialized AAPP repository.

## 🛠️ Step-by-Step Instructions

### 1. Start from One Seed Plan
Begin with a single blueprint for the core initiative:
```bash
aapp draft epic-architecture
```
As you refine the technical blueprint in Section 2, watch for natural fault lines:
- A change that touches two completely different subsystems.
- A foundation (e.g. schema migration or protocol spec) that must freeze before consumer code can be written.
- A task that is too large for a single focused session.

### 2. Split When a Gap Appears
Rather than letting a blueprint swell beyond readable bounds, split out a sibling plan:
```bash
# Sibling 1: Foundational protocol / data structures
aapp draft epic-part-1-protocol

# Sibling 2: CLI integration & daily verbs
aapp draft epic-part-2-cli

# Sibling 3: Documentation & recipes
aapp draft epic-part-3-docs
```

### 3. Establish the Group Blueprint
Create a master group coordinator plan or section:
1. **Shared Decisions**: Document common conventions (naming standards, error types, exit codes) in one place.
2. **Order with Reasons**: Explicitly define execution order and dependencies:
   ```markdown
   ### 🌊 Execution Waves
   - **Wave 1**: `P-72A` (Core Protocol & Types) -> Must land first to establish types.
   - **Wave 2**: `P-72B` (CLI & Verbs) & `P-72C` (Engine Hooks) -> Can execute in parallel.
   - **Wave 3**: `P-72D` (Documentation & Guides) -> Verifies working shipped system.
   ```
3. **End-State Architecture**: Describe the holistic state of the repository once all members complete.

### 4. Carry Decisions to Every Member at Once
When an architectural decision evolves during review:
- Update the master group blueprint immediately.
- Refine each member plan (`aapp refine <id> ...`) to align target files and interfaces before freezing.
- Never allow one member plan to proceed on outdated assumptions.

### 5. Run Verification Checks
Catch mistakes before freezing or starting:
```bash
# 1. Verify target files do not collide unexpectedly
aapp plan conflict-check P-72A P-72B

# 2. Check which group plans are free to start
aapp plan conflict-free P-72
```

### 6. When Is Planning Done?
Planning for the group is done when:
- Every member plan has `Status: 🔷 Frozen`.
- Every member has resolved all Open Questions.
- Blast radius target files are disjoint or strictly ordered by wave.
- `aapp matrix --check` exits with 0.

## ⚠️ Critical Invariants & Gotchas
- **Never Cross-Amend in Development**: Once Wave 1 starts (`⚡ In Development`), never edit its blueprint from another session's worktree. Amend it only from within its own checkout. A file or correction outside a started member goes through the group's amendments member: see [Group Amendments](../../reference/16-group-amendments.md).
- **Clean Breaks Over Shims**: If a plan group migrates an API, enforce clean breaks across all member plans. Do not introduce temporary compatibility wrappers between group phases unless explicitly justified in Section 2.

## 🔗 Related References
- 📖 [Technical Manual: Plan Lifecycle Governance](../../../MANUAL.md#plan-lane-governance)
- 🍳 [Recipe: Multi-Agent Worktrees](multi-agent-worktrees.md)
- 🍳 [Recipe: TDD Failure Assertions](tdd-failure-assertions.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
