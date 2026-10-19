---
title: "Blast Radius Refusal Recovery"
description: "How to diagnose and resolve file write refusals from Layer 1 write-guard and Layer 2 pre-commit hooks."
category: "troubleshooting"
difficulty: "beginner"
tags: [blast-radius, write-guard, pre-commit, refusal, troubleshooting]
---

# 🍳 Recipe: Blast Radius Refusal Recovery

## 🎯 Goal
Diagnose why an edit or commit was refused by AAPP's two-layer Blast Radius engine, break agent refusal loops safely, and expand target boundaries cleanly when necessary.

## 📋 Prerequisites
- A plan in development (`⚡ In Development`) or frozen (`🔷 Frozen`).
- A terminal or AI chat reporting `[Blast Radius Refusal]` or `[Pre-Commit Design Lock Violation]`.

## 🛠️ Step-by-Step Instructions

### 1. Identify the Refusal Layer
Check the error output in your terminal or AI IDE:

| Diagnostic Pattern | Layer | Root Cause |
| :--- | :--- | :--- |
| `❌ [Blast Radius Refusal] Refusing write to <path>` | **Layer 1 (PreToolUse)** | The AI tool attempted to edit a file not listed under `### 📂 Target Files`. |
| `❌ [Pre-Commit Blast Radius Refusal] Staged file outside declared target files` | **Layer 2 (pre-commit)** | Files staged for `git commit` are not declared in the active plan. |
| `❌ [Pre-Commit Design Lock Violation] Cannot edit locked design sections` | **Design Lock** | Modifying Section 2 or Section 4 while status is `🔷 Frozen`. |
| `❌ [Guard Section 2 Refusal] Refusing edit to self-protected infrastructure` | **Infrastructure Protection** | Attempting to edit `.githooks/*` or `.agents/skills/aapp-*`. |

### 2. Determine the Appropriate Action

#### Scenario A: The File Genuinely Belongs to the Implementation
If the file should be modified:
1. Stop the agent immediately.
2. In the plan file (`.plans/current/<plan>.md`), add the file under `### 📂 Target Files`:
   ```markdown
   ### 📂 Target Files (Modifications & Additions)
   - [ ] `src/utils/helpers.ts` -> Added string parsing utility
   ```
   *Note: Only the first backticked path on each line is considered.*
3. Re-run your edit tool or `git add` and retry.

#### Scenario B: The Plan is Frozen (Design Locked)
If you attempted to edit Section 2 (Technical Blueprint) or Section 4 (Blast Radius) while the plan was `🔷 Frozen`:
1. Revert changes to Section 2 and Section 4.
2. If the architecture truly needs changes, unfreeze the plan by changing its status line to `📝 Refining`:
   ```bash
   aapp refine <plan-id> status refining
   ```
3. Update the design, then re-freeze with `aapp freeze <plan-id>`.

#### Scenario C: External Tool Scratchpad / Memory Write Refused
If an AI agent needs to write scratch files outside the repository (e.g. `~/.claude/`, `/tmp/`):
Configure the path authorization key in Git:
```bash
git config aapp.allowPath "$HOME/.custom-scratch"
```

## ⚠️ Critical Invariants & Gotchas
- **Do NOT Bypass with Shell Heredocs**: Never use bash scripts (`cat <<EOF > ...`), `sed -i`, or Python scripts to write files that write-guard refused. Layer 2 (`pre-commit`) will block the commit anyway, and intentional bypasses violate protocol integrity.
- **Section 2 Self-Protection**: Infrastructure files (`.githooks/*`, `.agents/skills/aapp-*`) cannot be added to `### 📂 Target Files`. They are protected to prevent autonomous self-modification.

## 🔗 Related References
- 📖 [Technical Manual: Blast Radius Enforcement](../../../MANUAL.md#layer-1-write-time-pretooluse-guard)
- 🍳 [Recipe: Worktree Collision Recovery](worktree-collision-recovery.md)
- 🍳 [Recipe: Solo Developer Workflow](../getting-started/solo-developer-workflow.md)

## 🧭 Continuous Navigation
- 🍳 [Cookbook Catalog](../../../COOKBOOK.md)
- 📖 [Technical Manual](../../../MANUAL.md)
- 🏠 [Repository Overview](../../../README.md)
