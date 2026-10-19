---
title: "Worktree Collision & Conflict Recovery"
description: "How to repair corrupted worktrees, resolve planning branch merge conflicts, and clean stale checkouts."
category: "troubleshooting"
difficulty: "intermediate"
tags: [worktrees, git, conflicts, troubleshooting, collision]
---

# 🍳 Recipe: Worktree Collision & Conflict Recovery

## 🎯 Goal
Safely repair stale or conflicting Git worktrees, clear branch locks after an interrupted session, and resolve merge conflicts in isolated planning branches (`plans`, `agents`) without endangering primary application code.

## 📋 Prerequisites
- A Git repository using AAPP worktrees (`.plans/`, `.agents/`, `.workspace/*`).
- Git 2.30+ installed.

## 🛠️ Step-by-Step Instructions

### 1. Prune Stale Worktree Registrations
If a worktree folder was deleted manually from disk, Git's internal index may still consider the branch checked out:
```bash
# Check registered worktrees and their paths
git worktree list

# Prune administrative records for deleted worktrees
git worktree prune
```

### 2. Handle Worktree Directory Collisions
If `aapp start <plan>` complains that a worktree directory already exists:
1. Inspect the directory:
   ```bash
   cd .workspace/<plan-slug>
   git status
   ```
2. If the worktree contains in-flight uncommitted work you want to save, commit or pause it:
   ```bash
   aapp commit "wip: progress before reset"
   ```
3. If the worktree is orphaned or safe to discard:
   ```bash
   git worktree remove --force .workspace/<plan-slug>
   ```

### 3. Resolve Merge Conflicts in `.plans/` or `.agents/`
Because `.plans` and `.agents` run on orphan branches (`plans` and `agents`), merge conflicts in them never touch your main application branch:
```bash
# Navigate to the planning worktree
cd .plans

# Pull remote changes
git pull origin plans

# If conflicts occur (e.g. in state_matrix.md or pickup.md):
# 1. Edit the file to resolve conflict markers (<<<<<<< / >>>>>>>)
# 2. Stage the resolution:
git add -A
git commit -m "chore: resolve planning merge conflicts"
git push origin plans
```
Return to your root directory:
```bash
cd ..
aapp status
```

### 4. Abandon an Unwanted Plan Safely
If a plan should be cancelled completely rather than archived:
```bash
aapp plan abort P-99 reason "Architectural pivot superseded this approach"
```
AAPP automatically:
- Moves the blueprint to `.plans/aborted/`.
- Deletes the associated worktree and branch.
- Restores the issue (if promoted from one) back to active status.

## ⚠️ Critical Invariants & Gotchas
- **Never Force Delete Active Checkouts**: Do not run `rm -rf .workspace/<slug>` without running `git worktree remove`. Git retains lockfiles in `.git/worktrees/` that block the branch from being checked out elsewhere.
- **Fail-Closed Integration**: If `aapp done <plan> integrate` encounters a merge conflict on the target branch, it halts without completing integration, leaving your branch and worktree intact so you can rebase or resolve conflicts manually.

## 🔗 Related References
- 📖 [Technical Manual: Worktree Isolation Architecture](../../../MANUAL.md#worktree-isolation-architecture)
- 🍳 [Recipe: Multi-Agent Worktrees](../workflows/multi-agent-worktrees.md)
- 🍳 [Recipe: Emergency Hotfixes](../workflows/emergency-hotfixes.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
