---
title: "Multi-Agent Worktree Concurrency"
description: "How to orchestrate multiple AI agents working simultaneously across isolated Git worktrees without merge collisions."
category: "workflows"
difficulty: "advanced"
tags: [multi-agent, worktrees, concurrency, blast-radius, parallelism]
---

# 🍳 Recipe: Multi-Agent Worktree Concurrency

## 🎯 Goal
Safely orchestrate multiple AI coding agents (or human pair programmers) working on separate plans concurrently in isolated Git worktrees without file write collisions, git index conflicts, or accidental cross-edits.

## 📋 Prerequisites
- A repository initialized with AAPP.
- Two or more blueprints frozen and ready for execution.

## 🛠️ Step-by-Step Instructions

### 1. Perform Blast Radius Conflict Check
Before activating multiple plans simultaneously, verify that their declared target files do not overlap:
```bash
aapp plan conflict-check P-1 P-2
```
AAPP scans `### 📂 Target Files` across both blueprints:
- If files overlap, AAPP warns of potential merge conflicts and recommends sequential execution.
- If disjoint, AAPP greenlights concurrent execution.

To find all plans safe to start right now:
```bash
aapp plan conflict-free
```

### 2. Spawn Independent Worktrees
Activate each plan into its dedicated worktree directory:
```bash
# Agent 1 starts Plan 1
aapp start P-1
# Spawns worktree at .workspace/P1 on branch plan/P1-...

# Agent 2 starts Plan 2
aapp start P-2
# Spawns worktree at .workspace/P2 on branch plan/P2-...
```

### 3. Launch Agents in Their Respective Worktrees
Direct each agent exclusively to its assigned worktree root:
- Agent 1 working directory: `/path/to/repo/.workspace/P1`
- Agent 2 working directory: `/path/to/repo/.workspace/P2`

Each agent operates under:
- Its own active plan buffer (`.git/aapp_active_plan` or worktree-local buffer).
- Its own Layer 1 write-guard enforcing file isolation.
- Its own separate Git index, allowing concurrent builds and test runs.

### 4. Commit and Archive Sequentially or in Parallel
When an agent finishes its checklist:
```bash
# Inside .workspace/P1
aapp commit "feat(auth): add OAuth provider"
aapp done P-1 integrate

# Inside .workspace/P2
aapp commit "feat(ui): update landing page layout"
aapp done P-2 integrate
```

## ⚠️ Critical Invariants & Gotchas
- **No Shared Working Trees**: Never point two active agents to the same worktree directory. Each agent must have its own `.workspace/<slug>` directory.
- **Never Cross-Amend Plans**: An agent in `.workspace/P1` must never edit `.plans/current/P2-*.md`. Plans in development are amended only by the session working them.
- **Circuit Breaker (`aapp pause`)**: If you need to step away or pause all active agents at once, run `aapp pause "lunch break"`. It discovers all active worktrees and quarantines uncommitted changes into SHA-addressed stashes simultaneously.

## 🔗 Related References
- 📖 [Technical Manual: Multi-Worktree Architecture](../../../MANUAL.md#linked-worktree-hook-architecture--universal-dispatching)
- 🍳 [Recipe: Solo Developer Workflow](../getting-started/solo-developer-workflow.md)
- 🍳 [Recipe: Worktree Collision Recovery](../troubleshooting/worktree-collision-recovery.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
