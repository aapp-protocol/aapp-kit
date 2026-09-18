---
name: aapp-active
description: Manage active plan execution buffer (display active boundaries, designate active plan, swap, or clear buffer).
disable-model-invocation: true
argument-hint: "[plan-id | swap | clear]"
---

# AAPP Active (Execution Buffer Switchboard)

Manage the local worktree active plan buffer (`$(git rev-parse --git-path aapp_active_plan)`). Enables sub-millisecond execution checks and seamless multi-agent context switching.

## Commands

| Action | Command / Usage | Purpose |
| :--- | :--- | :--- |
| **Inspect Buffer** | `/aapp-active` (or `aapp active`) | Display currently designated active plan and its declared boundaries. |
| **Set Buffer** | `/aapp-active <plan-id>` (or `aapp active <plan-id>`) | Point local worktree execution buffer to `<plan-id>` (stashing prior in `.prev`). |
| **Swap Buffer** | `/aapp-active swap` (or `aapp active swap`) | Toggle between current and previously active plan (like `git checkout -`). |
| **Clear Buffer** | `/aapp-active clear` (or `aapp active clear`) | Clear the local buffer, reverting to auto-discovery mode. |

---
*Canonical Specification: Refer to `.agents/AGENTS.md` for full protocol governance.*
