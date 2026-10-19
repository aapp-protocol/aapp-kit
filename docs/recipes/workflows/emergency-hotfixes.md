---
title: "Emergency Hotfixes & Issue Worktrees (`aapp issue fix`)"
description: "How to safely repair urgent bugs without disturbing active in-flight feature worktrees using AAPP mini-plans."
category: "workflows"
difficulty: "intermediate"
tags: [hotfix, emergency, issues, mini-plan, worktrees]
---

# 🍳 Recipe: Emergency Hotfixes & Issue Worktrees (`aapp issue fix`)

## 🎯 Goal
Execute an urgent, out-of-band hotfix for a production defect while one or more complex feature plans are in flight, using an isolated temporary mini-plan worktree (`.workspace/fix-<num>`) that guarantees clean isolation and one-commit closure.

## 📋 Prerequisites
- A defect logged in `.plans/ISSUES.md`.
- Issue queued or marked as a blocker in `.plans/issues_road_map.md`.

## 🛠️ Step-by-Step Instructions

### 1. Log or Queue the Urgent Defect
If not already logged, record the issue and prioritize it:
```bash
# Log the issue into the flat ledger
aapp issue log critical BUG "SQL injection vulnerability in search filter" file src/db/search.ts

# Queue as urgent plan blocker
aapp issue queue 42 urgent
```

### 2. Claim the Fix Worktree
Launch the hotfix runner:
```bash
aapp issue fix 42
```
AAPP automatically:
1. Validates that no conflicting fix worktree is currently open.
2. Allocates a temporary, isolated worktree at `.workspace/fix-42`.
3. Creates a confined mini-plan binding target files from the issue's `Location` field.
4. Switches your execution context into `.workspace/fix-42`.

### 3. Implement the Patch
Navigate to the fix worktree and patch the defect:
```bash
cd .workspace/fix-42

# Modify declared target files
# Run test suite
npm test
```

### 4. Commit the Hotfix
Commit using `aapp commit` with a mandatory changelog summary:
```bash
aapp commit "fix(security): sanitize search query parameters (#42)" changelog "Fixed: SQL injection vulnerability in search filter"
```
The helper:
- Writes the changelog entry under `## [Unreleased]`.
- Checks attribution trailers.
- Stages and commits the patch as a clean atomic commit.

### 5. Close and Relocate the Issue
Close the issue and clean up the worktree:
```bash
aapp issue close 42
```
AAPP automatically:
- Moves issue #42 from `.plans/ISSUES.md` into `.plans/done/000-issues-archive.md`.
- Prunes the queued blocker line from `.plans/issues_road_map.md`.
- Unblocks any plans that were waiting on this fix.
- Removes the temporary worktree `.workspace/fix-42`.

## ⚠️ Critical Invariants & Gotchas
- **One Fix at a Time**: To prevent Git worktree and ledger race conditions, only one `aapp issue fix` session may be active at any given moment. If another fix is open, `aapp issue fix` waits up to `aapp.issueFixWait` minutes before timing out.
- **Strict Location Confinement**: The mini-plan inherits target files strictly from the issue's declared `Location` column. If additional files are required, add them using `file <path>` during fix startup.
- **Relocation Invariant**: Resolved issues never stay in active `ISSUES.md`. They are physically relocated to `.plans/done/000-issues-archive.md`.

## 🔗 Related References
- 📖 [Technical Manual: Issue Lane Governance](../../../MANUAL.md#two-lanes-issues-vs-plans-never-merge-them)
- 🍳 [Recipe: Solo Developer Workflow](../getting-started/solo-developer-workflow.md)
- 🍳 [Recipe: Worktree Collision Recovery](../troubleshooting/worktree-collision-recovery.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
