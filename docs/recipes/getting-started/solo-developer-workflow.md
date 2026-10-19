---
title: "Solo Developer Workflow"
description: "A fast, streamlined cycle for human solo developers leveraging AAPP with or without AI agents."
category: "getting-started"
difficulty: "beginner"
tags: [workflow, solo, quickstart, lifecycle]
---

# 🍳 Recipe: Solo Developer Workflow

## 🎯 Goal
Master the end-to-end plan lifecycle as a solo developer: capture ideas rapidly, specify blast-radius boundaries, execute cleanly in isolated worktrees, and archive finished work with zero Git clutter.

## 📋 Prerequisites
- A repository initialized with `aapp init`.
- The `aapp` CLI available on `$PATH`.

## 🛠️ Step-by-Step Instructions

### 1. Ingest an Idea or Bug
When an idea or bug surfaces, record it instantly without interrupting your current focus:
```bash
# Log a defect into the flat issue ledger (ISSUES.md)
aapp issue log normal BUG "Authentication fails on empty password string" file src/auth/login.ts

# Or append a quick idea to pickup.md
aapp refine pickup "OAuth2: add GitHub provider support"
```

### 2. Draft an Execution Blueprint
When you are ready to implement, scaffold a durable plan in `.plans/current/`:
```bash
# Scaffold a new feature plan
aapp draft oauth-github

# Or promote an existing issue into a plan
aapp draft fix-empty-password issue 1
```

### 3. Refine the Scope & Boundaries
Open `.plans/current/P<N>-<slug>.md` and define:
1. **Target Files**: Enumerate the exact files this plan will modify.
2. **Implementation Checklist**: List discrete verifiable steps.
3. **Open Questions**: Resolve architectural unknowns.

```markdown
### 📂 Target Files (Modifications & Additions)
- [ ] `src/auth/login.ts` -> Handle empty password boundary
- [ ] `tests/auth_test.ts` -> Regression test for empty credentials
```

### 4. Lock & Activate the Plan
Lock the design and spin up a dedicated execution worktree:
```bash
# Freeze the blueprint to lock Section 2 & 4
aapp freeze P-1

# Activate into an isolated worktree (.workspace/P1)
aapp start P-1
```

### 5. Implement & Commit
Switch to the newly allocated worktree and implement the solution:
```bash
cd .workspace/P1

# Edit files declared in Target Files
# Run your tests
npm test

# Commit using the plan-bound commit helper
aapp commit "fix(auth): handle empty password strings safely (#1)"
```

### 6. Verify & Archive
Once all tests pass and the checklist is complete, archive the plan:
```bash
# Archives plan to .plans/done/, updates ledgers, and integrates branch
aapp done P-1 integrate
```

## ⚠️ Critical Invariants & Gotchas
- **Stay in Bounds**: Write-guard will reject file edits outside your declared `Target Files`. If you realize another file is needed, stop and add it to `### 📂 Target Files` before writing.
- **Plan-Bound Helper**: Always use `aapp commit` rather than raw `git commit` to ensure commit SHAs are recorded in the plan header and changelog entries are rolled up automatically.
- **One Active Plan per Worktree**: Keep each plan confined to its designated `.workspace/<slug>` directory to prevent merge collisions.

## 🔗 Related References
- 📖 [Technical Manual: The Plan-Bound Commit Helper](../../../MANUAL.md#aapp-commit--plan-bound-commit-helper)
- 🍳 [Recipe: Adopting an Existing Repository](adopt-existing-repo.md)
- 🍳 [Recipe: TDD Failure Assertions](../workflows/tdd-failure-assertions.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
