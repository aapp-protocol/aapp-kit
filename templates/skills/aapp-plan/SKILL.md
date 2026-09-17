---
name: aapp-plan
description: Manage active plan execution context (display active boundaries, switch active plan, swap, or clear buffer).
disable-model-invocation: true
argument-hint: "[plan-id | swap | clear]"
---

# AAPP Plan (Active Context Switchboard)

Manage the local worktree active plan buffer (`$(git rev-parse --git-path aapp_active_plan)`). Enables sub-millisecond execution checks and seamless multi-agent context switching.

## Commands

| Action | Command / Usage | Purpose |
| :--- | :--- | :--- |
| **Inspect Context** | `/aapp-plan` (or `aapp plan`) | Display currently designated active plan and its declared boundaries. |
| **Switch Context** | `/aapp-plan <plan-id>` (or `aapp plan <plan-id>`) | Point local worktree execution context to `<plan-id>` (stashing prior in `.prev`). |
| **Swap Context** | `/aapp-plan swap` (or `aapp plan-swap`) | Toggle between current and previously active plan (like `git checkout -`). |
| **Clear Context** | `/aapp-plan clear` (or `aapp plan-clear`) | Clear the local buffer, reverting to auto-discovery mode. |

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
